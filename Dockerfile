# JHenTai Android APK 构建环境
# 基于 Ubuntu 22.04
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y ca-certificates


# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_VERSION=3.24.4
ENV FLUTTER_CHANNEL=master
ENV JAVA_VERSION=17
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:/opt/flutter/bin"

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-${JAVA_VERSION}-jdk \
    wget \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++6 \
    lib32z1 \
    && rm -rf /var/lib/apt/lists/*

# 设置 JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64

# 安装 Flutter
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter \
    && flutter config --no-analytics \
    && flutter precache \
    && flutter doctor

# 安装 Android SDK Command Line Tools
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && cd ${ANDROID_SDK_ROOT}/cmdline-tools \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
    && unzip -q commandlinetools-linux-11076708_latest.zip \
    && mv cmdline-tools latest \
    && rm commandlinetools-linux-11076708_latest.zip

# 接受 Android SDK 许可证并安装必要组件
RUN yes | sdkmanager --licenses \
    && sdkmanager "platform-tools" \
    && sdkmanager "platforms;android-35" \
    && sdkmanager "build-tools;35.0.0" \
    && sdkmanager "ndk;26.1.10909125"

# 创建工作目录
WORKDIR /workspace

# 复制项目文件
COPY . /workspace/project/JHenTai

# 复制构建脚本到 PATH
COPY build-in-docker.sh /usr/local/bin/build-in-docker.sh
RUN chmod +x /usr/local/bin/build-in-docker.sh

# 预缓存 Flutter 依赖（需要网络）
RUN git config --global core.longpaths true \
    && cd /workspace/project/JHenTai \
    && flutter pub get

# 设置 git 配置（Flutter 需要）
RUN git config --global --add safe.directory /opt/flutter \
    && git config --global core.longpaths true

# https://docs.flutter.dev/community/china
ENV PUB_HOSTED_URL="https://mirrors.tuna.tsinghua.edu.cn/dart-pub"
ENV FLUTTER_STORAGE_BASE_URL="https://mirrors.tuna.tsinghua.edu.cn/flutter"

# 默认命令
CMD ["/bin/bash"]
