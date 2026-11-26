# 原理

本文记录「为什么 X Fold 需要这个模块」以及整条链路，来自对 `com.vivo.gamecube`（游戏魔盒）、
`com.vivo.gamewatch`（游戏助手/GameWatch）与系统显示服务的反编译分析。类名与字段名保留原文以便检索，
不包含任何厂商二进制。

## 1. 能力声明：`vivo.hardware.game.memc`

系统把「是否允许游戏插帧」做成 HAL 属性，游戏侧栏的入口与 GameWatch 的请求下发都要先看它：

```ini
# /vendor/etc/vivo_config.ini 片段
[vivo.hardware.game.memc]
java-game-opt-hal-support=true
```

X Fold 系列的出厂配置把这段裁掉（或置 false），所以即使硬件支持 MEMC，UI 也不给入口。

模块的做法：不改 `/vendor` 分区（不可写、会破坏 verity），而是**运行时 bind mount** 一份补上该段的
`vivo_config.ini`，再重启 `vivo-configstore-hal` 与 zygote 让 `SystemProperties` 重新读取。

> 坑：在 `post-fs-data.sh` 阶段做这个挂载会让 init 在 zygote 启动前 SIGABRT，表现为卡 logo。
> 必须在 `sys.boot_completed=1` 之后再挂，代价是开机多一次 zygote 重启。

## 2. 白名单：`game_dimen` 表

游戏魔盒判断「某个应用能不能插帧」并不看属性，而是查自己的数据库：

```
/data/data/com.vivo.gamecube/databases/support_dimension_list.db
  table game_dimen(game_id, function, type, pkg_name, label, channel,
                   oversea, game_index, support_sdk, frame_inter_value)
```

与本项目相关的行：

| function | 作用 |
|---|---|
| `boost_frame` | 开启「游戏插帧」功能（提升帧率）|
| `boost_frame_v3_60_120` | 提升帧率档的 60→120 参数 |
| `optimize_power` | 开启「优化功耗」功能 |
| `optimize_power_v3_60_30_60` | 优化功耗档的 30→60 参数，**同时决定第三档 radio 是否显示** |
| `screen_light_effect` | 视效增强（全局行为，无需独立开关）|

关键点：

- `game_index` 必须写 **9**。GameWatch 在 `measured <= depress` 时会走 `V(scene)` 判断，
  只有 `scene ∈ {9,13,16,21,25}` 返回 true，否则把 depress 归零、报文变成 `{…,0}`，系统据此关掉插帧。
- **不要**写 `boost_frame_v3_30_60`：`support_sdk=0` 时系统拿到的是 -100，
  `e9.i.b()` 里的三段 if 会全部执行，最后执行的 30 段用 `30_60` 把目标覆盖成 60。

## 3. 三档面板的可见性

`FrameInterViewV3` 创建三个 radio：

- 关闭（`rb_close`）：常驻
- 提升帧率（`rb_boost_frame`）：`e9.k.b..i` 任一命中（即 `boost_frame_v3_*`）
- 优化功耗（`rb_opti_power`）：`frameinterpolation.k.u(pkg)` →
  `e9.k.k || e9.k.l || e9.k.j` → `optimize_power_v3_60_30_60` / `_90_45_90` / `_120_60_120`

所以只写 `optimize_power`（功能行）不会让第三档出现，必须同时写 `optimize_power_v3_60_30_60`。

## 4. 请求链路

```
游戏侧栏选档
  └─ GameCube 写 settings: gamecube_frame_interpolation = "1:9:<pid>:<depress>:<target>"
       └─ GameWatch 解析：scene=9, depress, target
            └─ 6/7 参 IC payload → NovaUsecaseControllerV1 case 258
                 └─ mGameMemcFps = depress （非 Nova 分支，values[5]）
                      └─ computeUsecaseForGame: memcFps==60 || target==120 → 60995（120Hz）
                           └─ dumpsys display 里 frameRateOverride 把游戏 uid 压到 60 渲染、合成到 120
```

验证值：

| 档位 | `gamecube_frame_interpolation` | `gamecube_memc_effective` | 显示用例 |
|---|---|---|---|
| 关闭 | `0:-1:<pid>:0:0` | 0 | 默认 |
| 提升帧率 | `1:9:<pid>:60:120` | 60 | 60995 / 120Hz |
| 优化功耗 | `1:9:<pid>:30:60` | 30 | 60993 / 60Hz |

## 5. 为什么不做 Xposed / LSPosed

早期尝试过 Xposed 模块（hook `GameWatch` 的请求构造），结论：

- Vector 2.2 在本机（OriginOS 6 / Android 16）把模块列为「运行中」、作用域也对，但进程里既无
  `XposedBridge` 日志也无 `android.util.Log`，用最小探测器证实**根本没有注入模块类**。
- 改配置表 + 属性声明这条路完全不需要 hook，稳定性更好，也不依赖 LSPosed 生态。

`legacy/lsposed-module` 保留当年的代码，仅供研究，未维护。

## 6. 与 `support_sdk` 的关系

`support_sdk` 是「该游戏是否有原生帧率上报」的标记：

- `0`：系统传 -100，三段判断全跑（结论见上）。
- `≠0`：系统传 `sp_game_fps_origin` 里的实测帧率，只跑匹配的那一段。实测绝区零菜单只有 30 帧，
  因此「自适应」会把 60 帧游戏降成 30→60，不适合作为默认策略。
