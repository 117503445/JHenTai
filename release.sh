#!/usr/bin/env bash

set -e

docker run -v $(pwd):/workspace --network none builder build-in-docker.sh
# /workspace/project/JHenTai/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

adb install -r -d /workspace/project/JHenTai/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
