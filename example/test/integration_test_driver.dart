import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

void main() async {
  final packageName = "com.example.tl_flutter_plugin_example";
  final adbPath = "/opt/homebrew/bin/adb";
  final emulatorDeviceId = "emulator-5556";
  await Process.run(adbPath, [
    "-s",
    emulatorDeviceId,
    'shell',
    'pm',
    'grant',
    packageName,
    'android.permission.WRITE_EXTERNAL_STORAGE'
  ]);
  await Process.run(adbPath, [
    "-s",
    emulatorDeviceId,
    'shell',
    'pm',
    'grant',
    packageName,
    'android.permission.READ_EXTERNAL_STORAGE'
  ]);
  await integrationDriver();
}
