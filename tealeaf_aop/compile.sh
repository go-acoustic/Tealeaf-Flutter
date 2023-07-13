cd flutter_frontend_server
DART_VERSION="frontend_server.dart.snapshot."`dart version.dart`
echo "Building $DART_VERSION"
dart --deterministic --snapshot=$DART_VERSION starter.dart
cd ..
