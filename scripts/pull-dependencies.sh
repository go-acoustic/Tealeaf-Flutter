#!/usr/local/bin/bash

source scripts/setup-jenkins-env.sh
root=$(pwd)
for file in $(find . -type f -name 'pubspec.yaml'); do
  dir=$(dirname "$file")
  cd "$dir"
  flutter pub get
  cd "$root"
done