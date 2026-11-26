# 兼容性

## 机型

| 机型 | 影像芯片 | 模块支持 | 说明 |
|---|---|---|---|
| vivo X Fold2（PD2266 / V2266A） | V2 | ✅ 实测 | OriginOS 6 / Android 16，`PD2266_A_16.3.18.1.W10.V000L1` |
| vivo X Fold3 Pro（PD2337 / V2337A） | V3 | ⚠️ 理论 | 未验证；安装时警告 |
| vivo X Fold6（PD2507 / V2545A） | V3+ | ⚠️ 理论 | 未验证；安装时警告 |
| vivo X Fold5（PD2436） | 无 | ⛔ 拒绝 | 无独立 V 芯片 |
| vivo X Fold3（PD2329） | 无 | ⛔ 拒绝 | 无独立 V 芯片 |
| vivo X Fold+（PD2229） | 无 | ⛔ 拒绝 | 无独立 V 芯片 |
| vivo X Fold（PD2178） | 无 | ⛔ 拒绝 | 无独立 V 芯片 |
| vivo X100 / X90 等直板机 | 有 | ⛔ 不需要 | 出厂即开放游戏插帧 |

检测由 `module/customize.sh` 在安装时执行，读 `ro.product.vendor.device` / `ro.product.vendor.model`：
命中白名单的 X Fold2 直接通过；X Fold3 Pro / X Fold6 警告后继续；其余机型 `abort`。
白名单外但名字带 fold 的未知机型同样拒绝，避免把不支持的机型写坏。

## 判定依据

反编译 `com.vivo.gamecube` / `com.vivo.gamewatch` 可见：插帧能力开关由 `[vivo.hardware.game.memc]` 属性控制，游戏侧栏的「游戏插帧」入口、GameWatch 的 MEMC 请求下发都以此为前提。X Fold 系列把该属性裁掉了，直板机保留。

## 版本前提

- KernelSU 模块 WebUI 需要管理器支持（KernelSU 0.7+/ReSukiSU 4.x）。
- 系统「游戏魔盒」必须存在，且数据库路径为
  `/data/data/com.vivo.gamecube/databases/support_dimension_list.db`。
- 如果 OTA 后功能失效，优先检查上述路径与表 `game_dimen` 的列是否变化。

## 自行测试建议

1. 先确认 `ls /vendor/etc/vivo_config.ini` 存在，且其中没有 `java-game-opt-hal-support=true`。
2. 装模块后看日志 `/data/local/tmp/vivo-xfold-fi.log` 是否走完流程。
3. WebUI 能打开且状态显示「能力已就绪 / 已声明」。
4. 导入一个 60fps 游戏，侧栏是否出现「游戏插帧」，切「提升帧率」后
   `settings get system gamecube_frame_interpolation` 是否为 `1:9:<pid>:60:120`。

不满足时请带着机型、系统版本、日志与 `dumpsys` 片段提 issue。
