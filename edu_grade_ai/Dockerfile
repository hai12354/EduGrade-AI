# Build Stage
FROM ubuntu:22.04 AS build-env

# 1. Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    zip \
    unzip \
    libgconf-2-4 \
    gdb \
    libstdc++6 \
    libglu1-mesa \
    fonts-droid-fallback \
    lib32stdc++6 \
    python3 \
    openjdk-17-jdk \
    && apt-get clean

# 2. Setup Java Home
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH

# 3. Setup Android SDK
ENV ANDROID_SDK_ROOT=/opt/android-sdk
RUN mkdir -p $ANDROID_SDK_ROOT/cmdline-tools \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/tools.zip \
    && unzip /tmp/tools.zip -d $ANDROID_SDK_ROOT/cmdline-tools \
    && mv $ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest \
    && rm /tmp/tools.zip

ENV PATH=$PATH:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools

# Accept licenses
RUN yes | sdkmanager --licenses

# 4. Setup Flutter
ENV FLUTTER_HOME=/opt/flutter
RUN git clone https://github.com/flutter/flutter.git $FLUTTER_HOME
ENV PATH=$PATH:$FLUTTER_HOME/bin

# Set Flutter channel to stable
RUN flutter channel stable && flutter upgrade

# 5. Build the App
WORKDIR /app
COPY . .

# Run pub get
RUN flutter pub get

# Build APK (Release mode)
RUN flutter build apk --release

# Final Stage: Just to extract the APK
FROM scratch AS export-stage
COPY --from=build-env /app/build/app/outputs/flutter-apk/app-release.apk /app-release.apk
