# 第二阶段：生效原理与 KernelSU 模拟方案

**结论：限制来自“能力声明”，不是硬件缺失。** 显示驱动暴露 `/sys/rsc/vgarph/MEMC` 节点，`independent_grap` 节点写入的 IC 版本为 `NT72326_IC2.0_V3.0`；但 `/vendor/etc/vivo_config.ini` 只声明了 `[vivo.hardware.video.memc]`，没有 `[vivo.hardware.game.memc]`。GameCube 与 GameWatch 都先查这个能力，因此插帧入口在本机不出现。模块只补声明与游戏适配表，未做任何设备写入。

## 完整判定链（源码 + 真机）

| 层 | 事实 | 证据 |
|---|---|---|
| 硬件/驱动 | MEMC 节点存在，当前值 `0`；`super_resolution=0`、`fast_animation_engine=1` | `su -c 'ls /sys/rsc/vgarph/'`、`cat /sys/rsc/vgarph/MEMC` |
| 能力 HAL | `vendor.vivo.hardware.configstore` 运行中，解析 `/vendor/etc/vivo_config.ini` 与 `/feature_config/vivo_config.ini` | HAL 实现库字符串、`ps -A`、init rc |
| 能力判定 | `FtFeature.isFeatureSupport` → `VivoConfigStoreHelper.hasVivoFeature`，带进程内缓存 `sCachedFeatureMap` | [FtFeature.java](../fw/FtFeature.java#L665)、[VivoConfigStoreHelper.java](../fw/VivoConfigStoreHelper.java#L126) |
| 声明缺口 | ini 内有 `[vivo.hardware.video.memc] version=nova`，**无** `[vivo.hardware.game.memc]` | `/vendor/etc/vivo_config.ini` 第 323 行附近 |
| 应用入口 | GameCube 先查 `vivo.hardware.game.memc`，再查每游戏适配 | [e0.java](../decompiled/com.vivo.gamecube/sources/com/vivo/gameassistant/utils/e0.java#L1738) |
| 适配表 | `/system/etc/gamecube/FrameInterConfigList[PD2266].xml` 不存在；`frame_inter_list.db` 不存在；prefs 无 `frame_inter_config_list_version` | 真机 `ls`、SQLite 与 SharedPreferences 抽查 |
| 执行层 | GameWatch 监听 `gamecube_frame_interpolation`，经 `setDisplayEnhanceConfigure` / `sendCommandToIC` 下发给显示 IC | [e0/a.java](../decompiled/com.vivo.gamewatch/sources/e0/a.java#L1067)、[j0/l.java](../decompiled/com.vivo.gamewatch/sources/j0/l.java#L247) |

缓存语义决定了模块的时序要求：HAL 在构造时解析 ini，system_server 在初始化时把整张能力表读进 `sCachedFeatureMap`。所以覆盖必须在 system_server 启动前可见，并且 HAL 必须在覆盖之后重启；只改文件不重启 HAL、或只重启 HAL 不重启系统，都不会生效。

## 模块设计

最小改动两处覆盖 + 一次服务重启，不加任何内核代码：

```text
ksu-module/vivo-game-memc/
├── module.prop
├── post-fs-data.sh                 # 覆盖后重启 vivo-configstore-hal-1-0
├── service.sh                      # 开机后记录节点与请求状态
├── system/vendor/etc/vivo_config.ini          # 原文 + [vivo.hardware.game.memc]
└── system/system/etc/gamecube/FrameInterConfigList.xml   # 35 个游戏
```

已验证：`ini` 174 个 section 可解析、`game.memc` 段存在；适配表 XML 结构合法（35 个 `game` 节点）；两个脚本 `bash -n` 通过。原 ini 的 SHA-256 为 `45fe01d2…f6c59c`，覆盖文件为 `dffd5a19…2c6f7d3a`（仅追加 57 字节）。

## 风险与回退

- **覆盖 `/vendor/etc/vivo_config.ini`**：若 HAL 解析失败，能力表可能整张为空，连带影响依赖它的显示类功能（XDR、亮度策略、校准）。覆盖文件逐字节保留原内容，只追加一个合法段；删除模块并重启即恢复。
- **`setprop ctl.restart` 可能被 SELinux 拒绝**：这种情况只是不生效，不会破坏系统；日志会显示 HAL 未重启。
- **必须重启**：能力在 system_server 内缓存，热重载不成立。
- **效果不确定**：IC 是否接受 4:3.55 内屏的插帧、`sdk_version=nova` 是否是该机型正确属性，都要实测。

## 验收标准（不达标的都算失败）

1. 重启后 `grep -c vivo.hardware.game.memc /vendor/etc/vivo_config.ini` 为 3，`init.svc.vivo-configstore-hal-1-0` 为 `running`。
2. 打开适配表内的游戏，侧栏出现“游戏插帧”入口（此前不存在）。
3. 开启后 `settings get system gamecube_frame_interpolation` 从 `0:-1:0:0:0` 变为启用态，且 `cat /sys/rsc/vgarph/MEMC` 不再为 `0`。
4. 画面侧：同场景下实际显示帧率提升，或高速录像能看出帧间插值；仅“菜单出现”“设置值变化”不算生效。
