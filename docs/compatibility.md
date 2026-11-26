# 兼容性

## 机型

| 机型 | 状态 | 说明 |
|---|---|---|
| vivo X Fold2（PD2266 / V2266A） | ✅ 实测 | OriginOS 6 / Android 16，`PD2266_A_16.3.18.1.W10.V000L1` |
| vivo X Fold | ⚠️ 理论 | 未验证。属性名与 GameCube 数据库结构可能不同 |
| vivo X Fold+ | ⚠️ 理论 | 未验证 |
| vivo X Fold3 / X Fold3 Pro | ⚠️ 理论 | 未验证；新系统可能改过 `game_dimen` 表结构 |
| vivo X Fold5 | ⚠️ 理论 | 未验证 |
| vivo X100 / X90 等直板机 | ⛔ 无需 | 出厂即开放游戏插帧 |

## 判定依据

反编译 `com.vivo.gamecube` / `com.vivo.gamewatch` 可见：插帧能力开关由 `[vivo.hardware.game.memc]` 属性控制，游戏侧栏的「游戏插帧」入口、GameWatch 的 MEMC 请求下发都以此为前提。X Fold 系列把该属性裁掉了，直板机保留。

## 版本前提

- KernelSU 模块 WebUI 需要管理器支持（KernelSU 0.7+/ReSukiSU 4.x）。
- 系统「游戏魔盒」必须存在，且数据库路径为
  `/data/data/com.vivo.gamecube/databases/support_dimension_list.db`。
- 如果 OTA 后功能失效，优先检查上述路径与表 `game_dimen` 的列是否变化。

## 自行测试建议

1. 先确认 `ls /vendor/etc/vivo_config.ini` 存在，且其中没有 `java-game-opt-hal-support=true`。
2. 装模块后看日志 `/data/local/tmp/vivo-game-memc.log` 是否走完流程。
3. WebUI 能打开且状态显示「能力已就绪 / 已声明」。
4. 导入一个 60fps 游戏，侧栏是否出现「游戏插帧」，切「提升帧率」后
   `settings get system gamecube_frame_interpolation` 是否为 `1:9:<pid>:60:120`。

不满足时请带着机型、系统版本、日志与 `dumpsys` 片段提 issue。
