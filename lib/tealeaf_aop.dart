import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:crypto/crypto.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter/gestures.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter/services.dart';

import 'package:tl_flutter_plugin/aspectd_defs.dart';
import 'package:tl_flutter_plugin/timeit.dart';
import 'package:tl_flutter_plugin/tl_flutter_plugin.dart';
import 'package:tl_flutter_plugin/logger.dart';

// TBD: Add appropriate class documentation (before publishing to pub.dev)

class WidgetPath {
  WidgetPath();

  static const String excl = r'^(Focus|Semantics|InheritedElement|.*\n_).*$';
  static const String reduce = r"[a-z]";
  static const String sep = '/';
  static Hash get digest => sha1;

  static Map<int, dynamic> widgetContexts = {};
  static Map<Widget, String> pathCache = {};

  BuildContext? context;
  Element? parent;
  String? parentWidgetType;
  String? pathHash;
  int? key;
  late bool shorten;
  late bool hash;
  late String path;

  int position = 0;
  bool usedInLayout = false;
  Map<String, dynamic> parameters = {};

  int siblingPosition(Element parent, Widget child) {
    int result;

    try {
      final dynamic currentWidget = parent.widget;
      final List<Widget> children = currentWidget.children;
      result = children.indexOf(child);
    } on NoSuchMethodError {
      result = -1;
    }
    return result;
  }

  WidgetPath.create(this.context,
      {this.shorten = true, this.hash = false, String exclude = excl}) {
    if (context == null) {
      return;
    }

    final StringBuffer path = StringBuffer();
    final RegExp re = RegExp(exclude, multiLine: true);
    final List<dynamic> stk = [];
    final Widget widget = context!.widget;

    String widgetName = '$sep${widget.runtimeType.toString()}';
    Widget? child;

    this.path = '';

    context?.visitAncestorElements((ancestor) {
      final Widget parentWidget = ancestor.widget;
      String prt = parentWidget.runtimeType.toString();
      final String art = '${ancestor.runtimeType.toString()}\n$prt';

      if (stk.isEmpty) {
        parent = ancestor;
      }
      final String? parentPath = pathCache[parentWidget];
      if (parentPath != null) {
        path.write(parentPath);
        return false;
      }
      if (!re.hasMatch(art)) {
        if (child != null) {
          final int index = siblingPosition(ancestor, child!);
          if (index != -1) {
            prt += '_$index';
          }
        }
        stk.add(parentWidget);
        stk.add(makeShorter(prt));
      }
      child = ancestor.widget;
      return true;
    });

    for (int index = stk.length; index > 0;) {
      path.write('$sep${stk[--index]}');
      pathCache[stk[--index]] = path.toString();
    }

    path.write(widgetName);
    this.path = path.toString();
    parentWidgetType = parent!.widget.runtimeType.toString();

    tlLogger.v(
        'Widget path added: ${widget.runtimeType.toString()}, path: $this.path, digest: ${widgetDigest()}');
  }

  List<int> findExistingPathKeys() {
    final List<int> matches = [];

    for (MapEntry<int, dynamic> entry in widgetContexts.entries) {
      final WidgetPath wp = entry.value;
      if (this == wp) {
        tlLogger.v("Skip removing current widget path entry");
        continue;
      }
      if (isEqual(wp)) {
        tlLogger.v("Path match [${entry.key}]");
        matches.add(entry.key);
      }
    }
    return matches;
  }

  bool isEqual(WidgetPath other) {
    final bool equal = path.compareTo(other.path) == 0;
    if (equal) {
      tlLogger.v("Widget paths are equal!");
    }
    return equal;
  }

  void addInstance(int key) {
    final List<int> existingKeys = findExistingPathKeys();
    final int keyCount = existingKeys.length;
    if (keyCount > 0) {
      final WidgetPath firstPath = widgetContexts[existingKeys[0]];
      if (!firstPath.usedInLayout) {
        if (keyCount == 1) {
          firstPath.position = 1;
        }
        position = keyCount + 1;
        tlLogger.v('path sibling, count: $position');
      } else {
        if (existingKeys.contains(key)) {
          WidgetPath wp = widgetContexts[key];
          position = wp.position;
          tlLogger.v('Replacing logged widget: $key, position: $position');
        } else {
          tlLogger.v(
              'Removing $keyCount siblings(new key: $key): ...${firstPath.path.substring(max(0, firstPath.path.length - 90))}');
          for (int eKey in existingKeys) {
            WidgetPath wp = widgetContexts[eKey];
            tlLogger.v(
                'Removing $eKey, position: ${wp.position}, used: ${wp.usedInLayout}');
            removePath(eKey);
          }
        }
      }
    }
    this.key = key;
    widgetContexts[key] = this;
  }

  String widgetPath() => (position == 0) ? path : '$path/$position';

  String? widgetDigest() {
    if (hash && pathHash == null) {
      pathHash = digest.convert(utf8.encode(widgetPath())).toString();
    }
    return pathHash;
  }

  void addParameters(Map<String, dynamic> parameters) =>
      this.parameters.addAll(parameters);

  static WidgetPath? getPath(int key) => widgetContexts[key];
  static void removePath(int? key) {
    if (key != null) widgetContexts.remove(key);
  }

  static bool containsKey(int key) => widgetContexts.containsKey(key);
  static void clear() => widgetContexts.clear();
  static int get size => widgetContexts.length;
  static Function removeWhere = widgetContexts.removeWhere;
  static List<dynamic> entryList() =>
      widgetContexts.entries.toList(growable: false);
  static void clearPathCache() => pathCache.clear();
  String makeShorter(String str) =>
      shorten ? str.replaceAll(RegExp(reduce), '') : str;
}

typedef _Loader = Future<String> Function();

class _TlConfiguration {
  factory _TlConfiguration() => _instance ??= _TlConfiguration._internal();

  _TlConfiguration._internal() {
    _dataLoader ??= PluginTealeaf.getGlobalConfiguration;
  }

  static _Loader? _dataLoader;
  static Map<String, dynamic>? _configureInformation;
  static _TlConfiguration? _instance;

  Future<void> load([dynamic loader]) async {
    if (loader != null) {
      _dataLoader = loader;
      _configureInformation = null;
    }
    if (_configureInformation == null) {
      if (_dataLoader == null) {
        throw Exception("No data loader defined for configuration!");
      }
      final String data = await _dataLoader!();
      _configureInformation = jsonDecode(data);
      tlLogger.v('Global configuration loaded');
    }
  }

  dynamic get(String item) async {
    await load();

    dynamic value = _configureInformation;

    if (item.isNotEmpty) {
      final List<String> ids = item.split('/');
      final int idsLength = ids.length;

      int index;
      for (index = 0; index < idsLength && value != null; index++) {
        if (value is Map) {
          value = (value as Map<String, dynamic>)[ids[index]];
        } else {
          break;
        }
      }
      if (index != idsLength) {
        value = null;
      }
    }
    return value;
  }
}

class _TlBinder extends WidgetsBindingObserver {
  factory _TlBinder() => _instance ?? _TlBinder._internal();

  _TlBinder._internal() {
    _instance = this;
    tlLogger.v('TlBinder INSTANTIATED!!');
  }

  static const bool createRootLayout = false;
  static const bool usePostFrame = false;

  static int rapidFrameRateLimitMs = 160;
  static int rapidSequenceCompleteMs = 2 * rapidFrameRateLimitMs;
  static bool initRapidFrameRate = true;

  static _TlBinder? _instance;
  static List<Map<String, dynamic>>? layoutParametersForGestures;

  bool initEnvironment = true;
  String frameHash = "";
  int screenWidth = 0;
  int screenHeight = 0;
  int lastFrameTime = 0;
  bool loggingScreen = false;
  Timer? logFrameTimer;

  bool? maskingEnabled;
  List<dynamic>? maskIds;
  List<dynamic>? maskValuePatterns;

  _Swipe? scrollCapture;

  void startScroll(Offset? position, Duration? timeStamp) {
    scrollCapture = _Swipe();
    scrollCapture?.startPosition = position ?? Offset(0, 0);
    scrollCapture?.startTimeStamp = timeStamp ?? Duration();
  }

  void updateScroll(Offset? position, Duration? timeStamp) {
    scrollCapture?.updatePosition = position ?? Offset(0, 0);
    scrollCapture?.updateTimestamp = timeStamp ?? Duration();
  }

  void endScroll(Velocity? velocity) {
    scrollCapture?.velocity =
        velocity ?? Velocity(pixelsPerSecond: Offset(0, 0));
    scrollCapture?.calculateSwipe();
  }

  Future<void> checkForScroll() async {
    if (scrollCapture != null) {
      final _Swipe swipe = scrollCapture!;

      scrollCapture = null;

      if (swipe.getUpdatePosition != null && swipe.velocity != null) {
        final Offset? start = swipe.getStartPosition;
        final Offset? end = swipe.getUpdatePosition;
        final Velocity? velocity = swipe.velocity;
        final String direction = swipe.direction;

        tlLogger.v(
            'Scrollable start timestamp: ${swipe.getStartTimestampString()}');
        tlLogger.v(
            'Scrollable, start: ${start?.dx},${start?.dy}, end: ${end?.dx},${end?.dy}, velocity: $velocity, direction: $direction');

        await PluginTealeaf.onTlGestureEvent(
            gesture: 'swipe',
            id: '../Scrollable',
            target: 'Scrollable',
            data: <String, dynamic>{
              'pointer1': {
                'dx': start?.dx,
                'dy': start?.dy,
                'ts': swipe.getStartTimestampString()
              },
              'pointer2': {
                'dx': end?.dx,
                'dy': end?.dy,
                'ts': swipe.getUpdateTimestampString()
              },
              'velocity': {
                'dx': velocity?.pixelsPerSecond.dx,
                'dy': velocity?.pixelsPerSecond.dy
              },
              'direction': direction,
            },
            layoutParameters: _TlBinder.layoutParametersForGestures);
      } else {
        tlLogger.v('Incomplete scroll before frame');
      }
    }
  }

  void init() {
    final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

    binding.addPersistentFrameCallback((timestamp) {
      if (usePostFrame) {
        tlLogger.v("Frame handling with single PostFrame callbacks");
        handleWithPostFrameCallback(binding, timestamp);
      } else {
        tlLogger.v("Frame handling with direct persistent callbacks");
        handleScreenUpdate(timestamp);
      }
    });
    binding.addObserver(this);
  }

  void release() {
    final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

    binding.removeObserver(this);
    WidgetPath.clear();
  }

  Future<bool?> getMaskingEnabled() async {
    if (maskingEnabled == null) {
      maskingEnabled = await _TlConfiguration()
              .get("GlobalScreenSettings/Masking/HasMasking") ??
          false;
      maskIds = await _TlConfiguration()
              .get("GlobalScreenSettings/Masking/MaskIdList") ??
          [];
      maskValuePatterns = await _TlConfiguration()
              .get("GlobalScreenSettings/Masking/MaskValueList") ??
          [];
    }
    return maskingEnabled;
  }

  void logFrameIfChanged(WidgetsBinding binding, Duration timestamp) async {
    final Element? rootViewElement = binding.renderViewElement;

    if (initRapidFrameRate) {
      await getFrameRateConfiguration();
    }

    if (initEnvironment) {
      final RenderObject? rootObject = rootViewElement?.findRenderObject();

      if (rootObject != null) {
        screenWidth = rootObject.paintBounds.width.round();
        screenHeight = rootObject.paintBounds.height.round();

        if (screenWidth != 0 && screenHeight != 0) {
          initEnvironment = false;

          await PluginTealeaf.tlSetEnvironment(
              screenWidth: screenWidth, screenHeight: screenHeight);

          tlLogger.v('TlBinder, renderView w: $screenWidth, h: $screenHeight');
        }
      }
    }

    final int currentTime = DateTime.now().millisecondsSinceEpoch;
    final int elapsed = currentTime - lastFrameTime;
    bool skippingFrame = false;

    if (logFrameTimer != null && logFrameTimer!.isActive) {
      tlLogger.v(
          'Cancelling screenview logging, frame interval, elapsed: $elapsed, start: $currentTime');
      logFrameTimer!.cancel();
      logFrameTimer = null;
      skippingFrame = loggingScreen;
    } else {
      tlLogger.v(
          'Logging screenview, no pending frame, frame interval: $elapsed, start: $currentTime, logging now: $loggingScreen');
    }
    final int waitTime =
        (elapsed < rapidFrameRateLimitMs) ? rapidSequenceCompleteMs : 0;

    void performScreenview() async {
      loggingScreen = true;
      logFrameTimer = null;
      final int timerDelay =
          DateTime.now().millisecondsSinceEpoch - currentTime;
      final int frameInterval = lastFrameTime == 0 ? 0 : elapsed;
      final List<Map<String, dynamic>> layouts = await getAllLayouts();

      WidgetPath.clearPathCache();
      await checkForScroll();
      tlLogger.v(
          'Logging screenview, delay: $timerDelay, wait: $waitTime, frame interval: $frameInterval, Layout count: ${layouts.length}');
      await PluginTealeaf.onScreenview("LOAD", timestamp, layouts);
      loggingScreen = false;
    }

    if (lastFrameTime == 0) {
      tlLogger.v('Logging first frame');
      performScreenview();
    } else if (skippingFrame) {
      tlLogger.v('Logging screenview in process, skipping frame');
    } else {
      tlLogger.v("Logging screenview, wait: $waitTime");
      logFrameTimer =
          Timer(Duration(milliseconds: waitTime), performScreenview);
    }
    lastFrameTime = currentTime;
  }

  void handleWithPostFrameCallback(WidgetsBinding binding, Duration timestamp) {
    binding.addPostFrameCallback((timestamp) => handleScreenUpdate(timestamp));
  }

  void handleScreenUpdate(Duration timestamp) {
    tlLogger.v(
        'Frame callback @$timestamp (widget path map size: ${WidgetPath.size})');

    final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

    logFrameIfChanged(binding, timestamp);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        scrollCapture = null;
        tlLogger.v("Screenview UNLOAD");
        break;
      case AppLifecycleState.resumed:
        tlLogger.v("Screenview VISIT");
        break;
      default:
        tlLogger.v("Screenview: ${state.toString()}");
        break;
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> getFrameRateConfiguration() async {
    rapidFrameRateLimitMs =
        await _TlConfiguration().get("GlobalScreenSettings/RapidFrameRate") ??
            160;
    rapidSequenceCompleteMs =
        await _TlConfiguration().get("GlobalScreenSettings/RapidFrameDone") ??
            (2 * rapidSequenceCompleteMs);
    initRapidFrameRate = false;
  }

  Future<String> maskText(String text) async {
    final bool? maskingEnabled = await getMaskingEnabled();
    if (maskingEnabled!) {
      if ((await _TlConfiguration()
                  .get("GlobalScreenSettings/Masking/HasCustomMask") ??
              "")
          .toString()
          .contains("true")) {
        final String? smallCase = await _TlConfiguration()
            .get("GlobalScreenSettings/Masking/Sensitive/smallCaseAlphabet");
        final String? capitalCase = await _TlConfiguration()
            .get("GlobalScreenSettings/Masking/Sensitive/capitalCaseAlphabet");
        final String? symbol = await _TlConfiguration()
            .get("GlobalScreenSettings/Masking/Sensitive/symbol");
        final String? number = await _TlConfiguration()
            .get("GlobalScreenSettings/Masking/Sensitive/number");

        // Note: The following r"\p{..} expressions have been flagged erroneously as errors in some versions of the IDE
        //       However, they work fine and also do NOT show up in linter, so they do not break CI/CD

        if (smallCase != null) {
          text = text.replaceAll(RegExp(r"\p{Ll}", unicode: true), smallCase);
        }
        if (capitalCase != null) {
          text = text.replaceAll(RegExp(r"\p{Lu}", unicode: true), capitalCase);
        }
        if (symbol != null) {
          text = text.replaceAll(RegExp(r"\p{P}|\p{S}", unicode: true), symbol);
        }
        if (number != null) {
          text = text.replaceAll(RegExp(r"\p{N}", unicode: true), number);
        }
      }
    }
    return text;
  }

  Map<String, dynamic> createRootLayoutControl() {
    return <String, dynamic>{
      "zIndex": 500,
      "type": "FlutterImageView",
      "subType": "UIView",
      "tlType": "image",
      "id": "[w,0],[v,0],[v,0],[FlutterView,0]",
      "position": <String, dynamic>{
        "y": "0",
        "x": "0",
        "width": "$screenWidth",
        "height": "$screenHeight"
      },
      "idType": -4,
      "style": <String, dynamic>{
        "borderColor": 0,
        ""
            "borderAlpha": 1,
        "borderRadius": 0
      },
      "cssId": "w0v0v0FlutterView0",
      "image": <String, dynamic>{
        // If # items change, update item count checks in native code
        "width": "$screenWidth",
        "height": "$screenHeight",
        "value": "",
        "mimeExtension": "",
        "type": "image",
        "base64Image": ""
      }
    };
  }

  Future<List<Map<String, dynamic>>> getAllLayouts() async {
    final List<Map<String, dynamic>> layouts = [];
    final List<dynamic> pathList = WidgetPath.entryList();
    final int pathCount = pathList.length;
    bool hasGestures = false;

    if (createRootLayout) {
      layouts.add(createRootLayoutControl());
    }

    for (dynamic entry in pathList) {
      final MapEntry<int, dynamic> widgetEntry =
          entry as MapEntry<int, dynamic>;
      final int key = widgetEntry.key;
      final WidgetPath wp = widgetEntry.value as WidgetPath;
      final BuildContext? context = wp.context;

      if (context == null) {
        tlLogger.w('Context null for path (removed): ${wp.path}');
        WidgetPath.removePath(key);
        continue;
      }
      final String contextString = context.toString();
      if (contextString.startsWith('State') &&
          contextString.endsWith('(DEFUNCT)(no widget)')) {
        tlLogger
            .v("Deleting obsolete path item: $key, context: $contextString");
        WidgetPath.removePath(key);
        continue;
      }
      final Widget widget = context.widget;
      final Map<String, dynamic> args = wp.parameters;
      final String? type = args['type'] ?? '';
      final String? subType = args['subType'] ?? '';

      wp.usedInLayout = true;

      if (type != null && type.compareTo("GestureDetector") == 0) {
        hasGestures = true;
      } else if (subType != null) {
        final String path = wp.widgetPath();
        final dynamic getData = args['data'];
        Map<String, dynamic>? aStyle;
        Map<String, dynamic>? font;
        Map<String, dynamic>? image;
        String? text;

        Map<String, dynamic>? accessibility = args['accessibility'];
        bool? maskingEnabled = await getMaskingEnabled();
        bool masked = maskingEnabled! &&
            (maskIds!.contains(path) || maskIds!.contains(wp.widgetDigest()));

        if (subType.compareTo("ImageView") == 0) {
          image = await getData(widget);
          if (image == null) {
            tlLogger.v("Image is empty!");
            continue;
          }
          tlLogger.v('Image is available: ${widget.runtimeType.toString()}');
        } else if (subType.compareTo("TextView") == 0) {
          text = getData(widget) ?? '';

          final TextStyle style = args['style'] ?? TextStyle();
          final TextAlign align = args['align'] ?? TextAlign.left;

          if (maskingEnabled && !masked && maskValuePatterns != null) {
            for (final String pattern in maskValuePatterns!) {
              if (text!.contains(RegExp(pattern))) {
                masked = true;
                tlLogger.v(
                    'Masking matched content with RE: $pattern, text: $text');
                break;
              }
            }
          }
          if (masked) {
            try {
              text = await maskText(text!);
            } on TealeafException catch (te) {
              tlLogger.v('Unable to mask text. ${te.getMsg}');
            }

            tlLogger.v(
                "Text Layout masked text: $text, Widget: ${widget.runtimeType.toString()}, "
                "Digest for MASKING: ${wp.widgetDigest()}");
          } else {
            tlLogger.v(
                "Text Layout text: $text, Widget: ${widget.runtimeType.toString()}");
          }

          font = {
            'family': style.fontFamily,
            'size': style.fontSize.toString(),
            'bold': (FontWeight.values.indexOf(style.fontWeight!) >
                    FontWeight.values.indexOf(FontWeight.normal))
                .toString(),
            'italic': (style.fontStyle == FontStyle.italic).toString()
          };

          double top = 0, bottom = 0, left = 0, right = 0;

          if (wp.parent!.widget is Padding) {
            final Padding padding = wp.parent!.widget as Padding;
            if (padding.padding is EdgeInsets) {
              final EdgeInsets eig = padding.padding as EdgeInsets;
              top = eig.top;
              bottom = eig.bottom;
              left = eig.left;
              right = eig.right;
            }
          }

          aStyle = {
            'textColor': (style.color!.value & 0xFFFFFF).toString(),
            'textAlphaColor': (style.color?.alpha ?? 0).toString(),
            'textAlphaBGColor': (style.backgroundColor?.alpha ?? 0).toString(),
            'textAlign': align.toString().split('.').last,
            'paddingBottom': bottom.toInt().toString(),
            'paddingTop': top.toInt().toString(),
            'paddingLeft': left.toInt().toString(),
            'paddingRight': right.toInt().toString(),
            'hidden': (style.color!.opacity == 1.0).toString(),
            'colorPrimary': (style.foreground?.color ?? 0).toString(),
            'colorPrimaryDark': 0.toString(), // TBD: Dark theme??
            'colorAccent': (style.decorationColor?.value ?? 0)
                .toString(), // TBD: are this the same??
          };
        }

        final RenderBox box = context.findRenderObject() as RenderBox;
        final Offset position = box.localToGlobal(Offset.zero);

        if (image != null) {
          tlLogger.v("Adding image to layouts....");
        }
        tlLogger.v(
            '--> Layout Flutter -- x: ${position.dx}, y: ${position.dy}, width: ${box.size.width.toInt()}, text: $text');

        layouts.add(<String, dynamic>{
          'id': path,
          'cssId': wp.widgetDigest(),
          'idType': (-4).toString(),
          'tlType': (image != null)
              ? 'image'
              : (text != null && text.contains('\n') ? 'textArea' : 'label'),
          'type': type,
          'subType': subType,
          'position': <String, String>{
            'x': position.dx.toInt().toString(),
            'y': position.dy.toInt().toString(),
            'width': box.size.width.toInt().toString(),
            'height': box.size.height.toInt().toString(),
          },
          'zIndex': "501",
          'currState': <String, dynamic>{
            'text': text,
            'placeHolder': "", // TBD??
            'font': font
          },
          if (image != null) 'image': image,
          if (aStyle != null) 'style': aStyle,
          if (accessibility != null) 'accessibility': accessibility,
          'originalId': path.replaceAll("/", ""),
          'masked': '$masked'
        });
      }
    }
    layoutParametersForGestures =
        hasGestures ? List.unmodifiable(layouts) : null;

    tlLogger.v(
        "WigetPath cache size, before: $pathCount, after: ${WidgetPath.size}, # of layouts: ${layouts.length}");

    return layouts;
  }
}

class _Pinch {
  static const initScale = 1.0;
  final List<String> directions = ['close', 'open'];

  Offset? _startPosition;
  Offset? _updatePosition;
  double _scale = -1;
  int _fingers = 0;

  set startPosition(Offset position) => _startPosition = position;
  set updatePosition(Offset position) => _updatePosition = position;
  set scale(double scale) => _scale = scale;
  set fingers(int gesturePoints) {
    if (_fingers < gesturePoints) {
      _fingers = gesturePoints;
    }
  }

  Offset? get getStartPosition => _startPosition;
  Offset? get getUpdatePosition => _updatePosition;
  double get getScale => _scale;
  int get getMaxFingers => _fingers;

  String pinchResult() {
    if (_startPosition == null ||
        _updatePosition == null ||
        _scale == initScale ||
        _fingers != 2) {
      return "";
    }
    return directions[_scale < initScale ? 0 : 1];
  }
}

class _Swipe {
  final List<String> directions = ['right', 'left', 'down', 'up'];

  Offset? _startPosition;
  Offset? _updatePosition;
  Duration _startTimestamp = Duration();
  Duration _updateTimestamp = Duration();
  Velocity? _velocity = Velocity(pixelsPerSecond: const Offset(0, 0));
  String _direction = "";

  set startPosition(Offset position) => _startPosition = position;
  set startTimeStamp(Duration ts) => _startTimestamp = ts;
  set updatePosition(Offset position) => _updatePosition = position;
  set updateTimestamp(Duration ts) => _updateTimestamp = ts;
  set velocity(Velocity? v) => _velocity = v;
  Offset? get getStartPosition => _startPosition;
  Offset? get getUpdatePosition => _updatePosition;
  Velocity? get velocity => _velocity!;
  String get direction => _direction;
  String getStartTimestampString() => _startTimestamp.inMilliseconds.toString();
  String getUpdateTimestampString() =>
      _updateTimestamp.inMilliseconds.toString();

  String calculateSwipe() {
    if (_startPosition == null || _updatePosition == null) {
      return "";
    }
    final Offset offset = _updatePosition! - _startPosition!;
    return _getSwipeDirection(offset);
  }

  String _getSwipeDirection(Offset offset) {
    final int axis = offset.dx.abs() < offset.dy.abs() ? 2 : 0;
    final int direction =
        (axis == 0) ? (offset.dx < 0 ? 1 : 0) : (offset.dy < 0 ? 1 : 0);
    return (_direction = directions[axis + direction]);
  }
}

@Aspect()
@pragma("vm:entry-point")
class TealeafAopInstrumentation {
  TealeafAopInstrumentation();

  static const String _tap = "onTap";
  static const String _doubleTap = "onDoubleTap";
  static const String _longPress = "onLongPress";
  static const String _onPanStart = "onPanStart";
  static const String _onPanEnd = "onPanEnd";
  static const String _onPanUpdate = "onPanUpdate";
  static const String _onScaleStart = "onScaleStart";
  static const String _onScaleUpdate = "onScaleUpdate";
  static const String _onScaleEnd = "onScaleEnd";

  static const String _onVerticalDragStart = "onVerticalDragStart";
  static const String _onVerticalDragUpdate = "onVerticalDragUpdate";
  static const String _onVerticalDragEnd = "onVerticalDragEnd";
  static const String _onHorizontalDragStart = "onHorizontalDragStart";
  static const String _onHorizontalDragUpdate = "onHorizontalDragUpdate";
  static const String _onHorizontalDragEnd = "onHorizontalDragEnd";

  /* Example ONLY of field instrumentation
  @pragma("vm:entry-point")
  @FieldGet('dart:io', 'Platform', 'isAndroid', true)
  static bool _xxxTealeaf1(PointCut pointCut) {
    // Note that there is no way to get PointCut data as parameter is null (investigate)
    return true;
  }
  */

  @Call("package:flutter/src/widgets/binding.dart", "", "+runApp")
  @pragma("vm:entry-point")
  static void _xxxTealeaf6(PointCut pointcut) {
    TimeIt(label: 'runApp Injection').execute(() {
      final dynamic rootWidget = pointcut.positionalParams?[0];

      FlutterError.onError = wrap(FlutterError.onError, "Flutter onError");

      _TlBinder().init();
      catchForLogging(rootWidget ?? const Text("The main app widget is null!"));

      // Create watcher for scroll notifications to map to a swipe event (from top of render tree)
      pointcut.positionalParams?[0] = NotificationListener(
        child: rootWidget,
        onNotification: (Notification? notification) {
          if (notification is ScrollStartNotification) {
            final ScrollStartNotification scrollStartNotification =
                notification;
            final DragStartDetails? details =
                scrollStartNotification.dragDetails;
            _TlBinder()
                .startScroll(details?.globalPosition, details?.sourceTimeStamp);
          } else if (notification is ScrollUpdateNotification) {
            final ScrollUpdateNotification scrollUpdateNotification =
                notification;
            final DragUpdateDetails? details =
                scrollUpdateNotification.dragDetails;
            _TlBinder().updateScroll(
                details?.globalPosition, details?.sourceTimeStamp);
          } else if (notification is ScrollEndNotification) {
            final ScrollEndNotification scrollEndNotification = notification;
            final DragEndDetails? details = scrollEndNotification.dragDetails;
            _TlBinder().endScroll(details?.velocity);
            tlLogger.v('Scroll notification completed');
          }
          return false;
        },
      );
      pointcut.proceed();
      tlLogger.v("Exit runApp replacement hook");
    });
  }

  @Execute("package:flutter/src/widgets/text.dart", "Text", "-build")
  @pragma("vm:entry-point")
  dynamic _xxxTealeaf7(PointCut pointcut) {
    final TimeIt timer =
        TimeIt(label: "Text Injection: (${pointcut.target.toString()}");
    try {
      return timer.execute(() {
        if (pointcut.target is Text) {
          textHelper(
              pointcut,
              (widget) =>
                  widget.data ??
                  (widget.textSpan != null
                      ? widget.textSpan.toPlainText()
                      : ""));
        }
        return timer.execute(() => pointcut.proceed(),
            label: "Text build only");
      }, label: "Total time for text build");
    } finally {
      timer.showResults();
    }
  }

  @Call("package:flutter/src/material/text_field.dart", "_TextFieldState",
      "+_TextFieldState")
  @pragma("vm:entry-point")
  static dynamic _xxxTealeaf8(PointCut pointcut) {
    final TimeIt timer = TimeIt();
    try {
      return timer.execute(() {
        dynamic tfs = timer.execute(() => pointcut.proceed(),
            label: "_TextFieldState Constructor");
        tfs.forcePressEnabled =
            false; // Initialize "late" variable (always reset in build)
        return tfs;
      }, label: "Total including setting late variable");
    } finally {
      timer.showResults();
    }
  }

  @Execute("package:flutter/src/material/text_field.dart", "_TextFieldState",
      "-build")
  @pragma("vm:entry-point")
  dynamic _xxxTealeaf9(PointCut pointcut) {
    final TimeIt timer = TimeIt(label: 'TextField Injection');
    try {
      return timer.execute(() {
        final dynamic tfs = pointcut.target;
        final dynamic tfWidget = tfs.widget;
        if (tfWidget is TextField) {
          textHelper(pointcut, (widget) {
            try {
              String text = widget.controller.text;
              if (text.isEmpty) {
                text = widget.decoration.hintText;
                // TBD: do we need to handle errorText, and any others?
              }
              return text;
            } on NoSuchMethodError {
              tlLogger.v(
                  'The class object is not a TextField while attempting to get text data!');
              return "";
            }
          });
        }
        return timer.execute(() => pointcut.proceed(),
            label: 'TextField build only');
      });
    } finally {
      timer.showResults();
    }
  }

  // TBD: Remove if TextField types deemed redundant because they incorporate a Text() object
  @Execute("package:flutter/src/cupertino/text_field.dart",
      "CupertinoTextField", "-build")
  @pragma("vm:entry-point")
  dynamic _xxxTealeaf10(PointCut pointcut) {}

  @Call("package:flutter/src/material/selectable_text.dart",
      "_SelectableTextState", "+_SelectableTextState")
  @pragma("vm:entry-point")
  static dynamic _xxxTealeaf11(PointCut pointcut) {
    final TimeIt timer = TimeIt();
    try {
      return timer.execute(() {
        dynamic tfs = timer.execute(() => pointcut.proceed(),
            label: "_SelectableTextState Constructor");
        tfs.forcePressEnabled =
            false; // Initialize "late" variable (always reset in build)
        return tfs;
      }, label: "Total including setting late variable");
    } finally {
      timer.showResults();
    }
  }

  @Execute("package:flutter/src/material/selectable_text.dart",
      "_SelectableTextState", "-build")
  @pragma("vm:entry-point")
  dynamic _xxxTealeaf12(PointCut pointcut) {
    final TimeIt timer = TimeIt(
        label: "SelectableText Injection: (${pointcut.target.toString()}");
    try {
      return timer.execute(() {
        final dynamic sts = pointcut.target;
        final dynamic stWidget = sts.widget;

        if (stWidget is SelectableText) {
          textHelper(
              pointcut,
              (widget) =>
                  widget.data ??
                  (widget.textSpan != null
                      ? widget.textSpan.toPlainText()
                      : ""));
        }
        return timer.execute(() => pointcut.proceed(),
            label: "SelectableText build only");
      }, label: "Total time for selectable text build");
    } finally {
      timer.showResults();
    }
  }

  @pragma("vm:entry-point")
  @Execute("package:flutter/src/widgets/image.dart", "_ImageState",
      "-_handleImageFrame")
  dynamic _xxxTealeaf13(PointCut pointcut) {
    final TimeIt timer = TimeIt(label: 'Image Injection for ready handler');
    try {
      return timer.execute(() {
        final dynamic target = pointcut.target;
        final Widget widget = (target is Widget) ? target : target.widget;
        final WidgetPath? wp = WidgetPath.getPath(widget.hashCode);

        if (wp != null) {
          final ImageInfo imageInfo = pointcut.positionalParams?[0];
          wp.parameters['image'] = imageInfo.image;
          tlLogger.v(
              '_ImageState._handleImageFrame. Widget hash: ${widget.hashCode}, image: ${wp.parameters['image']}');
        }
        timer.execute(() => pointcut.proceed(), label: 'Set image handler');
      });
    } finally {
      timer.showResults();
    }
  }

  @Execute("package:flutter/src/widgets/image.dart", "_ImageState", "-build")
  @pragma("vm:entry-point")
  dynamic _xxxTealeaf14(PointCut pointcut) {
    final timer = TimeIt(label: 'Image Injection build');
    try {
      return timer.execute(() {
        final BuildContext bc = pointcut.positionalParams?[0];
        final dynamic target = pointcut.target;
        final Widget widget = (target is Widget) ? target : target.widget;

        tlLogger.v(
            '_ImageState class. widget: ${widget.runtimeType.toString()}, hash: ${widget.hashCode}');

        final dynamic build =
            timer.execute(() => pointcut.proceed(), label: 'Image build only');

        final WidgetPath? cp = WidgetPath.getPath(widget.hashCode);
        final WidgetPath wp = WidgetPath.create(bc, hash: true);
        final String? semantics = cp?.parameters['semanticsLabel'];

        wp.addInstance(widget.hashCode);

        wp.addParameters(<String, dynamic>{
          if (cp != null && cp.parameters.containsKey('image'))
            'image': cp.parameters['image'],
          'type': widget.runtimeType.toString(),
          'subType': 'ImageView',
          if (semantics != null && semantics.isNotEmpty)
            'accessibility': {'id': '/Image', 'label': '', 'hint': semantics},
          'data': (widget) async {
            tlLogger
                .v('_ImageState class: ${target.toString()}, hash: ${wp.key}');
            final dynamic image = wp.parameters['image'];
            if (image != null) {
              Uint8List data = Uint8List(1);
              final bool useImageData = await _TlConfiguration()
                      .get('TealeafBasicConfig/GetImageDataOnScreenLayout') ??
                  false;
              if (useImageData) {
                final ByteData byteData = await image.toByteData(
                    format: ImageByteFormat.rawUnmodified);
                data = byteData.buffer.asUint8List(
                    byteData.offsetInBytes, byteData.lengthInBytes);
              }
              final String width = '${image.width}';
              final String height = '${image.height}';
              tlLogger.v(
                  '--> Image: # of bytes: ${data.length}, w: $width, h: $height, widget: ${widget.runtimeType.toString()}');
              return <String, dynamic>{
                'base64Image': data,
                'value': '',
                'mimeExtension': '',
                'type': 'image',
                'width': width,
                'height': height
              };
            }
            return null;
          },
        });
        return build;
      });
    } finally {
      timer.showResults();
    }
  }

  @Call("package:flutter/src/widgets/basic.dart", "Listener", "+Listener")
  @pragma("vm:entry-point")
  static dynamic _xxxTealeaf2(PointCut pointcut) {
    final TimeIt timer = TimeIt(label: 'Listener Injection for PointerEvents');
    try {
      return timer.execute(() {
        final Map<dynamic, dynamic>? parms = pointcut.namedParams;

        parms?.forEach((key, value) {
          switch (key) {
            case 'onPointerDown':
              {
                PointerDownEventListener? userCallback = value;
                parms[key] = (PointerDownEvent pde) {
                  pointerEventHelper("DOWN", pde);
                  if (userCallback != null) {
                    userCallback(pde);
                  }
                };
                break;
              }
            case 'onPointerUp':
              {
                PointerUpEventListener? userCallback = value;
                parms[key] = (PointerUpEvent pue) {
                  pointerEventHelper("UP", pue);
                  if (userCallback != null) {
                    userCallback(pue);
                  }
                };
                break;
              }
            case 'onPointerMove':
              {
                PointerMoveEventListener? userCallback = value;
                parms[key] = (PointerMoveEvent pme) {
                  pointerEventHelper("MOVE", pme);
                  if (userCallback != null) {
                    userCallback(pme);
                  }
                };
                break;
              }
            case 'key':
              {
                break;
              }
            case 'child':
              {
                break;
              }
            case 'behavior':
              {
                break;
              }
            default:
              {
                tlLogger.v("Unhandled Pointer event: $key");
                break;
              }
          }
        });

        return timer.execute(
            () => Listener(
                key: parms?["key"],
                onPointerDown: parms?["onPointerDown"],
                onPointerMove: parms?["onPointerMove"],
                onPointerUp: parms?["onPointerUp"],
                onPointerHover: parms?["onPointerHover"],
                onPointerCancel: parms?["onPointerCancel"],
                onPointerSignal: parms?["onPointerSignal"],
                behavior: parms?["behavior"] ?? HitTestBehavior.deferToChild,
                child: parms?["child"]),
            label: 'Listener Constructor');
      });
    } finally {
      timer.showResults();
    }
  }

  @Call("package:flutter/src/widgets/gesture_detector.dart", "GestureDetector",
      "+GestureDetector")
  @pragma("vm:entry-point")
  static dynamic _xxxTealeaf3(PointCut pointcut) {
    final TimeIt timer = TimeIt(label: 'GestureDetector Injection');
    try {
      return timer.execute(() {
        final Map<dynamic, dynamic> params = pointcut.namedParams!;
        final Widget? child = params['child'];
        final String childType =
            (child != null) ? child.runtimeType.toString() : '<no child>';
        final String childCode = (child != null) ? '${child.hashCode}' : '0';
        Widget?
            gesture; // Note: this is set AFTER it is referenced in callback. On callback, the value has been set!

        tlLogger.v(
            'Gesture constructor child widget: $childType, child hash: $childCode');

        // Simple gestures
        if (params.containsKey(_tap)) {
          final GestureTapCallback? userCallback = params[_tap];
          params[_tap] = () {
            gestureHelper(gesture: gesture, gestureType: 'tap');
            if (userCallback != null) {
              userCallback();
            }
          };
        }
        if (params.containsKey(_doubleTap)) {
          final GestureDoubleTapCallback? userCallback = params[_doubleTap];
          params[_doubleTap] = () {
            gestureHelper(gesture: gesture, gestureType: 'doubletap');
            if (userCallback != null) {
              userCallback();
            }
          };
        }
        if (params.containsKey(_longPress)) {
          final GestureLongPressCallback? userCallback = params[_longPress];
          params[_longPress] = () {
            gestureHelper(gesture: gesture, gestureType: 'taphold');
            if (userCallback != null) {
              userCallback();
            }
          };
        }
        // Complex gestures
        if (params.containsKey(_onPanStart)) {
          final dynamic userCallback = params[_onPanStart];
          params[_onPanStart] = (DragStartDetails details) {
            final Offset position = details.globalPosition;
            final Duration? timestamp = details.sourceTimeStamp;
            swipeGestureHelper(
                gesture: gesture,
                onType: _onPanStart,
                offset: position,
                timestamp: timestamp!);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        if (params.containsKey(_onPanUpdate)) {
          final dynamic userCallback = params[_onPanUpdate];
          params[_onPanUpdate] = (DragUpdateDetails details) {
            final Offset position = details.globalPosition;
            final Duration? timestamp = details.sourceTimeStamp;
            swipeGestureHelper(
                gesture: gesture,
                onType: _onPanUpdate,
                offset: position,
                timestamp: timestamp!);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        if (params.containsKey(_onPanEnd)) {
          final dynamic userCallback = params[_onPanEnd];
          params[_onPanEnd] = (DragEndDetails details) {
            final Velocity velocity = details.velocity;
            swipeGestureHelper(
                gesture: gesture, onType: _onPanEnd, velocity: velocity);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        // Horizontal/Vertical drags versions of pan
        if (params.containsKey(_onHorizontalDragStart)) {
          final dynamic userCallback = params[_onHorizontalDragStart];
          params[_onHorizontalDragStart] = (DragStartDetails details) {
            final Offset position = details.globalPosition;
            final Duration? timestamp = details.sourceTimeStamp;
            swipeGestureHelper(
                gesture: gesture,
                onType: _onHorizontalDragStart,
                offset: position,
                timestamp: timestamp!);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        if (params.containsKey(_onHorizontalDragUpdate)) {
          final dynamic userCallback = params[_onHorizontalDragUpdate];
          params[_onHorizontalDragUpdate] = (DragUpdateDetails details) {
            final Offset position = details.globalPosition;
            final Duration? timestamp = details.sourceTimeStamp;
            swipeGestureHelper(
                gesture: gesture,
                onType: _onHorizontalDragUpdate,
                offset: position,
                timestamp: timestamp!);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        if (params.containsKey(_onHorizontalDragEnd)) {
          final dynamic userCallback = params[_onHorizontalDragEnd];
          params[_onHorizontalDragEnd] = (DragEndDetails details) {
            final Velocity velocity = details.velocity;
            swipeGestureHelper(
                gesture: gesture,
                onType: _onHorizontalDragEnd,
                velocity: velocity);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        if (params.containsKey(_onVerticalDragStart)) {
          final dynamic userCallback = params[_onVerticalDragStart];
          params[_onVerticalDragStart] = (DragStartDetails details) {
            final Offset position = details.globalPosition;
            final Duration? timestamp = details.sourceTimeStamp;
            swipeGestureHelper(
                gesture: gesture,
                onType: _onVerticalDragStart,
                offset: position,
                timestamp: timestamp!);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        if (params.containsKey(_onVerticalDragUpdate)) {
          final dynamic userCallback = params[_onVerticalDragUpdate];
          params[_onVerticalDragUpdate] = (DragUpdateDetails details) {
            final Offset position = details.globalPosition;
            final Duration? timestamp = details.sourceTimeStamp;
            swipeGestureHelper(
                gesture: gesture,
                onType: _onVerticalDragUpdate,
                offset: position,
                timestamp: timestamp!);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        if (params.containsKey(_onVerticalDragEnd)) {
          final dynamic userCallback = params[_onVerticalDragEnd];
          params[_onVerticalDragEnd] = (DragEndDetails details) {
            final Velocity velocity = details.velocity;
            swipeGestureHelper(
                gesture: gesture,
                onType: _onVerticalDragEnd,
                velocity: velocity);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        if (params.containsKey(_onScaleStart)) {
          final dynamic userCallback = params[_onScaleStart];
          params[_onScaleStart] = (ScaleStartDetails details) {
            final Offset position = details.focalPoint;
            pinchGestureHelper(
                gesture: gesture, onType: _onScaleStart, offset: position);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        if (params.containsKey(_onScaleUpdate)) {
          final dynamic userCallback = params[_onScaleUpdate];
          params[_onScaleUpdate] = (ScaleUpdateDetails details) {
            final Offset position = details.focalPoint;
            final double scale = details.scale;
            final int fingers = details.pointerCount;
            tlLogger.v('ScaleUpdate, scale: $scale, fingers: $fingers');

            pinchGestureHelper(
                gesture: gesture,
                onType: _onScaleUpdate,
                scale: scale,
                fingers: fingers,
                offset: position);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        if (params.containsKey(_onScaleEnd)) {
          final dynamic userCallback = params[_onScaleEnd];
          params[_onScaleEnd] = (ScaleEndDetails details) {
            final int fingers = details.pointerCount;
            final Velocity velocity = details.velocity;
            pinchGestureHelper(
                gesture: gesture,
                onType: _onScaleEnd,
                fingers: fingers,
                velocity: velocity);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        gesture = timer.execute(
            () => GestureDetector(
                key: params['key'],
                child: child,
                onTap: params[_tap],
                onTapDown: params['onTapDown'],
                onTapUp: params['onTapUp'],
                onTapCancel: params['onTapCancel'],
                onSecondaryTap: params['onSecondaryTap'],
                onSecondaryTapDown: params['onSecondaryTapDown'],
                onSecondaryTapUp: params['onSecondaryTapUp'],
                onSecondaryTapCancel: params['onSecondaryTapCancel'],
                onTertiaryTapDown: params['onTertiaryTapDown'],
                onTertiaryTapUp: params['onTertiaryTapUp'],
                onTertiaryTapCancel: params['onTertiaryTapCancel'],
                onDoubleTapDown: params['onDoubleTapDown'],
                onDoubleTap: params[_doubleTap],
                onDoubleTapCancel: params['onDoubleTapCancel'],
                onLongPressDown: params['onLongPressDown'],
                onLongPressCancel: params['onLongPressCancel'],
                onLongPress: params[_longPress],
                onLongPressStart: params['onLongPressStart'],
                onLongPressMoveUpdate: params['onLongPressMoveUpdate'],
                onLongPressUp: params['onLongPressUp'],
                onLongPressEnd: params['onLongPressEnd'],
                onSecondaryLongPressDown: params['onSecondaryLongPressDown'],
                onSecondaryLongPressCancel:
                    params['onSecondaryLongPressCancel'],
                onSecondaryLongPress: params['onSecondaryLongPress'],
                onSecondaryLongPressStart: params['onSecondaryLongPressStart'],
                onSecondaryLongPressMoveUpdate:
                    params['onSecondaryLongPressMoveUpdate'],
                onSecondaryLongPressUp: params['onSecondaryLongPressUp'],
                onSecondaryLongPressEnd: params['onSecondaryLongPressEnd:'],
                onTertiaryLongPressDown: params['onTertiaryLongPressDown'],
                onTertiaryLongPressCancel: params['onTertiaryLongPressCancel'],
                onTertiaryLongPress: params['onTertiaryLongPress:'],
                onTertiaryLongPressStart: params['onTertiaryLongPressStart'],
                onTertiaryLongPressMoveUpdate:
                    params['onTertiaryLongPressMoveUpdate'],
                onTertiaryLongPressUp: params['onTertiaryLongPressUp'],
                onTertiaryLongPressEnd: params['onTertiaryLongPressEnd'],
                onVerticalDragDown: params['onVerticalDragDown'],
                onVerticalDragStart: params[_onVerticalDragStart],
                onVerticalDragUpdate: params[_onVerticalDragUpdate],
                onVerticalDragEnd: params[_onVerticalDragEnd],
                onVerticalDragCancel: params['onVerticalDragCancel'],
                onHorizontalDragDown: params['onHorizontalDragDown'],
                onHorizontalDragStart: params[_onHorizontalDragStart],
                onHorizontalDragUpdate: params[_onHorizontalDragUpdate],
                onHorizontalDragEnd: params[_onHorizontalDragEnd],
                onHorizontalDragCancel: params['onHorizontalDragCancel'],
                onForcePressStart: params['onForcePressStart'],
                onForcePressPeak: params['onForcePressPeak'],
                onForcePressUpdate: params['onForcePressUpdate'],
                onForcePressEnd: params['onForcePressEnd'],
                onPanDown: params['onPanDown'],
                onPanStart: params[_onPanStart],
                onPanUpdate: params[_onPanUpdate],
                onPanEnd: params[_onPanEnd],
                onPanCancel: params['onPanCancel'],
                onScaleStart: params[_onScaleStart],
                onScaleUpdate: params[_onScaleUpdate],
                onScaleEnd: params[_onScaleEnd],
                behavior: params['behavior'],
                excludeFromSemantics: params['excludeFromSemantics'] ?? false,
                dragStartBehavior:
                    params['dragStartBehavior'] ?? DragStartBehavior.start),
            label: 'GestureDetector Constructor');
        tlLogger.v('--> Gesture class created: ${gesture.hashCode}');
        for (dynamic key in params.keys) {
          // Add simple logging for all passed gestures in case we have no instrumentation for that callback
          final String keyString = key as String;
          if (keyString.startsWith('on')) {
            tlLogger.v('Gesture handler parameter: $keyString');
          }
        }
        return gesture;
      });
    } finally {
      timer.showResults();
    }
  }

  @Execute("package:flutter/src/widgets/gesture_detector.dart",
      "GestureDetector", "-build")
  @pragma("vm:entry-point")
  dynamic _xxxTealeaf4(PointCut pointcut) {
    final TimeIt timer = TimeIt(label: 'GestureDetector Injection build');
    try {
      return timer.execute(() {
        Widget? widget = pointcut.target as Widget;
        tlLogger.v(
            'GestureDetector Build WIDGET: ${widget.runtimeType.toString()} ${widget.hashCode}');
        final BuildContext bc = pointcut.positionalParams?[0];
        final WidgetPath wp = WidgetPath.create(bc, hash: true);

        wp.addInstance(widget.hashCode);

        wp.addParameters(
            <String, dynamic>{'type': widget.runtimeType.toString()});
        return timer.execute(() => pointcut.proceed(),
            label: 'GestureDetector build');
      });
    } finally {
      timer.showResults();
    }
  }

  @Call("package:tl_flutter_plugin/tl_flutter_plugin.dart", "PluginTealeaf",
      "+aspectdTest")
  @pragma("vm:entry-point")
  static bool _xxxTealeaf5(PointCut pointcut) {
    tlLogger.v(
        '[AspectD test]: call method return value modified false => true (AOP TEST)');
    return true;
  }

  static void textHelper(PointCut pointcut, Function getText) async {
    final BuildContext bc = pointcut.positionalParams?[0];
    final dynamic target = pointcut.target;
    final Widget widget = (target is Widget) ? target : target.widget;

    tlLogger.v(
        'Text widget type: ${widget.runtimeType.toString()}, context: ${bc.toString()}');

    final TextStyle style = pointcut.members?['style'] ??
        DefaultTextStyle.of(bc).style ??
        TextStyle();
    final TextAlign textAlign = pointcut.members?['textAlign'] ??
        DefaultTextStyle.of(bc).textAlign ??
        TextAlign.left;
    final String semantics = pointcut.members?['semanticsLabel'] ?? '';
    final WidgetPath wp = WidgetPath.create(bc, hash: true);

    wp.addInstance(widget.hashCode);

    wp.addParameters(<String, dynamic>{
      'type': widget.runtimeType.toString(),
      'subType': 'TextView',
      'data': getText,
      'style': style,
      'align': textAlign,
      if (semantics.isNotEmpty)
        'accessibility': {'id': '/Text', 'label': '', 'hint': semantics},
    });
  }

  static Map<String, dynamic> checkForSemantics(WidgetPath? wp) {
    final BuildContext? context = wp!.context;
    final Map<String, dynamic> accessibility = {};
    Semantics? semantics;

    int maxVisit = 10; // TBD: How far up the tree should we look for Semantics?

    context?.visitAncestorElements((ancestor) {
      final Widget parentWidget = ancestor.widget;
      if (parentWidget is Semantics) {
        semantics = parentWidget;
        return false;
      }
      return --maxVisit > 0;
    });

    if (semantics != null) {
      final String? hint = semantics!.properties.hint;
      final String? label = semantics!.properties.label;
      accessibility.addAll({
        'accessibility': {
          'id': '/GestureDetector',
          'label': label ?? '',
          'hint': hint ?? ''
        }
      });
    }
    return accessibility;
  }

  static void pointerEventHelper(String action, PointerEvent pe) {
    final String json = jsonEncode(pe, toEncodable: encodeJsonPointerEvent);
    final Map<String, dynamic> fields = jsonDecode(json);

    tlLogger.v("My PointerEvent $action TRAP!");

    if (fields.containsKey('timestamp')) {
      fields['timestamp'] = fields['timestamp'].toString();
    }
    fields['action'] = action;
    PluginTealeaf.onTlPointerEvent(fields: fields);
  }

  static Map<String, dynamic> errorDetailsHelper(
      FlutterErrorDetails fed, String type) {
    final Map<String, dynamic> data = {};
    final String errorString = fed.exception.runtimeType.toString();

    data["name"] = errorString;
    data["message"] = fed.toStringShort();
    data["stacktrace"] = fed.stack.toString();
    data["handled"] = true;

    tlLogger.v(
        "!!! Flutter exception, type: $type, class: $errorString, hash: ${fed.exception.hashCode}");

    return data;
  }

  static Object? encodeJsonPointerEvent(Object? value) {
    Map<String, dynamic> map = {};

    if (value != null && value is PointerEvent) {
      final PointerEvent pointerEvent = value;

      map['position'] = {
        'dx': pointerEvent.position.dx,
        'dy': pointerEvent.position.dy
      };
      map['localPosition'] = {
        'dx': pointerEvent.localPosition.dx,
        'dy': pointerEvent.localPosition.dy
      };
      map['down'] = pointerEvent.down;
      map['kind'] = pointerEvent.kind.index;
      map['buttons'] = pointerEvent.buttons;
      map['embedderId'] = pointerEvent.embedderId;
      map['pressure'] = pointerEvent.pressure;
      map['timestamp'] = pointerEvent.timeStamp.inMicroseconds;
    }

    return map;
  }

  static dynamic wrap(
      dynamic Function(FlutterErrorDetails fed)? f, String type) {
    if (f != null) {
      final Function(FlutterErrorDetails fed) copyF = f;

      return (FlutterErrorDetails fed) {
        final dynamic result = copyF(fed);
        tlLogger.v("!!! Reporting onError from wrapped callback");
        PluginTealeaf.onTlException(data: errorDetailsHelper(fed, type));
        return result;
      };
    }
    return null;
  }

  static void catchForLogging(Widget appWidget) {
    tlLogger.v('Running app widget: ${appWidget.runtimeType.toString()}');

    runZonedGuarded<Future<void>>(() async {
      runApp(appWidget);
    }, (dynamic e, StackTrace stackTrace) {
      tlLogger.v(
          'Uncaught Exception: ${e.toString()}\nstackTrace: ${stackTrace.toString()}');

      final Map<String, dynamic> data = {};
      bool isLogException = false;

      if (e is PlatformException) {
        final PlatformException pe = e;
        data["nativecode"] = pe.code;
        data["nativemessage"] = pe.message ?? "";
        data["nativestacktrace"] = pe.stacktrace ?? "";
        data["message"] = e.toString();
      } else if (e is TealeafException) {
        final TealeafException te = e;

        data["nativecode"] = te.code ?? '';
        data["nativemessage"] = te.getNativeMsg ?? '';
        data["nativestacktrace"] = te.getNativeDetails ?? '';
        data["message"] = te.getMsg ?? '';
        isLogException =
            te.getMsg?.contains(TealeafException.logErrorMsg) ?? false;
      } else {
        String message = "";
        try {
          message = e.message ?? "";
        } on NoSuchMethodError {
          // TypeErrors, for example, do not have messages. But, let's try to
          // grab any that do have messages.
          tlLogger.v('No message with this type of Flutter exception');
        }
        data["message"] = message;
      }

      data["name"] = e.runtimeType.toString();
      data["stacktrace"] = stackTrace.toString();
      data["handled"] = false;

      // Prevent recursive calls if exception message can not be processed!!
      if (isLogException) {
        tlLogger.v("Not logging an uncaught log exception message");
      } else {
        PluginTealeaf.onTlException(data: data);
      }
    });
  }

  static String getGestureTarget(WidgetPath wp) {
    final dynamic widget = wp.context!.widget;
    String gestureTarget;

    try {
      gestureTarget = widget.child.runtimeType.toString();
    } on NoSuchMethodError {
      gestureTarget = wp.parentWidgetType!;
    }
    return gestureTarget;
  }

  static void gestureHelper({Widget? gesture, String? gestureType}) async {
    if (gesture == null) {
      tlLogger.w(
          'Warning: Gesture is null in gestureHelper, type: ${gestureType ?? "<NONE>"}');
      return;
    }
    final int hashCode = gesture.hashCode;

    if (WidgetPath.containsKey(hashCode)) {
      final WidgetPath? wp = WidgetPath.getPath(hashCode);
      final BuildContext? context = wp!.context;
      final String gestureTarget = getGestureTarget(wp);
      final Map<String, dynamic> accessibility = checkForSemantics(wp);

      tlLogger.v(
          '${gestureType!.toUpperCase()}: Gesture widget, context hash: ${context.hashCode}, widget hash: $hashCode');
      tlLogger.v('--> Path: ${wp.widgetPath()}, digest: ${wp.widgetDigest()}');

      await PluginTealeaf.onTlGestureEvent(
          gesture: gestureType,
          id: wp.widgetPath(),
          target: gestureTarget,
          data: accessibility.isNotEmpty ? accessibility : null,
          layoutParameters: _TlBinder.layoutParametersForGestures);
    } else {
      tlLogger.v(
          "ERROR: ${gesture.runtimeType.toString()} gesture not found for hashcode: $hashCode");
    }
  }

  static void swipeGestureHelper(
      {required Widget? gesture,
      required String onType,
      Offset? offset,
      Duration? timestamp,
      Velocity? velocity}) async {
    if (gesture == null) {
      tlLogger.w('Warning: Gesture is null in swipeGestureHelper');
      return;
    }
    final int hashCode = gesture.hashCode;

    if (WidgetPath.containsKey(hashCode)) {
      final WidgetPath? wp = WidgetPath.getPath(hashCode);
      final BuildContext? context = wp!.context;
      final String gestureTarget = getGestureTarget(wp);

      tlLogger.v(
          '${onType.toUpperCase()}: Gesture widget, context hash: ${context.hashCode}, widget hash: $hashCode');
      tlLogger.v('--> Path: ${wp.widgetPath()}, digest: ${wp.widgetDigest()}');

      switch (onType) {
        case _onPanStart:
        case _onHorizontalDragStart:
        case _onVerticalDragStart:
          {
            final _Swipe swipe = _Swipe();
            swipe.startPosition = offset!;
            swipe.startTimeStamp = timestamp!;
            wp.addParameters(<String, dynamic>{'swipe': swipe});
            break;
          }
        case _onPanUpdate:
        case _onHorizontalDragUpdate:
        case _onVerticalDragUpdate:
          {
            if (wp.parameters.containsKey('swipe')) {
              final _Swipe swipe = wp.parameters['swipe'];
              swipe.updatePosition = offset!;
              swipe.updateTimestamp = timestamp!;
            }
            break;
          }
        case _onPanEnd:
        case _onHorizontalDragEnd:
        case _onVerticalDragEnd:
          {
            if (wp.parameters.containsKey('swipe')) {
              final _Swipe swipe = wp.parameters['swipe'];
              final String direction = swipe.calculateSwipe();
              if (direction.isNotEmpty) {
                final Offset start = swipe.getStartPosition!;
                final Offset end = swipe.getUpdatePosition!;
                final Map<String, dynamic> accessibility =
                    checkForSemantics(wp);

                wp.parameters.clear();
                tlLogger
                    .v('Swipe start: ${DateTime.now().millisecondsSinceEpoch}');
                await PluginTealeaf.onTlGestureEvent(
                    gesture: 'swipe',
                    id: wp.widgetPath(),
                    target: gestureTarget,
                    data: <String, dynamic>{
                      'pointer1': {
                        'dx': start.dx,
                        'dy': start.dy,
                        'ts': swipe.getStartTimestampString()
                      },
                      'pointer2': {
                        'dx': end.dx,
                        'dy': end.dy,
                        'ts': swipe.getUpdateTimestampString()
                      },
                      'velocity': {
                        'dx': velocity?.pixelsPerSecond.dx,
                        'dy': velocity?.pixelsPerSecond.dy
                      },
                      'direction': direction,
                      ...accessibility,
                    },
                    layoutParameters: _TlBinder.layoutParametersForGestures);
              }
            }
            break;
          }
        default:
          break;
      }
    } else {
      tlLogger.v(
          "ERROR: ${gesture.runtimeType.toString()} not found for hashcode: $hashCode");
    }
  }

  static void pinchGestureHelper(
      {required Widget? gesture,
      required String onType,
      Offset? offset,
      double? scale,
      Velocity? velocity,
      int fingers = 0}) async {
    if (gesture == null) {
      tlLogger.w('Warning: Gesture is null in pinchGestureHelper');
      return;
    }
    final int hashCode = gesture.hashCode;

    if (WidgetPath.containsKey(hashCode)) {
      final WidgetPath? wp = WidgetPath.getPath(hashCode);
      final BuildContext? context = wp!.context;
      final String gestureTarget = getGestureTarget(wp);
      final Map<String, dynamic> accessibility = checkForSemantics(wp);

      tlLogger.v(
          '${onType.toUpperCase()}: Gesture widget, context hash: ${context.hashCode}, widget hash: $hashCode');

      switch (onType) {
        case _onScaleStart:
          {
            final _Pinch pinch = _Pinch();
            pinch.startPosition = offset!;
            wp.addParameters(<String, dynamic>{'pinch': pinch});
            break;
          }
        case _onScaleUpdate:
          {
            if (wp.parameters.containsKey('pinch')) {
              final _Pinch pinch = wp.parameters['pinch'];
              pinch.updatePosition = offset!;
              pinch.scale = scale!;
              pinch.fingers = fingers;
            }
            break;
          }
        case _onScaleEnd:
          {
            if (wp.parameters.containsKey('pinch')) {
              final _Pinch pinch = wp.parameters['pinch'];
              pinch.fingers = fingers;
              final String direction = pinch.pinchResult();
              tlLogger.v(
                  '--> Pinch, fingers: ${pinch.getMaxFingers}, direction: $direction');

              if (direction.isNotEmpty) {
                final Offset start = pinch.getStartPosition!;
                final Offset end = pinch.getUpdatePosition!;
                wp.parameters.clear();
                await PluginTealeaf.onTlGestureEvent(
                    gesture: 'pinch',
                    id: wp.widgetPath(),
                    target: gestureTarget,
                    data: <String, dynamic>{
                      'pointer1': {'dx': start.dx, 'dy': start.dy},
                      'pointer2': {'dx': end.dx, 'dy': end.dy},
                      'direction': direction,
                      'velocity': {
                        'dx': velocity?.pixelsPerSecond.dx,
                        'dy': velocity?.pixelsPerSecond.dy
                      },
                      ...accessibility,
                    },
                    layoutParameters: _TlBinder.layoutParametersForGestures);
              }
            }
            break;
          }
        default:
          break;
      }
    } else {
      tlLogger.v(
          "ERROR: ${gesture.runtimeType.toString()} not found for hashcode: $hashCode");
    }
  }
}
