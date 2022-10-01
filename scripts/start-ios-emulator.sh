#!/usr/local/bin/bash

VERSION=$1
DEVICE_ID=$(xcrun simctl list devices | grep -A15 "$VERSION" | grep -o "iPhone .* ([0-9A-F\-]*)" | grep -o "[0-9A-F\-]\{36\}" | head -1)

echo "Found device $DEVICE_ID with version $VERSION"
open -a Simulator --args -CurrentDeviceUDID "$DEVICE_ID"
