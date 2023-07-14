# Run from <tl plugin repo>/tealeaf_aop
echo 'Linking to Dart SDK'
if [ -z $1 ] 
  then
    echo 'build_frontend requires one parameter (dart sdk path)'
    exit
fi
if [ -d $1/pkg ]
  then
    echo 'Using Dart SDK at:' $1
  else
    echo $1 'does not exist or does not have pkg subdirectory'
  exit
fi
if [ ${PWD##*/} != 'tealeaf_aop' ]
  then
    echo "You need to run this script from tealeaf_aop directory!"
    exit
fi
rm -r pkg
mkdir pkg
cd pkg
for subdir in vm meta kernel js_runtime js_ast frontend_server front_end dev_compiler \
              dart2js_info compiler build_integration _fe_analyzer_shared \
              _js_interop_checks js_shared
do
   ln -s $1/pkg/$subdir $suddir
   ls -lt $subdir
done
target=$1'/pkg/vm/lib/target/flutter.dart'
md5=`md5 -q $target`
echo 'MDI value: ' $md5
cd ..
if [ $md5 == '4502d44f6f4b5a601a6b5b42bd13ac14' ]
  then
    echo 'flutter.dart already modified as needed!'
  else 
    if [ $md5 != 'd6b527b4400c8eb95a011af907f9bf73' ]
      then
      echo 'flutter.dart has changed, manually insert changes to the file!'
      exit
    fi
    echo 'Injecting aspectd code into' $target
    cp ./flutter.dart.2.18.0.modified $target
fi
# Next, clean up then get new dependencies
flutter clean
flutter pub get
# Do following if pubspec.yaml added more dependencies
# rm -r ~/.pub-cache
# flutter package get
# Build starter with proper vm build version
echo 'Building frontend starter with vm version match for dart in:' $PWD
./compile.sh
echo 'tealeaf_aop package setup complete'
