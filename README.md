# tl_flutter_plugin

TODO: Write a project description

## Getting Started

This section describes how to begin using the Tealeaf plugin for instrumentation of apps so user 
interactions and application data can be captured, played back, and analyzed with the Acoustic 
Tealeaf service.

* [Install the Tealeaf Plugin](#Installation)
* [Account Setup]
* [Configuation]
* [Usage Details](#Usage)
 
TODO: Describe startup process (continued)

## Features

TODO: List feaures (Acoustic Tealeaf features and references)

## Installation

1. Add the following line to pubspec.yaml (under existing dependency tag):

   dependencies:  
   &nbsp;&nbsp;tl_flutter_plugin:  
   &nbsp;&nbsp;&nbsp;&nbsp;git: https://github.com/aipoweredmarketer/TL-Flutter-Plugin.git  

2. Add the following comment and import statement to the application main.dart file:  

```dart
      // ignore: unused_import  
      import 'package:tl_flutter_plugin/tl_flutter_plugin.dart';  
```

3. Get the .zip file for flutter version 3.3.x from the repo in the top level directory 
   flutter_patches/   
   There may be other patch files for previous flutter versions as well.  
  
   tl_flutter_patch_3.3.x.zip  
  
   Go to the directory location where flutter is installed. If you do know the location, run the   
   following command in a shell:  
   
   which flutter    
   <b>/Users/someuser/development/flutter/</b>bin/flutter  

   The location of the flutter SDK directory root is the path WITHOUT the tailing portion
   bin/flutter. Given the above path, copy the .zip file from above to the flutter SDK root.
   Then, in the same shell, do the these commands:
  
   cd /Users/someuser/development/flutter/  
   unzip tl_flutter_patch_3.3.x.zip  
   rm tl_flutter_patch_3.3.x.zip  
   sudo rm -r /Users/someuser/development/flutter/bin/flutter/bin/cache  
   flutter --version  

   The last command will take some seconds and cause some downloads to occur. These steps
   cause the flutter stack to be instrumented with the aspectd hooks required for
   Tealeaf instrumentation. Aspectd code injection ONLY happens if the project being built specifies
   the tl_flutter_plugin package in its pubspec.yaml file. Otherwise, the project build proceeds 
   normally with no code modifications.

## Build Notes

In order to build, you may have to do a couple of changes to the application environment.

1. Set the Android app gradle.build to have the following default dependency version for com.android.tools.build:gradle:  
  
   dependencies {  
   &nbsp;&nbsp;&nbs`p;&nbsp;classpath 'com.android.tools.build:gradle:<b>4.1.3</b>'  
   &nbsp;&nbsp;&nbsp;&nbsp;classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"  
   }    

2. Set the --no-sound-null-safety dart option in pubspec.yaml if the environment dart SDK setting is >= 2.8  
   (Not doing so will when using >= 2.8 will cause build error)
 
## Usage


## History

TODO: Write history

## Credits

TODO: Write credits?

## License

TODO: Provide typical FLutter license

