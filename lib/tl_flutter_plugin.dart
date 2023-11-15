import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tl_flutter_plugin/tl_flutter_plugin_helper.dart';

import 'logger.dart';
import 'dart:convert';
import 'package:flutter/rendering.dart';

/// A widget that logs UI change events.
///
/// This [Tealeaf] widget listens to pointer events such as onPointerDown, onPointerUp, onPointerMove, and onPointerCancel.
/// It logs these events by printing them to the console if the app is running in debug mode.
/// Use this widget to log UI changes and interactions during development and debugging.
class Tealeaf extends StatelessWidget {
  /// The child widget to which the [Tealeaf] is applied.
  final Widget child;
  // final Function(GestureEvent) onGesture;
  final Widget rootWidget; // Store a reference to the root widget

  /// Use as reference time to calculate widget load time
  static int startTime = DateTime.now().millisecondsSinceEpoch;

  static bool showDebugLog = false;

  // Create an instance of LoggingNavigatorObserver
  static final LoggingNavigatorObserver loggingNavigatorObserver =
      LoggingNavigatorObserver();

  /// Constructs a [Tealeaf] with the given child.
  ///
  /// The [child] parameter is the widget to which the [Tealeaf] is applied.
  Tealeaf({Key? key, required this.child})
      : rootWidget = child,
        super(key: key);

  static void init(bool printLog) {
    startTime = DateTime.now().millisecondsSinceEpoch;
    showDebugLog = printLog;

    /// Handles screen layout data, and Gesture events
    TlBinder().init();
  }

  @override
  Widget build(BuildContext context) {
    UserInteractionLogger.initialize();

    Widget? widget = context.widget;

    tlLogger.v(
        'GestureDetector Build WIDGET: ${widget.runtimeType.toString()} ${widget.hashCode}');
    final WidgetPath wp = WidgetPath.create(context, hash: true);
    wp.addInstance(widget.hashCode);
    wp.addParameters(<String, dynamic>{'type': widget.runtimeType.toString()});

    return NotificationListener(
      onNotification: (Notification? notification) {
        if (notification is ScrollStartNotification) {
          final ScrollStartNotification scrollStartNotification = notification;
          final DragStartDetails? details = scrollStartNotification.dragDetails;
          TlBinder()
              .startScroll(details?.globalPosition, details?.sourceTimeStamp);
        } else if (notification is ScrollUpdateNotification) {
          final ScrollUpdateNotification scrollUpdateNotification =
              notification;
          final DragUpdateDetails? details =
              scrollUpdateNotification.dragDetails;
          TlBinder()
              .updateScroll(details?.globalPosition, details?.sourceTimeStamp);
        } else if (notification is ScrollEndNotification) {
          final ScrollEndNotification scrollEndNotification = notification;
          final DragEndDetails? details = scrollEndNotification.dragDetails;
          TlBinder().endScroll(details?.velocity);
          tlLogger.v('Scroll notification completed');
        }
        return false;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // onTap: () async {
        //   final Widget gesture = GestureDetector(
        //   child: child,
        //   onTap: params['onTap'],
        //   // Configure other properties and callbacks as needed
        //   );
        //   // debugDumpApp();
        // },
        // onTapUp: (TapUpDetails details) async {
        //   // developer.debug(() {
        //   // Isolate.spawn(yourCode, null);

        //   var str = findTouchedWidget(context, details.globalPosition);
        //   final target = details.toString();
        //   debugPrint('The value of count is $details');

        //   // Handle onTap gesture here
        //   await PluginTealeaf.onTlGestureEvent(
        //     gesture: target,
        //     id: wp.widgetPath(),
        //     target: target,
        //     data: null,
        //     layoutParameters: TlBinder.layoutParametersForGestures);
        // },
        child: Listener(
          onPointerUp: (details) async {
            // Handle onPointerUp event here
            // Start time as reference when there's navigation change
            Tealeaf.startTime = DateTime.now().millisecondsSinceEpoch;

            TealeafHelper.pointerEventHelper("UP", details);

            var touchedTarget = findTouchedWidget(context, details.position);
            debugPrint('The value of count is $details');

            // Handle onTap gesture here
            await PluginTealeaf.onTlGestureEvent(
                gesture: "tap",
                id: wp.widgetPath(),
                target: touchedTarget,
                data: null,
                layoutParameters: TlBinder.layoutParametersForGestures);
          },
          onPointerDown: (details) {
            TealeafHelper.pointerEventHelper("DOWN", details);
          },
          onPointerMove: (details) {
            TealeafHelper.pointerEventHelper("MOVE", details);
          },
          child: child,
        ),
      ),
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

  /// Use HitBox test to find touched item on the screen.
  ///
  /// Since the results are just a list of RenderObjects, we'll need to parse the Widget info.
  static String findTouchedWidget(
      final BuildContext context, final Offset position) {
    String jsonString = "";

    final RenderObject? renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      final RenderBox renderBox = renderObject;
      final Size widgetSize = renderBox.size;
      print('Widget size: $widgetSize');

      final Offset localOffset = renderBox.globalToLocal(position);
      print(renderBox);

      // Perform hit-testing
      final BoxHitTestResult result = BoxHitTestResult();
      renderBox.hitTest(result, position: localOffset);

      // Analyze the hit result to find the widget that was touched.
      for (HitTestEntry entry in result.path) {
        if (entry is! BoxHitTestEntry || entry is SliverHitTestEntry) {
          final targetWidget = entry.target;
          print('Touched Widget: $targetWidget');
          print('Touched entry: $entry');
          print('Runtime type: $targetWidget');

          final widgetString = targetWidget.toString();
          jsonString = jsonEncode(widgetString);

          // Check for a specific container type
          if (targetWidget.runtimeType == Container) {
            print('Touched a Container');
          }

          break;
        }
      }
    }
    return jsonString == "" ? "FlutterSurfaceView" : jsonString;
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

    // final WidgetPath wp = WidgetPath.create(context, hash: true);
    // wp.addInstance(widget.hashCode);
    // wp.addParameters(<String, dynamic>{'type': widget.runtimeType.toString()});

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
      /// TODO:  Get all accessibility props.
      // final AccessibleNodeList = TealeafHelper.getAllSemantics(element);

      _parseWidgetTree(element);
    }
  });
}

/// Parses the Flutter widget tree and returns a list of widget data maps.
///
/// [element]: The root element of the widget tree to parse.
List<Map<String, dynamic>> _parseWidgetTree(Element element) {
  final widgetTree = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> accessibilityList = [];

  // Recursively parse the widget tree
  void traverse(Element element, [int depth = 0]) {
    final widget = element.widget;
    final type = widget.runtimeType.toString();

    if (widget is Semantics) {
      final Semantics semantics = widget as Semantics;

      if (semantics.properties.label?.isNotEmpty == true || semantics.properties.label?.isNotEmpty == true) {
        final String? hint = semantics!.properties.hint;
        final String? label = semantics!.properties.label;

        final Map<String, dynamic> accessibility = {};
        accessibility.addAll({
          'accessibility': {
            'id': '/NavigatorObserver',
            'label': label ?? '',
            'hint': hint ?? ''
          }
        });

        accessibilityList.add(accessibility);

        print('Tealeaf - Widget is a semantic type: ${semantics.properties}');
      }
    }
    // For accessibility
    // TealeafHelper.checkForSemantics(element);

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

  /// Records network connection metrics for a specific URL.
  ///
  /// [url]: The URL of the network connection.
  /// [statusCode]: The HTTP status code of the network response.
  /// [description]: Optional description of the network connection.
  /// [responseSize]: Optional size of the network response data, in bytes.
  /// [initTime]: Optional time at which the network request was initiated.
  /// [loadTime]: Optional time at which the network response was received.
  /// [responseTime]: Optional time it took to receive the network response,
  ///   calculated as `loadTime - initTime` if not provided.
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

  /// Sends a custom event to the TeaLeaf platform.
  ///
  /// [eventName]: The name of the custom event.
  /// [customData]: Optional custom data associated with the event.
  /// [logLevel]: Optional log level for the event, where 0 is the lowest and 7 is the highest.
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

  /// Handles incoming gesture events from the Flutter engine.
  ///
  /// [gesture]: The type of gesture, e.g., 'pinch', 'swipe', 'taphold', 'doubletap', or 'tap'.
  /// [id]: The unique identifier of the gesture event.
  /// [target]: The target of the gesture event, e.g., a widget ID.
  /// [data]: Additional data associated with the gesture event, if any.
  /// [layoutParameters]: Layout parameters associated with the gesture event, if any.
  ///
  /// Throws a [TealeafException] if the gesture type is not supported or if there is an error processing the gesture message.
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _performanceCustomEvent(state);
  }
}

class SemanticsFinder extends WidgetsBindingObserver {
  List<SemanticsNode> semanticsNodes = [];

  @override
  void didChangeAccessibilityFeatures() {
    var tree = RendererBinding
        .instance.pipelineOwner.semanticsOwner?.rootSemanticsNode;

    tree?.visitChildren((SemanticsNode node) {
      semanticsNodes?.add(node);
      return true;
    });
  }
}
