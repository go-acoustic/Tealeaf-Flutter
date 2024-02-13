import 'dart:io';
import 'package:path/path.dart' as path;

void updateConfig(String projectDir, String key, String value, String type) {
  // Update Android
  String androidPath = path.join(
      projectDir, 'android/app/src/main/assets/TealeafBasicConfig.properties');
  File(androidPath).writeAsStringSync(File(androidPath)
      .readAsStringSync()
      .replaceAll(RegExp('.*$key=.*'), '$key=$value'));

  // Update iOS
  String iosPath = path.join(projectDir,
      'ios/Pods/TealeafDebug/SDKs/iOS/Debug/TLFResources.bundle/TealeafBasicConfig.plist');

  // Get int for key and value line
  List<String> iosLines = File(iosPath).readAsLinesSync();
  int keyLine = iosLines.indexWhere((line) => line.contains('<key>$key</key>'));
  int valueLine = keyLine + 1;
  String valueString = iosLines[valueLine];

  // Correct valueString for /
  String correctedString = valueString.replaceAll('/', r'\/');

  // Delete value string
  String iosContent = File(iosPath).readAsStringSync();
  File(iosPath).writeAsStringSync(iosContent.replaceAll(correctedString, ''));

  // Update based on type
  String replacement = "";
  if (type == 'String') {
    replacement = '>$key</key>\n\t<string>$value</string>';
  } else if (type == 'bool') {
    replacement = '>$key</key>\n\t<$value/>';
  } else if (type == 'int') {
    replacement = '>$key</key>\n\t<integer>$value</integer>';
  } else if (type == 'double') {
    replacement = '>$key</key>\n\t<real>$value</real>';
  }

  File(iosPath)
      .writeAsStringSync(iosContent.replaceAll(RegExp('.$key.*'), replacement));

  sleep(Duration(seconds: 1));
}

void main(List<String> args) {
  if (args.length < 5) {
    print('Usage: dart updateConfig.dart <projectDir> <KEY> <VALUE> <TYPE>');
    exit(1);
  }

  String projectDir = args[0];
  String key = args[1];
  String value = args[2];
  String type = args[3];

  updateConfig(projectDir, key, value, type);

  print('updateConfig done.');
}
