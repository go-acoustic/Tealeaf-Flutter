import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logger.dart';
import 'dart:convert';

/// A widget that logs UI change events.
///
/// This [Tealeaf] widget listens to pointer events such as onPointerDown, onPointerUp, onPointerMove, and onPointerCancel.
/// It logs these events by printing them to the console if the app is running in debug mode.
/// Use this widget to log UI changes and interactions during development and debugging.
class Tealeaf extends StatelessWidget {
  /// The child widget to which the [Tealeaf] is applied.
  final Widget child;

  /// Use as reference time to calculate widget load time
  static int startTime = DateTime.now().millisecondsSinceEpoch;

  static bool showDebugLog = false;

  // Create an instance of LoggingNavigatorObserver
  static final LoggingNavigatorObserver loggingNavigatorObserver =
      LoggingNavigatorObserver();

  /// Constructs a [Tealeaf] with the given child.
  ///
  /// The [child] parameter is the widget to which the [Tealeaf] is applied.
  Tealeaf({Key? key, required this.child}) : super(key: key);

  static void init(bool printLog) {
    startTime = DateTime.now().millisecondsSinceEpoch;
    showDebugLog = printLog;
  }

  @override
  Widget build(BuildContext context) {
    UserInteractionLogger.initialize(); // Initialize the UserInteractionLogger

    return Listener(
      onPointerUp: (details) {
        // Start time as reference when there's navigation change
        Tealeaf.startTime = DateTime.now().millisecondsSinceEpoch;
      },
      child: child,
    );
  }

  ///
  /// Converts erorr details
  ///
  static Map<String, dynamic> flutterErrorDetailsToMap(
      FlutterErrorDetails details) {
    return {
      'message': details.exception.toString(),
      'exceptionType': details.exception.runtimeType.toString(),
      'stacktrace': details.stack.toString(),
      'library': details.library,
      'name': details.context.toString(),
      'silent': details.silent,
      'handled': false,
      // Add other fields as needed
    };
  }
}

/// A navigator observer that logs navigation events using the Tealeaf plugin.
///
/// This [NavigatorObserver] subclass logs the navigation events, such as push and pop,
/// and communicates with the Tealeaf plugin to log the screen layout events.
class LoggingNavigatorObserver extends NavigatorObserver {
  /// Constructs a [LoggingNavigatorObserver].
  LoggingNavigatorObserver() : super();

  /// Called when a route is pushed onto the navigator.
  ///
  /// The `route` parameter represents the route being pushed onto the navigator.
  /// The `previousRoute` parameter represents the route that was previously on top of the navigator.
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // final startTime = DateTime.now().millisecondsSinceEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final endTime = DateTime.now().millisecondsSinceEpoch;
      final int duration = endTime - Tealeaf.startTime;

      PluginTealeaf.tlApplicationCustomEvent(
        eventName: 'Performance Metric',
        customData: {
          'Navigation': route.settings.name.toString(),
          'Load Time': duration.toString(),
        },
        logLevel: 1,
      );
    });

    PluginTealeaf.logScreenLayout('LOAD', route.settings.name.toString());
    _logWidgetTree();

    tlLogger.v('PluginTealeaf.logScreenLayout - Pushed ${route.settings.name}');
  }

  /// Called when a route is popped from the navigator.
  ///
  /// The `route` parameter represents the route being popped from the navigator.
  /// The `previousRoute` parameter represents the route that will now be on top of the navigator.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    PluginTealeaf.logScreenViewContextUnLoad(route.settings.name.toString(),
        previousRoute != null ? previousRoute.settings.name.toString() : "");

    tlLogger.v(
        'PluginTealeaf.logScreenViewContextUnLoad -Popped ${route.settings.name}');
  }
}

///
/// Log tree from current screen frame.
///
void _logWidgetTree() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    WidgetsFlutterBinding.ensureInitialized();

    // ignore: deprecated_member_use
    final element = WidgetsBinding.instance.renderViewElement;
    if (element != null) {
      _parseWidgetTree(element);
    }
  });
}

List<Map<String, dynamic>> _parseWidgetTree(Element element) {
  final widgetTree = <Map<String, dynamic>>[];

  // Recursively parse the widget tree
  void traverse(Element element, [int depth = 0]) {
    final widget = element.widget;
    final type = widget.runtimeType.toString();

    // For accessibility
    //getSemanticsNode(element);

    if (widget is Text ||
        widget is ElevatedButton ||
        widget is TextFormField ||
        widget is TextField ||
        widget is Checkbox ||
        widget is CheckboxListTile ||
        widget is Switch ||
        widget is SwitchListTile ||
        widget is Slider ||
        widget is Radio ||
        widget is RadioListTile ||
        widget is DropdownButton ||
        widget is DropdownMenuItem ||
        widget is ListView ||
        widget is GridView ||
        widget is Card ||
        widget is AppBar ||
        widget is BottomNavigationBar ||
        widget is Drawer ||
        widget is AlertDialog ||
        widget is SnackBar ||
        widget is Image ||
        widget is Icon) {
      final renderObject = element.renderObject as RenderBox?;
      final position = renderObject?.localToGlobal(Offset.zero);
      final size = renderObject?.size;

      final widgetData = {
        'type': type,
        'text': widget is Text ? widget.data : "",
        'position': position != null
            ? 'x: ${position.dx}, y: ${position.dy}, width: ${size?.width}, height: ${size?.height}'
            : "",
      };

      tlLogger.v('WidgetData - ${widget.toString()}');

      widgetTree.add(widgetData);
    }

    element.visitChildren((child) {
      traverse(child, depth + 1);
      return;
    });
  }

  // Starting to parse tree
  traverse(element, 0);

  // Encode the JSON object
  String jsonString = jsonEncode(widgetTree);

  PluginTealeaf.tlApplicationCustomEvent(eventName: jsonString);

  return widgetTree;
}

///
/// Tealeaf Log Exception.
///
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

///
/// Tealeaf Plugin API calls.
///
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
      Map<String, String?>? customData,
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

  ///
  /// For Application level handled exception
  ///
  static Future<void> tlApplicationCaughtException(
      {dynamic caughtException,
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

  ///
  /// For global unhandled exception
  ///
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

  /// Logs a screen layout event to the app. The event can be a load, unload, or visit event.
  ///
  /// The `tlType` argument should be a string representing the type of screen transition:
  /// - "LOAD" for when the screen is being loaded,
  /// - "UNLOAD" for when the screen is being unloaded,
  /// - "VISIT" for when the screen is visited.
  ///
  /// The `name` argument is the name of the screen that is being transitioned to/from.
  ///
  /// Throws a [TealeafException] if the provided `tlType` argument is not one of the allowed types
  /// or when the native platform throws a [PlatformException].
  static Future<void> logScreenLayout(String tlType, String name) async {
    try {
      if (["LOAD", "UNLOAD", "VISIT"].contains(tlType)) {
        // final String timeString = timestamp.inMicroseconds.toString();

        // Send the screen view event to the native side
        return await _channel.invokeMethod('logScreenLayout',
            <dynamic, dynamic>{'tlType': tlType, 'name': name});
      }

      throw TealeafException.create(
          code: 2, msg: 'Illegal screenview transition type');
    } on PlatformException catch (pe) {
      throw TealeafException(pe,
          msg: 'Unable to process screen view (update) message!');
    }
  }

  static Future<void> logScreenViewContextUnLoad(
      String logicalPageName, String referrer) async {
    try {
      // Send the screen view event to the native side
      return await _channel.invokeMethod('logScreenViewContextUnLoad',
          <dynamic, dynamic>{'name': logicalPageName, 'referrer': referrer});
    } on PlatformException catch (pe) {
      throw TealeafException(pe,
          msg:
              'Unable to process logScreenViewContextUnLoad (update) message!');
    }
  }

  /// Triggers a screen view event in the app. The event can be a load, unload or visit event.
  ///
  /// The `tlType` argument should be a string representing the type of screen transition:
  /// - "LOAD" for when the screen is being loaded,
  /// - "UNLOAD" for when the screen is being unloaded,
  /// - "VISIT" for when the screen is visited.
  ///
  /// The `timestamp` argument should be a [Duration] object representing the point in time
  /// the screen transition happened.
  ///
  /// The `layoutParameters` is an optional list of maps where each map has a `String` key and dynamic value.
  /// It can be used to pass extra parameters related to the screen transition.
  ///
  /// Throws a [TealeafException] if the provided `tlType` argument is not one of the allowed types
  /// or when the native platform throws a [PlatformException].
  static Future<void> onScreenview(String tlType, Duration timestamp,
      [List<Map<String, dynamic>>? layoutParameters]) async {
    try {
      if (["LOAD", "UNLOAD", "VISIT"].contains(tlType)) {
        final String timeString = timestamp.inMicroseconds.toString();

        // Send the screen view event to the native side
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

///
/// UI Interaction Logger
///
class UserInteractionLogger {
  static void initialize() {
    ///
    /// Catch unhandled app exception
    ///
    FlutterError.onError = (errorDetails) {
      PluginTealeaf.onTlException(
          data: Tealeaf.flutterErrorDetailsToMap(errorDetails));
    };
    // _setupGestureLogging();
    // _setupNavigationLogging();
    _setupPerformanceLogging();
  }

  // static void _setupGestureLogging() {
  //   // Enable gesture logging
  //   GestureBinding.instance.pointerRouter.addGlobalRoute((PointerEvent event) {
  //     _channel.invokeMethod('logGesture', <String, dynamic>{
  //       'timestamp': DateTime.now().millisecondsSinceEpoch,
  //       'event': describeEnum(event.runtimeType),
  //       // Add additional properties based on the event type if needed
  //     });
  //   });
  // }

  // static void _setupNavigationLogging() {
  // Enable navigation change logging
  // final RouteObserver<PageRoute<dynamic>> routeObserver =
  //     RouteObserver<PageRoute<dynamic>>();
  // Navigator.observer = routeObserver;
  // routeObserver.subscribe(null, (Route<dynamic> route, Route<dynamic>? previousRoute) {
  //   _channel.invokeMethod('logNavigationChange', <String, dynamic>{
  //     'timestamp': DateTime.now().millisecondsSinceEpoch,
  //     'from': previousRoute?.settings.name,
  //     'to': route.settings.name,
  //   });
  // } as PageRoute);
  // }

  static void _setupPerformanceLogging() {
    // Enable performance metric logging
    WidgetsBinding.instance.addObserver(PerformanceObserver());
  }
}

/// Log App Performance
///
///
class PerformanceObserver extends WidgetsBindingObserver {
  void _performanceCustomEvent(AppLifecycleState state) {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final endTime = DateTime.now().millisecondsSinceEpoch;
      final int duration = endTime - startTime;

      PluginTealeaf.tlApplicationCustomEvent(
        eventName: 'Performance Metric',
        customData: {
          'AppLifecycleState': state.toString(),
          'Load Time': duration.toString(),
        },
        logLevel: 1,
      );

      tlLogger.v('_PerformanceObserver($state): $duration');
    });
  }

  @override
  void didHaveMemoryPressure() {
    PluginTealeaf.tlApplicationCustomEvent(
      eventName: 'Performance Metric',
      customData: {
        'didHaveMemoryPressure': 'true',
      },
      logLevel: 1,
    );

    super.didHaveMemoryPressure();
  }

  // @override
  // void didChangeMetrics() {
  //   final startTime = DateTime.now().millisecondsSinceEpoch;
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     // This callback will be executed after the frame is rendered.
  //     final endTime = DateTime.now().millisecondsSinceEpoch;
  //     final duration = endTime - startTime;
  //     print("Frame rendering duration: ${duration}ms");

  //     PluginTealeaf.tlApplicationCustomEvent(
  //       eventName: 'Performance Metric',
  //       customData: {
  //         'didChangeMetrics': 'UI changes such as rotation.',
  //         'Load Time': duration.toString(),
  //       },
  //       logLevel: 1,
  //     );
  //   });

  //   super.didChangeMetrics();
  // }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _performanceCustomEvent(state);
  }
}
