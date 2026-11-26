# On-device observations; all commands are read-only.
echo '--- Firmware and display properties ---'
for k in ro.build.display.id ro.vivo.product.model persist.vivo.displayic.ver; do
  printf '%s=%s\n' "$k" "$(getprop "$k")"
done
echo '--- Settings state (user 0) ---'
for k in gamecube_frame_interpolation gamecube_frame_interpolation_for_sr; do
  printf '%s=%s\n' "$k" "$(settings --user 0 get system "$k")"
done
echo '--- Registered services (filtered) ---'
service list | grep -Ei 'iris|pixelworks|gamewatch|vivo.*(display|game)|vgarph|memc'
echo '--- Feature, per-game config and display files (paths only) ---'
for dir in /system/etc /system_ext/etc /product/etc /vendor/etc /odm/etc; do
  find "$dir" -maxdepth 3 -type f 2>/dev/null | grep -Ei 'ftfeature|vivo_feature|gamewatch|gamecube|frame.?inter|iris|memc|displayic|interpolat'
done
echo '--- Legacy GameCube config directories ---'
ls -ld /system/etc/gamecube /oem/etc/gamecube 2>&1
echo '--- Relevant logs (no matches is inconclusive) ---'
logcat -d -t 6000 -s IrisUtils FrameInterpolationConfigManager InterpolatedFpsAdjuster FtFeature MEMCManager | grep -E 'isSupport|not support|MEMC|FrameInter' | tail -n 25
echo '--- Sysfs visibility (shell) ---'
ls -ld /sys/rsc/vgarph/MEMC /sys/rsc/vgarph/independent_grap 2>&1
exit 0
