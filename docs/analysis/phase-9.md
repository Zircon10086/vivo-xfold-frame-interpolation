# 阶段九：开源化、体验修补与安装检测（v1.6 → v1.7）

## 1. 仓库化

- 目录重排为 `module/ docs/ scripts/ legacy/ dist/`
- 逆向产物（apks / decompiled / smali / fw / tools）移出仓库，放在同级的 `*-vendor/` 目录
- 协议定为 AGPL-3.0，补 README、CHANGELOG 与五篇文档
- 项目改名 `vivo-xfold-frame-interpolation`，范围收敛到 vivo X Fold 系列

## 2. WebUI 体验

| 问题 | 处理 |
|---|---|
| 导入面板按返回键直接退出模块 | 打开面板时 `history.pushState` 压历史，`popstate` 关面板；实测返回键回到主页面，WebUIActivity 不退出 |
| 无过场动画 | 面板底部滑入 + 淡入、对话框缩放、卡片/候选项上浮；`prefers-reduced-motion` 兜底 |
| 卡片底部提示与页面提示重复 | 删除卡片内提示 |

## 3. 模块 id 与安装检测

- id 改为 `vivo-xfold-frame-interpolation`（开发期不保留旧 id），设备上走 `ksud module uninstall` + `install` 重装
- 新增 `customize.sh`，安装时按设备型号（V 编号）判断是否带独立 V 系列影像芯片：

| 机型 | 设备型号 | 芯片 | 行为 |
|---|---|---|---|
| X Fold2 | V2266A | V2 | 通过（唯一实测）|
| X Fold3 Pro | V2337A | V3 | 警告后继续 |
| X Fold6 | V2545A | V3+ | 警告后继续 |
| X Fold5 / X Fold3 / X Fold+ / X Fold | V2436A / V2303A / V2229A / V2178A | 无 | 中止安装 |
| 其他 | — | — | 中止安装 |

- `scripts/test-customize.sh` 用环境变量模拟 11 种机型，覆盖型号判定与「仅设备代号」兜底
- 真机验证日志：

```
 vivo X Fold 插帧解锁 · 安装前设备检测
 型号: V2266A
 设备: PD2266
√ 检测到 X Fold2（影像芯片 V2），这是本模块唯一完整验证过的机型
```

## 4. 踩到的坑

- `ksud module install` 把 `system/vendor` 重排到模块根的 `vendor/`，但 `system/vendor/etc/vivo_config.ini` 仍保留，
  service.sh 的源路径无需修改；重启后模块目录才从 `modules_update/` 合并到 `modules/`。
- 安装器执行完会删掉 `customize.sh`，所以更新检测逻辑必须重新打包安装，不能只改设备上的文件。
