#!/bin/bash

# JHenTai Docker APK 构建脚本
# 用法: ./build_apk_docker.sh [debug|release]

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 构建模式，默认为 release
BUILD_MODE=${1:-release}

# 镜像名称
IMAGE_NAME="jhentai-build"
CONTAINER_NAME="jhentai-builder"

# 缓存卷名称
CACHE_VOLUME="jhentai-flutter-cache"

echo -e "${YELLOW}=== JHenTai Docker APK 构建脚本 ===${NC}"
echo -e "构建模式: ${BUILD_MODE}"

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装${NC}"
    exit 1
fi

# 清理旧容器
echo -e "${YELLOW}清理旧容器...${NC}"
docker rm -f ${CONTAINER_NAME} 2>/dev/null || true

# 构建 Docker 镜像
echo -e "${YELLOW}构建 Docker 镜像...${NC}"
docker build -t ${IMAGE_NAME} .

# 创建缓存卷（如果不存在）
echo -e "${YELLOW}创建 Flutter 缓存卷...${NC}"
docker volume create ${CACHE_VOLUME} 2>/dev/null || true

# 获取版本号
VERSION=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)
echo -e "${GREEN}应用版本: ${VERSION}${NC}"

# 运行容器进行构建
echo -e "${YELLOW}启动构建容器...${NC}"

# 创建输出目录
mkdir -p build/app/outputs/apk/${BUILD_MODE}

docker run --rm \
    --name ${CONTAINER_NAME} \
    -v "$(pwd):/workspace" \
    -v "${CACHE_VOLUME}:/root/.pub-cache" \
    -w /workspace \
    ${IMAGE_NAME} \
    bash -c "
        set -e
        echo '获取 Flutter 依赖...'
        flutter pub get
        
        echo '构建 APK...'
        if [ '${BUILD_MODE}' = 'release' ]; then
            flutter build apk -t lib/src/main.dart --release --split-per-abi
            
            # 重命名 APK 文件
            cd build/app/outputs/apk/release
            mv app-arm64-v8a-release.apk JHenTai-${VERSION}-arm64-v8a.apk 2>/dev/null || true
            mv app-armeabi-v7a-release.apk JHenTai-${VERSION}-armeabi-v7a.apk 2>/dev/null || true
            mv app-x86_64-release.apk JHenTai-${VERSION}-x64.apk 2>/dev/null || true
        else
            flutter build apk -t lib/src/main.dart --debug
        fi
        
        echo '构建完成!'
        ls -la build/app/outputs/apk/${BUILD_MODE}/
    "

# 检查构建结果
if [ $? -eq 0 ]; then
    echo -e "${GREEN}=== 构建成功! ===${NC}"
    echo -e "APK 输出目录: build/app/outputs/apk/${BUILD_MODE}/"
    ls -la build/app/outputs/apk/${BUILD_MODE}/
else
    echo -e "${RED}=== 构建失败! ===${NC}"
    exit 1
fi
