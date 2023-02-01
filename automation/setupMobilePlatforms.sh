#!/usr/local/bin/bash

projectDir=""
while [[ $projectDir = "" ]]; do
   read -p "Where is your Flutter project located? " projectDir
done

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
androidSuccess=false
appKey=b6c3709b7a4c479bb4b5a9fb8fec324c
cp -r $tlPlugin/example/android/app/src/main/assets "$projectDir/android/app/src/main/" &&  androidSuccess=true  || echo "Failed to copy assets"

if $androidSuccess
then
sed -i '' "s/.*AppKey=.*/AppKey=$appKey/" "$projectDir/android/app/src/main/assets/TealeafBasicConfig.properties"
sed -i '' "s/.*AppKey=.*/AppKey=$appKey/" "$projectDir/android/app/src/main/assets/TealeafBasicConfig.properties.original"
fi

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

podSuccess=false
# install pods
cd $projectDir/ios/
flutter precache --ios
pod install && podSuccess=true || echo "Issue installing pods"

echo 
echo

if $podSuccess
then
echo "iOS enviroment installed successfully"
echo "Path to configure Tealeaf for iOS: " $projectDir/ios/Pods/TealeafDebug/SDKs/TLFResources.bundle/
fi

echo
echo

if $androidSuccess
then
echo "Android enviroment installed successfully"
echo "Path to configure Tealeaf for Android: " $projectDir/android/app/src/main/assests/
echo
fi
