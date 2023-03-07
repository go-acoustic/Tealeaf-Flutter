import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:process_run/shell.dart';
import 'package:tlplugin/models/basic_config_model.dart';
import 'package:tlplugin/tlplugin.dart';

/// To run tlplugin dart commands
void main(List<String> arguments) async {
  final parser = ArgParser(allowTrailingOptions: true);

  parser.addFlag('help', abbr: 'h', help: 'Usage help', negatable: false);

  parser.addFlag('install',
      abbr: 'i',
      help:
          'Download tl_flutter_plugin dependencies and inject plugin to Flutter SDK',
      negatable: false);

  parser.addFlag('fullInstall',
      abbr: 'f',
      help: 'Full install of tl_flutter_plugin and project configuration',
      negatable: false);

  parser.addFlag('addToProject',
      abbr: 'a', help: 'Update Project configuration', negatable: false);

  parser.addFlag('generateConfig',
      abbr: 'g',
      help: 'Generate new TealeafConfig.json file',
      negatable: false);

  parser.addFlag('updateConfig',
      abbr: 'u', help: 'Update TealeafConfig.json', negatable: false);

  final argResults = parser.parse(arguments);
  final help = argResults['help'] as bool;
  final install = argResults['install'] as bool;
  final fullInstall = argResults['fullInstall'] as bool;
  final addToProject = argResults['addToProject'] as bool;
  final generateConfig = argResults['generateConfig'] as bool;
  final updateConfig = argResults['updateConfig'] as bool;

  String currentProjectDir = Directory.current.path;
  String pluginName = "tl_flutter_plugin";
  String version = await getVersion(currentProjectDir, pluginName);
  String pluginDirName = "$pluginName-$version";

// Get Flutter SDK dir
  var result = await Process.run('which', ['flutter']);
  String resultString = result.stdout;
  List splitPathNew = resultString.split("bin");
  String pluginRoot =
      "${splitPathNew[0]}.pub-cache/hosted/pub.dartlang.org/$pluginDirName/";

  bool debug = false;

  if (arguments.isEmpty) {
    stdout.writeln('Plugin requires an argument');
    stdout.writeln('Please run "tlplugin -h" to view list of options');
  }

  if (help) {
    stdout.writeln('Global options:');
    stdout.writeln(parser.usage);
  }

  if (install || fullInstall) {
    stdout.writeln('Please wait for installation to complete');
    await Shell(verbose: debug)
        .run("bash ${pluginRoot}automation/getSnapshot.sh $pluginRoot");

    await Shell(verbose: debug)
        .run("bash ${pluginRoot}automation/install-patch.sh $pluginRoot");

    if (install) {
      stdout.writeln('\nPlease restart your IDE\n');
    }
  }

  if (addToProject || fullInstall) {
    await Shell(verbose: debug).run(
        "bash ${pluginRoot}automation/setupMobilePlatforms.sh $pluginRoot $currentProjectDir");

    if (fullInstall) {
      generateJsonConfig(pluginRoot, currentProjectDir, debug);
      stdout.writeln('\nPlease restart your IDE\n');
    }
  }

  if (generateConfig) {
    generateJsonConfig(pluginRoot, currentProjectDir, debug);
  }

  if (updateConfig) {
    File file = File("$currentProjectDir/TealeafConfig.json");

    if (file.existsSync()) {
      var input =
          await File("$currentProjectDir/TealeafConfig.json").readAsString();

      Map<String, dynamic> configMap = jsonDecode(input);
      BasicConfig basicConfig = BasicConfig.fromJson(configMap);

      updateTealeafLayoutConfig(basicConfig, currentProjectDir);

      basicConfig.tealeaf!.toJson().forEach((key, value) async {
        if (key != "layoutConfig") {
          updateConfigShell(pluginRoot, currentProjectDir, key, value, debug);
        }
      });
    } else {
      stdout.writeln(
          'Unable to locate TealeafConfig.json in project\'s root directory\nPlease run "tlplugin -g" to generate new TealeafConfig.json');
    }
  }
}
