import 'dart:convert';
import 'dart:io';
import 'package:process_run/shell.dart';
import 'package:yaml/yaml.dart';

import 'models/basic_config_model.dart';

Future<String> getSDKPath(String pluginDirName) async {
  var result = await Process.run('which', ['flutter']);
  String resultString = result.stdout;
  List splitPathNew = resultString.split("bin");
  return "${splitPathNew[0]}.pub-cache/hosted/pub.dartlang.org/$pluginDirName/";
}

Future<String> getVersion(String currentProjectDir, String pluginName) async {
  var pubFile = await File("$currentProjectDir/pubspec.yaml").readAsString();
  final pubspecLoader = loadYaml(pubFile) as YamlMap;
  return pubspecLoader['dependencies'][pluginName].replaceAll('^', '');
}

generateJsonConfig(
    String pluginRoot, String currentProjectDir, bool debug) async {
  await Shell(verbose: debug).run(
      "bash ${pluginRoot}automation/generateConfig.sh $pluginRoot $currentProjectDir");
  stdout.writeln('Added TealeafConfig.json to current project');
}

updateConfigShell(String pluginRoot, String currentProjectDir, String key,
    dynamic value, bool debug) async {
  String valueType = value.runtimeType.toString();
  await Shell(verbose: debug).run(
      "bash ${pluginRoot}automation/updateConfig.sh  $currentProjectDir $key $value $valueType");
}

updateTealeafLayoutConfig(BasicConfig basicConfig, String currentProjectDir) {
  if (basicConfig.tealeaf?.layoutConfig != null) {
    JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String prettyprint = encoder.convert(basicConfig.tealeaf!.layoutConfig);

    try {
      File oldAndroidFile = File(
          '$currentProjectDir/android/app/src/main/assets/TealeafLayoutConfig.json');
      oldAndroidFile.deleteSync();
    } catch (e) {
      stdout.writeln(e);
    }

    try {
      File oldiOSFile = File(
          '$currentProjectDir/ios/Pods/TealeafDebug/SDKs/iOS/Debug/TLFResources.bundle/TealeafLayoutConfig.json');
      oldiOSFile.deleteSync();
    } catch (e) {
      stdout.writeln(e);
    }

    File('$currentProjectDir/android/app/src/main/assets/TealeafLayoutConfig.json')
        .create(recursive: true)
        .then((File file) {
      file.writeAsString(prettyprint);
      stdout.writeln('Updating Android TealeafLayoutConfig.json');
    });

    File('$currentProjectDir/ios/Pods/TealeafDebug/SDKs/iOS/Debug/TLFResources.bundle/TealeafLayoutConfig.json')
        .create(recursive: true)
        .then((File file) {
      file.writeAsString(prettyprint);
      stdout.writeln('Updating iOS TealeafLayoutConfig.json');
    });
  } else {
    stdout.writeln(
        "Issue with TealeafConfig.json\nPlease run ''tlplugin -u'' to generate new TealeafConfig.json");
  }
}
