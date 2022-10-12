#!/usr/local/bin/bash
# source scripts/setup-jenkins-env.sh
# shopt -s globstar

rm -rf test-results
mkdir -p test-results

cd test/
search_dir=$(pwd)
for testFile in "$search_dir"/*.dart
do
  if [[ $testFile != *"tealeaf.dart"* ]]; then
      echo "Running tests: $testFile"
      flutter test $testFile 
      #--reporter json > "../test-results/$folder.json"
  fi
done
