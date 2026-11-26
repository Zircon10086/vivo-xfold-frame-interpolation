#!/system/bin/sh
# vivo-xfold-frame-interpolation（KernelSU 模块）
#
# 只做一件事：开机后把带 [vivo.hardware.game.memc] 的 vivo_config.ini 覆盖到
# /vendor/etc/vivo_config.ini，再让配置 HAL 与 framework 重新读取。
#
# 为什么不在 post-fs-data 里挂：
#   实测（阶段三）在 post-fs-data 阶段 bind mount /vendor 会让 init 收到 SIGABRT，
#   开机卡 vivo logo 2~13 分钟，mountify 判定失败后自动禁用模块。
#   因此这里改为「等 sys.boot_completed=1 之后再挂 + 重启 HAL + 重启 zygote」。
#   zygote 重启发生在开机完成之后，不会阻塞开机；代价是每次开机多一次框架重启。
#
# 日志：/data/local/tmp/vivo-xfold-fi.log
MODDIR=${0%/*}
LOG=/data/local/tmp/vivo-xfold-fi.log
SRC_INI="$MODDIR/system/vendor/etc/vivo_config.ini"
DST_INI=/vendor/etc/vivo_config.ini

log() { echo "$(date '+%m-%d %H:%M:%S') $*" >> "$LOG"; }

log "== service.sh start"

# 等开机完成，最多等 5 分钟
i=0
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
    i=$((i + 1))
    [ "$i" -gt 100 ] && { log "boot_completed timeout, abort"; exit 0; }
done
sleep 15

if [ ! -f "$SRC_INI" ]; then
    log "payload missing: $SRC_INI"
    exit 0
fi

# 已经挂上了就只补一次 HAL/framework 重启的判断
if grep -q 'vivo.hardware.game.memc' "$DST_INI"; then
    log "ini already contains game.memc, skip mount"
else
    chcon u:object_r:vendor_configs_file:s0 "$SRC_INI" 2>>"$LOG"
    mount --bind "$SRC_INI" "$DST_INI" 2>>"$LOG"
    log "bind rc=$?"
fi
log "ini game.memc lines: $(grep -c 'vivo.hardware.game.memc' "$DST_INI")"

# 让 configstore HAL 重新解析 ini
setprop ctl.restart vivo-configstore-hal-1-0
log "hal restarted: $(getprop init.svc.vivo-configstore-hal-1-0)"
sleep 3

# 让 system_server 重建能力缓存（LcmFeature / FtFeature 静态量）
if [ "$(getprop sys.boot_completed)" = "1" ]; then
    setprop ctl.restart zygote
    log "zygote restarted"
fi

log "== service.sh done, MEMC=$(cat /sys/rsc/vgarph/MEMC 2>&1)"
