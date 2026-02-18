#!/usr/bin/env bash

# 确定项目目录（Docker 挂载可能导致路径变化）
if [ -d "/workspace/project/JHenTai" ]; then
    PROJECT_DIR="/workspace/project/JHenTai"
elif [ -d "/workspace" ]; then
    PROJECT_DIR="/workspace"
else
    PROJECT_DIR="/workspace/project/JHenTai"
fi

cd "$PROJECT_DIR"

# 设置 Flutter 镜像（使用清华镜像）
export PUB_HOSTED_URL="https://mirrors.tuna.tsinghua.edu.cn/dart-pub"
export FLUTTER_STORAGE_BASE_URL="https://mirrors.tuna.tsinghua.edu.cn/flutter"

# 复制密钥文件到正确位置
mkdir -p "$PROJECT_DIR/android/app"
cp -f "$PROJECT_DIR/upload-keystore.jks" "$PROJECT_DIR/android/app/upload-keystore.jks"

# 获取依赖
git config --global core.longpaths true
flutter pub get

# 构建 Android APK
flutter build apk -t lib/src/main.dart --release --split-per-abi
