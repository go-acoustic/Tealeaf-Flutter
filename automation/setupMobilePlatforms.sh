#!/bin/bash

flutterDir=$1
projectDir=$2

if [ ! -d "$projectDir/android" ] ||  [ ! -d "$projectDir/ios" ]
then
    echo "Error with Flutter project's root directory. Please confirm directory contains an android and ios directory."
    exit 1
fi

# Set up Android
# Copy assets from plugin to flutter project
tlPlugin=$flutterDir

echo -e "\nCopying Android assets"
cp -r $tlPlugin/automation/android/ "$projectDir/android/app/src/main/assets/" &&  androidSuccess=true  || echo "Failed to copy Android assets"

if $androidSuccess
then
echo -e "Complete Copying Android assets\n"
else
exit 1
fi

# Update build gradle 
androidBuildGradle="$projectDir/android/app/build.gradle"
sed -i '' "s/flutter.minSdkVersion/21/" $androidBuildGradle

# Copy assets from plugin to flutter project
echo -e "\nCopying iOS assets"
cp -r $tlPlugin/automation/ios/ "$projectDir/ios/Runner/" &&  iOsAssetSuccess=true  || echo "Failed to copy iOS assets"

if $iOsAssetSuccess
then
echo -e "Complete Copying iOS assets\n"
else
exit 1
fi

# Set up iOS
# Update Podfile
iosPodfile="$projectDir/ios/Podfile" 
sed -i '' "s/# platform :ios, '11.0'/platform :ios, '12.0'/" $iosPodfile 

# Update AppDelegate
iosAppdelegate="$projectDir/ios/Runner/AppDelegate.swift"

if ! grep -Fxq "import Tealeaf" $iosAppdelegate
then
sed -i '' "s/import Flutter/import Flutter\nimport Tealeaf/" $iosAppdelegate
sed -i '' "/@UIApplicationMain/d" $iosAppdelegate

addTealeafCode='\t\t\/\/ Tealeaf code\n\t\tTLFApplicationHelper().enableTealeafFramework()\n\t\t\/\/ End Tealeaf code\n'

sed -i '' "s/-> Bool {/-> Bool {\n$addTealeafCode/" $iosAppdelegate
fi

# Update Info.plist
infoPlist="$projectDir/ios/Runner/Info.plist"

if ! grep "TealeafApplication" $infoPlist
then
sed -i '' "s,<dict>,<dict>\n\t<key>NSPrincipalClass</key>\n\t<string>TealeafApplication</string>," $infoPlist
fi

# Delete pubspec.lock
if test -f $projectDir/pubspec.lock; then
rm $projectDir/pubspec.lock
fi 

# Update flutter dependencies
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
 