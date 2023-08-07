import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:tl_flutter_plugin/tl_flutter_plugin.dart';
import 'package:tl_flutter_plugin/logger.dart';
// import 'dart:ui';
// import 'package:flutter/gestures.dart';
// import 'package:flutter/semantics.dart';
// import 'package:flutter/services.dart';
// import 'package:tl_flutter_plugin/timeit.dart';

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

///
///
///


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

// ignore: lint, unused_element
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
    // ignore: deprecated_member_use
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

// ignore: unused_element
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

///
///
SemanticsNode? getSemanticsNode(BuildContext context) {
  // Get the RenderObject from the BuildContext
  final RenderObject? renderObject = context.findRenderObject();

  // Check if the RenderObject is a RenderObjectWithChildMixin
  if (renderObject is RenderObjectWithChildMixin) {
    // Get the PipelineOwner from the RenderObject
    final PipelineOwner? pipelineOwner = renderObject.owner;

    // Check if the PipelineOwner is not null
    if (pipelineOwner != null) {
      // Get the SemanticsOwner from the PipelineOwner
      final SemanticsOwner? semanticsOwner = pipelineOwner.semanticsOwner;

      // Check if the SemanticsOwner is not null
      if (semanticsOwner != null) {
        // Get the SemanticsNode from the SemanticsOwner using the findChild method
        // final SemanticsNode? semanticsNode = semanticsOwner.rootSemanticsNode!.findChild(renderObject.semanticId);
        final SemanticsNode? semanticsNode = semanticsOwner.rootSemanticsNode;
        print('semanticsNode - accessibility');
        print(semanticsNode.toString());
        // Return the SemanticsNode
        return semanticsNode;
      }
    }
  }

  // Return null if the SemanticsNode cannot be obtained
  return null;
}