#!/bin/bash
set -e

#com.${COMPANY_NAME}.${APP_NAME} e.g. com.mricro.niimath
COMPANY_NAME=mycompany
APP_NAME=hello
APP_SPECIFIC_PASSWORD=abcd-efgh-ijkl-mnop
APPLE_ID_USER=myname@gmail.com
APPLE_ID_INSTALL="Developer ID Installer: My Name"
APPLE_ID_APP="Developer ID Application: My Name"

fpc ./hello.pas -oexeX86 -Px86_64
fpc ./hello.pas -oexeARM -Paarch64
# Create the universal binary.
strip ./exeARM; strip ./exeX86
lipo -create -output ${APP_NAME} exeARM exeX86
rm ./exeARM; rm ./exeX86
# Create a staging area for the installer package.
mkdir -p usr/local/bin
# Move the binary into the staging area.
mv ${APP_NAME} usr/local/bin
# Sign the binary.
codesign --timestamp --options=runtime -s "${APPLE_ID_APP}" -v usr/local/bin/${APP_NAME}
# Build the package.
pkgbuild --identifier "com.${COMPANY_NAME}.${APP_NAME}.pkg" --sign "${APPLE_ID_INSTALL}" --timestamp --root usr/local --install-location /usr/local/ ${APP_NAME}.pkg
# Submit the package to the notarization service.

xcrun altool --notarize-app --primary-bundle-id "com.${COMPANY_NAME}.${APP_NAME}.pkg" --username $APPLE_ID_USER --password $APP_SPECIFIC_PASSWORD --file ${APP_NAME}.pkg --output-format xml > upload_log_file.txt

# now we need to query apple's server to the status of notarization
# when the "xcrun altool --notarize-app" command is finished the output plist
# will contain a notarization-upload->RequestUUID key which we can use to check status
echo "Checking status..."
sleep 50
REQUEST_UUID=`/usr/libexec/PlistBuddy -c "Print :notarization-upload:RequestUUID" upload_log_file.txt`
while true; do
  xcrun altool --notarization-info $REQUEST_UUID -u $APPLE_ID_USER -p $APP_SPECIFIC_PASSWORD --output-format xml > request_log_file.txt
  # parse the request plist for the notarization-info->Status Code key which will
  # be set to "success" if the package was notarized
  STATUS=`/usr/libexec/PlistBuddy -c "Print :notarization-info:Status" request_log_file.txt`
  if [ "$STATUS" != "in progress" ]; then
    break
  fi
  # echo $STATUS
  echo "$STATUS"
  sleep 10
done

# download the log file to view any issues
/usr/bin/curl -o log_file.txt `/usr/libexec/PlistBuddy -c "Print :notarization-info:LogFileURL" request_log_file.txt`

# staple
echo "Stapling..."
xcrun stapler staple ${APP_NAME}.pkg
xcrun stapler validate ${APP_NAME}.pkg

open log_file.txt
