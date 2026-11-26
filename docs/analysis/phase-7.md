# 阶段七：真机跑通 60→120（2026-11-26）

阶段六结束时只有「代码层闭环」，v0.4 注入模块在设备上**没有生效**。这一轮把设备接回来做了完整实测，结论是：

**最终有效路径 = KernelSU 模块（能力声明）+ `game_dimen` 行修正，不需要 LSPosed。**

## 一、LSPosed 方案为什么在这台机器上不成立（实测）

| 检查 | 结果 |
|---|---|
| Vector 2.2（`org.matrix.vector.manager`，API 102）状态 | 正常，5 个模块已启用 |
| `vector-cli modules ls` | `org.dsh.vivomemc` 显示 `STATUS=enabled` |
| `vector-cli scope ls org.dsh.vivomemc` | `com.vivo.gamecube`、`com.vivo.gamewatch` 都在 |
| 管理器 UI | 模块列在「运行中」，带两个作用域应用图标 |
| 实际注入 | **没有**。GameCube 写设置时仍是 `48:60`，hook 全部未命中 |
| 模块日志 `/data/adb/lspd/log/modules_*.log` | 只有 `----part 1 start----`，从未有 XposedBridge 输出 |
| 对照组：新建最小注入探测器 `diagnostics/xp-canary`（只 `Log.e("XpTest")`） | 作用域设到 `com.android.settings`、`system` 都没有任何输出 |

为了排除「是我们的 APK 有问题」，专门做了一个只打一行 `android.util.Log`、不带任何 hook 逻辑的模块（`diagnostics/xp-canary/`），结果同样没有任何日志。**结论：Vector 在这台机器上把模块标记为启用/运行中，但 Zygisk 侧没有把模块类加载进目标进程**（NeoZygisk 负责 zygisk 注入、zygisk_vector 提供 Vector 的 native 只在 system_server 里可见）。这不是我们模块能修的层面，也不该继续在这里耗。

因此 v0.4 模块已经在 Vector 里禁用（APK 仍装着，不动它，随时可以再测）；探测器也已卸载。

## 二、真正跑通的链路

```
[vivo-game-memc KernelSU 模块] 开机完成 → bind mount 带 game.memc 的 ini → 重启 configstore HAL → 重启 zygote
        ↓
[GameCube] 读 game_dimen：boost_frame_v3_60_120 命中、30_60 与 60_48_144 不存在 → e9.i.b 算出 {60,120}
        ↓  写 Settings.System gamecube_frame_interpolation = 1:9:<pid>:60:120
[GameWatch] 解析请求：scene=9、depress=60、target=120
        ↓  N() 对 scene=9 返回 true → depress 不被归零
        ↓  旧 IC 分支只发 6 参 {10,-1,2,-1,9,60}
[system_server] NovaUsecaseControllerV1 case 258（非 Nova 分支）→ mGameMemcFps=60
        ↓  computeUsecaseForGame: mGameMemcFps==60 → reqDfps=60995（120Hz）
[显示 IC] 面板 120Hz，游戏侧被限制在 60Hz 提交（frameRateOverride uid=10325 = 60Hz）
```

关键点：**`game_index=9` 是让 GameWatch 不把降帧口径归零的那把钥匙**。GameWatch 的 `N()` 在
`measured <= depress` 时走 `V(c)`，只有 `scene ∈ {9,13,16,21,25}` 才返回 true；否则 depress 被置 0，
报文变成 `{…,0}`，系统按 0 处理 = 关闭插帧。阶段四用的 `game_index=3` 恰好落在这个坑里。

## 三、实测记录（2026-11-26 08:2x ~ 08:5x）

### 1. 能力位自动声明（重启后无人工干预）

```
$ su -c cat /data/local/tmp/vivo-game-memc.log
11-26 08:38:08 == service.sh start
11-26 08:38:47 bind rc=0
11-26 08:38:47 ini game.memc lines: 1
11-26 08:38:47 hal restarted: running
11-26 08:38:50 zygote restarted
11-26 08:38:50 == service.sh done, MEMC=1
```

```
$ su -c "grep -c game.memc /vendor/etc/vivo_config.ini"   → 1
$ su -c "cat /sys/rsc/vgarph/MEMC"                        → 1
```

### 2. 侧栏面板（证据图 `reports/evidence/04-最终-提升帧率-120帧.png`）

- 原始帧率 / 提升帧率 两个档位，提升帧率选中
- 文案：**帧率最大可提升至 120 帧。**（阶段四是「60 帧」）

### 3. 开关 A/B（同一游戏进程 23525）

```
ON : req=1:9:23525:60:120   eff=60   MEMC=1
OFF: req=0:-1:23525:0:0     eff=0
ON : req=1:9:23525:60:120   eff=60
```

`gamecube_memc_effective` 是**系统写入的生效值**（= mGameMemcFps），60 对应 120Hz 用例；
不是请求值，也不是 IC 回写。

### 4. 显示侧状态

```
dumpsys display | grep frameRateOverride
  frameRateOverride {uid=10325 frameRateHz=60.000004}
内置屏 supportedModes: id=1 fps=120 / id=2 fps=60（当前在 120）
```

即：面板 120Hz、游戏进程被压到 60Hz 提交 —— 插帧的正确形态。

## 四、还留在设备上的东西

| 位置 | 内容 | 还原方式 |
|---|---|---|
| `/data/adb/modules/vivo-game-memc` | v1.1.0，开机自动覆盖 ini + 重启 HAL/zygote | 删目录或加 `disable` 文件后重启 |
| `support_dimension_list.db`（GameCube） | 绝区零 4 条插帧行：`game_index=9`，删了 `30_60`、`60_48_144` | 备份在 `/data/local/tmp/support_dimension_list.com.miHoYo.Nap.*.db` |
| `game_cube_assistantui.xml` | `sp_game_fps_origin` / `sp_game_fps_new` 里绝区零=60（阶段四写入，保留） | 删 key 或恢复旧文件 |
| Vector | `org.dsh.vivomemc` 仍装着但**已禁用**；`org.dsh.xptest` 已卸载 | 无需处理 |

## 五、复现步骤（换机/系统升级后）

```bash
# 1) 能力位（模块装上后重启一次即可）
adb push ksu-module/vivo-game-memc /data/local/tmp/vivo-game-memc
adb shell su -c "sh /data/local/tmp/install_module_device.sh"   # 旧脚本，确认路径后可用
# 或直接：把目录放进 /data/adb/modules/，重启

# 2) 每游戏适配行
adb push scripts/apply_game_dimen.sh /data/local/tmp/
adb shell su -c "sh /data/local/tmp/apply_game_dimen.sh com.miHoYo.Nap"

# 3) 进游戏 → 侧栏「游戏工具」→ 滚到底 →「游戏插帧」→ 提升帧率
adb shell settings get system gamecube_frame_interpolation   # 1:9:<pid>:60:120
adb shell settings get system gamecube_memc_effective        # 60
```

## 六、没闭环的部分（如实记录）

1. **IC 是否真的在插帧**：软件侧只能证到「系统按 120Hz 用例下发 + 面板 120Hz + 游戏被压 60Hz + 面板文案 120」。
   GameWatch/GameCube 的日志（`IrisUtils`、`InterpolatedFpsAdjuster`）在本机 logcat 里拿不到（属系统应用日志被裁），
   `dumpsys vivo_gfx_display_service` 也没有输出。要看真实观感得靠眼睛，或者用高速摄像/慢放对比开关两档。
2. **30 帧游戏**：`30_120` 行没补，删了 `30_60` 之后 30 帧游戏会失去 30→60 档。要支持需另加 `boost_frame_v3_30_120`。
3. **其他游戏**：`apply_game_dimen.sh` 可以指定包名，但前提是该包在 `game_dimen` 里已有 `boost_frame*` 行；没有行的游戏要先补行（参考阶段二的表结构）。
4. **系统升级**：GameCube 版本变化可能重写 `support_dimension_list.db`，重跑第 2 步即可。
5. **Vector 注入失效**：没有修，只在 `diagnostics/xp-canary` 留了探测器与结论。
