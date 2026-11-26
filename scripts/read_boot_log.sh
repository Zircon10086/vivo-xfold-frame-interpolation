#!/system/bin/sh
LOG=/data/adb/ksu/log/logcat.old.log
echo "=== fatal"
grep -a -n "Fatal signal 6" "$LOG" | head -5
echo "=== context"
grep -a -n -B5 -A12 "Fatal signal 6" "$LOG" | head -60
echo "=== watchdog"
grep -a -n -iE "watchdog|ANR in system_server|died|crash" "$LOG" | tail -25
