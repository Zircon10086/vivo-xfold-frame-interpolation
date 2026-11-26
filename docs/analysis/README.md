# 逆向分析记录

按时间顺序记录「怎么找到这条链路的」，保留失败方向与判据，方便后人少走弯路。

| 文件 | 内容 |
|---|---|
| [phase-1.md](phase-1.md) | 环境侦察：设备、系统、可用工具、APK 清单 |
| [phase-2.md](phase-2.md) | 定位插帧相关 APK 与关键字符串 |
| [phase-3.md](phase-3.md) | `game_dimen` 表结构与白名单逻辑 |
| [phase-4.md](phase-4.md) | 请求串格式与 `game_index` 的作用 |
| [phase-5.md](phase-5.md) | 早期方案（Xposed hook）与失败结论 |
| [phase-6.md](phase-6.md) | 属性声明路线：`vivo.hardware.game.memc` |
| [phase-7.md](phase-7.md) | 60→120 全链路验证（含 6/7 参 payload） |
| [phase-8.md](phase-8.md) | KernelSU WebUI：设计、踩坑、三档面板、版本演进 |

证据截图在 [evidence/](evidence/)。

> 说明：这些记录包含类名、方法名与行号，用于解释实现原理；仓库不含任何 vivo 二进制或反编译产物。
