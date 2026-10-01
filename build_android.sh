#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../mobile"
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter não encontrado. Instale o Flutter SDK antes de compilar."
  exit 1
fi
# The mobile folder intentionally contains app source only in early increments.
# Generate missing platform scaffolding without overwriting lib/ or pubspec.
if [ ! -d android ]; then
  tmp=$(mktemp -d)
  cp pubspec.yaml "$tmp/pubspec.yaml"
  cp -r lib "$tmp/lib"
  cd "$tmp"
  flutter create --platforms=android --org br.com.pintacred .
  cp -r android "$OLDPWD/android"
  cd "$OLDPWD"
  rm -rf "$tmp"
fi
flutter pub get
flutter build apk --debug --dart-define=API_BASE=${API_BASE:-http://10.0.2.2:8000}
echo "APK: build/app/outputs/flutter-apk/app-debug.apk"
