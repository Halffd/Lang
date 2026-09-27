# Flutter stable + Linux desktop toolchain + Android SDK for building
# APK, Linux bundle, and AppImage for the Lang app.
FROM ghcr.io/cirruslabs/flutter:stable

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
      clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
      libsecret-1-dev libsqlite3-dev libmpv-dev libkeybinder-3.0-dev \
      libnotify-dev libayatana-appindicator3-dev file \
      appstream wget fuse xz-utils && \
    rm -rf /var/lib/apt/lists/*

# appimagetool for producing the AppImage artifact
RUN wget -q https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage \
      -O /usr/local/bin/appimagetool && \
    chmod +x /usr/local/bin/appimagetool && \
    (cd /usr/local/bin && ./appimagetool --appimage-extract >/dev/null 2>&1 && \
     mv squashfs-root appimagetool-root && rm appimagetool && \
     ln -s /usr/local/bin/appimagetool-root/AppRun /usr/local/bin/appimagetool) || true

ENV PUB_CACHE=/opt/pub-cache
RUN mkdir -p /opt/pub-cache && chmod -R 777 /opt/pub-cache

WORKDIR /app
