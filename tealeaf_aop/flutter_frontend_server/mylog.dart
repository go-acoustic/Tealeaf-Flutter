import 'dart:io' as io;

class MyLog {
  static io.File _file;
  static bool _enabled = true;

  static void p(String msg) {
    if (_enabled) {
      if (_file == null) {
        final String home = io.Platform.environment['HOME'] ??
            io.Platform.environment['USERPROFILE'];
        final String name = '${home == null ? "." : home}/tl_aop.log';

        _file = io.File(name);
        if (!_file.existsSync()) {
          _file.createSync();
        }
      }
      _file.writeAsStringSync('$msg\n', mode: io.FileMode.append, flush: true);
    }
  }
}
