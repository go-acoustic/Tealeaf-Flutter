import 'package:http/http.dart' as http;
import 'package:tl_flutter_plugin/aspectd.dart';
import 'package:tl_flutter_plugin/tl_flutter_plugin.dart';
import 'logger.dart';

@Aspect()
@pragma("vm:entry-point")
class TealeafAopInstrumentationHttp {

@Call("package:http/src/base_client.dart", "BaseClient", "-send")
@pragma("vm:entry-point")
  dynamic _xxxTealeaf20(PointCut pointCut) async {
    final DateTime startTime = DateTime.now();
    final Object request = pointCut.positionalParams?[0];
    final int hash = request.hashCode;

    tlLogger.v("TL http BaseClient: ${request.toString()}, request hash: $hash, @${startTime.millisecondsSinceEpoch}");

    _TimedMap<int,int>().add(hash, startTime.millisecondsSinceEpoch);

    return pointCut.proceed();
  }

  @Call("package:http/src/response.dart", "Response", "+fromStream")
  @pragma("vm:entry-point")
  static Object _xxxTealeaf21(PointCut pointCut) {
    tlLogger.v("TL http response.fromStream: ${pointCut.toString()}");

    final Future<http.Response> result = pointCut.proceed() as Future<http.Response>;

    result.whenComplete(() async {
      final http.Response response = await result;
      final DateTime doneTime = DateTime.now();
      final http.Request request = response.request as http.Request;
      final int hash = request.hashCode;
      final String url = request.url.toString();
      final int start = _TimedMap<int, int>().remove(hash) ?? 0;
      final int done = doneTime.millisecondsSinceEpoch;

      tlLogger.v("http Response is ready: ${response.toString()}, request hash: $hash, start: $start,  done: $done");

      if (response.contentLength != null) {
        PluginTealeaf.tlConnection(
            url: url,
            statusCode: response.statusCode,
            description: response.reasonPhrase?? '',
            responseSize: response.contentLength?? 0,
            initTime: start,
            loadTime: done);
      }
    });

    return result;
  }
}

class _TimedMap<K,V> {
  static const int defaultTO = 30 * 1000; //milliseconds
  static const int frequency = 5;         // secs
  static bool running = false;

  V?   data;
  int  start = 0;
  int  timeout = 0;
  final int defaultTimeout;

  static Map<dynamic,dynamic> map = {};

  _TimedMap({this.defaultTimeout = defaultTO});

  void add(K key, V data, {int timeout = -1}) {
    this.data = data;
    this.timeout = timeout > 0 ? timeout : defaultTimeout;
    start = DateTime.now().millisecondsSinceEpoch;
    map[key] = this;
    checkForTimeouts();
  }

  V? remove(K key) {
    final _TimedMap<K,V> item = map.remove(key);
    return item.data;
  }

  void checkForTimeouts() {
    if (running || map.isEmpty) {
      tlLogger.v("Checks for Map timeouts stopped.");
      return;
    }
    running = true;

    Future.delayed(const Duration(seconds: frequency), ()
    {
      tlLogger.v("Running check for map timeouts");

      dynamic keys = map.keys.where((item) {
        final _TimedMap<K, V> value = map[item];
        return (DateTime.now().millisecondsSinceEpoch - value.start) > value.timeout;
      }).toList(growable: false);

      for (K key in keys) {
        tlLogger.v("Removed item ${key.toString()} on timeout from Map");
        map.remove(key);
      }

      running = false;
      checkForTimeouts();
    });
  }
}
