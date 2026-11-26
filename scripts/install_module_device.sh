#!/system/bin/sh
# 设备端安装脚本：把 /data/local/tmp 下的模块搬到 /data/adb/modules
set -e
SRC=/data/local/tmp/vivo-xfold-frame-interpolation
DST=/data/adb/modules/vivo-xfold-frame-interpolation

[ -f "$SRC/module.prop" ] || { echo "missing module.prop in $SRC"; exit 1; }
rm -rf "$DST"
mkdir -p "$DST"
cp -r "$SRC"/. "$DST"/
chown -R root:root "$DST"
find "$DST" -type d -exec chmod 755 {} +
find "$DST" -type f -exec chmod 644 {} +
chmod 755 "$DST/post-fs-data.sh" "$DST/service.sh"
echo "installed:"
ls -l "$DST"
echo "payload:"
ls -l "$DST/system/vendor/etc/vivo_config.ini" "$DST/system/system/etc/gamecube/FrameInterConfigList.xml"
