#!/usr/local/bin/bash
API_LEVEL=$1
set -e

AVD=$(emulator -list-avds | grep $API_LEVEL)
emulator -avd $AVD > /dev/null 2>&1 &

until adb shell true; do sleep 1; done # Wait for the android device to boot up before continuing
sleep 10 # Wait a few more seconds before continuing
