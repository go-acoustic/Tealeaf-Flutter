#!/usr/local/bin/bash

read -p "Where is your Flutter project located? " projectDir


if [ ! -d "$projectDir/android" ] ||  [ ! -d "$projectDir/ios" ]
then
    echo "Error with Flutter project's root directory. Please confirm directory contains an android and ios directory."
    exit 0
fi

#Set up Android
whichFlutter=$(which flutter)
flutterDir=${whichFlutter%???????????}

cd $flutterDir.pub-cache/hosted/pub.dartlang.org/
pwd=$(pwd)

# Copy assets from plugin to flutter project
tlPlugin=$(find $pwd -name *"tl_flutter_plugin-"*)
cp -r $tlPlugin/example/android/app/src/main/assets "$projectDir/android/app/src/main/" || echo "Failed to copy assets"

# Update build gradle 
androidBuildGradle="$projectDir/android/app/build.gradle"
sed -i '' "s/flutter.minSdkVersion/21/" $androidBuildGradle 

#Set up iOS
# Update Podfile
iosPodfile="$projectDir/ios/Podfile" 
sed -i '' "s/# platform :ios, '11.0'/platform :ios, '12.0'/" $iosPodfile 

# Update AppDelegate
iosAppdelegate="$projectDir/ios/Runner/AppDelegate.swift"

if ! grep -Fxq "import Tealeaf" $iosAppdelegate
then
sed -i '' "s/import Flutter/import Flutter\nimport Tealeaf/" $iosAppdelegate 

addTealeafCode='\t\t\/\/ Tealeaf code\n\t\tsetenv("EODebug", "1", 1);\n\t\tsetenv("TLF_DEBUG", "1", 1);\n\t\tlet tlfApplicationHelperObj = TLFApplicationHelper()\n\t\ttlfApplicationHelperObj.enableTealeafFramework()\n\t\t\/\/'
sed -i '' "s/-> Bool {/-> Bool {\n$addTealeafCode/" $iosAppdelegate
fi

if test -f $projectDir/pubspec.lock; then
rm $projectDir/pubspec.lock
fi 

cd $projectDir
flutter clean && flutter pub get

# install pods
cd $projectDir/ios/
flutter precache --ios
pod install


