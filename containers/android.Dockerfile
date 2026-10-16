# 编译与模拟器共享 Android SDK 基础环境，运行数据由宿主挂载。
FROM docker.io/library/ubuntu:24.04 AS sdk
ENV DEBIAN_FRONTEND=noninteractive \
    ANDROID_HOME=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk \
    JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/emulator:/opt/flutter/bin:${PATH}
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git unzip xz-utils zip openjdk-17-jdk-headless \
    libglu1-mesa libpulse0 libnss3 libx11-6 libxcb1 libxcomposite1 libxcursor1 \
    libxi6 libxtst6 libxrandr2 libxdamage1 libxfixes3 libxkbcommon0 libasound2t64 \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /opt/android-sdk/cmdline-tools && \
    curl -fL --retry 3 https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip -o /opt/tools.zip && \
    unzip -q /opt/tools.zip -d /opt/android-sdk/cmdline-tools && \
    mv /opt/android-sdk/cmdline-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest && rm /opt/tools.zip && \
    yes | sdkmanager --licenses >/dev/null
RUN sdkmanager 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0'

FROM sdk AS builder
ARG FLUTTER_VERSION=3.44.8
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git /opt/flutter && \
    git config --global --add safe.directory /opt/flutter && \
    flutter config --no-analytics && flutter precache --android
RUN sdkmanager 'ndk;28.2.13676358' 'cmake;3.22.1' 'build-tools;35.0.0' \
    'platforms;android-31' 'platforms;android-33' 'platforms;android-34' 'platforms;android-35'
WORKDIR /workspace

FROM sdk AS emulator
RUN sdkmanager 'emulator' 'system-images;android-35;google_apis;x86_64'
ENV ANDROID_AVD_HOME=/state/android/avd ANDROID_USER_HOME=/state/android
WORKDIR /workspace
