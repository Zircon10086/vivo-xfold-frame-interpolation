#!/system/bin/sh
# 给指定游戏补齐「提升帧率 60→120」所需的 game_dimen 行（设备端执行，需 root）。
#
#   adb shell su -c "sh /data/local/tmp/apply_game_dimen.sh com.miHoYo.Nap"
#
# 做的事：
#   1) 备份 support_dimension_list.db
#   2) 插帧相关的行 game_index 改成 9（9 是 GameWatch 侧 V() 白名单里的取值，
#      N() 判定一定为 true，降帧口径 60 才不会被归零）
#   3) 删掉 boost_frame_v3_30_60（-100 分支里最后执行，会把 120 覆盖成 60）
#      与 boost_frame_v3_60_48_144（会把目标帧算成 144，本机面板只有 120）
#   4) 确保 boost_frame_v3_60_120 存在
#
# 前提：/sys/rsc/vgarph/MEMC 已是 1（能力位由 vivo-game-memc 模块声明）。
set -e

PKG="${1:-com.miHoYo.Nap}"
DB=/data/data/com.vivo.gamecube/databases/support_dimension_list.db
TS=$(date +%Y%m%d-%H%M%S)
BAK=/data/local/tmp/support_dimension_list.$PKG.$TS.db

[ -f "$DB" ] || { echo "db not found: $DB"; exit 1; }
command -v sqlite3 >/dev/null 2>&1 || { echo "sqlite3 missing"; exit 1; }

ROWS=$(sqlite3 "$DB" "select count(*) from game_dimen where pkg_name='$PKG' and function like 'boost_frame%';")
if [ "$ROWS" -eq 0 ]; then
    echo "no boost_frame rows for $PKG — 该游戏还没有适配行，先补行再跑本脚本"
    exit 1
fi

am force-stop com.vivo.gamecube
sleep 2
cp "$DB" "$BAK"
echo "backup: $BAK"

sqlite3 "$DB" "update game_dimen set game_index=9 where pkg_name='$PKG' and function in ('boost_frame','optimize_power','boost_frame_v3_60_120','boost_frame_v3_60_45_90');"
sqlite3 "$DB" "update game_dimen set game_index=3 where pkg_name='$PKG' and function in ('screen_light_effect','back_light_effect','game_manipulation_touch');"
sqlite3 "$DB" "delete from game_dimen where pkg_name='$PKG' and function in ('boost_frame_v3_30_60','boost_frame_v3_60_48_144');"

EXIST=$(sqlite3 "$DB" "select count(*) from game_dimen where pkg_name='$PKG' and function='boost_frame_v3_60_120';")
if [ "$EXIST" -eq 0 ]; then
    sqlite3 "$DB" "insert into game_dimen(function,type,pkg_name,label,channel,oversea,game_index,support_sdk,frame_inter_value)
                   select 'boost_frame_v3_60_120','white',pkg_name,label,channel,oversea,9,support_sdk,frame_inter_value
                   from game_dimen where pkg_name='$PKG' and function='boost_frame' limit 1;"
    echo "inserted boost_frame_v3_60_120"
fi

echo "--- 当前 $PKG 的插帧行 ---"
sqlite3 "$DB" "select game_id,function,game_index from game_dimen where pkg_name='$PKG' order by game_id;"
echo "done. 重启游戏后再看 侧栏→游戏工具→游戏插帧。"
