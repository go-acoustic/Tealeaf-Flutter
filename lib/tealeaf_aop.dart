import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'package:tl_flutter_plugin/aspectd.dart';
import 'package:tl_flutter_plugin/timeit.dart';
import 'package:tl_flutter_plugin/tl_flutter_plugin.dart';
import 'package:tl_flutter_plugin/logger.dart';

class WidgetPath {
  WidgetPath();

  static const String excl = r'^(Focus|Semantics|.*<.*>|InheritedElement|_|.*\n_).*$';
  static const String reduce = r"[a-z]";
  static const String sep = '/';
  static Hash get digest => sha1;

  static Map<int, dynamic> widgetContexts = {};

  BuildContext? context;
  Element?  parent;
  String?   parentWidgetType;
  String?   pathHash;
  int?      key;
  late bool shorten;
  late bool hash;
  late String path;

  Map<String, dynamic>? parameters;

  WidgetPath.create(this.context, {this.shorten = true, this.hash = false, String exclude = excl}) {
    if (context == null) {
      return;
    }

    final StringBuffer path = StringBuffer();
    final RegExp re = RegExp(exclude, multiLine: true);
    final List<String> stk = [];
    Widget? widget = context?.widget;

    this.path = '';

    context?.visitAncestorElements((ancestor) {
      final String wrt = ancestor.widget.runtimeType.toString();
      final String rt = ancestor.runtimeType.toString();
      final String rts = '$rt\n$wrt';

      if (stk.isEmpty) {
        stk.add(widget.runtimeType.toString());
        parent = ancestor;
      }

      if (!re.hasMatch(rts)) {
        stk.add(wrt);
      }
      return true;
    });

    String widgetName = '';
    while (stk.isNotEmpty) {
      path.write('$widgetName$sep');
      widgetName = stk.removeLast();
    }
    this.path = makeShorter(path.toString()) + widgetName;

    try {
      final dynamic parentWidget = parent?.widget;
      final List<Widget> children = parentWidget.children;
      tlLogger.v("Widget has siblings, checking for parent list position");
      final int position = children.indexOf(widget!);
      this.path += '/$position';
      parentWidgetType = parentWidget.runtimeType.toString();
    }
    on NoSuchMethodError {
      tlLogger.v('Widget has <= 1 child');
    }

    if (hash) {
      pathHash = digest.convert(utf8.encode(this.path)).toString();
    }

    tlLogger.v('@@@ WIDGET: ${widget.runtimeType.toString()}, path: $widgetPath, digest: $widgetDigest');
  }

  int? findExistingPathKey() {
    int? match;

    for (MapEntry<int, dynamic> entry in widgetContexts.entries) {
      final WidgetPath wp = entry.value;
      if (this == wp) {
        tlLogger.v("Skip removing current widget path entry");
        continue;
      }
      if (isEqual(wp)) {
        tlLogger.v("Path match [${entry.key}]");
        match = entry.key;
        break;
      }
    }
    return match;
  }

  bool isEqual(WidgetPath other) {
    final bool equal = path.compareTo(other.path) == 0;
    if (equal) {
      tlLogger.v("Widget paths are equal!");
    }
    return equal;
  }

  void addInstance(int key) {
    final int? existingKey = findExistingPathKey();
    removePath(existingKey);
    if (existingKey != null) {
      tlLogger.v('Removing key $existingKey from widgetContext cache');
    }
    this.key = key;
    widgetContexts[key] = this;
  }

  set setParameters(Map<String, dynamic> parameters) => this.parameters = parameters;

  static WidgetPath?  getPath(int key) => widgetContexts[key];
  static void          removePath(int? key) { if (key != null) widgetContexts.remove(key); }
  static bool          containsKey(int key) => widgetContexts.containsKey(key);
  static void          clear() => widgetContexts.clear();
  static int           get size => widgetContexts.length;
  static Function      removeWhere = widgetContexts.removeWhere;
  static List<dynamic> valueList = widgetContexts.values.toList(growable: false);
  String               get widgetPath => path;
  String?              get widgetDigest => pathHash;
  String               makeShorter(String str) => shorten ? str.replaceAll(RegExp(reduce), '') : str;
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
        throw Exception("No data loader injected for configuration!");
      }
      final String data = await _dataLoader!();
      _configureInformation = jsonDecode(data);
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
  static const int  rapidFrameRateLimitMs = 160;
  static const int  rapidSequenceCompleteMs = rapidFrameRateLimitMs * 2;

  static _TlBinder? _instance;
  static List<Map<String,dynamic>>? layoutParametersForGestures;

  bool   initEnvironment = true;
  String frameHash = "";
  int    screenWidth = 0;
  int    screenHeight = 0;
  int    lastFrameTime = 0;
  bool   loggingScreen = false;
  Timer? logFrameTimer;

  bool?  maskingEnabled;
  List<dynamic>? maskIds;
  List<dynamic>? maskValuePatterns;

  void init() {
    final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

    binding.addPersistentFrameCallback((timestamp) {
      if (usePostFrame) {
        tlLogger.v("#### Frame handling with single PostFrame callbacks");
        handleWithPostFrameCallback(binding, timestamp);
      }
      else {
        tlLogger.v("#### Frame handling with direct persistent callbacks");
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
      maskingEnabled = await _TlConfiguration().get("GlobalScreenSettings/Masking/HasMasking")?? false;
      maskIds = await _TlConfiguration().get("GlobalScreenSettings/Masking/MaskIdList") ?? [];
      maskValuePatterns = await _TlConfiguration().get("GlobalScreenSettings/Masking/MaskValueList") ?? [];
    }
    return maskingEnabled;
  }

  void logFrameIfChanged(WidgetsBinding binding, Duration timestamp) async {
    final Element? rootViewElement = binding.renderViewElement;

    if (initEnvironment) {
      final RenderObject? rootObject = rootViewElement?.findRenderObject();

      if (rootObject != null) {
        screenWidth  = rootObject.paintBounds.width.round();
        screenHeight = rootObject.paintBounds.height.round();

        if (screenWidth != 0 && screenHeight != 0) {
          initEnvironment = false;

          await PluginTealeaf.tlSetEnvironment(screenWidth: screenWidth, screenHeight: screenHeight);

          tlLogger.v('TlBinder, renderView w: $screenWidth, h: $screenHeight');
        }
      }
    }

    final int currentTime = DateTime.now().millisecondsSinceEpoch;
    final int elapsed = currentTime - lastFrameTime;
    bool skippingFrame = false;

    if (logFrameTimer != null && logFrameTimer!.isActive) {
      tlLogger.v('Cancelling screenview logging, frame interval: $elapsed');
      logFrameTimer!.cancel();
      logFrameTimer = null;
      skippingFrame = loggingScreen;
    }
    else {
      tlLogger.v('Logging screenview with no pending frame, frame interval: $elapsed, logging now: $loggingScreen');
    }
    final int waitTime = (elapsed < rapidFrameRateLimitMs) ? rapidSequenceCompleteMs : 0;

    void performScreenview() async {
      loggingScreen = true;
      logFrameTimer = null;
      final int timerDelay = DateTime.now().millisecondsSinceEpoch - currentTime;
      final int frameInterval = lastFrameTime == 0 ? 0: elapsed;
      final List<Map<String, dynamic>> layouts = await getAllLayouts();

      tlLogger.v('Logging screenview, delay: $timerDelay, wait: $waitTime, frame interval: $frameInterval, Layout count: ${layouts.length}');

      await PluginTealeaf.onScreenview("LOAD", timestamp, layouts);
      loggingScreen = false;
    }

    if (lastFrameTime == 0) {
      tlLogger.v('Logging first frame');
      performScreenview();
    }
    else if (skippingFrame) {
      tlLogger.v('Logging screenview in process, skipping frame');
    }
    else {
      tlLogger.v("Logging screenview, wait: $waitTime");
      logFrameTimer = Timer(Duration(milliseconds: waitTime), performScreenview);
    }
    lastFrameTime = currentTime;
  }

  void handleWithPostFrameCallback(WidgetsBinding binding, Duration timestamp) {
    binding.addPostFrameCallback((timestamp) => handleScreenUpdate(timestamp));
  }

  void handleScreenUpdate(Duration timestamp) {
    tlLogger.v('##### Frame callback @$timestamp (widget path map size: ${WidgetPath.size})');

    final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();

    logFrameIfChanged(binding, timestamp);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        tlLogger.v("###### Screenview UNLOAD");
        break;
      case AppLifecycleState.resumed:
        tlLogger.v("###### Screenview VISIT");
        break;
      default:
        tlLogger.v("###### Screenview: ${state.toString()}");
        break;
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<String> maskText(String text) async {
    final bool? maskingEnabled = await getMaskingEnabled();
    if (maskingEnabled!) {
      if ((await _TlConfiguration().get("GlobalScreenSettings/Masking/HasCustomMask") ?? "").toString().contains("true")) {
        final String? smallCase = await _TlConfiguration().get("GlobalScreenSettings/Masking/Sensitive/smallCaseAlphabet");
        final String? capitalCase = await _TlConfiguration().get("GlobalScreenSettings/Masking/Sensitive/capitalCaseAlphabet");
        final String? symbol = await _TlConfiguration().get("GlobalScreenSettings/Masking/Sensitive/symbol");
        final String? number = await _TlConfiguration().get("GlobalScreenSettings/Masking/Sensitive/number");

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
    return <String, dynamic> {
      "zIndex":500,
      "type":"FlutterImageView",
      "subType":"UIView",
      "tlType":"image",
      "id":"[w,0],[v,0],[v,0],[FlutterView,0]",
      "position":<String, dynamic> {
        "y":"0",
        "x":"0",
        "width": "$screenWidth",
        "height": "$screenHeight"
      },
      "idType":-4,
      "style":<String, dynamic> {
        "borderColor":0,""
        "borderAlpha":1,
        "borderRadius":0
      },
      "cssId":"w0v0v0FlutterView0",
      "image": <String, dynamic> { // If # items change, update item count checks in native code
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
    final List<dynamic> pathList = WidgetPath.valueList;

    bool hasGestures = false;

    if (createRootLayout) {
      layouts.add(createRootLayoutControl());
    }

    for (dynamic widgetPath in pathList) {
      final WidgetPath wp = widgetPath as WidgetPath;
      final Map <String, dynamic>? args = wp.parameters;

      if (args != null) {
        final String? type = args['type'];
        final String? subType = args['subType'];
        final BuildContext? context = wp.context;
        final Widget? widget = context?.widget;

        if (type != null && type.compareTo("GestureDetector") == 0) {
          hasGestures = true;
        }
        else if (subType != null && widget != null) {
          final String path = wp.widgetPath;
          final dynamic getData = args['data'];
          Map<String, dynamic>? aStyle;
          Map<String, dynamic>? font;
          Map<String, dynamic>? image;
          String? text;
          bool?  maskingEnabled = await getMaskingEnabled();

          bool masked = maskingEnabled! && (maskIds!.contains(wp.widgetPath) || maskIds!.contains(wp.widgetDigest));

          if (subType.compareTo("ImageView") == 0) {
            image = await getData(widget);
            if (image == null) {
              tlLogger.v("Image is empty!");
              continue;
            }
            tlLogger.v('*** Image is available: ${widget.runtimeType.toString()}');
          }
          else if (subType.compareTo("TextView") == 0) {
            text = getData(widget);

            final TextStyle style = args['style']?? TextStyle();
            final TextAlign align = args['align']?? TextAlign.left;

            if (maskingEnabled && !masked && maskValuePatterns != null) {
              for (final String pattern in maskValuePatterns!) {
                if (text!.contains(RegExp(pattern))) {
                  masked = true;
                  tlLogger.v('Masking matched content with RE: $pattern, text: $text');
                  break;
                }
              }
            }
            if (masked) {
              try {
                text = await maskText(text!);
              }
              on TealeafException catch (te) {
                tlLogger.v('Unable to mask text. ${te.getMsg}');
              }

              tlLogger.v("Text Layout masked text: $text, Widget: ${widget.runtimeType.toString()}, "
                "Digest for MASKING: ${wp.widgetDigest}");
            }
            else {
              tlLogger.v("Text Layout text: $text, Widget: ${widget.runtimeType.toString()}");
            }

            font = {
              'family': style.fontFamily,
              'size': style.fontSize.toString(),
              'bold': (FontWeight.values.indexOf(style.fontWeight!) > FontWeight.values.indexOf(FontWeight.normal)).toString(),
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
              'colorAccent': (style.decorationColor?.value ?? 0).toString(), // TBD: are this the same??
            };
          }

          final RenderBox box = context!.findRenderObject() as RenderBox;
          final Offset position = box.localToGlobal(Offset.zero);

          if (image != null) {
            tlLogger.v("Adding image to layouts....");
          }
          tlLogger.v('*#* Layout Flutter -- x: ${position.dx}, y: ${position.dy}, width: ${box.size.width.toInt()}, text: $text');

          layouts.add(<String, dynamic>{
            'id': path,
            'cssId': wp.widgetDigest,
            'idType': (-4).toString(),
            'tlType': (image != null) ? 'image' : (text!.contains('\n') ? 'textArea' : 'label'),
            'type': type,
            'subType': subType,
            'position': <String, String>{
              'x': position.dx.toInt().toString(),
              'y': position.dy.toInt().toString(),
              'width': box.size.width.toInt().toString(),
              'height': box.size.height.toInt().toString(),
            },
            'zIndex': "501",
            if (text != null) 'currState': <String, dynamic>{
              'text': text,
              'placeHolder': "", // TBD??
              'font': font
            },
            if (image != null)  'image' : image,
            if (aStyle != null) 'style' : aStyle,
            'originalId': path.replaceAll("/", ""),
            'masked': '$masked'
          });
        }
      }
    }
    tlLogger.v('*#* Number of layouts to log: ${layouts.length}');
    layoutParametersForGestures = hasGestures ? List.unmodifiable(layouts) : null;

    tlLogger.v("Size of widget path cache before removing text objects: ${WidgetPath.size}");

    WidgetPath.removeWhere((key, value) {
      final WidgetPath wp = value as WidgetPath;
      final String subType = wp.parameters == null ? "" : wp.parameters!['subType']?? "";
      if (subType.compareTo("TextView") == 0) {
        return true;
      }
      // Images are immutable, so they are reused, even while waiting for the image data
      // to appear. When the data is available, a setState causes a redraw and that is the frame
      // that has the image data!
      if (subType.compareTo("ImageView") == 0 && wp.parameters?['image'] != null) {
        tlLogger.v("Removing image and adding to layout!!!");
        return true;
      }
      return false;
    });

    tlLogger.v("Cache after: ${WidgetPath.size}, # of layouts: ${layouts.length}");

    return layouts;
  }
}

class _Pinch {
  static const initScale = 1.0;
  final List<String> directions = ['close', 'open'];

  Offset? _startPosition;
  Offset? _updatePosition;
  double  _scale = -1;
  int     _fingers = 0;

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
  double  get getScale => _scale;
  int     get getMaxFingers => _fingers;

  String pinchResult() {
    if (_startPosition == null || _updatePosition == null || _scale == initScale || _fingers != 2) {
      return "";
    }
    return directions[_scale < initScale ? 0 : 1];
  }
}

class _Swipe {
  final List<String> directions = ['right', 'left', 'down', 'up'];

  Offset? _startPosition;
  Offset? _updatePosition;
  Duration? _startTimestamp;
  Duration? _updateTimestamp;

  set startPosition(Offset position) => _startPosition = position;
  set startTimeStamp(Duration ts) => _startTimestamp = ts;
  set updatePosition(Offset position) => _updatePosition = position;
  set updateTimestamp(Duration ts) => _updateTimestamp = ts;
  Offset? get getStartPosition => _startPosition;
  Offset? get getUpdatePosition => _updatePosition;
  String getStartTimestampString() => _startTimestamp!.inMilliseconds.toString();
  String getUpdateTimestampString() => _updateTimestamp!.inMilliseconds.toString();

  String calculateSwipe() {
    if (_startPosition == null || _updatePosition == null) {
      return "";
    }
    final Offset offset = _updatePosition! - _startPosition!;
    return _getSwipeDirection(offset);
  }

  String _getSwipeDirection(Offset offset) {
    final int axis = offset.dx.abs() < offset.dy.abs() ? 2 : 0;
    final int direction = (axis == 0) ? (offset.dx < 0 ? 1 : 0) : (offset.dy < 0 ? 1 : 0);
    return directions[axis + direction];
  }
}

@Aspect()
@pragma("vm:entry-point")
class TealeafAopInstrumentation {
  TealeafAopInstrumentation();

  static const String _tap           = "onTap";
  static const String _doubleTap     = "onDoubleTap";
  static const String _longPress     = "onLongPress";
  static const String _onPanStart    = "onPanStart";
  static const String _onPanEnd      = "onPanEnd";
  static const String _onPanUpdate   = "onPanUpdate";
  static const String _onScaleStart  = "onScaleStart";
  static const String _onScaleUpdate = "onScaleUpdate";
  static const String _onScaleEnd    = "onScaleEnd";

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
      FlutterError.onError = wrap(FlutterError.onError, "Flutter onError");

      _TlBinder().init();
      catchForLogging(pointcut.positionalParams?[0]?? const Text("The main app widget is null!"));

      tlLogger.v("!!! exit runApp replacement hook");
    });
  }

  @Execute("package:flutter/src/widgets/text.dart", "Text", "-build")
  @pragma("vm:entry-point")
  dynamic _xxxTealeaf7(PointCut pointcut) {
    final TimeIt timer = TimeIt(label: "Text Injection: (${pointcut.target.toString()}");
    try {
      return timer.execute(() {
        if (pointcut.target is Text) {
          textHelper(pointcut, (widget) => widget.data ?? (widget.textSpan != null ? widget.textSpan.toPlainText() : ""));
        }
        return timer.execute(() => pointcut.proceed(), label: "Text build only");
      });
    }
    finally {
      timer.showResults();
    }
  }

  @Call("package:flutter/src/material/text_field.dart", "_TextFieldState", "+_TextFieldState")
  @pragma("vm:entry-point")
  static dynamic _xxxTealeaf8(PointCut pointcut) {
    final TimeIt timer = TimeIt();
    try {
      return timer.execute(() {
        dynamic tfs = timer.execute(() => pointcut.proceed(), label: "_TextFieldState Constructor");
        tfs.forcePressEnabled = false; // Initialize "late" variable (always reset in build)
        return tfs;
      },
      label: "Total including setting late variable");
    }
    finally {
      timer.showResults();
    }
  }

  @Execute("package:flutter/src/material/text_field.dart", "_TextFieldState", "-build")
  @pragma("vm:entry-point")
  dynamic _xxxTealeaf9(PointCut pointcut) {
    final TimeIt timer = TimeIt(label: 'TextField Injection');
    try {
      return timer.execute(() {
        final dynamic tfs = pointcut.target;
        final dynamic widget = tfs.widget;
        if (widget is TextField) {
          textHelper(pointcut, (widget) {
            try {
              String text = widget.controller.text;
              if (text.isEmpty) {
                text = widget.decoration.hintText;
                // TBD: do we need to handle errorText, and any others?
              }
              return text;
            }
            on NoSuchMethodError {
              tlLogger.v('The class object is not a TextField while attempting to get text data!');
              return "";
            }
          });
        }
        return timer.execute(() => pointcut.proceed(), label: 'TextField build only');
      });
    }
    finally {
      timer.showResults();
    }
  }

  @Execute("package:flutter/src/cupertino/text_field.dart", "CupertinoTextField", "-build")
  @pragma("vm:entry-point")
  dynamic _xxxTealeaf10(PointCut pointcut) {
  }

  static void textHelper(PointCut pointcut, Function getText) async {
    final BuildContext bc = pointcut.positionalParams?[0];
    final dynamic target = pointcut.target;
    final Widget widget = (target is Widget) ? target : target.widget;

    tlLogger.v('Text widget: ${widget.runtimeType.toString()}, context: ${bc.toString()}');

    final TextStyle style = pointcut.members?['style']?? DefaultTextStyle.of(bc).style?? TextStyle();
    final TextAlign textAlign = pointcut.members?['textAlign']?? DefaultTextStyle.of(bc).textAlign?? TextAlign.left;
    final WidgetPath wc = WidgetPath.create(bc, shorten: true, hash: true);

    wc.addInstance(widget.hashCode);

    wc.setParameters = <String, dynamic> {
      'type':    widget.runtimeType.toString(),
      'subType': 'TextView',
      'data':    getText,
      'style':   style,
      'align':   textAlign
    };
  }

  @pragma("vm:entry-point")
  @Execute("package:flutter/src/widgets/image.dart", "_ImageState", "-_handleImageFrame")
  dynamic _xxxTealeaf12(PointCut pointcut) {
    final TimeIt timer = TimeIt(label: 'Image Injection for ready handler');
    try {
      return timer.execute(() {
        final dynamic target = pointcut.target;
        final Widget widget = (target is Widget) ? target : target.widget;
        final WidgetPath? wc = WidgetPath.getPath(widget.hashCode);

        if (wc != null) {
          final ImageInfo imageInfo = pointcut.positionalParams?[0];
          wc.parameters?['image'] = imageInfo.image;
          tlLogger.v('*** _ImageState._handleImageFrame. Widget hash: ${widget.hashCode}, image: ${wc.parameters?['image']}');
        }
        timer.execute(() => pointcut.proceed(), label: 'Set image handler');
      });
    }
    finally {
      timer.showResults();
    }
  }

  @Execute("package:flutter/src/widgets/image.dart", "_ImageState", "-build")
  @pragma("vm:entry-point")
  dynamic _xxxTealeaf13(PointCut pointcut) {
    final timer = TimeIt(label: 'Image Injection build');
    try {
      return timer.execute(() {
        final BuildContext bc = pointcut.positionalParams?[0];
        final dynamic target = pointcut.target;
        final Widget widget = (target is Widget) ? target : target.widget;

        tlLogger.v('_ImageState class. widget: ${widget.runtimeType.toString()}, hash: ${widget.hashCode}');

        final dynamic build = timer.execute(() => pointcut.proceed(), label: 'Image build only');

        final WidgetPath wc = WidgetPath.create(bc, shorten: true, hash: true);

        wc.addInstance(widget.hashCode);

        wc.setParameters = <String, dynamic>{
          'type': widget.runtimeType.toString(),
          'subType': 'ImageView',
          'data': (widget) async {
            tlLogger.v('_ImageState class: ${target.toString()}, hash: ${wc.key}');
            final dynamic image = wc.parameters?['image'];
            if (image != null) {
              Uint8List data = Uint8List(1);
              final bool useImageData = await _TlConfiguration().get('TealeafBasicConfig/GetImageDataOnScreenLayout')?? false;
              if (useImageData) {
                final ByteData byteData = await image.toByteData(format: ImageByteFormat.rawUnmodified);
                data = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);
              }
              final String width = '${image.width}';
              final String height = '${image.height}';
              tlLogger.v('*#* Image: # of bytes: ${data.length}, w: $width, h: $height, widget: ${widget.runtimeType.toString()}');
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
        };
        return build;
      });
    }
    finally {
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

        return timer.execute(() =>
            Listener(key: parms?["key"],
                onPointerDown: parms?["onPointerDown"],
                onPointerMove: parms?["onPointerMove"],
                onPointerUp: parms?["onPointerUp"],
                onPointerHover: parms?["onPointerHover"],
                onPointerCancel: parms?["onPointerCancel"],
                onPointerSignal: parms?["onPointerSignal"],
                behavior: parms?["behavior"] ?? HitTestBehavior.deferToChild,
                child: parms?["child"]
            ),
            label: 'Listener Constructor'
        );
      });
    }
    finally {
      timer.showResults();
    }
  }

  @Call("package:flutter/src/widgets/gesture_detector.dart", "GestureDetector", "+GestureDetector")
  @pragma("vm:entry-point")
  static dynamic _xxxTealeaf3(PointCut pointcut) {
    final TimeIt timer = TimeIt(label: 'GestureDetector Injection');
    try {
      return timer.execute(() {
        final Map<dynamic, dynamic> params = pointcut.namedParams!;
        final Widget child = params['child'];
        Widget? gesture; // Note: this is set AFTER it is referenced in callback. On callback, the value has been set!

        tlLogger.v('Gesture constructor child widget: ${child.runtimeType.toString()}, child hash: ${child.hashCode}');

        // Simple gestures

        if (params.containsKey(_tap)) {
          final GestureTapCallback? userCallback = params[_tap];
          params[_tap] = () {
            gestureHelper(gesture: gesture!, gestureType: 'tap');
            if (userCallback != null) {
              userCallback();
            }
          };
        }
        if (params.containsKey(_doubleTap)) {
          final GestureDoubleTapCallback? userCallback = params[_doubleTap];
          params[_doubleTap] = () {
            gestureHelper(gesture: gesture!, gestureType: 'doubletap');
            if (userCallback != null) {
              userCallback();
            }
          };
        }
        if (params.containsKey(_longPress)) {
          final GestureLongPressCallback? userCallback = params[_longPress];
          params[_longPress] = () {
            gestureHelper(gesture: gesture!, gestureType: 'taphold');
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
            swipeGestureHelper(gesture: gesture!, onType: _onPanStart, offset: position, timestamp: timestamp!);
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
            swipeGestureHelper(gesture: gesture!, onType: _onPanUpdate, offset: position, timestamp: timestamp!);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        if (params.containsKey(_onPanEnd)) {
          final dynamic userCallback = params[_onPanEnd];
          params[_onPanEnd] = (DragEndDetails details) {
            final Velocity velocity = details.velocity;
            swipeGestureHelper(gesture: gesture!, onType: _onPanEnd, velocity: velocity);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        if (params.containsKey(_onScaleStart)) {
          final dynamic userCallback = params[_onScaleStart];
          params[_onScaleStart] = (ScaleStartDetails details) {
            final Offset position  = details.focalPoint;
            pinchGestureHelper(gesture: gesture!, onType: _onScaleStart, offset:position);
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
            tlLogger.v('&&& ScaleUpdate, scale: $scale, fingers: $fingers');

            pinchGestureHelper(gesture: gesture!, onType: _onScaleUpdate, scale: scale, fingers: fingers, offset: position);
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
            pinchGestureHelper(gesture: gesture!, onType: _onScaleEnd, fingers: fingers, velocity: velocity);
            if (userCallback != null) {
              userCallback(details);
            }
          };
        }
        gesture = timer.execute(() =>
            GestureDetector(
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
                onSecondaryLongPressCancel: params['onSecondaryLongPressCancel'],
                onSecondaryLongPress: params['onSecondaryLongPress'],
                onSecondaryLongPressStart: params['onSecondaryLongPressStart'],
                onSecondaryLongPressMoveUpdate: params['onSecondaryLongPressMoveUpdate'],
                onSecondaryLongPressUp: params['onSecondaryLongPressUp'],
                onSecondaryLongPressEnd: params['onSecondaryLongPressEnd:'],
                onTertiaryLongPressDown: params['onTertiaryLongPressDown'],
                onTertiaryLongPressCancel: params['onTertiaryLongPressCancel'],
                onTertiaryLongPress: params['onTertiaryLongPress:'],
                onTertiaryLongPressStart: params['onTertiaryLongPressStart'],
                onTertiaryLongPressMoveUpdate: params['onTertiaryLongPressMoveUpdate'],
                onTertiaryLongPressUp: params['onTertiaryLongPressUp'],
                onTertiaryLongPressEnd: params['onTertiaryLongPressEnd'],
                onVerticalDragDown: params['onVerticalDragDown'],
                onVerticalDragStart: params['onVerticalDragStart'],
                onVerticalDragUpdate: params['onVerticalDragUpdate'],
                onVerticalDragEnd: params['onVerticalDragEnd'],
                onVerticalDragCancel: params['nVerticalDragCancel'],
                onHorizontalDragDown: params['onHorizontalDragDown'],
                onHorizontalDragStart: params['onHorizontalDragStart'],
                onHorizontalDragUpdate: params['onHorizontalDragUpdate'],
                onHorizontalDragEnd: params['onHorizontalDragEnd'],
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
                onScaleStart: params['onScaleStart'],
                onScaleUpdate: params['onScaleUpdate'],
                onScaleEnd: params['onScaleEnd'],
                behavior: params['behavior'],
                excludeFromSemantics: params[''] ?? false,
                dragStartBehavior: params['dragStartBehavior'] ?? DragStartBehavior.start
            ),
            label: 'GestureDetector Constructor'
        );
        tlLogger.v('@@@ Gesture class created: ${gesture.hashCode}');

        return gesture;
      });
    }
    finally {
      timer.showResults();
    }
  }

  @Execute("package:flutter/src/widgets/gesture_detector.dart", "GestureDetector", "-build")
  @pragma("vm:entry-point")
  dynamic _xxxTealeaf4(PointCut pointcut) {
    final TimeIt timer = TimeIt(label: 'GestureDetector Injection build');
    try {
      return timer.execute(() {
        Widget? w = pointcut.target as Widget;
        tlLogger.v('Build WIDGET: ${w.runtimeType.toString()} ${w.hashCode}');
        final BuildContext b = pointcut.positionalParams?[0];
        final WidgetPath wc = WidgetPath.create(b, shorten: true, hash: true);

        wc.addInstance(w.hashCode);

        wc.setParameters = <String, dynamic>{ 'type': w.runtimeType.toString()};
        return timer.execute(() => pointcut.proceed(), label: 'GestureDetector build');
      });
    }
    finally {
      timer.showResults();
    }
  }

   @Call("package:tl_flutter_plugin/tl_flutter_plugin.dart", "PluginTealeaf", "+aspectdTest")
   @pragma("vm:entry-point")
   static bool _xxxTealeaf5(PointCut pointcut) {
     tlLogger.v('[AspectD test]: call method return value modified false => true (AOP TEST)');
     return true;
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

   static Map<String, dynamic> errorDetailsHelper(FlutterErrorDetails fed, String type) {
     final Map<String, dynamic> data = {};
     final String errorString = fed.exception.runtimeType.toString();

     data["name"] = errorString;
     data["message"] = fed.toStringShort();
     data["stacktrace"] = fed.stack.toString();
     data["handled"] = true;

     tlLogger.v("!!! Flutter exception, type: $type, class: $errorString, hash: ${fed.exception.hashCode}");

     return data;
   }

  static Object? encodeJsonPointerEvent(Object? value) {
    Map<String, dynamic> map = {};

    if (value != null && value is PointerEvent) {
      final PointerEvent pointerEvent = value;

      map['position'] = { 'dx': pointerEvent.position.dx, 'dy': pointerEvent.position.dy };
      map['localPosition'] = { 'dx': pointerEvent.localPosition.dx, 'dy': pointerEvent.localPosition.dy };
      map['down'] = pointerEvent.down;
      map['kind'] = pointerEvent.kind.index;
      map['buttons'] = pointerEvent.buttons;
      map['embedderId'] = pointerEvent.embedderId;
      map['pressure'] = pointerEvent.pressure;
      map['timestamp'] = pointerEvent.timeStamp.inMicroseconds;
    }

    return map;
  }

  static dynamic wrap(dynamic Function(FlutterErrorDetails fed)? f, String type) {
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
      tlLogger.v('Uncaught Exception: ${e.toString()}\nstackTrace: ${stackTrace.toString()}');

      final Map<String, dynamic> data = {};
      bool isLogException = false;

      if (e is PlatformException) {
        final PlatformException pe = e;
        data["nativecode"] = pe.code;
        data["nativemessage"] = pe.message?? "";
        data["nativestacktrace"] = pe.stacktrace?? "";
        data["message"] = e.toString();
      }
      else if (e is TealeafException) {
        final TealeafException te = e;

        data["nativecode"] = te.code?? '';
        data["nativemessage"] = te.getNativeMsg?? '';
        data["nativestacktrace"] = te.getNativeDetails?? '';
        data["message"] = te.getMsg?? '';
        isLogException = te.getMsg?.contains(TealeafException.logErrorMsg)?? false;
      } else {
        String message = "";
        try {
          message = e.message?? "";
        }
        on NoSuchMethodError {
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
      }
      else {
        PluginTealeaf.onTlException(data: data);
      }
    });
  }

  static String getGestureTarget(WidgetPath wc) {
    final dynamic widget = wc.context!.widget;
    String gestureTarget;

    try {
      gestureTarget = widget.child.runtimeType.toString();
    }
    on NoSuchMethodError {
      gestureTarget = wc.parentWidgetType!;
    }
    return gestureTarget;
  }

  static void gestureHelper({Widget? gesture, String? gestureType}) async {
    final int hashCode = gesture.hashCode;

    if (WidgetPath.containsKey(hashCode)) {
      final WidgetPath? wc = WidgetPath.getPath(hashCode);
      final BuildContext? context = wc!.context;
      final String gestureTarget = getGestureTarget(wc);

      tlLogger.v('@@@ ${gestureType!.toUpperCase()}: Gesture widget, context hash: ${context.hashCode}, widget hash: $hashCode');
      tlLogger.v('--> Path: ${wc.widgetPath}, digest: ${wc.widgetDigest}');

      await PluginTealeaf.onTlGestureEvent(
        gesture: gestureType,
        id: wc.widgetPath,
        target: gestureTarget,
        layoutParameters: _TlBinder.layoutParametersForGestures
      );
    }
    else {
      tlLogger.v("ERROR: ${gesture.runtimeType.toString()} gesture not found for hashcode: $hashCode");
    }
  }

  static void swipeGestureHelper({required Widget gesture, required String onType, Offset? offset, Duration? timestamp, Velocity? velocity}) async {
    final int hashCode = gesture.hashCode;

    if (WidgetPath.containsKey(hashCode)) {
      final WidgetPath? wc = WidgetPath.getPath(hashCode);
      final BuildContext? context = wc!.context;
      final String gestureTarget = getGestureTarget(wc);

      tlLogger.v('@@@ ${onType.toUpperCase()}: Gesture widget, context hash: ${context.hashCode}, widget hash: $hashCode');
      tlLogger.v('--> Path: ${wc.widgetPath}, digest: ${wc.widgetDigest}');

      switch (onType) {
        case _onPanStart: {
          final _Swipe swipe = _Swipe();
          swipe.startPosition = offset!;
          swipe.startTimeStamp = timestamp!;
          wc.setParameters = <String, dynamic> {'swipe' : swipe};
          break;
        }
        case _onPanUpdate: {
          if (wc.parameters != null && wc.parameters!.containsKey('swipe')) {
            final _Swipe swipe = wc.parameters?['swipe'];
            swipe.updatePosition = offset!;
            swipe.updateTimestamp = timestamp!;
          }
          break;
        }
        case _onPanEnd: {
          if (wc.parameters != null && wc.parameters!.containsKey('swipe')) {
            final _Swipe swipe = wc.parameters?['swipe'];
            final String direction = swipe.calculateSwipe();
            if (direction.isNotEmpty) {
              final Offset start = swipe.getStartPosition!;
              final Offset end   = swipe.getUpdatePosition!;
              wc.parameters!.clear();
              await PluginTealeaf.onTlGestureEvent(
                gesture: 'swipe',
                id: wc.widgetPath,
                target: gestureTarget,
                data: <String, dynamic> {
                  'pointer1':  {'dx': start.dx, 'dy': start.dy, 'ts': swipe.getStartTimestampString()},
                  'pointer2':  {'dx': end.dx,   'dy': end.dy,   'ts': swipe.getUpdateTimestampString()},
                  'velocity':  {'dx': velocity?.pixelsPerSecond.dx, 'dy': velocity?.pixelsPerSecond.dy},
                  'direction': direction,
                },
                layoutParameters: _TlBinder.layoutParametersForGestures
              );
            }
          }
          break;
        }
        default:
          break;
      }
    }
    else {
      tlLogger.v("ERROR: ${gesture.runtimeType.toString()} not found for hashcode: $hashCode");
    }
  }

  static void pinchGestureHelper({required Widget gesture, required String onType, Offset? offset, double? scale, Velocity? velocity, int fingers=0}) async {
    final int hashCode = gesture.hashCode;

    if (WidgetPath.containsKey(hashCode)) {
      final WidgetPath? wc = WidgetPath.getPath(hashCode);
      final BuildContext? context = wc!.context;
      final String gestureTarget = getGestureTarget(wc);

      tlLogger.v('@@@ ${onType.toUpperCase()}: Gesture widget, context hash: ${context.hashCode}, widget hash: $hashCode');

      switch (onType) {
        case _onScaleStart: {
          final _Pinch pinch = _Pinch();
          pinch.startPosition = offset!;
          wc.setParameters = <String, dynamic> {'pinch' : pinch};
          break;
        }
        case _onScaleUpdate: {
          if (wc.parameters != null && wc.parameters!.containsKey('pinch')) {
            final _Pinch pinch = wc.parameters?['pinch'];
            pinch.updatePosition = offset!;
            pinch.scale = scale!;
            pinch.fingers = fingers;
          }
          break;
        }
        case _onScaleEnd: {
          if (wc.parameters != null && wc.parameters!.containsKey('pinch')) {
            final _Pinch pinch = wc.parameters?['pinch'];
            pinch.fingers = fingers;
            final String direction = pinch.pinchResult();
            tlLogger.v('--> Pinch, fingers: ${pinch.getMaxFingers}, direction: $direction');

            if (direction.isNotEmpty) {
              final Offset start = pinch.getStartPosition!;
              final Offset end   = pinch.getUpdatePosition!;
              wc.parameters!.clear();
              await PluginTealeaf.onTlGestureEvent(
                  gesture: 'pinch',
                  id: wc.widgetPath,
                  target: gestureTarget,
                  data: <String, dynamic> {
                    'pointer1':  {'dx': start.dx, 'dy': start.dy},
                    'pointer2':  {'dx': end.dx,   'dy': end.dy},
                    'direction': direction,
                    'velocity':  {'dx': velocity?.pixelsPerSecond.dx, 'dy': velocity?.pixelsPerSecond.dy},
                  },
                  layoutParameters: _TlBinder.layoutParametersForGestures
              );
            }
          }
          break;
        }
        default:
          break;
      }
    }
    else {
      tlLogger.v("ERROR: ${gesture.runtimeType.toString()} not found for hashcode: $hashCode");
    }
  }
}
