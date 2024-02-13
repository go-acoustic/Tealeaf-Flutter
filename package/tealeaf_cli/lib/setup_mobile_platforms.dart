import 'dart:io';

class SetupMobilePlatforms {
  void run(String flutterDir, String projectDir) {
    // Check if android and ios directories exist
    if (!Directory('$projectDir/android').existsSync() ||
        !Directory('$projectDir/ios').existsSync()) {
      print(
          "Error with Flutter project's root directory. Please confirm the directory contains an android and ios directory.");
      exit(1);
    }

    // Set up Android
    // Copy assets from plugin to flutter project
    print("\nCopying Android assets");
    bool androidSuccess = copyAssets('$flutterDir/automation/android/',
        '$projectDir/android/app/src/main/assets/');

    if (androidSuccess) {
      print("Complete Copying Android assets\n");
    } else {
      exit(1);
    }

    // Update build gradle
    String androidBuildGradle = '$projectDir/android/app/build.gradle';
    updateBuildGradle(androidBuildGradle);

    // Copy assets from plugin to flutter project
    print("\nCopying iOS assets");
    bool iOsAssetSuccess =
        copyAssets('$flutterDir/automation/ios/', '$projectDir/ios/Runner/');

    if (iOsAssetSuccess) {
      print("Complete Copying iOS assets\n");
    } else {
      exit(1);
    }

    // Set up iOS
    // Update Podfile
    // String iosPodfile = '$projectDir/ios/Podfile';
    // updatePodfile(iosPodfile);

    // // Update AppDelegate
    // String iosAppdelegate = '$projectDir/ios/Runner/AppDelegate.swift';
    // updateAppDelegate(iosAppdelegate);

    // // Update Info.plist
    // String infoPlist = '$projectDir/ios/Runner/Info.plist';
    // updateInfoPlist(infoPlist);

    // Delete pubspec.lock
    // if (File('$projectDir/pubspec.lock').existsSync()) {
    //   File('$projectDir/pubspec.lock').deleteSync();
    // }

    // // Update flutter dependencies
    // Process.runSync('flutter', ['clean'], workingDirectory: projectDir);
    // Process.runSync('flutter', ['pub', 'get'], workingDirectory: projectDir);
    // print('');

    // Install pods
    // bool podSuccess = installPods(projectDir);

    // if (podSuccess) {
    //   print("\niOS environment installed successfully");
    // }

    if (androidSuccess) {
      print("Android environment installed successfully\n");
    }
  }

  bool copyAssets(String sourceDir, String destinationDir) {
    try {
      Directory(destinationDir).createSync(recursive: true);
      Process.runSync('cp', ['-r', sourceDir, destinationDir]);
      return true;
    } catch (e) {
      print('Failed to copy assets: $e');
      return false;
    }
  }

  void updateBuildGradle(String androidBuildGradle) {
    String content = File(androidBuildGradle).readAsStringSync();
    content = content.replaceFirst(RegExp(r'flutter\.minSdkVersion'), '21');
    File(androidBuildGradle).writeAsStringSync(content);
  }

  // void updatePodfile(String iosPodfile) {
  //   String content = File(iosPodfile).readAsStringSync();
  //   //TODO:
  //   // content = content.replaceFirst(RegExp(r'# platform :ios, \'11.0\''), 'platform :ios, \'12.0\'');
  //   File(iosPodfile).writeAsStringSync(content);
  // }

  // void updateAppDelegate(String iosAppdelegate) {
  //   String content = File(iosAppdelegate).readAsStringSync();
  //   if (!content.contains('import Tealeaf')) {
  //     content = content.replaceFirst(
  //         RegExp(r'import Flutter'), 'import Flutter\nimport Tealeaf');
  //     content = content.replaceAll(RegExp(r'@UIApplicationMain'), '');
  //     content +=
  //         '\n\t\t// Tealeaf code\n\t\tTLFApplicationHelper().enableTealeafFramework()\n\t\t// End Tealeaf code\n';
  //     //TODO:
  //     // content = content.replaceFirst(RegExp(r'-> Bool {'), '-> Bool {\n$addTealeafCode');
  //     File(iosAppdelegate).writeAsStringSync(content);
  //   }
  // }

  // void updateInfoPlist(String infoPlist) {
  //   String content = File(infoPlist).readAsStringSync();
  //   if (!content.contains('TealeafApplication')) {
  //     content = content.replaceFirst(RegExp(r'<dict>'),
  //         '<dict>\n\t<key>NSPrincipalClass</key>\n\t<string>TealeafApplication</string>');
  //     File(infoPlist).writeAsStringSync(content);
  //   }
  // }

  // bool installPods(String projectDir) {
  //   try {
  //     Directory('$projectDir/ios/').createSync();
  //     Process.runSync('rm', ['-rf', 'Podfile.lock'],
  //         workingDirectory: '$projectDir/ios/');
  //     Process.runSync('flutter', ['precache', '--ios'],
  //         workingDirectory: '$projectDir/ios/');
  //     Process.runSync('pod', ['update'], workingDirectory: '$projectDir/ios/');
  //     Process.runSync('pod', ['install'], workingDirectory: '$projectDir/ios/');
  //     return true;
  //   } catch (e) {
  //     print('Issue installing pods: $e');
  //     return false;
  //   }
  // }
}

void main(List<String> args) {
  String currentProjectDir = Directory.current.path;
  // String pluginRoot = getPluginPath(currentProjectDir);

  // Get the Flutter project path from the environment variable
  // final flutterProjectPath = Platform.environment['FLUTTER_PROJECT_PATH'];
  // print(flutterProjectPath);
  // print(Platform.resolvedExecutable);

  // if (pluginRoot.isEmpty) {
  //   print('Error: FLUTTER_PROJECT_PATH environment variable not set.');
  //   exit(1);
  // }

  if (args.length != 2) {
    print('Usage: dart run flutter_setup.dart <flutterDir> <projectDir>');
    exit(1);
  }

  String flutterDir = args[0];
  String projectDir = args[1];

  print(flutterDir);
  print(projectDir);

  SetupMobilePlatforms().run(flutterDir, projectDir);
}
