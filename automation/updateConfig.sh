#!/bin/bash

projectDir=$1
KEY=$2
VALUE=$3
TYPE=$4

# Update Android 
androidPath="$projectDir/android/app/src/main/assets/TealeafBasicConfig.properties"
sed -i '' "s,.*$KEY=.*,$KEY=$VALUE," $androidPath

# Update iOS 
iosPath="$projectDir/ios/Pods/TealeafDebug/SDKs/iOS/Debug/TLFResources.bundle/TealeafBasicConfig.plist"

# Get int for key and value line
keyLine=$(grep -n $iosPath -e "<key>$KEY<\/key>"|awk -F":" '{print $1}';)
valueLine="$(($keyLine+1))"

# Goes through file and sets valueString once counter equals valueLine
counter=0
valueString=""
while IFS= read -r line
do
    counter=$(($counter+1))

  if [ "$valueLine" == "$counter" ];then
   
    valueString=$line
  fi
 
done < "$iosPath"


# Corrects valueString for /
# To use with sed must be in \/ format
correctedString=""
for (( i=0; i<${#valueString}; i++ )); do
    if [ "${valueString:$i:1}" == "/" ];then
        correctedString+="\/"
    else
        correctedString+="${valueString:$i:1}"
    fi
done


# Delete value string 
 sed -i '' "s/$correctedString//" $iosPath


# String
if [ $TYPE == "String" ];then
    sed -i '' "s,.$KEY.*,>$KEY<\/key>\n\t<string>$VALUE<\/string>," $iosPath
fi

# bool
if [ $TYPE == "bool" ];then
    sed -i '' "s,.$KEY.*,>$KEY<\/key>\n\t<$VALUE\/>," $iosPath
fi

# int
if [ $TYPE == "int" ];then
    sed -i '' "s,.$KEY.*,>$KEY<\/key>\n\t<integer>$VALUE<\/integer>," $iosPath
fi

# double
if [ $TYPE == "double" ];then
    sed -i '' "s,.$KEY.*,>$KEY<\/key>\n\t<real>$VALUE<\/real>," $iosPath
fi


sleep 1