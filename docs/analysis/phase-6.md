# 阶段六：v0.3 注入模块（60→120 档闭环）

> **后续（2026-11-26）**：本阶段的 Xposed 模块方案在真机上未成立（Vector 不注入模块类），最终跑通的路径见 [phase-7.md](phase-7.md)：KernelSU 模块做能力声明 + `game_dimen` 用 `game_index=9` 并删掉 30_60/60_48_144。本文的代码分析仍然有效，可直接用于理解 phase-7 的链路。


上一轮（阶段五）停在「系统侧第 7 位到底是什么、补位是否有效」这个未验证点上。本轮把这一段全部核到源码与 smali，改了模块，并给出了可复现的本地校验。

## 一、事实（逐条带证据）

### 1. 系统侧 258 报文的字段布局与分支

`fw/src-services/sources/com/android/server/display/color/displayenhance/NovaUsecaseControllerV1.java:2347-2399`：

- `case 258` 先看 `LcmFeature.mSupportNovaMemcAcqFpsV1`。
  - 该分支（Nova）：`count>=7` 时 `[0..3]`=pid/flags、`[4]=mGameMemcFps`、`[5]=mGameMemcDfps`、`[6]=mGameMemcTargetFps`，`count==8` 再取 `[7]=mGameAccquireFps`（:2358-2368）。
  - 非 Nova 分支：`count>=7` 时 `[5]=mGameMemcFps`、`[6]=mGameMemcTargetFps`；`count==6` 只取 `[5]=mGameMemcFps`，目标帧率留 0（:2373-2378）。
- `LcmFeature.java:432`：`mSupportNovaMemcAcqFpsV1 = isFeatureSupport("vivo.hardware.game.memc") && "frw_nova".equals(getFeatureAttribute(...,"acquire_fps_place","false"))`。本机 ini 无该键 → 走非 Nova 分支，即 **6 参只有 memcFps、7 参才有目标帧率**。

结论：阶段五设想的「补第 7 位 = 目标帧率」在非 Nova 分支成立，且索引 6 正确。

### 2. 目标帧率/降帧口径如何决定 IC 用例

`NovaUsecaseControllerV1.java:826-841`（`computeUsecaseForGame`）的判定顺序：

```
memcFps==30 || target==60   → 60993 (60Hz)
memcFps==45 || target==90   → 60994 (90Hz)
memcFps==60 || target==120  → 60995 (120Hz)
memcFps==48 || target==144 || memcFps==72 || target==144 → 60996 (144Hz)
其余                         → 60993 (60Hz)
```

因此 **有两种独立达成 120 的方式**：`memcFps==60`，或 `target==120`。前者不需要补位，只要请求真的把 60 送下去；后者靠补位兜底（当 GameWatch 把 depress 归零时）。

### 3. GameWatch 侧的 6 参报文是硬编码的

`decompiled/com.vivo.gamewatch/sources/j0/l.java:872-880`（`n0()`，旧 x0 合并进来）：

```java
if (!f3110b0) {
    if (!f3114f0) {                       // 本机：两个都为 false
        e0.a.h().o(258, new int[]{10, -1, 2, -1, cVar.f3152b, cVar.f3154d});
        return;                            // 目标帧率 cVar.f3155e 被丢弃
    }
    ... o(258, new int[]{10,-1,2,-1,cVar.f3152b,cVar.f3154d,i5});  // latency_opt 才有 7 参
}
```

- `f3110b0 = f3113e0 || f3115g0`，`j0/l.java:301-336`：`f3113e0` 要求 sdk_version=="nova" 且显示 IC 前缀不是 NT72325/72326；本机 `NT72326_IC2.0_V3.0` → false。`f3115g0` 要求 `acquire_fps_place=="frw_nova"`。两者皆 false。
- `f3114f0` = `latency_opt=="true"`，ini 未写 → false。
- `e0/a.java:1042-1076`（`o(int,int[])`）：`setDisplayEnhanceConfigure(type, iArr, iArr.length)` —— **count 取自数组长度**，所以 hook 里换成 7 元素数组后系统真的会按 7 参解析。
- `e0/a.java:24,124-130`：`f2044j`（8 参 Q3/Q4 路径）要求显示 IC 串含 `DPIC1.0_Q3.0/Q4.0`，本机不命中，确认走 `o()` 而非 `b()`。

### 4. 请求字符串的格式与 scene 字段

- 解析端 `j0/l.java:169-171`：`gamecube_frame_interpolation` 按 `:` 切成 `(open, scene, pid, depress, target)` 五段填 `c`。
- 写入端 `j0/l.java` 对应 `com/vivo/common/utils/l0.java:b()`（GameCube 侧唯一写入者）：字符串为 `open:gameIndex:pid:depress:target`。
- 阶段四真机读到的 `1:3:8591:48:60` 即 `open=1, gameIndex=3（借自原神）, pid=8591, depress=48, target=60`；GameWatch 把 `gameIndex=3` 当 `scene` 用。
- `j0/l.java:1051-1104`（`Y()`）：`scene` 为 3 时落到末尾默认分支 `return true`（:1082），这就是「借壳 game_index=3 后链路能跑通」的机制性原因，与「GameWatch 认识该游戏」无关。

### 5. 「最大可提升至 60 帧」的准确来源

`decompiled/com.vivo.gamecube/sources/com/vivo/gameassistant/frameinterpolation/frameinterstrategy/FrameInterViewV3.java:360-426`：

```java
int i10 = (state == BOOST_FRAME) ? 120 : 90;      // 传入的目标帧率
int iC  = this.f18685a ? i.e().c(ctx, pkg) : -100; // 无 sdk → -100
int[] iArrB = this.D.b(ctx, iC, this.f18687c, i10, state);  // → e9.h.d → e9.i.b
... tip = bottom_tip_no_sdk_new.format(iArrB[1])            // 用返回数组的 [1]
```

`e9/i.java:26-91`（`b()`）在 `i10 == -100` 时三段 `if` 顺序执行：90 段、60 段、**30 段最后跑**。30 段是 `i12 = k.c(str) ? 60 : k.b(str) ? 120 : i12`：

- 阶段三/四往 `game_dimen` 写的是 `boost_frame_v3_30_60`（`e9.k.c`）而**没有** `boost_frame_v3_30_120`（`e9.k.b`），所以 30 段把已经算出的 120 覆盖成 60 —— 这既是「最大 60」文案的来源，也是实际下发 48/60 的来源。
- 反过来，只要 `k.c=false` 且 `k.b=true`，同一条调用链就会返回 `{60,120,30}`，请求变成 `60:120`。

这条把阶段四「可能是每游戏参数表缺失」的推断收紧成：**缺的是 `30_120` 这一条能力位，而多写了 `30_60`**。

### 6. 写请求的最终落点

`com/vivo/gameassistant/frameinterpolation/i.java:162-165`：

```java
public void h(int i10, int i11, int i12, int i13) {
    p0.f("FrameInterpolationHelper", "interpolateFrame: gameIndex=..., gamePid=..., depressFps=..., targetFps=...");
    l0.b(AssistantUIService.f17925f, true, i10, i11, i12, i13);
}
```

`e9/h.java:163-190`（`l()`）先取 `iArrD = d(...)`（→ `e9.i.b`）覆盖 `i14/i13`，再调 `i.e().h(gameIndex, pid, i14, i13)`。所以 hook `e9.i.b` 与 hook `l0.b` 是两个等效的收口点。

## 二、v0.3 模块（xposed-module/vivo-memc-v0.3.apk）

作用域：`com.vivo.gamecube`（含 `:assistantui`）、`com.vivo.gamewatch`。

| # | 类.方法 | 时机 | 行为 | 目的 |
|---|---|---|---|---|
| 1 | `android.util.FtFeature.isFeatureSupport(String)` | after | `vivo.hardware.game.memc/aisr` → true | 免改 vendor ini 的能力位 |
| 2 | `com.vivo.gameassistant.utils.e0.p0(String)` | after | 恒 true | 游戏适配总闸 |
| 3 | `com.vivo.gameassistant.frameinterpolation.i.c(Context,String)` | after | 恒 60 | 原生帧率判定（`h.i1` 的「需高帧率」提示） |
| 4 | `e9.i.b(Context,int,int,int,FrameInterpolationState)` | after | `BOOST_FRAME` → `{60,120,60}` | 直接给出 60→120 口径，绕开 `-100` 三段覆盖 |
| 5 | `e9.k.b/c/d/f(String)` | after | b=true, c=false, d=true, f=false | 放行 `30_120`/`60_120`，关掉 `30_60`、`60_48_144`（面板 120Hz，144 不可用） |
| 6 | `com.vivo.common.utils.l0.b(Context,Z,I,I,I,I)` | before | 启用且 target≥100 时钉成 `depress=60,target=120` | 唯一 Settings 写入点的兜底 |
| 7 | `e0.a.o(int,int[])`（GameWatch） | before | 6 参 258 报文补第 7 位：30→60、45→90、60→120、48/72→（60,120） | 非 Nova 分支补目标帧率 |
| 8 | `j0.l.Y(int,int,l$c)` / `j0.l.N(l$c)` | after | 只打日志 | 真机定位闸门，不改行为 |

第 5 条是「文案也变 120」的关键：`FrameInterViewV3.setBottomTip` 用的正是 `e9.i.b` 的返回值，能力位一变，文案与请求同时变成 120。

### 本地校验（已跑）

```
python scripts/check_hooks.py     → PASSED: 12 个 hook 目标签名全部命中
bash xposed-module/build.sh       → vivo-memc-v0.3.apk，versionCode=3 / versionName=0.3
apksigner verify --verbose        → Verifies（v2 + v3 签名；v1 false）
dexdump                           → HookMain + 9 个回调类都在 classes.dex
```

注意：`j0.l` 的内部类在运行时叫 `j0.l$c`（jadx 输出成 `j0/c.java`），v0.2 的 `Class.forName("j0.c")` 会失败；v0.3 已改。

## 三、真机验证步骤（设备接回后）

1. `bash scripts/install_xposed_module.sh`（安装 + 推取证脚本 + 打印后续手点步骤）
2. Vector 管理器启用模块，作用域勾 GameCube / GameWatch，强停两个进程或重启
3. 进《绝区零》→ 侧栏「游戏插帧」→ 提升帧率档
4. `adb shell sh /data/local/tmp/verify_memc.sh`，判据：
   - `gamecube_frame_interpolation` = `1:<index>:<pid>:60:120`
   - logcat `FrameInterpolationHelper: interpolateFrame: gameIndex=…, gamePid=…, depressFps=60, targetFps=120`
   - logcat `IrisUtils: Command for putting is: 1:…:60:120`
   - `gamecube_memc_effective` = 120（系统写入的生效值，不是请求值）
   - `[VivoMemc]` 行确认 7 个 hook 全部装上、`payload -> [10,-1,2,-1,…,60,120]`
5. 若仍显示 60：先看 `[VivoMemc] e9.i.b state=… result=…` 是否有输出。没有输出说明 hook 未命中（类加载器/进程问题）；有输出但 result 仍 60 说明第 5 条没生效。

### 不做模块时的等价改法（备选，不需要 LSPosed）

如果只想验证代码结论，可以直接改数据库：把《绝区零》的 `boost_frame_v3_30_60` 换成 `boost_frame_v3_30_120`（保留 `60_120`、`60_45_90`，删掉 `60_48_144`），然后强停 GameCube。这样 `e9.i.b` 自己就会算出 60:120 —— 但 GameWatch 侧 `N()` 若把 depress 归零，报文就退化成 `{…,0}`（60Hz），所以**只有模块的第 6、7 条能兜住这条**。

## 四、未知与风险

- 未确认：`j0.l.N(c)` 在本机（measured 60、depress 60）走 `V(c)` 的取值。若为 false，depress 会被归零 —— 这正是第 7 条补位必须存在的原因；第 8 条日志就是为它准备的。
- 未确认：`modeshift`（monster+/超能模式）在 `e9.h.l:169-172` 会用另一组帧率对覆盖（`frameinterpolation.i.e().f()`），该覆盖发生在 `e9.i.b` 之后、写入之前。若用户开这些模式仍看到 48/144，需要再加一条针对 `f()` 的 hook。
- 未确认：`e9.k` 的缓存 map 会记录真实能力值，我们只覆盖返回值，未清缓存 —— 不影响结论（每次调用都被覆盖），但会让「关模块后立即恢复」依赖进程重启。
- 风险：第 6 条把 `l0.b` 的 `target≥100` 一律钉成 60:120，若以后机型/固件支持 144，这个钉死会限制到 120。当前面板 120Hz，符合预期。
- 回退：Vector 里关模块（或卸载 APK）+ 强停 GameCube/GameWatch 即完全还原；模块不改任何系统文件。

## 五、模块以外仍留在设备上的东西（来自阶段三/四，未清理）

- 运行期 bind mount `/vendor/etc/vivo_config.ini`（重启即消失）
- `support_dimension_list.db` 里 `com.miHoYo.Nap` 的 `game_dimen` 行（6 条，`game_index=3`）
- `game_cube_assistantui.xml` 里两条 `sp_game_fps_*` 映射
- 若改用备选改法，需要把 `boost_frame_v3_30_60` 换成 `boost_frame_v3_30_120`
