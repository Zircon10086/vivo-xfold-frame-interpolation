# vivo-memc（Xposed / LSPosed 模块）

> **状态（2026-11-26 真机实测）**：本模块在这台 PD2266 上**不生效**。Vector 2.2 把它列为「运行中」、作用域也对，但目标进程里没有任何模块日志，连只打 `android.util.Log` 的最小探测器（`diagnostics/xp-canary`）也加载不进来 —— 是框架侧没把模块类注入进程，不是本模块的 hook 写错。设备上的模块已禁用。
>
> 已跑通的方案不走 LSPosed：见 [reports/phase-7.md](../reports/phase-7.md)（KernelSU 模块 + `game_dimen` 行修正）。本目录保留作代码存档与后续（换框架/修好 Vector 后）复用。


给 PD2266（vivo X Fold 2）的 GameCube 补上「60 → 120」插帧档位的能力位与报文。

- 设计依据与证据链：[../reports/phase-6.md](../reports/phase-6.md)
- 三个子代理的原始逆向：[../reports/agents/gamecube.md](../reports/agents/gamecube.md)、[gamewatch.md](../reports/agents/gamewatch.md)、[gamespace-train.md](../reports/agents/gamespace-train.md)

## 作用域

- `com.vivo.gamecube`（含 `:assistantui` 进程）
- `com.vivo.gamewatch`

GameSpace / GameTrain 不需要（阶段五结论：两包不参与插帧键读写）。

## 构建

```bash
bash xposed-module/build.sh
```

javac + aapt2 + d8 + zipalign + apksigner，只用本机 xfold-2-unlock 里的 SDK（API 37 平台 jar、build-tools 37.0.0），`stubs/` 里是编译用的 Xposed API 最小桩。产物 `vivo-memc-v0.3.apk`（约 12.7 KB）。

## 装之前先自检

```bash
python scripts/check_hooks.py
```

12 条 hook 目标逐个在 smali 里精确匹配签名。任何一条 NOT FOUND 都不要装 —— 装了也只会得到一行 `hook xxx failed`。

## 安装

```bash
bash scripts/install_xposed_module.sh [设备序列号]
```

然后手动：Vector 管理器 → 启用模块 → 作用域勾上面两个包 → 强停两个应用（或重启）。

## 验证

```bash
adb shell sh /data/local/tmp/verify_memc.sh
```

期望：`gamecube_frame_interpolation` = `1:<index>:<pid>:60:120`，`gamecube_memc_effective` = 120，logcat 里有 `FrameInterpolationHelper: … depressFps=60, targetFps=120` 与 `[VivoMemc]` 的 hook 装载行。

## 回退

Vector 里关掉模块，或 `adb uninstall org.dsh.vivomemc`，再强停 GameCube/GameWatch。模块不写系统文件、不改配置，回退是干净的。

## 版本

- v0.1：只有 FtFeature / e0.p0 / i.c 三条能力位。
- v0.2：加了 `e9.i.b` 的 BOOST 覆盖与 GameWatch 的 6→7 参补位；`j0.c` 类名写错（应为 `j0.l$c`）。
- v0.3：补 `e9.k` 能力位（放行 30_120/60_120、关掉 30_60 与 60_48_144）、`l0.b` 写入点兜底、`j0.l$c` 修正、Y/N 诊断日志。
