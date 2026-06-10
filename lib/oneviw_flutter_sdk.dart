/// OneViw analytics & product-insights SDK for Flutter.
///
/// Initialize once at startup, then capture events, identify users, evaluate
/// feature flags, and more:
///
/// ```dart
/// import 'package:oneviw_flutter_sdk/oneviw_flutter_sdk.dart';
///
/// await OneViw().setup(OneViwConfig('<project_token>'));
/// await OneViw().capture(eventName: 'app_opened');
/// ```
library oneviw_flutter_sdk;

export 'src/attribution/campaign_keys.dart'
    show defaultCampaignKeys, clickIdKeys;
export 'src/oneviw.dart';
export 'src/oneviw_config.dart';
export 'src/oneviw_feature_flag_result.dart';
export 'src/oneviw_observer.dart';
export 'src/oneviw_widget.dart';
