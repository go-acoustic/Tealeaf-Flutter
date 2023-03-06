#!/usr/local/bin/bash

PLUGIN_DIR=$1

whichFlutter=$(which flutter)
FLUTTER_DIR=${whichFlutter%???????????}

# Check if flutter has been properly installed
if ! command -v flutter &> /dev/null
then
    echo "The flutter tool was not found. See https://docs.flutter.dev/get-started/install/macos#update-your-path for help"
    exit 1
fi

# Get flutter version and retrieve flutter & dart version number  
flutterVer=$(flutter --version)
flutterVerArray=($(echo $flutterVer | tr "  " "\n"))

flutterIndex=-1
channelIndex=-1
dartIndex=-1
count=0
for i in "${flutterVerArray[@]}"
do
    if [ "$i" = "Flutter" ]; then
        let "flutterIndex=count+1"
    elif [ "$i" = "Dart" ]; then
        let "dartIndex=count+1"
    elif [ "$i" = "channel" ]; then
        let "channelIndex=count+1"
    fi

    let "count+=1"
done

# Set Flutter and Dart version number into variables
flutterVer=0
dartVer=0
channelVer=0

if [ $flutterIndex -gt -1 ]; then
    flutterVer=${flutterVerArray[flutterIndex]}
fi

if [ $dartIndex -gt -1 ]; then
    dartVer=${flutterVerArray[dartIndex]}
fi

if [ $channelIndex -gt -1 ]; then
    channelVer=${flutterVerArray[channelIndex]}
fi

# Check if Flutter channel is supported
if [ $channelVer != "stable" ]; then
    echo "Flutter version is not supported. Flutter channel must be stable"
    exit 1
fi

# Check if Flutter version is supported
if [[ ${flutterVer:0:1} -gt 2 && ${flutterVer:2:1} -lt 3  && ${flutterVer:4:2} -gt 10 ]]
then
    echo "Flutter version is not supported. Flutter version must be between 3.3.0 - 3.3.10"
    exit 1
fi

cd $PLUGIN_DIR/flutter_patches
flutterPatchesDir=$(pwd)

# Set the Flutter patch file
patchFile="tl_flutter_patch_${flutterVer}.zip"


if [ ! -f "$flutterPatchesDir/$patchFile" ]; then
    echo "$flutterPatchesDir/$patchFile  does not exists."
    exit 1
fi

# Copy Flutter patch to Flutter directory and unzip it
cp "$flutterPatchesDir/$patchFile" $FLUTTER_DIR
cd $FLUTTER_DIR
unzip -o $FLUTTER_DIR/$patchFile
rm $FLUTTER_DIR/$patchFile

# Check if cache directory exist and if it does delete it 
if [ -d $FLUTTER_DIR/bin/cache ] 
then
    rm -rf $FLUTTER_DIR/bin/cache
fi

# Rebuild flutter
flutter --version

exit 0