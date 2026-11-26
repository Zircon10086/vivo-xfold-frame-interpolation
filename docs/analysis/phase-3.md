# 阶段三：开机卡死的归因、可用路径与白名单语义

## 1. 开机卡死的归因（已定位到模块动作）

| 实验 | 结果 |
|---|---|
| 模块启用（post-fs-data 里 bind mount `/vendor/etc/vivo_config.ini`） | 开机卡在 vivo logo，约 2–13 分钟后才重启或需手动重启；`post-fs-data` 日志出现两次 |
| 模块禁用（同一份 ini、无挂载） | **45 秒干净开机**，`/vendor/etc/vivo_config.ini` 恢复原始 SHA-256、无挂载 |

上一轮启动的 logcat 中，`init`（pid 1187）在 `03:53:53` 收到 SIGABRT；`crash_dump64` 因 SELinux `ptrace` 被拒，拿不到 abort 原因。可以确定的是：**卡死与“在 post-fs-data 阶段替换/挂载 vendor 文件”强相关**，而不是数据库内容——数据库在禁用模块的那次启动里保持原样，设备正常。

结论：模块不能再在 post-fs-data 阶段动 `/vendor`。可选路径只有两条：在 system_server 启动前用不触发 init 异常的方式声明能力，或放弃开机期声明、改为运行期生效（需要一次 framework 重启）。

## 2. 已验证可用的运行期路径

在设备已开机的前提下，按顺序执行即可让能力与适配同时到位（全部可逆，重启即还原）：

1. `mount --bind` 模块内的 `vivo_config.ini` 到 `/vendor/etc/vivo_config.ini`
2. `setprop ctl.restart vivo-configstore-hal-1-0`（HAL 重启后重新解析 ini，PID 会变化）
3. `setprop ctl.restart zygote`（system_server 重建进程级能力缓存）
4. 向 `com.vivo.gamecube` 的 `support_dimension_list.db` 的 `game_dimen` 表补行，并重启 GameCube 进程

结果：`/sys/rsc/vgarph/MEMC` 从 `0` 变为 `1`，`gamecube_frame_interpolation` 请求值带上游戏 PID，游戏侧栏出现“游戏插帧”入口。

## 3. 白名单的真实语义（还剩最后一层）

`game_dimen` 的行不是“允许开关”，而是“该游戏支持哪组帧率变换”。对照真适配的《原神》：

```
com.miHoYo.Yuanshen  game_index=3
  boost_frame_v3_30_60 / 60_45_90 / 60_120 / 60_48_144
  boost_frame / optimize_power
```

《绝区零》我们只补了 `boost_frame`、`optimize_power`、`60_120`、`60_45_90`、`optimize_power_v3_60_30_60`，`game_index` 写成 10。入口能出现，但开启时仍提示“需将原生帧率设置至高帧率”。

代码层面的判定点在 `e9/h.java:929`：`if (this.f18731m != 60)` 才弹这条提示——即 GameCube 认为当前游戏帧率不是 60。这个值不是我们写进数据库的，而是 GameCube 自己采到的运行状态。这正是你判断的“原生适配游戏会主动上报状态”那一层。

## 4. 下一步的三个方向

- **A（借壳验证）**：把《绝区零》的 `game_index` 改成真适配游戏的值（如《原神》的 3），并补齐同一组 V3 行，验证“缺少游戏侧状态上报”是否才是唯一剩余障碍。改动小、可逆，但不解决状态上报。
- **B（逆向状态接口）**：`vivo-services.jar` 里的 `VivoDisplayEnhanceManagerService` 已有 `GAME_MEMC_TYPE=258`、`MEMC_MAIN_SWITCH_SETTING`、`DISPLAY_ENHANCE_GAME_MEMC_ACTIVATED` 等常量，另有 `game_manager: com.vivo.game.IGameManager` 服务；这两者就是“系统侧接收游戏状态”的候选接口，适合继续逆向。
- **C（先修模块）**：把模块从 post-fs-data 挪到 `service.sh`（开机后），配合一次 framework 重启完成生效，彻底避开开机期挂载。
