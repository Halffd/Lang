#!/usr/bin/env bash
# Build APK + Linux AppImage inside the lang-builder docker image.
# Artifacts land in dist/.
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=lang-builder
docker build -t "$IMAGE" -f docker/Dockerfile .

mkdir -p dist

docker run --rm --shm-size=4g \
  -v "$PWD":/app \
  -v lang-pub-cache:/opt/pub-cache \
  -v lang-gradle-cache:/root/.gradle \
  "$IMAGE" bash -c '
    set -e
    rm -f /root/.gradle/caches/journal-*/journal-*.lock 2>/dev/null || true

    echo "== build apk =="
    flutter build apk --release --split-per-abi
    cp build/app/outputs/flutter-apk/*-release.apk dist/

    echo "== build linux =="
    flutter config --enable-linux-desktop
    flutter build linux --release

    echo "== package AppImage =="
    # cmake install prefix defaults to /usr/local inside the container
    D=/app/dist/appimage/Lang.AppDir
    rm -rf "$D"
    mkdir -p "$D/usr/lib"
    cp /usr/local/lang "$D/lang"
    cp /usr/local/lib/*.so "$D/usr/lib/"
    cp -r /usr/local/data "$D/"
    cat > "$D/lang.desktop" <<EOF
[Desktop Entry]
Name=Lang
Exec=lang
Icon=lang
Type=Application
Categories=Education;
EOF
    cat > "$D/AppRun" <<EOF
#!/bin/sh
HERE="\$(dirname "\$(readlink -f "\$0")")"
export LD_LIBRARY_PATH="\$HERE/usr/lib:\$LD_LIBRARY_PATH"
exec "\$HERE/lang" "\$@"
EOF
    chmod +x "$D/AppRun"
    cp /usr/local/data/flutter_assets/assets/app_icon.png "$D/lang.png" 2>/dev/null || true

    (cd /app/dist/appimage && ARCH=x86_64 appimagetool Lang.AppDir Lang-x86_64.AppImage)

    echo "== done =="
    ls -la /app/dist /app/dist/appimage
  '

echo "Artifacts in dist/:"
ls -la dist/ dist/appimage/
