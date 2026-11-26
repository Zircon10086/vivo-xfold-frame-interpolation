# vivo-xfold-frame-interpolation

[![Release](https://img.shields.io/github/v/release/Zircon10086/vivo-xfold-frame-interpolation?label=release)](https://github.com/Zircon10086/vivo-xfold-frame-interpolation/releases)
[![License](https://img.shields.io/github/license/Zircon10086/vivo-xfold-frame-interpolation?label=license)](LICENSE)
[![Build](https://github.com/Zircon10086/vivo-xfold-frame-interpolation/actions/workflows/release.yml/badge.svg)](https://github.com/Zircon10086/vivo-xfold-frame-interpolation/actions/workflows/release.yml)

**给 vivo X Fold 系列补上游戏帧率插值（MEMC）能力的 KernelSU 模块。**

vivo 的 X Fold 折叠屏机型在系统里保留了显示芯片的插帧（MEMC）能力，但游戏魔盒的启用名单被裁剪，普通用户无法为任意应用打开插帧。
本模块在开机后向系统声明 `[vivo.hardware.game.memc]` 能力，并配合游戏魔盒的 `game_dimen` 配置表，让任意已安装应用都能在游戏侧栏里获得：

- **关闭**
- **提升帧率（60 → 120）**
- **优化功耗（30 → 60）**

> 已验证机型：**vivo X Fold2（PD2266 / V2266A，OriginOS 6 / Android 16）**。
> 其他 X Fold 机型仅理论上适用，请自行测试；非 X Fold 直板机多数原生开放插帧，通常不需要本模块。

---

## 适用范围

本模块**只对带独立 V 系列影像芯片的 X Fold 机型**有意义：图像插值（MEMC）走的就是这颗协处理器的通路，
没有它的机型硬件层面就不存在插帧能力。安装时 `customize.sh` 会自动检测并拦截。

| 机型 | 设备型号 | 影像芯片 | 模块支持 |
|---|---|---|---|
| vivo X Fold6 | V2545A | **V3+**（蓝图影像芯片） | ⚠️ 理论支持，未验证（安装时警告）|
| vivo X Fold5 | V2436A | 无独立 V 芯片 | ⛔ 拒绝安装 |
| vivo X Fold3 Pro | V2337A | **V3**（自研影像芯片） | ⚠️ 理论支持，未验证（安装时警告）|
| vivo X Fold3 | V2303A | 无独立 V 芯片 | ⛔ 拒绝安装 |
| **vivo X Fold2** | **V2266A** | **V2**（自研芯片） | ✅ 实测通过（设备代号 PD2266）|
| vivo X Fold+ | V2229A | 无独立 V 芯片 | ⛔ 拒绝安装 |
| vivo X Fold | V2178A | 无独立 V 芯片 | ⛔ 拒绝安装 |
| vivo X100 等直板机 | — | 有 V 芯片，但系统未限制 | ⛔ 不需要：出厂即开放游戏插帧 |

**为什么要拦掉没有 V 芯片的机型？**
X Fold5 / X Fold3 / X Fold+ / X Fold 这一代没有独立影像芯片，插帧能力由主 SoC 或软件路径承担，
本模块写入的 `game_dimen` 行与 `vivo_config.ini` 声明在这些机型上既不会出现侧栏入口，也可能触发
GameCube 的异常状态，所以直接拒绝，避免用户白折腾。

**检测逻辑**（`module/customize.sh`，安装时由 KernelSU 执行）：

| 检测结果 | 行为 |
|---|---|
| X Fold2（V2266A / PD2266） | 通过，提示「唯一完整验证过的机型」|
| X Fold3 Pro（V2337A / PD2337）、X Fold6（V2545A / PD2507） | **警告后继续安装**（理论支持）|
| X Fold5（V2436A）、X Fold3（V2303A）、X Fold+（V2229A）、X Fold（V2178A） | **中止安装**，提示该机型无独立 V 芯片 |
| 非 X Fold 机型 | **中止安装**，提示直板机原生开放插帧 |
| 未知 X Fold 机型（名字里带 fold 但不在白名单） | **中止安装**，提示确认机型 |

调试逃生门：设备上存在 `/data/local/tmp/vivo-xfold-force` 时，任何机型都会带警告放行（自担风险）。

---|---|
| vivo X Fold2 | ✅ 实测通过（本项目全部证据来自该机型） |
| vivo X Fold / X Fold+ / X Fold3 / X Fold3 Pro / X Fold5 | ⚠️ 理论适用，未验证：依赖 `vivo.hardware.game.memc` 属性与 `com.vivo.gamecube` 的数据库结构是否同构 |
| vivo X100 等直板机 | ⛔ 不需要：出厂即开放游戏插帧，用系统自带开关即可 |
| 其他品牌 | ⛔ 不适用 |

判定依据（反编译 `com.vivo.gamecube` 得到）：X Fold 系列把插帧能力声明做成 HAL 属性，`GameWatch` 只在属性存在时才允许下发 MEMC 请求；直板机的同一属性默认开启。

---

## 原理（一图流）

```
KernelSU 模块（开机后，等 sys.boot_completed + 15s）
   └─ bind mount 一份声明了 [vivo.hardware.game.memc] 的 vivo_config.ini
       到 /vendor/etc/vivo_config.ini
   └─ 重启 vivo-configstore-hal / zygote     ← 让属性生效
游戏魔盒（com.vivo.gamecube）
   └─ 读取 game_dimen 表：某个应用是否有 boost_frame / optimize_power 等行
   └─ 有 → 游戏侧栏出现「游戏插帧」，三档可选
   └─ 选档 → 写 settings: gamecube_frame_interpolation = 1:9:<pid>:<depress>:<target>
系统（NovaUsecaseControllerV1 / GameWatch）
   └─ depress=60,target=120 → 把游戏渲染压到 60 并插帧到 120
```

详细链路（含类名、行号、字段含义）见 [docs/how-it-works.md](docs/how-it-works.md)。

---

## 快速开始

前置条件：

- 已 root（本模块在 **KernelSU / ReSukiSU** 上开发验证；Magisk 未测试）
- OriginOS 6 / Android 16（X Fold2 的 `PD2266_A_16.3.18.1.W10.V000L1` 为验证版本）
- 关闭「游戏魔盒」的省电策略，保证它能常驻

安装：

1. 从 Releases 下载 `vivo-xfold-frame-interpolation-vX.Y.Z.zip`，或本地运行 `scripts/build-module.sh` 自行打包（产物在 `dist/`）
2. KernelSU 管理器 → 模块 → 从本地安装 → 选择 zip
3. 重启手机。**开机会多一次 zygote 重启，约 30 秒**，属正常现象
4. 进入 KernelSU 模块列表，点本模块卡片左下角的按钮打开 WebUI

使用：

1. WebUI 里点「导入应用」，搜索并导入你想插帧的应用（默认只列用户应用，可勾选显示系统应用）
2. 打开该应用，从屏幕左边缘上部滑出游戏侧栏 → 游戏工具 → 滚动到底 → **游戏插帧**
3. 三档任选：关闭 / 提升帧率 / 优化功耗。切换后立即生效

卸载：

- KernelSU 里停用或删除模块，重启即恢复原状（`/vendor/etc/vivo_config.ini` 的 bind mount 随重启消失）
- 若想连游戏魔盒的应用名单一起恢复：WebUI 里点「恢复游戏魔盒初始设置」

---

## 已验证 / 未验证

已验证（X Fold2）：

- 绝区零、原神、崩坏：星穹铁道、bilibili、相机：插帧生效
- 三档面板同时显示，实际请求值分别为 `60:120` / `30:60`
- WebUI：导入/移除/清理未安装应用/恢复魔盒设置

未验证：

- 其他 X Fold 机型（参数、数据库表、GameCube 版本都可能不同）
- 高帧率游戏（90/144Hz 档位未打通，`48/72→144` 在 120Hz 面板上无意义）
- Magisk 环境
- 超分（`super_resolution`）入口：本机型/游戏没有出现，未启用

---

## 目录结构

```
module/            KernelSU 模块本体（可直接打包刷入）
  bin/vivo-memc.sh   后端：状态/导入/移除/清理/档位
  webroot/           KernelSU WebUI（原生 JS，无依赖）
  system/            需要 bind mount 的 vivo_config.ini 等
docs/              安装、使用、原理、兼容性、FAQ
docs/analysis/     逆向过程记录（phase-1 ~ phase-9）
scripts/           构建与真机辅助脚本
legacy/            早期 LSPosed 实验（已废弃，保留供参考）
dist/              构建产物
```

---

## 构建

```bash
./scripts/build-module.sh          # 产物：dist/vivo-xfold-frame-interpolation-v<version>.zip
./scripts/test-customize.sh        # 用环境变量模拟各机型，验证安装检测分支
```

WebUI 是纯静态文件，改完直接重新部署即可（不需要编译）。

## 安装时检测

`module/customize.sh` 在 KernelSU 安装阶段执行（`ksud module install` 或管理器里选 zip 都会跑），
通过 `ro.product.vendor.model`（V 编号，权威）与 `ro.product.vendor.device`（PD 代号，兜底）判断机型与影像芯片，输出：

```
----------------------------------------------------------------
 vivo X Fold 插帧解锁 · 安装前设备检测
 型号: V2266A
 设备: PD2266
 市场名: 未知
----------------------------------------------------------------
√ 检测到 X Fold2（影像芯片 V2），这是本模块唯一完整验证过的机型
----------------------------------------------------------------
```

规则见上方「适用范围」表格。临时绕过：`touch /data/local/tmp/vivo-xfold-force` 后重装。

---

## 风险与免责

- 本模块修改的是**游戏魔盒的配置数据库**与 `vivo_config.ini` 的挂载，属于系统级改动。刷入前请确认你能接受「开不了机就重刷系统包」的风险。
- 写数据库前会自动备份到 `/data/local/tmp/vivo-xfold-backup/`；但「恢复游戏魔盒初始设置」会清空游戏魔盒数据，操作前请确认。
- 不要在 `post-fs-data.sh` 里挂 `/vendor`：本机实测会导致 init SIGABRT、卡开机 logo（这也是本项目早期的一个坑）。
- 仅供个人学习与自用，请遵守你所在地区的法律与厂商条款。因使用本模块造成的数据丢失、保修失效等问题由使用者自行承担。

---

## 协议

本项目以 **AGPL-3.0** 发布，全文见 [LICENSE](LICENSE)。

简单说：你可以自由使用、修改、分发；如果你修改后以网络服务形式提供，必须公开修改后的源码。

---

## 商标声明

vivo、X Fold、OriginOS、iQOO 等是维沃移动通信有限公司的商标。本项目为第三方非官方项目，与 vivo 无任何关联，未获得其授权或背书。

本项目**不包含**任何 vivo 私有二进制或反编译产物；仓库中的 `docs/analysis` 仅记录分析结论与类名/字段名，用于说明实现原理。
