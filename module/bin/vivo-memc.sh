#!/system/bin/sh
# vivo-memc 后端：给 KernelSU WebUI 用的控制脚本（root 执行）。
#
#   vivo-memc.sh status                  状态行 key=value
#   vivo-memc.sh installed               已安装应用包名（每行一个，含系统应用）
#   vivo-memc.sh games                   已配置且已安装：pkg \t label \t mode \t flags
#   vivo-memc.sh prune                   删除「数据库里有、本机没装」的游戏行（自动备份）
#   vivo-memc.sh add <pkg> [label]       导入应用（默认 60→120、开插帧+省电）
#   vivo-memc.sh remove <pkg>            移除应用（只删本脚本管理的函数行）
#   vivo-memc.sh set-mode <pkg> <mode>   mode: 60-120 | 30-60
#   vivo-memc.sh set-flag <pkg> <flag> <on|off>   flag: power | sr | light
#   vivo-memc.sh restart-gc              重启游戏助手（让改动生效）
#   vivo-memc.sh reapply-cap             重新挂载能力声明并重启 HAL/zygote
#
# 写库不再强停 GameCube：实测带 busy_timeout 时在 GC 运行中写入只要 ~50ms。
# 改动要在 GameCube 重新启动后才生效，所以 UI 里保留独立的「重启游戏助手」。
#
# 退出码：0 成功；非 0 时 stdout 第一行是 ERROR: <原因>
set -u

MODDIR=${0%/*}
MODDIR=${MODDIR%/bin}
DB=/data/data/com.vivo.gamecube/databases/support_dimension_list.db
LOG=/data/local/tmp/vivo-game-memc.log
GC=com.vivo.gamecube
BACKUP_DIR=/data/local/tmp/vivo-memc-backup

MANAGED="'boost_frame','optimize_power','optimize_power_v3_60_30_60','optimize_power_v3_90_45_90','optimize_power_v3_120_60_120','super_resolution','screen_light_effect','back_light_effect','boost_frame_v3_30_60','boost_frame_v3_60_120','boost_frame_v3_60_45_90','boost_frame_v3_60_48_144'"

die() { echo "ERROR: $*"; exit 1; }
# 所有写操作都带 busy_timeout（用 .timeout 而不是 pragma，避免 pragma 的结果被当成查询输出）
sql() { printf '.timeout 8000\n%s\n' "$1" | sqlite3 "$DB"; }

need_root() { [ "$(id -u)" = "0" ] || die "需要 root"; }
need_db() {
    [ -f "$DB" ] || die "找不到 $DB"
    command -v sqlite3 >/dev/null 2>&1 || die "缺少 sqlite3"
}
check_pkg() { echo "$1" | grep -qE '^[A-Za-z0-9_.]+$' || die "包名不合法: $1"; }

count_row() { sql "select count(*) from game_dimen where pkg_name='$1' and function='$2';"; }

installed_file() { echo /tmp/vivo-memc-installed.txt; }

refresh_installed() {
    pm list packages 2>/dev/null | sed 's/^package://' | sort -u > "$(installed_file)"
    n=$(wc -l < "$(installed_file)" | tr -d ' ')
    [ "$n" -gt 50 ] || die "已安装列表异常（只有 $n 项），中止"
}

is_installed() { grep -qxF "$1" "$(installed_file)"; }

ensure_row() { # _pkg _label _fn _gi
    _pkg=$1; _label=$2; _fn=$3; _gi=$4
    if [ "$(count_row "$_pkg" "$_fn")" -eq 0 ]; then
        sql "insert into game_dimen(function,type,pkg_name,label,channel,oversea,game_index,support_sdk,frame_inter_value) values('$_fn','white','$_pkg','$_label','#',0,$_gi,0,-1);"
    fi
    [ "$(count_row "$_pkg" "$_fn")" -gt 0 ] || die "写入失败: $_pkg/$_fn"
}

drop_row() { sql "delete from game_dimen where pkg_name='$1' and function='$2';"; }

label_of() {
    _l=$(sql "select label from game_dimen where pkg_name='$1' limit 1;")
    [ -n "$_l" ] || _l=$1
    echo "$_l"
}

games() {
    refresh_installed
    sql "select pkg_name from game_dimen where function='boost_frame' group by pkg_name;" | while read -r _p; do
        [ -n "$_p" ] || continue
        is_installed "$_p" || continue
        _lb=$(label_of "$_p")
        _c60=$(count_row "$_p" boost_frame_v3_60_120)
        _c30=$(count_row "$_p" boost_frame_v3_30_60)
        if [ "$_c60" -gt 0 ] && [ "$_c30" -gt 0 ]; then
            _mode=dual
        elif [ "$_c60" -gt 0 ]; then
            _mode=60-120
        elif [ "$_c30" -gt 0 ]; then
            _mode=30-60
        else
            _mode=none
        fi
        _flags=""
        [ "$(count_row "$_p" optimize_power)" -gt 0 ] && _flags="$_flags power"
        [ "$(count_row "$_p" super_resolution)" -gt 0 ] && _flags="$_flags sr"
        [ "$(count_row "$_p" screen_light_effect)" -gt 0 ] && _flags="$_flags light"
        printf '%s\t%s\t%s\t%s\n' "$_p" "$_lb" "$_mode" "${_flags# }"
    done
}

cmd_installed() { refresh_installed; cat "$(installed_file)"; }

# 删掉数据库里存在、但本机没安装的游戏行（进入 WebUI 时自动跑一次）
cmd_prune() {
    refresh_installed
    mkdir -p "$BACKUP_DIR"
    _ts=$(date +%Y%m%d-%H%M%S)
    cp "$DB" "$BACKUP_DIR/support_dimension_list.$_ts.db" || die "备份失败，中止"
    _total=$(sql "select count(distinct pkg_name) from game_dimen;")
    _sqlf=/tmp/vivo-memc-prune.sql
    {
        echo ".timeout 8000"
        echo "create temp table inst(pkg text);"
        awk -v q="'" '{gsub(q, "", $0); if (length($0) > 0) printf "insert into inst values(%s%s%s);\n", q, $0, q}' "$(installed_file)"
        echo "delete from game_dimen where pkg_name not in (select pkg from inst);"
        echo "select 'deleted=' || changes();"
        echo "select 'left=' || count(*) from game_dimen;"
    } > "$_sqlf"
    _res=$(sqlite3 "$DB" < "$_sqlf") || die "prune 执行失败"
    _left=$(sql "select count(distinct pkg_name) from game_dimen;")
    echo "$_res"
    echo "before=$_total after=$_left backup=$BACKUP_DIR/support_dimension_list.$_ts.db"
}

cmd_add() {
    pkg=$1
    refresh_installed
    is_installed "$pkg" || die "本机未安装: $pkg"
    lbl=$(label_of "$pkg"); [ "$lbl" = "$pkg" ] && lbl=${2:-$pkg}
    if [ "$(count_row "$pkg" boost_frame)" -gt 0 ]; then echo "already exists"; return 0; fi
    ensure_row "$pkg" "$lbl" boost_frame 9
    ensure_row "$pkg" "$lbl" boost_frame_v3_60_120 9
    ensure_row "$pkg" "$lbl" optimize_power 9
    ensure_row "$pkg" "$lbl" optimize_power_v3_60_30_60 9
    ensure_row "$pkg" "$lbl" screen_light_effect 9
    echo "added $pkg（重进游戏后生效）"
}

cmd_remove() {
    pkg=$1
    [ "$(count_row "$pkg" boost_frame)" -gt 0 ] || die "未配置: $pkg"
    sql "delete from game_dimen where pkg_name='$pkg' and function in ($MANAGED);"
    echo "removed $pkg"
}

cmd_set_mode() {
    pkg=$1; mode=$2
    case $mode in
        60-120) want=boost_frame_v3_60_120 ;;
        30-60)  want=boost_frame_v3_30_60 ;;
        dual)   want="boost_frame_v3_60_120 boost_frame_v3_30_60" ;;
        *) die "不支持的档位: $mode（只支持 60-120 / 30-60 / dual）" ;;
    esac
    lbl=$(label_of "$pkg")
    ensure_row "$pkg" "$lbl" boost_frame 9
    ensure_row "$pkg" "$lbl" optimize_power 9
    ensure_row "$pkg" "$lbl" screen_light_effect 9
    sql "update game_dimen set game_index=9 where pkg_name='$pkg' and function in ('boost_frame','optimize_power');"
    for f in boost_frame_v3_30_60 boost_frame_v3_60_120 boost_frame_v3_60_45_90 boost_frame_v3_60_48_144; do
        case " $want " in *" $f "*) continue ;; esac
        drop_row "$pkg" "$f"
    done
    for f in $want; do ensure_row "$pkg" "$lbl" "$f" 9; done
    if [ "$mode" = "60-120" ]; then
        ensure_row "$pkg" "$lbl" optimize_power 9
        ensure_row "$pkg" "$lbl" optimize_power_v3_60_30_60 9
    fi
    # dual 档需要让 GameCube 传真实原生帧率（否则 -100 会让三段 if 全跑，30 段最后覆盖成 60）
    if [ "$mode" = "dual" ]; then
        sql "update game_dimen set support_sdk=1 where pkg_name='$pkg' and function in ('boost_frame','optimize_power');"
    else
        sql "update game_dimen set support_sdk=0 where pkg_name='$pkg' and function in ('boost_frame','optimize_power');"
    fi
    # 改档位必须重启游戏助手才生效，这里直接重启（异步队列里跑，不会卡界面）
    am force-stop $GC 2>/dev/null
    echo "mode=$mode（已重启游戏助手）"
}

cmd_set_flag() {
    pkg=$1; flag=$2; state=$3
    case $flag in
        power) want=optimize_power ;;
        sr)    want=super_resolution ;;
        light) want=screen_light_effect ;;
        boost) want=boost_frame ;;
        *) die "未知功能: $flag" ;;
    esac
    lbl=$(label_of "$pkg")
    case $state in
        on)  ensure_row "$pkg" "$lbl" "$want" 9 ;;
        off) drop_row "$pkg" "$want" ;;
        *) die "状态只能是 on/off" ;;
    esac
    echo "$flag=$state（重进游戏后生效）"
}

cmd_set_label() {
    pkg=$1; lbl=$2
    [ -n "$lbl" ] || die "label 不能为空"
    sql "update game_dimen set label='$lbl' where pkg_name='$pkg';"
    echo "label=$lbl"
}

# 把游戏魔盒恢复到出厂状态（清数据）。会删掉所有导入配置与游戏助手自己的名单。
cmd_reset_gc() {
    pm clear $GC >/dev/null 2>&1 || die "pm clear 失败"
    echo "gamemode-reset: 游戏魔盒数据已清除，需要重新导入应用"
}

cmd_status() {
    echo "memc=$(cat /sys/rsc/vgarph/MEMC 2>/dev/null)"
    echo "ic=$(getprop persist.vivo.displayic.ver)"
    if grep -q 'vivo.hardware.game.memc' /vendor/etc/vivo_config.ini 2>/dev/null; then echo "ini=1"; else echo "ini=0"; fi
    echo "req=$(settings get system gamecube_frame_interpolation 2>/dev/null)"
    echo "eff=$(settings get system gamecube_memc_effective 2>/dev/null)"
    echo "gc_pid=$(pidof $GC 2>/dev/null)"
    echo "module_log=$(tail -n 1 "$LOG" 2>/dev/null)"
}

cmd_reapply() {
    SRC="$MODDIR/system/vendor/etc/vivo_config.ini"
    [ -f "$SRC" ] || die "缺少 $SRC"
    if ! grep -q 'vivo.hardware.game.memc' /vendor/etc/vivo_config.ini 2>/dev/null; then
        chcon u:object_r:vendor_configs_file:s0 "$SRC" 2>/dev/null
        mount --bind "$SRC" /vendor/etc/vivo_config.ini
    fi
    setprop ctl.restart vivo-configstore-hal-1-0
    echo "hal restarted"
    sleep 2
    echo "zygote reboot"
    setprop ctl.restart zygote
}

need_root
case ${1:-} in
    status)     cmd_status ;;
    installed)  cmd_installed ;;
    games)      need_db; games ;;
    prune)      need_db; cmd_prune ;;
    add)        need_db; check_pkg "${2:-}"; cmd_add "${2}" "${3:-}" ;;
    remove)     need_db; check_pkg "${2:-}"; cmd_remove "${2}" ;;
    set-mode)   need_db; check_pkg "${2:-}"; cmd_set_mode "${2}" "${3:-}" ;;
    set-flag)   need_db; check_pkg "${2:-}"; cmd_set_flag "${2}" "${3:-}" "${4:-}" ;;
    set-label)  need_db; check_pkg "${2:-}"; cmd_set_label "${2}" "${3:-}" ;;
    reset-gc)   cmd_reset_gc ;;
    restart-gc) am force-stop $GC; echo "gamecube restarted" ;;
    reapply-cap) cmd_reapply ;;
    *) sed -n '2,18p' "$0" ;;
esac
