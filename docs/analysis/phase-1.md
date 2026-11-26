# vivo X Fold2 游戏插帧：第一轮只读取证

**结论：已找到插帧请求接口，并确认 GameCube 和 GameWatch 都包含相应代码；未证实这台机器可启用游戏插帧。** 请求值不是硬件能力开关。第一轮没有写入手机设置、安装 APK、修改分区、重启手机或使用 root。

## 样本与反编译

真机为 V2266A / PD2266，OriginOS 6 / Android 16，构建 `PD2266_A_16.3.18.1.W10.V000L1`，安全补丁 `2026-09-01`。设备包管理器对这四包各返回一个 APK，无分包。四个 APK 的设备端与本机 SHA-256 逐一一致，ZIP CRC 检查通过。原件共 119,491,537 字节（113.96 MiB），包含 10 个 DEX。完整设备路径、版本和摘要在 [APK 清单](apk-inventory.json)。

| APK | 版本 | DEX | JADX Java 文件 | JADX 资源文件 | JADX 报错数 |
|---|---|---:|---:|---:|---:|
| [GameCube](../apks/com.vivo.gamecube/GameCube.apk) | 14.0.13.02_de | 3 | 9,077 | 5,140 | [118](jadx-com.vivo.gamecube.log#L2653) |
| [vivogamespace](../apks/com.vivo.gamespace/vivogamespace.apk) | 1.0.4.3 | 5 | 12,022 | 5,832 | [106](jadx-com.vivo.gamespace.log#L3699) |
| [GameTraining](../apks/com.vivo.gametrain/GameTraining.apk) | 2.0.1.2 | 1 | 2,286 | 474 | [14](jadx-com.vivo.gametrain.log#L974) |
| [GameWatch](../apks/com.vivo.gamewatch/GameWatch.apk) | 25.0.0.07 | 1 | 1,355 | 22 | [15](jadx-com.vivo.gamewatch.log#L367) |

JADX 1.5.7 四包均有可读输出，四次退出码都是 3，详见 [运行结果](jadx-result.json)。生成的是重建 Java，并非厂商原始源码，也不保证可直接编译。关键类额外用发布包内的 baksmali 对原 APK 的 DEX 反汇编，保留指令偏移。JADX ZIP 与 [官方发布 API](https://api.github.com/repos/skylot/jadx/releases/latest) 公示的 SHA-256 `1755e4242ade71a077438723689f404079592ec7764a3a0572f98fef94ebcbf3` 一致。

## 已证实的调用链

1. **入口能力与游戏适配是两层判定。** GameCube 的 [e0.p0](../decompiled/com.vivo.gamecube/sources/com/vivo/gameassistant/utils/e0.java#L1738) 先调用 [W0](../decompiled/com.vivo.gamecube/sources/com/vivo/common/a.java#L1011) 查询 `FtFeature.isFeatureSupport("vivo.hardware.game.memc")`，通过后才由当前插帧策略查询游戏支持。相关分支和特征名分别在 [e0.smali](smali/gamecube/com/vivo/gameassistant/utils/e0.smali#L10428) 与 [a.smali](smali/gamecube/com/vivo/common/a.smali#L6926) 复核。GameCube 资源表有 [插帧菜单标题](gamecube-resources.txt#L50941)，但资源存在不能证明入口在本机显示。
2. **请求由 GameCube 写出、GameWatch 观察。** GameCube 的 [FrameInterpolationHelper](../decompiled/com.vivo.gamecube/sources/com/vivo/gameassistant/frameinterpolation/i.java#L163) 将状态、游戏索引、进程 ID、降帧与目标帧率传给 [IrisUtils](../decompiled/com.vivo.gamecube/sources/com/vivo/common/utils/l0.java#L35)，写至 `Settings.System` 的 `gamecube_frame_interpolation`；[原始 Smali](smali/gamecube/com/vivo/common/utils/l0.smali#L235) 确认这次写入。GameWatch 的 [InterpolatedFpsAdjuster](../decompiled/com.vivo.gamewatch/sources/j0/l.java#L247) 观察并读回该键及超分相关请求；[观察者 Smali](smali/gamewatch/j0/l%24a.smali#L661) 已复核。GameWatch 另有[每款游戏/帧率档位配置](../decompiled/com.vivo.gamewatch/sources/h0/e.java#L38)；本轮未证明该配置读取与上述观察器在本机每一条分支中的具体关系。
3. **固件里有显示链路，但尚不能归因于某一道门控。** [真机快照](device-display-probe.txt) 显示 `persist.vivo.displayic.ver=NT72326_IC2.0_V3.0`、插帧请求 `0:-1:0:0:0`，以及已注册的 `gamewatch_server`、`vivo_display_enhance`、`vivo_gfx_display_service`。GameWatch [有一段分支](../decompiled/com.vivo.gamewatch/sources/j0/l.java#L308) 专门区分 `NT72325`/`NT72326`，但这是特定 `nova` 分支的条件，不是全局禁用断言。当前请求值与 GameCube 的 [清除请求路径](../decompiled/com.vivo.gamecube/sources/com/vivo/common/utils/l0.java#L71) 一致，不代表该功能不可用，也不能证明手动填入请求就会生效。
4. **未找到 PD2266 的同类静态配置。** GameCube 的 [XML 解析器](../decompiled/com.vivo.gamecube/sources/g7/a.java#L206) 查找随包或 `/system/etc/gamecube`、`/oem/etc/gamecube` 的配置；真机 shell 对这两个目录返回不存在。GameCube APK 按配置文件名只匹配到 [PD2301 样本](../decompiled/com.vivo.gamecube/resources/assets/PD2301/FrameInterConfigList.xml)，不等于运行时没有其他配置来源。本机的 [vivo_displayic_policy.xml](vivo_displayic_policy.xml) 与设备端哈希一致，其中 13 个包名是相机、视频和测试应用等；不是这里找到的游戏插帧配置表。对 `/sys/rsc/vgarph/MEMC` 的普通 shell 查询返回权限不足，不能据此判定节点不存在或其值为 0。

## 下一步和验收

待确认的是：本机 vivo 框架的 `FtFeature` 实际返回值、**指定游戏**使用的运行时配置来源，以及显示后端是否有适配内屏或外屏的路径。建议先拿一台实际可开插帧的 iQOO 11 做同游戏对照，尽量对齐 OriginOS 大版本和游戏版本，比较能力标志、实际游戏配置和运行结果。没有对照机时，先补查 X Fold2 的能力配置读取链路，再考虑是否有必要做任何设置实验。不把菜单出现、读回请求值、面板切到 120 Hz 或 FPS 悬浮窗数字当作插帧成功。要判定生效，应让游戏保持同一原生帧率与场景，配合同一屏幕上的高速录像或可区分应用提交帧与实际显示帧的显示侧统计做 A/B。

公开资料：[X Fold2 发布稿确认搭载 V2](https://m.vivo.com.cn/brand/news/detail?id=1144&type=3)、[X Fold2 官方规格确认内外屏最高 120 Hz](https://www.vivo.com.cn/vivo/param/xfold2)、[iQOO 11 发布稿明确说明 V2 与 GPU 协同插帧](https://www.vivo.com.cn/brand/news/detail?id=1115)。同名芯片支持进一步对照，不能证明两个机型的显示链路、固件和游戏适配相同。
