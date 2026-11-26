#!/system/bin/sh
# vivo-game-memc（KernelSU 模块）
#
# 本脚本刻意什么都不做：按阶段三的实测，在 post-fs-data 阶段对 /vendor 做 bind mount
# 会让 init 收到 SIGABRT、开机卡 logo。覆盖动作全部挪到 service.sh（开机完成之后）。
MODDIR=${0%/*}
LOG=/data/local/tmp/vivo-game-memc.log
echo "$(date '+%m-%d %H:%M:%S') == post-fs-data (no-op by design)" >> "$LOG"
exit 0
