import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tl_flutter_plugin/tl_flutter_plugin.dart';
import 'dart:convert';

void main() {
  const String platform = 'Arbitrary platform 47';
  const String tealeaf = '10.3.274';
  const String plugin = '1.0.0';
  const String key = 'valid key';
  const String sessionId = '012345678901234567890123456789ff';
  const String globalConfigJsonString = '{"AppKey": "e753a61c93ab4620aab64648505a9647"}';

  List<Map<String, dynamic>> layoutParameters = [
    {
      "controls": [
        {
          "id":
              "/MA/MA/WA/RRS/RS/SAD/S/DTES/A/L/T/CMB/B/CP/B/SM/AT/T/CT/N/L/AP/O/TM/AB/RS/PS/B/A/RB/AB/DTB/AB/CB/FT/ST/T/FT/ST/T/DTB/AB/CB/FT/ST/T/FT/ST/T/AB/IP/RB/B/S/SNO/M/APM/PM/ADTS/AB/CMCL/SOPD/GD/RGD/L/SCSV/S/GOI/RB/CP/RB/L/RGD/L/IP/C/C/I/1",
          "cssId": "a5f8e5309344a1b3f2ea59bd5376ee98115b749a",
          "idType": -4,
          "type": "Image",
          "subType": "ImageView",
          "position": {"x": 290, "y": 180, "width": 140, "height": 140}
        }
      ]
    }
  ];

  const MethodChannel channel = MethodChannel('tl_flutter_plugin');

  TestWidgetsFlutterBinding.ensureInitialized();

  validateParameter(String request, dynamic args, String arg, List<Type> types, {String prefix = ''}) {
    final dynamic parameter = args[arg];

    if (parameter == null) {
      throw Exception("Request $request missing parameter '$arg'");
    }
    Type type = parameter.runtimeType;

    // TBD: How to check if a Type is a subtype. " is " works,
    // but only on actual compile types, NOT type variables. There must
    // be a way to do this for all types, not just for Map (all that is needed for now)
    if (types.contains(Map) && parameter is Map) {
      const Type newType = Map;
      debugPrint("Checked if type $type is a $newType");
      type = newType;
    }

    if (!types.contains(type)) {
      throw Exception(
          " Request $request parameter '$prefix$arg', type '$type' not allowed");
    }
  }

  validatePosition(String request, dynamic args, String key) {
    validateParameter(request, args, key, [Map]);

    final Map points = args[key];
    final String prefix = '/$key';

    validateParameter(request, points, 'dx', [double], prefix: prefix);
    validateParameter(request, points, 'dy', [double], prefix: prefix);
  }

  void printTealeafException(Exception e) {
    if (kDebugMode) {
      if (e is TealeafException) {
         final TealeafException te = e;
         print("TealeafException: ${te.msg}, platform details: ${te.nativeMsg}, ${te.nativeDetails}");
      }
      else {
        print(e.toString());
      }
    }
  }


  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall == null) {
        throw Exception("methodCall in test mock handler is null!");
      }
      final String request = methodCall.method;
      if (request == null) {
        throw Exception("methodCall.method request is null!");
      }
      final dynamic args = methodCall.arguments;

      switch (request.toLowerCase()) {
        case "getplatformversion":
          return platform;
        case "gettealeafversion":
          return tealeaf;
        case "getpluginversion":
          return plugin;
        case "getappkey":
          return key;
        case "gettealeafsessionid":
          return sessionId;
        case "getglobalconfiguration":
          return globalConfigJsonString;
        case "setenv": 
          if (!args.containsKey('screenw')) {
            throw Exception("tlSetEnvironment missing 'screenw' parameter");
          }
          if (!args.containsKey('screenh')) {
            throw Exception("tlSetEnvironment missing 'screenh' parameter");
          }
          validateParameter(request, args, 'screenw', [int]);
          validateParameter(request, args, 'screenh', [int]);
          if (args['screenw'] <= 0) {
            throw Exception("tlSetEnvironment invalid 'screenw' parameter: $args['screenw']");
          }
          if (args['screenh'] <= 0) {
            throw Exception("tlSetEnvironment invalid 'screenh' parameter: $args['screenh']");
          }
          return null;
        case 'gesture':
          if (!args.containsKey('tlType')) {
            throw Exception("Missing gesture type!");
          }
          if (!['pinch', 'swipe', 'taphold', 'tap', 'doubletap'].contains(args['tlType'])) {
            throw Exception("Gesture type not supported: ${args['tlType']}");
          }
          return null;
        case 'pointerevent':
          if (!args.containsKey('down')) {
            throw Exception("pointerEvent missing 'down' parameter");
          }
          if (!args.containsKey('kind')) {
            throw Exception("pointerEvent missing 'kind' parameter");
          }
          if (!args.containsKey('buttons')) {
            throw Exception("pointerEvent missing 'buttons' parameter");
          }
          if (!args.containsKey('embeddedId')) {
            throw Exception("pointerEvent missing 'embeddedId' parameter");
          }

          validatePosition(request, args, 'position');
          validatePosition(request, args, 'localPosition');
          validateParameter(request, args, "pressure", [double]);
          validateParameter(request, args, 'timestamp', [int]);

          if (args['timestamp'] < 0) {
            throw Exception(
                "pointerEvent invalid 'timestamp' parameter: $args['timestamp']");
          }

          return null;
        case 'connection': {
            validateParameter(request, args, 'url', [String]);
            validateParameter(request, args, 'statusCode', [int, String]);
            validateParameter(request, args, 'initTime', [int, String]);
            validateParameter(request, args, 'loadTime', [int, String]);

            if (args.containsKey('responsesize')) {
              validateParameter(request, args, 'responseSize', [int, String]);
            }
            return null;
        }
        case 'customevent': {
            validateParameter(request, args, 'eventname', [String]);
            if (args.containsKey('logLevel')) {
              validateParameter(request, args, 'loglLevel', [int]);
            }
            if (args.containsKey('data')) {
              validateParameter(request, args, 'data', [Map]);
            }
            return null;
        }
        case 'exception': {
            validateParameter(request, args, 'name', [String]);
            validateParameter(request, args, 'message', [String]);
            validateParameter(request, args, 'handled', [bool]);
            validateParameter(request, args, 'stacktrace', [String]);
            if (args.containsKey('appdata')) {
              validateParameter(request, args, 'appdata', [Map]);
            }
            return null;
        }
        case 'screenview': {
            validateParameter(request, args, 'tlType', [String]);
            validateParameter(request, args, 'timeStamp', [String, int]);

            final String type = args['tlType'];

            if (!["LOAD", "UNLOAD", "VISIT"].contains(type)) {
              throw Exception(
                  "Parameter tlType is not one of the supported tealeaf screen types: $type");
            }
            return null;
        }
        default:
          throw Exception('No such method (in test)');
      }
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  group('PluginTealeaf method call interface', () {
    test('platformVersion', () async {
      expect(await PluginTealeaf.platformVersion, platform);
    });
    test('tealeafVersion', () async {
      expect(await PluginTealeaf.tealeafVersion, tealeaf);
    });
    test('pluginVersion', () async {
      expect(await PluginTealeaf.pluginVersion, plugin);
    });
    test('appKey', () async {
      expect(await PluginTealeaf.appKey, key);
    });

    test('tealeafSessionId', () async {
      String result;
      try {
        await PluginTealeaf.tealeafSessionId;
        result = 'ok';
      } on Exception catch (e) {
        if (kDebugMode) print(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('setenv', () async {
      String result;
      try {
        await PluginTealeaf.tlSetEnvironment(
            screenWidth: 1440, screenHeight: 2880);
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlGestureEvent pinch', () async {
      String result;
      try {
        await PluginTealeaf.onTlGestureEvent(
            gesture: "pinch",
            target: "Text",
            id: "/MA/MA/WA/RRS/RS/SAD/S/DTES/A/L/T/CMB/B/CP/B/SM/AT/T/CT/N/L/AP/O/TM/AB/RS/PS/B/A/RB/AB/DTB/AB/CB/FT/ST/T/FT/ST/T/DTB/AB/CB/FT/ST/T/FT/ST/T/AB/IP/RB/B/S/SNO/M/APM/PM/ADTS/AB/CMCL/SOPD/GD/RGD/L/SCSV/S/GOI/RB/CP/RB/L/RGD/L/IP/C/C/I/1",
            data: {
              'pointer1': {'dx': 47.0, 'dy': 47.0},
              'pointer2': {'dx': 47.0, 'dy': 47.0},
              'dx': 20,
              'dy': 20,
              'direction': "open",
            });
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
	result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlGestureEvent swipe', () async {
      String result;
      try {
        await PluginTealeaf.onTlGestureEvent(
            gesture: "swipe",
            target: "Text",
            id: "/MA/MA/WA/RRS/RS/SAD/S/DTES/A/L/T/CMB/B/CP/B/SM/AT/T/CT/N/L/AP/O/TM/AB/RS/PS/B/A/RB/AB/DTB/AB/CB/FT/ST/T/FT/ST/T/DTB/AB/CB/FT/ST/T/FT/ST/T/AB/IP/RB/B/S/SNO/M/APM/PM/ADTS/AB/CMCL/SOPD/GD/RGD/L/SCSV/S/GOI/RB/CP/RB/L/RGD/L/IP/C/C/I/1",
            data: {
              'pointer1': {'dx': 47.0, 'dy': 47.0, 'ts': '217002223455'},
              'pointer2': {'dx': 47.0, 'dy': 47.0, 'ts': '217002223455'},
              'velocity': {
                'dx': 20,
                'dy': 20,
              },
              'direction': "right",
            });
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlGestureEvent taphold', () async {
      String result;
      try {
        await PluginTealeaf.onTlGestureEvent(
          gesture: "taphold",
          target: "Text",
          id: "/MA/MA/WA/RRS/RS/SAD/S/DTES/A/L/T/CMB/B/CP/B/SM/AT/T/CT/N/L/AP/O/TM/AB/RS/PS/B/A/RB/AB/DTB/AB/CB/FT/ST/T/FT/ST/T/DTB/AB/CB/FT/ST/T/FT/ST/T/AB/IP/RB/B/S/SNO/M/APM/PM/ADTS/AB/CMCL/SOPD/GD/RGD/L/SCSV/S/GOI/RB/CP/RB/L/RGD/L/IP/C/C/I/1",
        );
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlGestureEvent doubletap', () async {
      String result;
      try {
        await PluginTealeaf.onTlGestureEvent(
          gesture: "doubletap",
          target: "Text",
          id: "/MA/MA/WA/RRS/RS/SAD/S/DTES/A/L/T/CMB/B/CP/B/SM/AT/T/CT/N/L/AP/O/TM/AB/RS/PS/B/A/RB/AB/DTB/AB/CB/FT/ST/T/FT/ST/T/DTB/AB/CB/FT/ST/T/FT/ST/T/AB/IP/RB/B/S/SNO/M/APM/PM/ADTS/AB/CMCL/SOPD/GD/RGD/L/SCSV/S/GOI/RB/CP/RB/L/RGD/L/IP/C/C/I/1",
        );
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlGestureEvent tap', () async {
      String result;
      try {
        await PluginTealeaf.onTlGestureEvent(
          gesture: "tap",
          target: "Text",
          id: "/MA/MA/WA/RRS/RS/SAD/S/DTES/A/L/T/CMB/B/CP/B/SM/AT/T/CT/N/L/AP/O/TM/AB/RS/PS/B/A/RB/AB/DTB/AB/CB/FT/ST/T/FT/ST/T/DTB/AB/CB/FT/ST/T/FT/ST/T/AB/IP/RB/B/S/SNO/M/APM/PM/ADTS/AB/CMCL/SOPD/GD/RGD/L/SCSV/S/GOI/RB/CP/RB/L/RGD/L/IP/C/C/I/1",
        );
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('connection', () async {
      String result;
      try {
        await PluginTealeaf.tlConnection(
            url: "www.yahoo.com",
            statusCode: 200,
            responseSize: 47,
            initTime: 114547,
            loadTime: 114600);
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('tlApplicationCustomEvent', () async {
      String result;
      try {
        await PluginTealeaf.tlApplicationCustomEvent(
            eventName: "Custom test event",
            customData: {
              "data1": "END OF UI BUILD",
              "time": DateTime.now().toString()
            });
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('tlApplicationCaughtException on null', () async {
      String result;
      try {
        await PluginTealeaf.tlApplicationCaughtException(caughtException: null);
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'fail');
    });

    test('tlApplicationCaughtException', () async {
      String result;
      try {
        await PluginTealeaf.tlApplicationCaughtException(
            caughtException: Exception("Test Exception"),
            stack: StackTrace.current,
            appData: {"msg": "My error message", "where": "in my main.dart"});
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlException', () async {
      String result;
      Exception e = Exception("This is an exception");
      Map<dynamic, dynamic> mapData = {
        "nativecode": "501",
        "nativemessage": "Native error message",
        "nativestacktrace": "[method1]\n[method2]\n",
        "name": e.runtimeType.toString(),
        "stacktrace": StackTrace.current.toString(),
        "message": e.toString(),
        "handled": true
      };
      try {
        await PluginTealeaf.onTlException(data: mapData);
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onScreenview Load', () async {
      String result;
      try {
        await PluginTealeaf.onScreenview(
            "LOAD", const Duration(seconds: 2), layoutParameters);
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onScreenview Unload', () async {
      String result;
      try {
        await PluginTealeaf.onScreenview(
            "UNLOAD", const Duration(seconds: 2), layoutParameters);
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onScreenview Visit', () async {
      String result;
      try {
        await PluginTealeaf.onScreenview(
            "VISIT", const Duration(seconds: 2), layoutParameters);
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('onTlPointerEvent', () async {
      String result;
      final dynamic ptrFields = {
        'position': {'dx': 47.0, 'dy': 47.0},
        'localPosition': {'dx': 47.0, 'dy': 47.0},
        'down': false,
        'kind': 1,
        'buttons': 0,
        'embeddedId': 0,
        'pressure': 0.47,
        'timestamp': const Duration(microseconds: 47).inMicroseconds,
      };
      try {
        await PluginTealeaf.onTlPointerEvent(fields: ptrFields);
        result = 'ok';
      } on Exception catch (e, stack) {
        debugPrint('$e, ${stack.toString()}');
        result = 'fail';
      }
      expect(result, 'ok');
    });

    test('getGlobalConfiguration', () async {
      bool result;
      try {
        final String response = await PluginTealeaf.getGlobalConfiguration();
        final dynamic map = json.decode(response);
        if (map is Map) {
          result = map.containsKey('AppKey');
        }
        else {
          debugPrint("getGlobalConfiguration 'AppKey' not found!");
        }
      } on Exception catch (e) {
        printTealeafException(e);
        result = false;
      }
      expect(result, true);
    });

    // Test some calls that should fail.
    test('onTlGestureEvent tripletap', () async {
      String result;
      try {
        await PluginTealeaf.onTlGestureEvent(gesture: "tripletap", id: '/xxx/Text', target: 'Text');
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'fail');
    });

    test('noMethodTest', () async {
      String result;
      try {
        await PluginTealeaf.badCall();
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'fail');
    });

    test('onGestureTlEvent bad parameter test', () async {
      String result;
      try {
        await PluginTealeaf.onTlGestureEvent(gesture: "_bad_", id: 'someId', target: 'widgetName');
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'fail');
    });

    test('onTlPointerEvent missing PointerEvent fields test', () async {
      String result;
      final dynamic ptrFields = {
        'position': {'dx': 47.0, 'dy': 47.0},
        'localPosition': {'dx': 47.0, 'dy': 47.0},
        'down': false,
        'kind': 1,
        'buttons': 0,
        'embeddedId': 0,
        'pressure': 0.47,
        'timestemp': DateTime.now().millisecondsSinceEpoch,
      };
      try {
        await PluginTealeaf.onTlPointerEvent(fields: ptrFields);
        result = 'ok';
      } on Exception catch (e) {
        printTealeafException(e);
        result = 'fail';
      }
      expect(result, 'fail');
    });

    // Verify that Aspectd AOP is working.
    test('AspectD injection validation test', () {
      expect(PluginTealeaf.aspectdTest(), true);
    });
  });
}
