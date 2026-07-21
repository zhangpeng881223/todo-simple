#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

VERSION=$(sed -n 's/^project(xiaou-todo VERSION \([^ ]*\) LANGUAGES.*$/\1/p' CMakeLists.txt | head -n1)
if [[ -z "$VERSION" ]]; then
    echo "Unable to read project version from CMakeLists.txt" >&2
    exit 1
fi
ARCH=${DEB_ARCH:-$(dpkg --print-architecture)}
PKG_DIR="$ROOT_DIR/pkg"
DIST_DIR="$ROOT_DIR/dist"
DEB_PATH="$DIST_DIR/小U待办_${VERSION}_${ARCH}.deb"

cmake --build build --clean-first -j"${BUILD_JOBS:-2}"
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR" "$DIST_DIR"
DESTDIR="$PKG_DIR" cmake --install build --prefix /usr >/dev/null

# Use the icon theme name so launchers can select the best raster size or scalable SVG.
sed -i 's|^Icon=.*|Icon=xiaou-todo|' "$PKG_DIR/usr/share/applications/xiaou-todo.desktop"
sed -i 's/^Name=.*/Name=小U待办/' "$PKG_DIR/usr/share/applications/xiaou-todo.desktop"

mkdir -p "$PKG_DIR/DEBIAN"
INSTALLED_SIZE=$(du -sk "$PKG_DIR/usr" | awk '{print $1}')
cat > "$PKG_DIR/DEBIAN/control" <<CONTROL
Package: xiaou-todo
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Installed-Size: $INSTALLED_SIZE
Maintainer: zhangpeng <zhangpeng@example.com>
Replaces: todo260606
Conflicts: todo260606
Provides: todo260606
Depends: libc6 (>= 2.34), libdtk6gui (>= 6.7.42), libdtk6widget (>= 6.7.42), libgcc-s1 (>= 3.0), libqt6core6 (>= 6.8.0), libqt6dbus6 (>= 6.1.2), libqt6gui6 (>= 6.1.2), libqt6network6 (>= 6.1.2), libqt6qml6 (>= 6.6.0), libqt6quick6 (>= 6.6.0), libqt6quickcontrols2-6 (>= 6.6.0), libqt6widgets6 (>= 6.3.0), libstdc++6 (>= 5), libdtk6declarative, qml6-module-qtquick, qml6-module-qtquick-window, qml6-module-qtquick-controls, qml6-module-qtquick-layouts, qml6-module-qtquick-dialogs, qml6-module-qtquick-particles, qml6-module-qt5compat-graphicaleffects, qml6-module-qtquick-controls2-styles-chameleon, qt6-qpa-plugins, xdotool
Description: 小U待办
 小U待办是一个面向 deepin/UOS 的桌面待办应用。
CONTROL

cat > "$PKG_DIR/DEBIAN/preinst" <<'SCRIPT'
#!/bin/sh
set -e
stop_xiaou_todo() {
    if command -v pkill >/dev/null 2>&1; then
        pkill -TERM -x xiaou-todo 2>/dev/null || true
        pkill -TERM -x todo260606 2>/dev/null || true
        sleep 1
        pkill -KILL -x xiaou-todo 2>/dev/null || true
        pkill -KILL -x todo260606 2>/dev/null || true
    fi
}
case "$1" in
    install|upgrade)
        stop_xiaou_todo
        ;;
esac
exit 0
SCRIPT

cat > "$PKG_DIR/DEBIAN/prerm" <<'SCRIPT'
#!/bin/sh
set -e
stop_xiaou_todo() {
    if command -v pkill >/dev/null 2>&1; then
        pkill -TERM -x xiaou-todo 2>/dev/null || true
        pkill -TERM -x todo260606 2>/dev/null || true
        sleep 1
        pkill -KILL -x xiaou-todo 2>/dev/null || true
        pkill -KILL -x todo260606 2>/dev/null || true
    fi
}
case "$1" in
    remove|purge|upgrade|deconfigure)
        stop_xiaou_todo
        ;;
esac
exit 0
SCRIPT

cat > "$PKG_DIR/DEBIAN/postinst" <<'SCRIPT'
#!/bin/sh
set -e

cleanup_legacy_launchers() {
    rm -f /usr/share/applications/todo260606.desktop
    rm -f /usr/share/pixmaps/todo260606.png
    rm -f /usr/share/pixmaps/xiaou-todo.png
    rm -f /usr/share/pixmaps/xiaou-todo-calendar.png
    rm -f /usr/share/dsg/icons/todo260606.dci
    rm -f /usr/share/dsg/icons/xiaou-todo.dci
    rm -f /usr/share/dsg/icons/xiaou-todo-calendar.dci
    for icon_dir in /usr/share/icons/hicolor/*x*/apps /usr/share/icons/bloom/*x*/apps /usr/share/icons/bloom/apps/*; do
        [ -d "$icon_dir" ] || continue
        rm -f "$icon_dir/todo260606.png"
        rm -f "$icon_dir/xiaou-todo.png"
        rm -f "$icon_dir/xiaou-todo-calendar.png"
    done
    for home_dir in /home/* /root; do
        [ -d "$home_dir" ] || continue
        rm -f "$home_dir/.local/share/applications/todo260606.desktop"
        rm -f "$home_dir/Desktop/todo260606.desktop"
    done
}

cleanup_runtime_caches() {
    for home_dir in /home/* /root; do
        [ -d "$home_dir" ] || continue
        rm -rf "$home_dir/.cache/XiaoU/小U待办/qmlcache"
        rm -rf "$home_dir/.cache/XiaoU/小U待办/qtpipelinecache-x86_64-little_endian-lp64"
        rm -rf "$home_dir/.cache/XiaoU/小U待办"/_qt_QGfxShaderBuilder_*
        rm -rf "$home_dir/.cache/Todo260606/小U待办/qmlcache"
        rm -rf "$home_dir/.cache/Todo260606/小U待办/qtpipelinecache-x86_64-little_endian-lp64"
        rm -rf "$home_dir/.cache/Todo260606/小U待办"/_qt_QGfxShaderBuilder_*
    done
}

refresh_desktop_caches() {
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
    fi
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        for theme in hicolor bloom; do
            [ -d "/usr/share/icons/$theme" ] || continue
            gtk-update-icon-cache -q -f -t "/usr/share/icons/$theme" >/dev/null 2>&1 || true
        done
    fi
    if command -v xdg-icon-resource >/dev/null 2>&1; then
        xdg-icon-resource forceupdate --theme hicolor >/dev/null 2>&1 || true
        xdg-icon-resource forceupdate --theme bloom >/dev/null 2>&1 || true
    fi
}

case "$1" in
    configure)
        cleanup_legacy_launchers
        cleanup_runtime_caches
        refresh_desktop_caches
        ;;
esac
exit 0
SCRIPT

cat > "$PKG_DIR/DEBIAN/postrm" <<'SCRIPT'
#!/bin/sh
set -e
case "$1" in
    remove|purge)
        rm -f /usr/share/dsg/icons/xiaou-todo.dci
        rm -f /usr/share/dsg/icons/xiaou-todo-calendar.dci
        for home_dir in /home/* /root; do
            [ -d "$home_dir" ] || continue
            rm -rf "$home_dir/Documents/小U待办"
            rm -rf "$home_dir/.todo260606"
            rm -rf "$home_dir/.cache/XiaoU/小U待办/qmlcache"
            rm -rf "$home_dir/.cache/Todo260606/小U待办/qmlcache"
        done
        ;;
esac
exit 0
SCRIPT

chmod 0755 "$PKG_DIR/DEBIAN/preinst" "$PKG_DIR/DEBIAN/prerm" "$PKG_DIR/DEBIAN/postinst" "$PKG_DIR/DEBIAN/postrm"
find "$DIST_DIR" -maxdepth 1 -type f -name '*.deb' -delete
dpkg-deb --root-owner-group --build "$PKG_DIR" "$DEB_PATH" >/dev/null

echo "$DEB_PATH"
