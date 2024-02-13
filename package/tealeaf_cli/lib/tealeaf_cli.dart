import 'dart:io';
import 'dart:convert';
import 'package:dcli/dcli.dart';
import 'package:tealeaf_cli/setup_mobile_platforms.dart';
import 'package:yaml/yaml.dart';
import 'models/basic_config_model.dart';
import 'update_config.dart';

String getPluginPath(String currentProjectDir) {
  String pluginName = "tl_flutter_plugin";
  var pubFile = File("$currentProjectDir/pubspec.yaml").readAsStringSync();
  final pubspecLoader = loadYaml(pubFile) as YamlMap;
  final dependencies = pubspecLoader['dependencies'][pluginName];
  if (dependencies is YamlMap) {
    return dependencies['path'];
  } else {
    String version = dependencies.replaceAll('^', '');
    String pluginDirName = "$pluginName-$version";
    return "~/.pub-cache/hosted/pub.dev/$pluginDirName";
  }
}

setupMobilePlatforms(String pluginRoot, String currentProjectDir) {
  SetupMobilePlatforms setupMobilePlatforms = SetupMobilePlatforms();
  setupMobilePlatforms.run(pluginRoot, currentProjectDir);
}

void setupJsonConfig(String pluginRoot, String currentProjectDir, String appKey,
    String postMessageUrl) {
  var template = "$pluginRoot/automation/TealeafConfig.json";
  var file = "$currentProjectDir/TealeafConfig.json";
  // Ensure the file exists by copying the template first
  if (!File(file).existsSync()) {
    File(template).copySync(file);
    stdout.writeln("$template was copied to $file");
  }

  // Now update the TealeafConfig.json file with AppKey and PostMessageUrl
  updateTealeafConfig(file, appKey, postMessageUrl);
  stdout.writeln(
      'TealeafConfig updated with your project settings. You are ready to go!');
}

void updateTealeafConfig(
    String filePath, String appKey, String postMessageUrl) {
  var tealeafConfig = File(filePath);
  var configContent = tealeafConfig.readAsStringSync();

  // Use a more flexible way to replace the values
  var updatedConfig = configContent
      .replaceAll(RegExp(r'"AppKey":\s*".*?"'), '"AppKey": "$appKey"')
      .replaceAll(RegExp(r'"PostMessageUrl":\s*".*?"'),
          '"PostMessageUrl": "$postMessageUrl"');

  tealeafConfig.writeAsStringSync(updatedConfig);
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
    stdout.writeln("Issue with TealeafConfig.json");
  }
}

updateBasicConfig(
    String pluginRoot, String currentProjectDir, String key, dynamic value) {
  String valueType = value.runtimeType.toString();

  updateConfig(currentProjectDir, key, value, valueType);
}
