# 阶段五：三份子代理报告汇总与 v0.2 注入模块

## 一、三个包的结论（子代理产出）

| 包 | 是否参与插帧 | 结论 |
|---|---|---|
| com.vivo.gamecube | 是，唯一请求生产者 | 全工程仅 `l0.b()` 写 `gamecube_frame_interpolation`；“最大 60”来自 `e9.i.b()` 三段 if 顺序执行 |
| com.vivo.gamewatch | 是，执行侧 | 本机走旧 IC 分支，258 报文只有 6 个 int，**没有目标帧率字段** |
| com.vivo.gamespace | 否 | 只做 ComponentName 跳转；无插帧键读写 |
| com.vivo.gametrain | 否 | 声场训练场，无 IPC |

报告：[gamecube.md](agents/gamecube.md)、[gamewatch.md](agents/gamewatch.md)、[gamespace-train.md](agents/gamespace-train.md)。

## 二、两个根因（比“未适配”更具体）

1. **GameCube 侧把 120 覆盖成 60**：`support_sdk=0` 时 `e9.i.b()` 收到 `-100`，三个 `if (i10==90/60/30 || z10)` 全部命中，最后一段用 `boost_frame_v3_30_60` 把已算出的 120/144 覆盖为 60。返回数组语义是 `{depress, target, gameFps}`（`e9/i.java:101`）。
2. **GameWatch 侧根本没发目标帧率**：`j0/l` 静态块要求 `sdk_version=nova` 且 displayic 版本前缀非 `NT72325/NT72326`；本机 `NT72326_IC2.0_V3.0` → 走旧分支，`x0()` 只发 `{10,-1,2,-1,gameId,depressFps}`。系统侧 `NovaUsecaseControllerV1.computeUsecaseForGame()` 只认 30→60 / 45→90 / 60→120 / 48,72→144，其余静默落 60Hz。

可信验收读回点：`Settings.System gamecube_memc_effective`（系统写入的生效帧率），不是 `gamecube_frame_interpolation`（请求值），也不是 `/sys/rsc/vgarph/MEMC`（能力回写）。

## 三、v0.2 模块（xposed-module/vivo-memc-v0.2.apk）

作用域：`com.vivo.gamecube`、`com.vivo.gamewatch`（GameSpace/GameTrain 不需要）。

| # | 类.方法 | 时机 | 改动 | 目的 |
|---|---|---|---|---|
| 1 | `android.util.FtFeature.isFeatureSupport(String)` | after | `game.memc/aisr` 返回 true | 免改 vendor ini、免重启 HAL |
| 2 | `com.vivo.gameassistant.utils.e0.p0(String)` | after | 返回 true | 游戏适配总闸 |
| 3 | `com.vivo.gameassistant.frameinterpolation.i.c(Context,String)` | after | 返回 60 | 原生帧率判定 |
| 4 | `e9.i.b(Context,int,int,int,FrameInterpolationState)` | after | BOOST 时返回 `{60,120,60}` | 绕开 30_60 覆盖 |
| 5 | `e0.a.o(int,int[])`（GameWatch） | before | 258 且 6 参且 `values[5]==60` 时补第 7 位 120 | 旧协议补目标帧率 |

构建：`bash xposed-module/build.sh`（javac + aapt2 + d8 + zipalign + apksigner，本地 API 桩只参与编译）。产物 12.7 KB，`versionCode=2`，`apksigner verify` 通过，dex 内含 `Lorg/dsh/vivomemc/HookMain;`。

## 四、安装与验证步骤（等设备接回后执行）

1. `adb install -r xposed-module/vivo-memc-v0.2.apk`
2. 打开 Vector 管理器（`org.matrix.vector.manager`）→ 模块列表启用“vivo 插帧注入”→ 作用域勾选 GameCube 与 GameWatch
3. `am force-stop com.vivo.gamecube; am force-stop com.vivo.gamewatch`（或重启手机）
4. 进《绝区零》开插帧，抓三处证据：
   - `adb logcat -s Xposed` / Vector 日志里的 `[VivoMemc]` 行
   - `settings get system gamecube_frame_interpolation`（应出现 target=120）
   - `settings get system gamecube_memc_effective`（应为 120 而非 0/60）
5. 若第 4 步 target 仍是 60，说明 `e9.i.b` hook 未命中（类加载器或方法签名不符），改用次选 `e9.k.b/c/d` 放行组合。

## 五、风险

- 模块是 app 进程内 hook：GameCube/GameWatch 崩溃只会影响游戏助手，不影响系统；Vector 里关掉模块或卸载即回退。
- 若 `e9.i.b` 返回的数组被下游当作“真实能力”，可能出现 UI 与实际不一致；以 `gamecube_memc_effective` 与画面为准。
- 系统侧 48→144 等组合仍受 `computeUsecaseForGame` 映射表限制，120 是唯一表内可命中项。
