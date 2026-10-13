#!/bin/zsh
# 打包 JSONPretty.app：release 编译后手工组装 .app bundle
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="JSONPretty"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"

echo "▶ Building release..."
swift build -c release

echo "▶ Assembling ${APP_DIR}..."
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

# 应用图标（不存在时自动生成）
if [[ ! -f "Resources/${APP_NAME}.icns" ]]; then
  echo "▶ Generating app icon..."
  rm -rf "Resources/${APP_NAME}.iconset"
  swift Scripts/generate-icon.swift "Resources/${APP_NAME}.iconset"
  iconutil -c icns "Resources/${APP_NAME}.iconset" -o "Resources/${APP_NAME}.icns"
fi
cp "Resources/${APP_NAME}.icns" "${APP_DIR}/Contents/Resources/${APP_NAME}.icns"

cat > "${APP_DIR}/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>JSONPretty</string>
    <key>CFBundleDisplayName</key><string>JSON Pretty</string>
    <key>CFBundleIdentifier</key><string>com.local.jsonpretty</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleExecutable</key><string>JSONPretty</string>
    <key>CFBundleIconFile</key><string>JSONPretty</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticTermination</key><true/>
</dict>
</plist>
EOF

echo "✅ Done: $(pwd)/${APP_DIR}"
echo "   双击运行，或执行: open ${APP_DIR}"
