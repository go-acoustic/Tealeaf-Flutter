#!/bin/bash

flutterDir=$1
projectDir=$2

if [ ! -d "$projectDir/android" ] ||  [ ! -d "$projectDir/ios" ]
then
    echo "Error with Flutter project's root directory. Please confirm directory contains an android and ios directory."
    exit 1
fi

#Set up Android
# Copy assets from plugin to flutter project
tlPlugin=$flutterDir

echo -e "\nCopying Android assets"
cp -r $tlPlugin/automation/android/ "$projectDir/android/app/src/main/assets/" &&  androidSuccess=true  || echo "Failed to copy assets"

if $androidSuccess
then
echo -e "Complete Copying Android assets\n"
else
exit 1
fi

# Update build gradle 
androidBuildGradle="$projectDir/android/app/build.gradle"
sed -i '' "s/flutter.minSdkVersion/21/" $androidBuildGradle 

# Set up iOS
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
echo

podSuccess=false
# install pods
cd $projectDir/ios/
rm -rf Podfile.lock
flutter precache --ios
pod update
pod install && podSuccess=true || echo "Issue installing pods"


if $podSuccess
then
echo -e "\niOS enviroment installed successfully"
fi

if $androidSuccess
then
echo -e "Android enviroment installed successfully\n"
fi
 