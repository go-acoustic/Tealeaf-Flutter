import 'dart:io';
import 'dart:convert';
import 'package:dcli/dcli.dart';
import 'package:yaml/yaml.dart';
import 'models/basic_config_model.dart';

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
  "bash $pluginRoot/automation/setupMobilePlatforms.sh $pluginRoot $currentProjectDir"
      .run;
}

setupJsonConfig(String pluginRoot, String currentProjectDir) {
  var template = "$pluginRoot/automation/TealeafConfig.json";
  var file = "$currentProjectDir/TealeafConfig.json";
  if (exists(file)) {
    stdout.writeln('TealeafConfig found in your project. You are ready to go!');
  } else {
    "cp $template $file".run;
    stdout.writeln("$template was copied to $file");
  }
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
  "bash $pluginRoot/automation/updateConfig.sh  $currentProjectDir $key $value $valueType"
      .run;
}
