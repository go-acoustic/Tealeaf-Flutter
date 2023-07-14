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
              dart2js_info compiler build_integration _fe_analyzer_shared _js_interop_checks
do
   ln -s $1/pkg/$subdir $suddir
   ls -lt $subdir
done
target=$1'/pkg/vm/lib/target/flutter.dart'
md5=`md5 -q $target`
echo 'MDI value: ' $md5
cd ..
if [ $md5 == '9702fa8d230ef3e74135e58214476410' ]
  then
    echo 'flutter.dart already modified as needed!'
  else 
    if [ $md5 != '3ef7ec085423ed6b513a9040971e26af' ]
      then
      echo 'flutter.dart has changed, manually insert changes to the file!'
      exit
    fi
    echo 'Injecting aspectd code into' $target
    cp ./flutter.dart.modified $target
fi
# Build starter with proper vm build version
cd flutter_frontend_server
echo 'Building frontend starter with vm version match for dart in:' $PWD
dart --deterministic --snapshot=frontend_server.dart.snapshot starter.dart
cd ..
echo 'tealeaf_aop package setup complete'
