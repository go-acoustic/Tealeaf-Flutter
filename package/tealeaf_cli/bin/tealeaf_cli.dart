import 'dart:convert';
import 'dart:io';
import 'package:tealeaf_cli/tealeaf_cli.dart' as tealeaf_cli;
import 'package:tealeaf_cli/models/basic_config_model.dart';
import 'package:dcli/dcli.dart';

void main(List<String> arguments) async {
  bool debug = false;
  Settings().setVerbose(enabled: debug);

  String? appKey;
  String? postmessageURL;

  if (arguments.length == 2) {
    appKey = arguments[0];
    postmessageURL = arguments[1];

    print(appKey);
    print(postmessageURL);
  }

  // For test only
  // String currentProjectDir =
  //     "/Users/changjieyang/developer/Acoustic/TL-Flutter-Plugin/example/gallery";

  String currentProjectDir = Directory.current.path;
  String pluginRoot = tealeaf_cli.getPluginPath(currentProjectDir);
  stdout.writeln('tealeaf_cli working...');

  // Setup TealeafConfig.json
  stdout.writeln('Setup TealeafConfig.json');
  tealeaf_cli.setupJsonConfig(
      pluginRoot, currentProjectDir, appKey, postmessageURL);

  // Setup mobile platforms
  stdout.writeln('Setup mobile platforms');
  tealeaf_cli.setupMobilePlatforms(pluginRoot, currentProjectDir);

  // Update config
  var input = File("$currentProjectDir/TealeafConfig.json").readAsStringSync();
  Map<String, dynamic> configMap = jsonDecode(input);
  BasicConfig basicConfig = BasicConfig.fromJson(configMap);
  stdout.writeln('Updating TealeafLayoutConfig');
  tealeaf_cli.updateTealeafLayoutConfig(basicConfig, currentProjectDir);

  // Update Tealeaf basic config.
  basicConfig.tealeaf!.toJson().forEach((key, value) async {
    if (key == "layoutConfig") return;

    if (key == "AppKey" && appKey != null) {
      value = appKey;
    }
    if (key == "PostMessageUrl" && postmessageURL != null) {
      value = postmessageURL;
    }

    tealeaf_cli.updateBasicConfig(pluginRoot, currentProjectDir, key, value);
  });

  stdout.writeln('tl_flutter_plugin configured');
}
