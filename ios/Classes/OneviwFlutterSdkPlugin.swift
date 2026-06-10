import Flutter
import Foundation
import WebKit

/// Reads OneViw configuration from the host app's Info.plist:
///
///   oneviw.PROJECT_TOKEN : String
///   oneviw.HOST           : String
///   oneviw.DEBUG         : Bool   (optional)
///   oneviw.DISABLE_ATTRIBUTION : Bool   (optional)
///   oneviw.REGISTER_CAMPAIGN_SUPER_PROPERTIES : Bool   (optional)
///
/// Also performs the iOS vlink attribution request over an off-screen
/// `WKWebView` (the `vlinkAttribute` method call) so it carries WebKit's
/// User-Agent, cookies and TLS for accurate attribution correlation.
public class OneviwFlutterSdkPlugin: NSObject, FlutterPlugin, WKScriptMessageHandler,
    WKNavigationDelegate
{
    private static let channelName = "oneviw_flutter_sdk"
    private static let keyProjectToken = "oneviw.PROJECT_TOKEN"
    private static let keyHost = "oneviw.HOST"
    private static let keyDebug = "oneviw.DEBUG"
    private static let keyDisableAttribution = "oneviw.DISABLE_ATTRIBUTION"
    private static let keyRegisterCampaignSuperProperties =
        "oneviw.REGISTER_CAMPAIGN_SUPER_PROPERTIES"

    private static let messageHandlerName = "oneviw"
    private static let vlinkTimeout: TimeInterval = 60
    // Error code returned when the WKWebView attempted the request but failed
    // (timeout, navigation error, or in-page fetch error). Dart distinguishes
    // this from a missing native handler and treats it as transient.
    private static let vlinkErrorCode = "vlink_failed"

    // Single-slot state for the in-flight vlink request. Install attribution
    // fires once per cold start (deduped in Dart), so concurrency isn't a
    // real concern; a second concurrent call falls back to plain HTTP (nil).
    private var webView: WKWebView?
    private var pendingResult: FlutterResult?
    private var timeoutTimer: Timer?
    private var fetchUrl = ""
    private var authorization = ""

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = OneviwFlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getNativeConfig":
            result(readNativeConfig())
        case "vlinkAttribute":
            guard let args = call.arguments as? [String: Any],
                let url = args["url"] as? String,
                let auth = args["authorization"] as? String
            else {
                result(nil)
                return
            }
            startVlink(url: url, authorization: auth, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Native config

    private func readNativeConfig() -> [String: Any] {
        var config: [String: Any] = [:]
        let info = Bundle.main.infoDictionary ?? [:]

        if let token = info[OneviwFlutterSdkPlugin.keyProjectToken] as? String {
            config["projectToken"] = token
        }
        if let host = info[OneviwFlutterSdkPlugin.keyHost] as? String {
            config["host"] = host
        }
        if let debug = info[OneviwFlutterSdkPlugin.keyDebug] as? Bool {
            config["debug"] = debug
        }
        if let disableAttribution =
            info[OneviwFlutterSdkPlugin.keyDisableAttribution] as? Bool
        {
            config["disableAttribution"] = disableAttribution
        }
        if let registerCampaignSuperProperties =
            info[OneviwFlutterSdkPlugin.keyRegisterCampaignSuperProperties] as? Bool
        {
            config["registerCampaignSuperProperties"] = registerCampaignSuperProperties
        }
        return config
    }

    // MARK: - vlink WKWebView request

    private func startVlink(
        url: String, authorization: String, result: @escaping FlutterResult
    ) {
        // Already busy — let Dart fall back to plain HTTP.
        if pendingResult != nil {
            result(nil)
            return
        }
        guard let endpoint = URL(string: url),
            let scheme = endpoint.scheme,
            let host = endpoint.host
        else {
            result(nil)
            return
        }

        pendingResult = result
        fetchUrl = url
        self.authorization = authorization

        let contentController = WKUserContentController()
        contentController.add(self, name: OneviwFlutterSdkPlugin.messageHandlerName)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        // Load minimal HTML with baseURL = endpoint origin so the injected
        // fetch is same-origin and bypasses CORS.
        var origin = "\(scheme)://\(host)"
        if let port = endpoint.port {
            origin += ":\(port)"
        }
        let baseURL = URL(string: origin)
        webView.loadHTMLString(
            "<!doctype html><html><head></head><body></body></html>",
            baseURL: baseURL
        )

        timeoutTimer = Timer.scheduledTimer(
            withTimeInterval: OneviwFlutterSdkPlugin.vlinkTimeout,
            repeats: false
        ) { [weak self] _ in
            self?.finish(with: nil)
        }
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript(
            buildInjectedFetch(url: fetchUrl, authorization: authorization),
            completionHandler: nil
        )
    }

    public func webView(
        _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
    ) {
        finish(with: nil)
    }

    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(with: nil)
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == OneviwFlutterSdkPlugin.messageHandlerName else { return }
        finish(with: message.body as? String)
    }

    /// Resolve the pending Flutter result once and tear down the WebView.
    ///
    /// A successful body is returned as-is. A `nil` body (timeout / navigation
    /// failure) or the `__oneviw_error` sentinel posted by the injected script
    /// means the WebView ran but failed — that is surfaced as a `FlutterError`
    /// so Dart treats it as a transient failure (no HTTP fallback, no
    /// "attributed" mark, retry next launch) rather than "WebView unavailable".
    private func finish(with body: String?) {
        timeoutTimer?.invalidate()
        timeoutTimer = nil

        let result = pendingResult
        pendingResult = nil

        if let webView = webView {
            webView.configuration.userContentController.removeScriptMessageHandler(
                forName: OneviwFlutterSdkPlugin.messageHandlerName
            )
            webView.navigationDelegate = nil
        }
        webView = nil

        if let body = body, !body.contains("__oneviw_error") {
            result?(body)
        } else {
            result?(
                FlutterError(
                    code: OneviwFlutterSdkPlugin.vlinkErrorCode,
                    message: "vlink WKWebView request failed",
                    details: nil
                )
            )
        }
    }

    private func buildInjectedFetch(url: String, authorization: String) -> String {
        let safeUrl = jsEscape(url)
        let safeAuth = jsEscape(authorization)
        return """
            (function() {
              try {
                fetch("\(safeUrl)", { method: 'GET', headers: { "Authorization": "\(safeAuth)" } })
                  .then(function(r) { return r.text(); })
                  .then(function(t) { window.webkit.messageHandlers.oneviw.postMessage(t); })
                  .catch(function(e) {
                    window.webkit.messageHandlers.oneviw.postMessage(
                      JSON.stringify({ __oneviw_error: String(e && e.message || e) })
                    );
                  });
              } catch (e) {
                window.webkit.messageHandlers.oneviw.postMessage(
                  JSON.stringify({ __oneviw_error: String(e && e.message || e) })
                );
              }
              true;
            })();
            """
    }

    private func jsEscape(_ s: String) -> String {
        return s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
