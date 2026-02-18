#!/usr/bin/env bash

set -e  # 遇到错误立即退出

echo "=== 开始 JHenTai 构建流程 ==="

# 检查工作目录
if [ ! -f "pubspec.yaml" ]; then
    echo "错误: 未找到 pubspec.yaml 文件，请确保在项目根目录运行此脚本"
    exit 1
fi

echo "1. 配置环境..."
git config --global core.longpaths true

# 确保环境变量设置正确
export PUB_CACHE=/opt/pub-cache
export GRADLE_USER_HOME=/opt/gradle

# 从预缓存目录恢复 Flutter 依赖（解决无网络环境下运行）
if [ -d "/opt/flutter-cache" ]; then
    echo "1.5. 恢复 Flutter 依赖缓存..."
    cp -r /opt/flutter-cache/.dart_tool ./
    cp /opt/flutter-cache/pubspec.lock ./
    echo "依赖缓存恢复完成"
fi

echo "2. 检查依赖缓存..."
if [ -d "$PUB_CACHE" ]; then
    echo "Flutter 依赖缓存: $PUB_CACHE"
else
    echo "错误: Flutter 依赖缓存不存在"
    exit 1
fi

if [ -d "$GRADLE_USER_HOME" ]; then
    echo "Gradle 缓存: $GRADLE_USER_HOME"
else
    echo "错误: Gradle 缓存不存在"
    exit 1
fi

echo "3. 配置 Gradle 离线模式..."
# 配置 gradle-wrapper.properties 使用本地 Gradle
mkdir -p android/gradle/wrapper
cat > android/gradle/wrapper/gradle-wrapper.properties << EOF
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=file\:${GRADLE_USER_HOME}/wrapper/dists/gradle-8.4-all/4haxfzv2ri7iluvsav9q5mdmi/gradle-8.4-all.zip
EOF

echo "4. 获取应用版本信息..."
VERSION=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)
echo "应用版本: $VERSION"

echo "5. 构建 Android APK..."
flutter build apk -t lib/src/main.dart --release --split-per-abi

echo "6. 重命名 APK 文件..."
cd build/app/outputs/apk/release

# 重命名各个架构的 APK 文件
if [ -f "app-arm64-v8a-release.apk" ]; then
    mv app-arm64-v8a-release.apk JHenTai-${VERSION}-arm64-v8a.apk
    echo "已生成: JHenTai-${VERSION}-arm64-v8a.apk"
fi

if [ -f "app-armeabi-v7a-release.apk" ]; then
    mv app-armeabi-v7a-release.apk JHenTai-${VERSION}-armeabi-v7a.apk
    echo "已生成: JHenTai-${VERSION}-armeabi-v7a.apk"
fi

if [ -f "app-x86_64-release.apk" ]; then
    mv app-x86_64-release.apk JHenTai-${VERSION}-x64.apk
    echo "已生成: JHenTai-${VERSION}-x64.apk"
fi

echo "7. 列出生成的文件..."
ls -la *.apk 2>/dev/null || echo "未找到 APK 文件"

echo "=== 构建完成 ==="
echo "生成的 APK 文件位于: $(pwd)"