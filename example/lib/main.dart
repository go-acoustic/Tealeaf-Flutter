import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tl_flutter_plugin/swipeorpinch.dart';

// ignore: unused_import
import 'package:tl_flutter_plugin/tl_flutter_plugin.dart';

void main() {
  runApp(const MaterialApp(
    title: 'Navigation Basics',
    home: FirstRoute(),
  ));
}

class FirstRoute extends StatefulWidget {
  const FirstRoute({super.key});

  @override
  State<FirstRoute> createState() => _MyAppState();
}

class _MyAppState extends State<FirstRoute> {
  static const String undefined = 'undefined';

  String _platformVersion = undefined;
  String _pluginVersion = undefined;
  String _tealeafVersion = undefined;
  String _tealeafSessionId = undefined;
  String _appKey = undefined;
  // bool _aspectdEnabled = false;
  bool _pinch = false;
  bool _showExceptionMsg = true;
  static int count = 0;

  TextEditingController textEditingController = TextEditingController();
  Widget imgHolder = const Center(child: Icon(Icons.image));
  List<dynamic> httpList = [];

  @override
  void initState() {
    super.initState();
    initPlatformState();
    Future.delayed(const Duration(seconds: 20), () {
      debugPrint('Removing "tap on me for exception" message');
      if (mounted) {
        setState(() {
          _showExceptionMsg = false;
        });
      }
    });
  }

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion,
        tealeafVersion,
        tealeafSessionId,
        pluginVersion,
        appKey;
    // Platform messages may fail, so we use a try/catch TealeafException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = await PluginTealeaf.platformVersion;
    } on TealeafException {
      platformVersion = 'Failed to get platform version.';
    }
    try {
      tealeafVersion = await PluginTealeaf.tealeafVersion;
    } on TealeafException {
      tealeafVersion = 'Failed to get tealeaf lib version';
    }
    try {
      tealeafSessionId = await PluginTealeaf.tealeafSessionId;
    } on TealeafException {
      tealeafSessionId = 'Failed to get current session id';
    }
    try {
      pluginVersion = await PluginTealeaf.pluginVersion;
    } on TealeafException {
      pluginVersion = 'Failed to get plugin version';
    }
    try {
      appKey = await PluginTealeaf.appKey;
    } on TealeafException {
      appKey = 'Failed to get app key';
    }

    // _aspectdEnabled = PluginTealeaf.aspectdTest();

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance
    if (!mounted) return;

    if (tealeafSessionId.length > 32) {
      tealeafSessionId = '${tealeafSessionId.substring(0, 32)}...';
    }
    setState(() {
      _platformVersion = platformVersion;
      _tealeafVersion = tealeafVersion;
      _tealeafSessionId = tealeafSessionId;
      _pluginVersion = pluginVersion;
      _appKey = appKey;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget w = MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Tealeaf plugin (SDK) example app'),
        ),
        body: SwipeOrPinchDetector(
            pinch: _pinch,
            onPinch: (double? scale) =>
                debugPrint('PINCH (main.dart), scale: $scale'),
            onSwipe: (dir, offset) => debugPrint(
                'SWIPE (main.dart), direction: ${dir.toString()}, x,y: ${offset.dx}.${offset.dy}'),
            child: SingleChildScrollView(
                child: Center(
              child: Column(children: [
                const Padding(padding: EdgeInsets.only(top: 10.0)),
                const Image(
                  key: Key("owlImage"),
                  height: 70,
                  image: NetworkImage(
                      'https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg'),
                ),
                const Padding(padding: EdgeInsets.only(top: 15.0)),
                /*
            TextField(
              controller: textEditingController,
              onChanged: (s) {
                debugPrint('TextField CHANGED: s: $s, controller text> ${textEditingController.text?? "NONE"}');
              },
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.fromLTRB(10, 0, 10, 6),
                prefixIcon: Padding(
                  padding: EdgeInsetsDirectional.only(start: 12.0),
                  child: Icon(Icons.text_snippet_outlined),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10.0),),
                  borderSide: BorderSide(width: 0, style: BorderStyle.none,),
                ),
                filled: true,
                fillColor: Colors.lightBlueAccent,
                hintText: "Please enter text"
              )
            ),
            */
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Swipe"),
                  Radio(
                    key: Key("swipeRadio"),
                    value: false,
                    groupValue: _pinch,
                    onChanged: (value) {
                      setState(() => _pinch = value as bool);
                    },
                    activeColor: Colors.green,
                  ),
                  const Padding(padding: EdgeInsets.only(right: 15.0)),
                  const Text("Pinch"),
                  Radio(
                    key: Key("PinchRadio"),
                    value: true,
                    groupValue: _pinch,
                    onChanged: (value) {
                      setState(() => _pinch = value as bool);
                      print("pinch radio value $value");
                      print("pinch radio _pinch $_pinch");
                    },
                    activeColor: Colors.green,
                  )
                ]),
                const Padding(padding: EdgeInsets.only(top: 205.0)),
                Text('Running on: $_platformVersion'),
                Text('Tealeaf library version: $_tealeafVersion'),
                Text('Tealeaf plugin version: $_pluginVersion'),
                // Text('AspectD enabled: $_aspectdEnabled'),
                const Padding(padding: EdgeInsets.only(top: 10.0)),
                Text('AppKey: $_appKey'),
                const Text('Tealeaf SaaS Session ID: '),
                SelectableText(_tealeafSessionId),
                const Padding(padding: EdgeInsets.only(top: 20.0)),
                Text('Taps: $count'),
                const Padding(padding: EdgeInsets.only(bottom: 20.0)),
                if (_showExceptionMsg)
                  GestureDetector(
                      key: Key("exceptionGesture"),
                      child: const Text(
                          key: Key("exceptionText"),
                          "Tap on me to cause an exception!",
                          semanticsLabel: 'Expires in 15 seconds'),
                      onTap: () {
                        debugPrint("User wanted an exception thrown");
                        throw Exception(
                            "Test logging of uncaught Flutter exception");
                      }),
                const Padding(padding: EdgeInsets.only(bottom: 20.0)),
                Column(
                  children: <Widget>[
                    ElevatedButton(
                      child: const Text('Open route'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SecondRoute()),
                        );
                      },
                    ),
                    Text('Http list size: ${httpList.length}'),
                    ElevatedButton(
                      key: Key("httpGet"),
                      onPressed: () async {
                        List<dynamic> list = await connectionExample(
                            "https://jsonplaceholder.typicode.com/posts");
                        setState(() {
                          httpList = list;
                        });
                      },
                      child: const Text("http get"),
                    )
                  ],
                ),
                const Padding(padding: EdgeInsets.only(bottom: 40.0)),
                Semantics(
                    hint: "my hint",
                    label: "my label",
                    child: GestureDetector(
                        key: Key("GestureButton"),
                        child: Stack(
                            alignment: AlignmentDirectional.center,
                            children: [
                              Container(
                                  width: 55.0,
                                  height: 55.0,
                                  decoration: const BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle)),
                              const Icon(Icons.add)
                            ]),
                        onTap: () {
                          debugPrint("Incremented counter");
                          setState(() {
                            count += 1;
                          });
                        },
                        onLongPress: () {
                          debugPrint("Incremented counter (twice)");
                          setState(() {
                            count += 2;
                          });
                        })),
              ]),
            ))),
        floatingActionButton: FloatingActionButton(
          key: Key("floatingButton"),
          onPressed: () async {
            debugPrint("FAB onPressed!");
            setState(() {
              count += 1;
            });
          },
          tooltip: 'Increment the counter by pressing this button',
          child: const Icon(Icons.add),
        ),
      ),
    );

    /*
    try {
      throw Exception("Test Exception message");
    }
    catch(e, stack) {
      debugPrint("!!! Caught my own exception");
      PluginTealeaf.tlApplicationCaughtException(caughtException: e, stack: stack,
        appData:{
          "msg": "My error message",
          "where": "in my main.dart"
        }
      );
    }
    */
    PluginTealeaf.tlApplicationCustomEvent(
        eventName: "Custom test event",
        customData: {
          "data1": "END OF UI BUILD",
          "time": DateTime.now().toString()
        });
    return w;
  }

  Future<List<dynamic>> connectionExample(String url) async {
    final http.Response res = await http.get(Uri.parse(url));

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw "Unable to retrieve posts.";
  }
}

class SecondRoute extends StatelessWidget {
  const SecondRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Route'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Go back!'),
        ),
      ),
    );
  }
}
