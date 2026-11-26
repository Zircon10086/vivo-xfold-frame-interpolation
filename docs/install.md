# 安装

## 前置条件

| 项 | 要求 |
|---|---|
| Root 方案 | KernelSU（本项目在 ReSukiSU 4.2.0-rc3 / KernelSU API 102 上验证）|
| 系统 | OriginOS 6 / Android 16（X Fold2 验证版本 `PD2266_A_16.3.18.1.W10.V000L1`）|
| 机型 | vivo X Fold 系列（详见 [compatibility.md](compatibility.md)）|
| 其他 | 已安装并启用「游戏魔盒 / 游戏助手」（`com.vivo.gamecube`）|

## 安装步骤

1. 从 Releases 或 `dist/` 取得 `vivo-xfold-frame-interpolation-vX.Y.Z.zip`。
2. 打开 KernelSU 管理器 → 底部「模块」→ 右上角「安装」→ 选择 zip。
   安装时会先跑 `customize.sh` 做机型检测：X Fold2 直接通过；X Fold3 Pro / X Fold6 会提示「理论支持、未验证」后继续；
   其他机型（含无 V 芯片的 X Fold）会**中止安装**并说明原因。
3. 安装完成后**重启**。
4. 开机 30 秒左右会再重启一次 zygote（屏幕可能闪黑/重绘一次），这是模块在重启配置 HAL 与 zygote，属预期行为。
5. 回到模块列表，本模块卡片左下角会出现入口按钮，点它打开 WebUI。

> 如果卡片上没有入口按钮：检查模块目录的 SELinux 上下文，手工放模块时需要
> `chcon -R u:object_r:system_file:s0 /data/adb/modules/vivo-xfold-frame-interpolation`
> （用管理器刷 zip 安装会自动处理）。

## 开机日志

```
/data/local/tmp/vivo-xfold-fi.log
```

正常应包含：等待 `sys.boot_completed` → `chcon` → `bind mount vivo_config.ini` → `restart vivo-configstore-hal-1-0` → `restart zygote`。

## 卸载

- KernelSU 中停用或删除模块 → 重启。
- bind mount 与属性随重启消失，系统恢复原状。
- 想连游戏魔盒的应用名单一起恢复：WebUI → 「恢复游戏魔盒初始设置」（`pm clear com.vivo.gamecube`）。

## 升级

直接用新 zip 覆盖安装，重启即可。模块配置（导入的应用）保存在游戏魔盒数据库里，不随模块升级丢失。
