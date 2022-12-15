#!/usr/local/bin/bash

# Check if flutter has been properly installed
if ! command -v flutter &> /dev/null
then
    echo "The flutter tool was not found. See https://docs.flutter.dev/get-started/install/macos#update-your-path for help"
    exit
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

# Check if Flutter version is supported
if [ $channelVer != "stable" ]; then
    echo "Flutter version is not supported. Flutter channel must be stable"
    exit
fi

if [[ ${flutterVer:0:1} -gt 2 && ${flutterVer:2:1} -lt 3 ]]
then
    echo "Flutter version is not supported. Flutter version must be greater than or equal to 3.3.0"
    exit
fi

cd ../flutter_patches
flutterPatchesDir=$(pwd)

# Get Flutter directory
flutterDir=$(which flutter)
flutterDirLen=${#flutterDir}
removeFlutterDirLen=11
flutterIndex=$(expr $flutterDirLen - $removeFlutterDirLen)
flutterDir=${flutterDir:0:flutterIndex}

# #Set the Flutter patch file
patchFile="tl_flutter_patch_3.3.x.zip"

# Copy Flutter patch to Flutter directory and unzip it
cp $flutterPatchesDir/$patchFile $flutterDir
cd $flutterDir
unzip -o $patchFile
rm $patchFile

# Check if cache directory exist and if it does delete it 
if [ -d $flutterDir/bin/cache ] 
then
    rm -rf $flutterDir/bin/cache
fi

# rebuild flutter
flutter --version


