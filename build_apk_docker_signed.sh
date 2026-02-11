#!/bin/bash

# JHenTai Docker APK 签名构建脚本
# 用法: ./build_apk_docker_signed.sh /path/to/keystore.jks keystore_password key_alias key_password

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 参数检查
if [ $# -lt 4 ]; then
    echo -e "${RED}用法: $0 /path/to/keystore.jks keystore_password key_alias key_password${NC}"
    echo -e "${YELLOW}示例: $0 ~/upload-keystore.jks mypassword myalias mykeypassword${NC}"
    exit 1
fi

KEYSTORE_PATH=$1
KEYSTORE_PASSWORD=$2
KEY_ALIAS=$3
KEY_PASSWORD=$4

# 检查密钥库文件是否存在
if [ ! -f "$KEYSTORE_PATH" ]; then
    echo -e "${RED}错误: 密钥库文件不存在: ${KEYSTORE_PATH}${NC}"
    exit 1
fi

# 镜像名称
IMAGE_NAME="jhentai-build"
CONTAINER_NAME="jhentai-builder"

# 缓存卷名称
CACHE_VOLUME="jhentai-flutter-cache"

echo -e "${YELLOW}=== JHenTai Docker APK 签名构建脚本 ===${NC}"

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

# 创建临时 key.properties 文件
KEY_PROPERTIES_CONTENT="storeFile=/workspace/android/app/upload-keystore.jks
storePassword=${KEYSTORE_PASSWORD}
keyAlias=${KEY_ALIAS}
keyPassword=${KEY_PASSWORD}"

# 运行容器进行构建
echo -e "${YELLOW}启动构建容器...${NC}"

# 创建输出目录
mkdir -p build/app/outputs/apk/release

docker run --rm \
    --name ${CONTAINER_NAME} \
    -v "$(pwd):/workspace" \
    -v "${KEYSTORE_PATH}:/workspace/android/app/upload-keystore.jks:ro" \
    -v "${CACHE_VOLUME}:/root/.pub-cache" \
    -w /workspace \
    ${IMAGE_NAME} \
    bash -c "
        set -e
        echo '配置签名密钥...'
        cat > /workspace/android/key.properties << 'EOF'
${KEY_PROPERTIES_CONTENT}
EOF
        
        echo '获取 Flutter 依赖...'
        flutter pub get
        
        echo '构建签名 APK...'
        flutter build apk -t lib/src/main.dart --release --split-per-abi
        
        # 重命名 APK 文件
        cd build/app/outputs/apk/release
        mv app-arm64-v8a-release.apk JHenTai-${VERSION}-arm64-v8a.apk 2>/dev/null || true
        mv app-armeabi-v7a-release.apk JHenTai-${VERSION}-armeabi-v7a.apk 2>/dev/null || true
        mv app-x86_64-release.apk JHenTai-${VERSION}-x64.apk 2>/dev/null || true
        
        echo '构建完成!'
        ls -la
    "

# 检查构建结果
if [ $? -eq 0 ]; then
    echo -e "${GREEN}=== 签名构建成功! ===${NC}"
    echo -e "APK 输出目录: build/app/outputs/apk/release/"
    ls -la build/app/outputs/apk/release/
else
    echo -e "${RED}=== 构建失败! ===${NC}"
    exit 1
fi
