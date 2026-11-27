#!/usr/bin/env bash
# Run once inside the project folder: generates android/ios folders and adds the permissions the app needs.
set -e
flutter create --project-name city_guide --org com.example .
M=android/app/src/main/AndroidManifest.xml
if ! grep -q ACCESS_FINE_LOCATION "$M"; then
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n    <application#' "$M"
  sed -i 's#</manifest>#    <queries>\n        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>\n    </queries>\n</manifest>#' "$M"
fi
flutter pub get
echo "Done. Start an emulator and run: flutter run"
