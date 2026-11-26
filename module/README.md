# module/

这是可直接刷入的 KernelSU 模块目录，结构：

```
module.prop         模块元信息（id 保持 vivo-game-memc，避免老用户升级断档）
post-fs-data.sh     刻意留空：此阶段挂 /vendor 会导致 init SIGABRT
service.sh          开机后等 sys.boot_completed → 挂 vivo_config.ini → 重启 HAL/zygote
bin/vivo-memc.sh    后端脚本（状态/导入/移除/清理/恢复/重启）
webroot/            KernelSU WebUI（原生 JS + CSS，无构建步骤）
system/             被 bind mount 的 vivo_config.ini 等只读素材
```

打包：`../scripts/build-module.sh`，产物在 `../dist/`。

## 后端命令

```bash
sh bin/vivo-memc.sh status                 # 能力/声明/请求值/生效值
sh bin/vivo-memc.sh installed               # 已安装包名列表
sh bin/vivo-memc.sh games                   # 当前已配置应用（pkg/label/mode/flags）
sh bin/vivo-memc.sh add <pkg> [label]       # 导入：写齐三档所需的行
sh bin/vivo-memc.sh remove <pkg>            # 移除：删掉本模块管理的行
sh bin/vivo-memc.sh set-mode <pkg> 60-120|30-60|dual
sh bin/vivo-memc.sh set-flag <pkg> power|sr|light on|off
sh bin/vivo-memc.sh set-label <pkg> <label>
sh bin/vivo-memc.sh prune                   # 删除未安装应用的预置行（先备份）
sh bin/vivo-memc.sh restart-gc              # 重启游戏助手
sh bin/vivo-memc.sh reapply-cap             # 重新挂载声明并重启 HAL/zygote
sh bin/vivo-memc.sh reset-gc                # pm clear 游戏魔盒（危险）
```
