#!/usr/local/bin/bash
adb devices | grep emulator | cut -f1 | while read line; do adb -s $line shell reboot -p; done

xcrun simctl shutdown all
kill $(ps -e | grep -e "Simulator -CurrentDeviceUDID [0-9A-F\-]\{36\}" | grep -o -e "^ *[0-9]\+")
