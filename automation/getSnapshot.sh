#!/bin/bash

PLUGIN_DIR=$1
whichFlutter=$(which flutter)
flutterDir=${whichFlutter%???????????}

cd $PLUGIN_DIR
pwd=$(pwd)


if [ ! -d "$pwd/tealeaf_aop" ]
then
    mkdir -p tealeaf_aop/flutter_frontend_server
fi

cd "$pwd/tealeaf_aop/flutter_frontend_server"

# Gets the dart version number
dartVersion=$(dart --version | perl -pe '($_)=/([0-9]+([.][0-9]+)+)/')

echo "Downloading frontend_server.dart.snapshot.$dartVersion"

# Downloads the snapshot based on dart version
curl -L  -O "https://github.com/acoustic-analytics/acoustic_tealeaf/raw/main/tealeaf_aop/flutter_frontend_server/frontend_server.dart.snapshot.$dartVersion"
