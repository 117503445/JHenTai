# JHenTai Android APK 构建环境
# 基于 Ubuntu 22.04
FROM ubuntu:22.04

ENV http_proxy=http://192.168.100.1:1080
ENV https_proxy=http://192.168.100.1:1080

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV FLUTTER_VERSION=3.24.4
ENV JAVA_VERSION=17
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV PUB_CACHE=/opt/pub-cache
ENV GRADLE_USER_HOME=/opt/gradle
ENV PATH="${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:/opt/flutter/bin"

# 配置国内镜像源加速下载（在安装依赖前设置）
ENV PUB_HOSTED_URL="https://mirrors.tuna.tsinghua.edu.cn/dart-pub"
ENV FLUTTER_STORAGE_BASE_URL="https://mirrors.tuna.tsinghua.edu.cn/flutter"

# 安装系统依赖（合并 apt-get 操作以优化镜像大小）
RUN apt-get update && apt-get install -y \
    ca-certificates \
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
    jq \
    && rm -rf /var/lib/apt/lists/*

# 设置 JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-amd64

# 设置 git 配置（在克隆前设置）
RUN git config --global --add safe.directory '*' \
    && git config --global core.longpaths true

# 安装 Flutter
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter \
    && flutter config --no-analytics \
    && flutter precache --android \
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
    && sdkmanager "platforms;android-31" \
    && sdkmanager "platforms;android-33" \
    && sdkmanager "platforms;android-34" \
    && sdkmanager "platforms;android-35" \
    && sdkmanager "build-tools;30.0.3" \
    && sdkmanager "build-tools;33.0.1" \
    && sdkmanager "build-tools;34.0.0" \
    && sdkmanager "build-tools;35.0.0"

# 预下载 Gradle 8.4 (Wrapper 需要 zip 文件)
RUN mkdir -p ${GRADLE_USER_HOME}/wrapper/dists/gradle-8.4-all/4haxfzv2ri7iluvsav9q5mdmi \
    && cd ${GRADLE_USER_HOME}/wrapper/dists/gradle-8.4-all/4haxfzv2ri7iluvsav9q5mdmi \
    && wget -q https://services.gradle.org/distributions/gradle-8.4-all.zip \
    && unzip -q gradle-8.4-all.zip \
    && touch gradle-8.4-all.zip.lck \
    && touch gradle-8.4-all.zip.ok

# ===== 利用分层缓存：预先下载依赖 =====
# 设置工作目录
WORKDIR /workspace

# 先复制依赖配置文件（pubspec.yaml, pubspec.lock）
# 这样当代码变化但依赖不变时，可以利用缓存
COPY pubspec.yaml pubspec.lock /workspace/

# 运行 flutter pub get 下载依赖（这层会被缓存，直到 pubspec.yaml/pubspec.lock 变化）
# PUB_CACHE 已设置为 /opt/pub-cache，所有依赖将下载到该目录
RUN flutter pub get

# 将 Flutter 依赖缓存保存到独立目录，避免运行时被 volume 挂载覆盖
RUN mkdir -p /opt/flutter-cache \
    && cp -r .dart_tool /opt/flutter-cache/ \
    && cp pubspec.lock /opt/flutter-cache/

# ===== 复制完整项目以便预构建 =====
# 复制 Android 配置
COPY android/ /workspace/android/

# 复制 lib 源代码 (需要以便完成构建)
COPY lib/ /workspace/lib/

# 复制其他必要文件
COPY assets/ /workspace/assets/

# 配置 Gradle Wrapper 使用本地已下载的 Gradle
RUN cd /workspace/android \
    && mkdir -p gradle/wrapper \
    && echo "distributionBase=GRADLE_USER_HOME" > gradle/wrapper/gradle-wrapper.properties \
    && echo "distributionPath=wrapper/dists" >> gradle/wrapper/gradle-wrapper.properties \
    && echo "zipStoreBase=GRADLE_USER_HOME" >> gradle/wrapper/gradle-wrapper.properties \
    && echo "zipStorePath=wrapper/dists" >> gradle/wrapper/gradle-wrapper.properties \
    && echo "distributionUrl=file\\:${GRADLE_USER_HOME}/wrapper/dists/gradle-8.4-all/4haxfzv2ri7iluvsav9q5mdmi/gradle-8.4-all.zip" >> gradle/wrapper/gradle-wrapper.properties

# 创建必要的配置文件
RUN echo "sdk.dir=${ANDROID_SDK_ROOT}" > /workspace/android/local.properties \
    && echo "flutter.sdk=/opt/flutter" >> /workspace/android/local.properties \
    && echo "flutter.buildMode=release" >> /workspace/android/local.properties \
    && echo "flutter.versionName=1.0.0" >> /workspace/android/local.properties \
    && echo "flutter.versionCode=1" >> /workspace/android/local.properties

# 下载 Gradle Wrapper JAR
RUN mkdir -p /workspace/android/gradle/wrapper \
    && wget -q -O /workspace/android/gradle/wrapper/gradle-wrapper.jar \
    https://github.com/gradle/gradle/raw/v8.4.0/gradle/wrapper/gradle-wrapper.jar

# 执行一次完整构建以预下载所有 Maven 依赖
# 这会下载 Flutter embedding, Android 依赖等
# 构建可能会因为签名配置等问题失败，但依赖会被下载
RUN cd /workspace \
    && flutter build apk -t lib/src/main.dart --release 2>&1 || echo "Pre-build completed (dependencies downloaded)"

# 清理预构建产物
RUN rm -rf /workspace/build/

# 复制构建脚本到容器内
COPY build-in-docker.sh /usr/local/bin/build-in-docker.sh
RUN chmod +x /usr/local/bin/build-in-docker.sh

# 默认命令
CMD ["/bin/bash"]
