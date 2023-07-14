// @dart=2.18
import 'dart:io' as io;

void main() {
  final String version = io.Platform.version;

  final RegExp re =
      RegExp(r'[0-9]{1,2}\.[0-9]{1,2}\.[0-9]{1,2}', multiLine: false);
  final String? match = re.firstMatch(version)?[0];

  print('${match ?? ""}');
}
