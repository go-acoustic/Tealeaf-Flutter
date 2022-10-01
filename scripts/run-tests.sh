#!/usr/local/bin/bash

DEVICE=$1
cd scripts

#./kill-devices.sh

echo "Starting device..."
if [[ "$DEVICE" == "android"* ]]; then
  bash ./start-android-emulator.sh "$DEVICE"
  DEVICE_ID=$(flutter devices | grep -o -e emulator-[0-9]*)
else
  bash ./start-ios-emulator.sh "$DEVICE"
  DEVICE_ID=$(flutter devices | grep -o -e "[0-9A-F\-]\{36\}")
fi

echo "Device $DEVICE_ID started."

cd ../example
echo "Running integration tests for platform $DEVICE..."
flutter test integration_test -d $DEVICE_ID --machine | grep { > "../test-results/$DEVICE.json"
EXIT=$?
echo "Test framework returned exit code $EXIT."

cd ..
#./kill-devices.sh

exit $EXIT
