package com.oneviw.oneviw_flutter_sdk

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Reads OneViw configuration from `<meta-data>` entries declared in the host
 * app's AndroidManifest.xml:
 *
 *   <meta-data android:name="oneviw.PROJECT_TOKEN" android:value="..." />
 *   <meta-data android:name="oneviw.HOST"           android:value="https://your-oneviw-host" />
 *   <meta-data android:name="oneviw.DEBUG"         android:value="true" />   (optional)
 *   <meta-data android:name="oneviw.DISABLE_ATTRIBUTION" android:value="false" />   (optional)
 *   <meta-data android:name="oneviw.REGISTER_CAMPAIGN_SUPER_PROPERTIES" android:value="true" />   (optional)
 */
class OneviwFlutterSdkPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    private companion object {
        const val CHANNEL_NAME = "oneviw_flutter_sdk"
        const val KEY_PROJECT_TOKEN = "oneviw.PROJECT_TOKEN"
        const val KEY_HOST = "oneviw.HOST"
        const val KEY_DEBUG = "oneviw.DEBUG"
        const val KEY_DISABLE_ATTRIBUTION = "oneviw.DISABLE_ATTRIBUTION"
        const val KEY_REGISTER_CAMPAIGN_SUPER_PROPERTIES =
            "oneviw.REGISTER_CAMPAIGN_SUPER_PROPERTIES"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getNativeConfig" -> result.success(readNativeConfig())
            else -> result.notImplemented()
        }
    }

    private fun readNativeConfig(): Map<String, Any?> {
        val config = HashMap<String, Any?>()
        val metaData = applicationMetaData() ?: return config

        metaData.getString(KEY_PROJECT_TOKEN)?.let { config["projectToken"] = it }
        metaData.getString(KEY_HOST)?.let { config["host"] = it }
        if (metaData.containsKey(KEY_DEBUG)) {
            config["debug"] = metaData.getBoolean(KEY_DEBUG, false)
        }
        if (metaData.containsKey(KEY_DISABLE_ATTRIBUTION)) {
            config["disableAttribution"] =
                metaData.getBoolean(KEY_DISABLE_ATTRIBUTION, false)
        }
        if (metaData.containsKey(KEY_REGISTER_CAMPAIGN_SUPER_PROPERTIES)) {
            config["registerCampaignSuperProperties"] =
                metaData.getBoolean(KEY_REGISTER_CAMPAIGN_SUPER_PROPERTIES, true)
        }
        return config
    }

    private fun applicationMetaData(): Bundle? {
        return try {
            val appInfo: ApplicationInfo = context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA,
            )
            appInfo.metaData
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
