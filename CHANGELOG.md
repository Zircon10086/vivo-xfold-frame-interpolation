# 更新日志

## v1.7.0

- **模块 id 改为 `vivo-xfold-frame-interpolation`**（开发期不保留旧 id；日志、备份目录、WebUI 路径同步更新）
- 新增 `customize.sh`：安装时按机型与影像芯片检测
  - X Fold2：通过（唯一已验证）
  - X Fold3 Pro / X Fold6：警告后继续（带 V3 / V3+，理论支持）
  - 无 V 芯片的 X Fold（Fold5 / Fold3 / Fold+ / Fold）：中止安装
  - 非 X Fold 机型、未知折叠机型：中止安装
  - 调试逃生门：`/data/local/tmp/vivo-xfold-force`
- README / 兼容性文档补充历代 X Fold 的芯片对照表与拦截理由

## v1.6.0

- 开源整理：仓库结构重排（`module/`、`docs/`、`scripts/`、`legacy/`），补 README、安装/使用/原理/兼容性/FAQ 文档，协议改为 AGPL-3.0
- 项目更名 `vivo-xfold-frame-interpolation`，明确只面向 vivo X Fold 系列，并注明仅 X Fold2 实测
- WebUI：新增面板/对话框/卡片入场动效
- WebUI：修复导入应用界面按返回键直接退出模块的问题（现在返回主页面）
- WebUI：移除每张应用卡片底部的重复提示
- 后端：导入时写齐三档所需的全部行（含 `optimize_power_v3_60_30_60`）

## v1.5.0

- 找到「优化功耗」第三档不显示的原因：缺少 `optimize_power_v3_60_30_60` 行
- 面板现在同时提供 关闭 / 提升帧率(60→120) / 优化功耗(30→60)
- 移除「自适应」档（`support_sdk=1` 时不按预期工作）
- 移除「省电插帧」开关与「视效增强」标签
- 界面精简为「导入应用 + 管理当前应用」

## v1.4.0

- 切档自动重启游戏助手
- 修复移除后导入面板状态不刷新、应用名显示为包名
- 导入面板默认隐藏系统应用
- 新增「恢复游戏魔盒初始设置」
- 档位选择改为页内分段按钮（修复原生 select 弹层错位）

## v1.3.0

- WebUI 改为导入式（导入任意已安装应用）
- 进入页面自动清理未安装的预置游戏行
- 所有写操作异步串行执行，不再阻塞界面
- 写库不再强停游戏助手（`sqlite3 .timeout`）

## v1.2.0

- 首个可用的 KernelSU WebUI（状态 + 预置游戏列表 + 档位/开关）
- 修复：模块文件 SELinux 上下文、脚本 CRLF

## v1.1.0

- 改为开机后 bind mount `vivo_config.ini` + 重启 HAL/zygote
- `game_dimen` 的 `game_index` 统一改为 9，修掉「生效但 depress 被归零」

## v1.0.0

- 首次打通 60→120 插帧
