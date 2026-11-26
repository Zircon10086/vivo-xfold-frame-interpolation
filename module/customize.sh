#!/system/bin/sh
# vivo-xfold-frame-interpolation —— 安装时设备检测
#
# 规则（依据各代 X Fold 是否带 V 系列自研影像芯片）：
#   X Fold2 (V2) / X Fold3 Pro (V3) / X Fold6 (V3+)  → 允许安装
#     - X Fold2：唯一实测机型
#     - 其余：给警告，继续安装（理论支持，需自行验证）
#   其他 X Fold（无独立 V 芯片） → 拒绝
#   非 X Fold 机型 → 拒绝
#
# 调试逃生门：存在 /data/local/tmp/vivo-xfold-force 时，任何机型都会带警告放行。

MODEL="${VIVO_MODEL:-$(getprop ro.product.vendor.model)}"
[ -n "$MODEL" ] || MODEL="$(getprop ro.product.model)"
DEVICE="${VIVO_DEVICE:-$(getprop ro.product.vendor.device)}"
[ -n "$DEVICE" ] || DEVICE="$(getprop ro.product.device)"
MARKET="${VIVO_MARKET:-$(getprop ro.product.marketname)}"
[ -n "$MARKET" ] || MARKET="$(getprop ro.product.marketname_full)"
[ -n "$MARKET" ] || MARKET="未知"

# 安装器可能没有提供这两个函数（本地测试时会走到 fallback）
command -v ui_print >/dev/null 2>&1 || ui_print() { echo "$1"; }
command -v abort >/dev/null 2>&1 || abort() { echo "! $1" >&2; exit 1; }

say_line="----------------------------------------------------------------"
warn() { ui_print "! $1"; }

DEV_NORM="$(echo "$DEVICE" | tr 'a-z' 'A-Z')"
MODEL_NORM="$(echo "$MODEL" | tr 'a-z' 'A-Z')"

ui_print "$say_line"
ui_print " vivo X Fold 插帧解锁 · 安装前设备检测"
ui_print " 型号: $MODEL"
ui_print " 设备: $DEVICE"
ui_print " 市场名: $MARKET"
ui_print "$say_line"

TIER=""
NAME=""
CHIP=""

classify() {
  case "$1" in
    # 型号（V 编号）优先：来自官方规格页，比设备代号可靠
    V2266*) TIER=verified; NAME="X Fold2";     CHIP="V2";  return 0 ;;
    V2337*) TIER=warn;     NAME="X Fold3 Pro"; CHIP="V3";  return 0 ;;
    V2545*) TIER=warn;     NAME="X Fold6";     CHIP="V3+"; return 0 ;;
    V2436*) TIER=nochip;   NAME="X Fold5";     CHIP="无";  return 0 ;;
    V2303*) TIER=nochip;   NAME="X Fold3";     CHIP="无";  return 0 ;;
    V2229*) TIER=nochip;   NAME="X Fold+";     CHIP="无";  return 0 ;;
    V2178*) TIER=nochip;   NAME="X Fold";      CHIP="无";  return 0 ;;
    # 设备代号（PD 编号）兜底
    PD2266) TIER=verified; NAME="X Fold2";     CHIP="V2";  return 0 ;;
    PD2337) TIER=warn;     NAME="X Fold3 Pro"; CHIP="V3";  return 0 ;;
    PD2507) TIER=warn;     NAME="X Fold6";     CHIP="V3+"; return 0 ;;
    PD2436) TIER=nochip;   NAME="X Fold5";     CHIP="无";  return 0 ;;
    PD2303) TIER=nochip;   NAME="X Fold3";     CHIP="无";  return 0 ;;
    PD2229) TIER=nochip;   NAME="X Fold+";     CHIP="无";  return 0 ;;
    PD2178) TIER=nochip;   NAME="X Fold";      CHIP="无";  return 0 ;;
  esac
  return 1
}

if ! classify "$MODEL_NORM"; then
  # 型号没命中时，用设备代号兜底
  if ! classify "$DEV_NORM"; then
    if echo "$MODEL_NORM$DEV_NORM" | grep -qi 'FOLD'; then
      TIER=unknown_fold; NAME="未识别的 X Fold 机型"; CHIP="未知"
    else
      TIER=other; NAME="非 X Fold 机型"; CHIP="未知"
    fi
  fi
fi

if [ -f /data/local/tmp/vivo-xfold-force ]; then
  if [ "$TIER" != "verified" ]; then
    warn "检测到调试放行文件 /data/local/tmp/vivo-xfold-force，跳过兼容性拦截（风险自负）"
  fi
  TIER=forced
fi

case "$TIER" in
  verified)
    ui_print "√ 检测到 $NAME（影像芯片 $CHIP），这是本模块唯一完整验证过的机型"
    ;;
  warn)
    warn "检测到 $NAME（影像芯片 $CHIP）"
    warn "该机型未经验证，仅理论支持：属性名、游戏魔盒数据库结构、档位参数都可能不同"
    warn "继续安装，出问题请附日志与机型信息提 issue"
    ;;
  forced)
    warn "已按调试放行继续安装，当前机型 $MODEL 不在支持列表内"
    ;;
  nochip)
    abort "检测到 $NAME：该机型没有独立 V 系列影像芯片，硬件不支持 MEMC 插帧，安装中止。"
    ;;
  unknown_fold)
    abort "检测到 $MODEL（$MARKET）：无法确认是否带 V 系列影像芯片。请先确认机型，或在 /data/local/tmp/vivo-xfold-force 写入任意内容后重试（风险自负）。"
    ;;
  *)
    abort "检测到 $MODEL（$MARKET）：这不是 vivo X Fold 系列机型。直板机通常原生开放游戏插帧，不需要本模块。"
    ;;
esac

ui_print "$say_line"
ui_print " 检测通过，继续安装"
ui_print "$say_line"
