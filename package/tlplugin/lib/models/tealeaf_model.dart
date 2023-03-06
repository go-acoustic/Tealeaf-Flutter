import 'layout_config_model.dart';

class Tealeaf {
  bool? killSwitchEnabled;
  String? killSwitchUrl;
  String? postMessageUrl;
  String? appKey;
  int? killSwitchMaxNumberOfTries;
  int? killSwitchTimeInterval;
  bool? useWhiteList;
  String? whiteListParam;
  int? printScreen;
  int? maxStringsLength;
  bool? cookieSecure;
  int? sessionTimeout;
  String? screenshotFormat;
  int? percentOfScreenshotsSize;
  int? percentToCompressImage;
  double? screenShotPixelDensity;
  bool? getImageDataOnScreenLayout;
  bool? setGestureDetector;
  bool? logLocationEnabled;
  bool? disableAutoInstrumentation;
  LayoutConfig? layoutConfig;

  Tealeaf(
      {this.killSwitchEnabled,
      this.killSwitchUrl,
      this.postMessageUrl,
      this.appKey,
      this.killSwitchMaxNumberOfTries,
      this.killSwitchTimeInterval,
      this.useWhiteList,
      this.whiteListParam,
      this.printScreen,
      this.maxStringsLength,
      this.cookieSecure,
      this.sessionTimeout,
      this.screenshotFormat,
      this.percentOfScreenshotsSize,
      this.percentToCompressImage,
      this.screenShotPixelDensity,
      this.getImageDataOnScreenLayout,
      this.setGestureDetector,
      this.logLocationEnabled,
      this.disableAutoInstrumentation,
      this.layoutConfig});

  Tealeaf.fromJson(Map<String, dynamic> json) {
    killSwitchEnabled = json['KillSwitchEnabled'];
    killSwitchUrl = json['KillSwitchUrl'];
    postMessageUrl = json['PostMessageUrl'];
    appKey = json['AppKey'];
    killSwitchMaxNumberOfTries = json['KillSwitchMaxNumberOfTries'];
    killSwitchTimeInterval = json['KillSwitchTimeInterval'];
    useWhiteList = json['UseWhiteList'];
    whiteListParam = json['WhiteListParam'];
    printScreen = json['PrintScreen'];
    maxStringsLength = json['MaxStringsLength'];
    cookieSecure = json['CookieSecure'];
    sessionTimeout = json['SessionTimeout'];
    screenshotFormat = json['ScreenshotFormat'];
    percentOfScreenshotsSize = json['PercentOfScreenshotsSize'];
    percentToCompressImage = json['PercentToCompressImage'];
    screenShotPixelDensity = json['ScreenShotPixelDensity'];
    getImageDataOnScreenLayout = json['GetImageDataOnScreenLayout'];
    setGestureDetector = json['SetGestureDetector'];
    logLocationEnabled = json['LogLocationEnabled'];
    disableAutoInstrumentation = json['DisableAutoInstrumentation'];

    layoutConfig = json['layoutConfig'] != null
        ? LayoutConfig.fromJson(json['layoutConfig'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (killSwitchEnabled != null) {
      data['KillSwitchEnabled'] = killSwitchEnabled;
    }

    if (killSwitchUrl != null) {
      data['KillSwitchUrl'] = killSwitchUrl;
    }

    if (postMessageUrl != null) {
      data['PostMessageUrl'] = postMessageUrl;
    }

    if (appKey != null) {
      data['AppKey'] = appKey;
    }

    if (killSwitchMaxNumberOfTries != null) {
      data['KillSwitchMaxNumberOfTries'] = killSwitchMaxNumberOfTries;
    }

    if (killSwitchTimeInterval != null) {
      data['KillSwitchTimeInterval'] = killSwitchTimeInterval;
    }

    if (useWhiteList != null) {
      data['UseWhiteList'] = useWhiteList;
    }

    if (whiteListParam != null) {
      data['WhiteListParam'] = whiteListParam;
    }

    if (printScreen != null) {
      data['PrintScreen'] = printScreen;
    }

    if (maxStringsLength != null) {
      data['MaxStringsLength'] = maxStringsLength;
    }

    if (cookieSecure != null) {
      data['CookieSecure'] = cookieSecure;
    }

    if (sessionTimeout != null) {
      data['SessionTimeout'] = sessionTimeout;
    }

    if (screenshotFormat != null) {
      data['ScreenshotFormat'] = screenshotFormat;
    }

    if (percentOfScreenshotsSize != null) {
      data['PercentOfScreenshotsSize'] = percentOfScreenshotsSize;
    }

    if (percentToCompressImage != null) {
      data['PercentToCompressImage'] = percentToCompressImage;
    }

    if (screenShotPixelDensity != null) {
      data['ScreenShotPixelDensity'] = screenShotPixelDensity;
    }

    if (getImageDataOnScreenLayout != null) {
      data['GetImageDataOnScreenLayout'] = getImageDataOnScreenLayout;
    }

    if (setGestureDetector != null) {
      data['SetGestureDetector'] = setGestureDetector;
    }

    if (logLocationEnabled != null) {
      data['LogLocationEnabled'] = logLocationEnabled;
    }

    if (disableAutoInstrumentation != null) {
      data['DisableAutoInstrumentation'] = disableAutoInstrumentation;
    }

    if (layoutConfig != null) {
      data['layoutConfig'] = layoutConfig!.toJson();
    }

    if (layoutConfig != null) {
      data['layoutConfig'] = layoutConfig!.toJson();
    }
    return data;
  }
}
