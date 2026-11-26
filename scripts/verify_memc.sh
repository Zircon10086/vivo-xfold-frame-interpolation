#!/system/bin/sh
# 插帧链路只读取证。用法：adb shell sh /data/local/tmp/verify_memc.sh
# 不写任何设置，只读状态 + 捞日志。判定建议见 reports/phase-6.md。
echo '--- display IC ---'
for k in persist.vivo.displayic.ver ro.vivo.product.model ro.build.display.id; do
  printf '%s=%s\n' "$k" "$(getprop "$k")"
done
echo '--- Settings（请求值与生效值）---'
for k in gamecube_frame_interpolation gamecube_frame_interpolation_for_sr gamecube_memc_effective; do
  printf '%s=%s\n' "$k" "$(settings get system "$k" 2>&1)"
done
echo '--- 能力回写 ---'
cat /sys/rsc/vgarph/MEMC 2>&1
echo '--- 模块注入痕迹 ---'
logcat -d -t 4000 -s Xposed 2>/dev/null | grep -a '\[VivoMemc\]' | tail -n 30
echo '--- GameCube 请求链（FrameInterpolationHelper 打出 gameIndex/gamePid/depress/target）---'
logcat -d -t 4000 -s FrameInterpolationHelper IrisUtils 2>/dev/null | tail -n 20
echo '--- GameWatch 闸门与下发 ---'
logcat -d -t 4000 -s InterpolatedFpsAdjuster AbsVivoDisplayEnhanceManager 2>/dev/null \
  | grep -aE 'mSupportFrwScheme|onChange  info|Command for putting|set display enhance config|reset IC' | tail -n 20
echo '--- 系统侧 258 用例 ---'
logcat -d -t 4000 2>/dev/null | grep -aE 'NovaUsecaseControllerV1|computeUsecaseForGame|mGameMemcFps' | tail -n 20
exit 0
