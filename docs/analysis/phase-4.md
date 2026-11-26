# 阶段四：插帧链路已打通，但只到 48→60，未达到提升帧率

## 已达成的部分（真机实测）

| 环节 | 结果 |
|---|---|
| 能力声明 | 运行期 bind mount `/vendor/etc/vivo_config.ini` + 重启 configstore HAL + 重启 framework，`/sys/rsc/vgarph/MEMC` 由 0 变 1 |
| 游戏适配 | `game_dimen` 补 `com.miHoYo.Nap` 的 `boost_frame_v3_*` 行并把 `game_index` 对齐真实适配游戏（3）后，侧栏出现“游戏插帧” |
| 请求下发 | `settings get system gamecube_frame_interpolation` 由 `0:-1:...` 变为 **`1:3:8591:48:60`**（开启、索引 3、PID、48→60） |
| 原生帧率记录 | `game_cube_assistantui.xml` 里补写 `sp_game_fps_origin` / `sp_game_fps_new` 的 `com.miHoYo.Nap:60`，这是 `i.c()` 判定“原生帧率”的数据源 |

## 未达成的部分

- 侧栏“提升帧率”仍提示帧率不够，UI 显示“最大可提升至 60 帧”。
- 当前实际下发的是 **48→60 的优化功耗档**，不是 60→120 的提升帧率档。

结论：能力门、名单门、请求门都已通；剩下的是**每游戏参数层**——`frame_inter_list.db`（`frame_inter_support_game` 表，字段含 `boost_frame_values` / `opti_power_values` / `frame_rate_tip`）在这台机器上根本不存在，我们只写了 `game_dimen` 的“函数名”，没有写这组帧率对与提示数据，所以 UI 只能拼出 60 的上限。

## 关键教训

1. **不要在 post-fs-data 阶段挂载 `/vendor`**。实测两次开机卡在 logo，上一轮 logcat 里 `init` 收到 SIGABRT，crash_dump 被 SELinux 拒；禁用模块后 45 秒干净开机。
2. 运行期路径（挂载 + HAL 重启 + framework 重启）可复现地让能力生效，适合做成 `service.sh` 形式，而不是开机期覆盖。
3. 名单只解决“允许”，真正的帧率对来自每游戏参数表；借用真实游戏的 `game_index` 能让入口与基础档可用。

## 已留在设备上的可逆改动

- 运行期 bind mount（重启自动消失）
- `support_dimension_list.db` 中 `com.miHoYo.Nap` 的 6 条 `game_dimen` 行
- `game_cube_assistantui.xml` 中两条帧率映射

模块本身已放 `disable` 文件，不参与开机流程。
