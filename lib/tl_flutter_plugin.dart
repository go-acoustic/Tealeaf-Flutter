import 'dart:async';

import 'package:flutter/services.dart';
// import 'package:yaml/yaml.dart';

// ignore: unused_import
import 'tealeaf_aop.dart';
import 'logger.dart';

class TealeafException implements Exception {
  TealeafException.create(
      {required int code,
      required this.msg,
      this.nativeMsg,
      this.nativeStacktrace,
      this.nativeDetails}) {
    this.code = _getCode(code);
  }

  TealeafException(PlatformException pe, {this.msg})
      : code = pe.code,
        nativeStacktrace = pe.stacktrace,
        nativeMsg = pe.message,
        nativeDetails = pe.details?.toString();

  static String logErrorMsg = 'Error logging an exception';
  static int codeBase = 600;

  String? nativeStacktrace;
  String? nativeDetails;
  String? nativeMsg;
  String? msg;
  String? code;

  static String _getCode(int num) => 'Tealeaf API error: #${num + codeBase}';
  String? get getMsg => msg;
  String? get getNativeMsg => nativeMsg;
  String? get getNativeStacktrace => nativeStacktrace;
  String? get getNativeDetails => nativeDetails;
}

class PluginTealeaf {
  static const MethodChannel _channel = MethodChannel('tl_flutter_plugin');

  static Future<String> get platformVersion async {
    try {
      return await _channel.invokeMethod('getPlatformVersion');
    } on PlatformException catch (pe) {
      throw TealeafException(pe,
          msg: 'Unable to process platform version request message!');
    }
  }

  static Future<String> get tealeafVersion async {
    try {
      final String version = await _channel.invokeMethod('getTealeafVersion');
      tlLogger.v("Tealeaf version: $version");
      return version;
    } on PlatformException catch (pe) {
      throw TealeafException(pe,
          msg: 'Unable to process TeaLeaf request version message!');
    }
  }

  static Future<String> get tealeafSessionId async {
    try {
      final String sessionId =
          await _channel.invokeMethod('getTealeafSessionId');
      tlLogger.v("Tealeaf sessionId: $sessionId");
      return sessionId;
    } on PlatformException catch (pe) {
      throw TealeafException(pe,
          msg: 'Unable to process Tealeaf request sessionId message!');
    }
  }

  static Future<String> get pluginVersion async {
    try {

      // TODO:
      // final String pubspecData = ("See tl_flutter_plugin version in pubspec.yaml.");
      
      return "2.0.0";
    } on Exception catch (e) {
      throw TealeafException.create(
          code: 7, msg: 'Unable to obtain platform version: ${e.toString()}');
    }
  }

  static Future<String> get appKey async {
    try {
      return await _channel.invokeMethod('getAppKey');
    } on PlatformException catch (pe) {
      throw TealeafException(pe,
          msg: 'Unable to process app key request message!');
    }
  }

  static Future<void> tlSetEnvironment(
      {required int screenWidth, required int screenHeight}) async {
    try {
      await _channel.invokeMethod(
          'setenv', {'screenw': screenWidth, 'screenh': screenHeight});
    } on PlatformException catch (pe) {
      throw TealeafException(pe,
          msg: 'Unable to send Flutter screen parameters message!');
    }
  }

  static Future<void> tlConnection(
      {required String url,
      required int statusCode,
      String description = '',
      int responseSize = 0,
      int initTime = 0,
      int loadTime = 0,
      responseTime = 0}) async {
    if (responseTime == 0) {
      responseTime = loadTime - initTime;
    }
    try {
      await _channel.invokeMethod('connection', {
        'url': url,
        'statusCode': statusCode.toString(),
        'responseDataSize': responseSize.toString(),
        'initTime': initTime.toString(),
        'loadTime': loadTime.toString(),
        'responseTime': responseTime.toString(),
        'description': description
      });
    } on PlatformException catch (pe) {
      throw TealeafException(pe, msg: 'Unable to process connection message!');
    }
  }

  static Future<void> tlApplicationCustomEvent(
      {required String? eventName,
      Map<String, String>? customData,
      int? logLevel}) async {
    if (eventName == null) {
      throw TealeafException.create(code: 6, msg: 'eventName is null');
    }
    try {
      await _channel.invokeMethod('customevent',
          {'eventname': eventName, 'loglevel': logLevel, 'data': customData});
    } on PlatformException catch (pe) {
      throw TealeafException(pe,
          msg: 'Unable to process custom event message!');
    }
  }

  static Future<void> tlApplicationCaughtException(
      {Exception? caughtException,
      StackTrace? stack,
      Map<String, String>? appData}) async {
    try {
      if (caughtException == null) {
        throw TealeafException.create(
            code: 4, msg: 'User caughtException is null');
      }
      await _channel.invokeMethod('exception', {
        "name": caughtException.runtimeType.toString(),
        "message": caughtException.toString(),
        "stacktrace": stack == null ? "" : stack.toString(),
        "handled": true,
        "appdata": appData
      });
    } on PlatformException catch (pe) {
      throw TealeafException(pe,
          msg: 'Unable to process user caught exception message!');
    }
  }

  static Future<void> onTlException(
      {required Map<dynamic, dynamic> data}) async {
    try {
      await _channel.invokeMethod('exception', data);
    } on PlatformException catch (pe) {
      tlLogger.v(
          'Unable to log app exception: ${pe.message}, stack: ${pe.stacktrace}');
      throw TealeafException(pe, msg: TealeafException.logErrorMsg);
    }
  }

  static Future<void> onTlPointerEvent({required Map fields}) async {
    tlLogger.v('fields: ${fields.toString()}');

    try {
      await _channel.invokeMethod('pointerEvent', fields);
    } on PlatformException catch (pe, stack) {
      tlLogger.v(
          "pointerEvent exception: ${pe.toString()}, stack: ${stack.toString()}");
      throw TealeafException(pe,
          msg: 'Unable to process flutter pointer event message!');
    }
  }

  static Future<void> onTlGestureEvent(
      {required String? gesture,
      required String id,
      required String target,
      Map<String, dynamic>? data,
      List<Map<String, dynamic>>? layoutParameters}) async {
    try {
      if (["pinch", "swipe", "taphold", "doubletap", "tap"].contains(gesture)) {
        return await _channel.invokeMethod('gesture', <dynamic, dynamic>{
          'tlType': gesture,
          'id': id,
          'target': target,
          'data': data,
          'layoutParameters': layoutParameters
        });
      }
      throw TealeafException.create(
          code: 3, msg: 'Illegal gesture type: "$gesture"');
    } on PlatformException catch (pe) {
      throw TealeafException(pe, msg: 'Unable to process gesture message!');
    }
  }

  static Future<void> onScreenview(String tlType, Duration timestamp,
      [List<Map<String, dynamic>>? layoutParameters]) async {
    try {
      if (["LOAD", "UNLOAD", "VISIT"].contains(tlType)) {
        final String timeString = timestamp.inMicroseconds.toString();

        return await _channel.invokeMethod('screenview', <dynamic, dynamic>{
          'tlType': tlType,
          'timeStamp': timeString,
          'layoutParameters': layoutParameters
        });
      }

      throw TealeafException.create(
          code: 2, msg: 'Illegal screenview transition type');
    } on PlatformException catch (pe) {
      throw TealeafException(pe,
          msg: 'Unable to process screen view (update) message!');
    }
  }

  static Future<String> getGlobalConfiguration() async {
    try {
      return await _channel.invokeMethod('getGlobalConfiguration');
    } on PlatformException catch (pe) {
      throw TealeafException(pe,
          msg: 'Unable to process global configuration settings message!');
    }
  }

  static Future<String> maskText(String text, [String? page]) async {
    try {
      return await _channel.invokeMethod(
          'maskText', <dynamic, dynamic>{'text': text, 'page': page ?? ""});
    } on PlatformException catch (pe) {
      throw TealeafException(pe,
          msg: 'Unable to process string masking request!');
    }
  }

  static Future<void> badCall() async {
    await _channel.invokeMethod('no such method');
  }

  static bool aspectdTest() {
    tlLogger.v("Test NOT injected!");
    // If aspectd is working, we will inject replacement call with a return of 'true'
    return false;
  }
}
