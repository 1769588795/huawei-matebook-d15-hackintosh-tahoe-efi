# 踩坑记录

按时间顺序记录这台机器上实际踩过的坑，以及验证有效的解法。
所有修复脚本都在 [`../scripts/`](../scripts/)，**改动前都会自动备份 `config.plist` 到桌面**。

## 当前状态速查

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| 原装 Samsung PM981 / PM981a | ✅ 已换盘 | 不支持黑苹果，已换成宏碁（Acer）SATA 固态硬盘，见 §1 |
| Intel 9560 Wi-Fi | ✅ 可用 | `AirportItlwm.kext` 驱动，日常使用已验证 |
| Intel 9560 蓝牙 | ✅ 已修复 | `-ibtcompatbeta` + 清控制器缓存，见 §2 |
| 蓝牙键盘开机自动回连 | ✅ 已修复 | 注入 `BluetoothLocalHostAddress` + `AutoSeek*`，见 §3 |
| 板载触控板 | ✅ 可用 | `VoodooI2C` + `VoodooI2CHID` + `VoodooInput` 直接驱动，未做额外修补 |
| 开机啰嗦模式 | ✅ 已关闭 | 见 §4 |
| USB 端口定制 | ⚠️ 遗留问题 | 见 §5 |

---

## 0. 两个 EFI 分区：别改错盘

这台机器上了双硬盘（Windows 512 GB + macOS 480 GB，容量为早期记录，换盘后以实际为准），`diskutil list` 能看到**两个 EFI 分区**：

```
disk0s1   EFI  NO NAME   314.6 MB   ← Windows 的 ESP
disk1s1   EFI  EFI       209.7 MB   ← OpenCore 在这里
```

早期脚本靠卷名/文本匹配找盘，结果经常挂到 Windows 那个上去，然后报「找不到 config.plist」。

**解法**：按分区类型 `Content == EFI` 枚举候选，再逐个挂载、下钻 3 层找 `config.plist`，
谁里面有 OpenCore 配置就用谁。已固化进所有脚本的 `[1/4]` 步骤。

---

## 1. 原装 PM981 装不上 macOS（已解决：换盘）

**现象**：用原机自带的 Samsung PM981 / PM981a NVMe 固态硬盘时，macOS 安装阶段就进行不下去 ——
安装器看不到目标盘，或安装过程中卡死 / 反复重启。

**原因**：PM981 系列是三星 OEM NVMe 盘，其主控与固件和 Apple 的 NVMe 驱动不兼容，
属于**硬件层面**的问题。改 `config.plist`、加 `NVMeFix.kext`、换 SMBIOS 都解决不了，别在这上面耗时间。

**解法**：物理换盘。本机换上的是 **宏碁（Acer）SATA 固态硬盘**，走 AHCI、macOS 原生支持最好；
如果机器只有 M.2 位，也可以换主控兼容 macOS 的 NVMe SSD（避开 PM981 / PM981a）。

**结果**：换成宏碁 SATA 固态后，安装、APFS、休眠唤醒均正常，可长期日常使用。EFI 中的
`NVMeFix.kext` + `SSDT-NVME.aml` 保留给 NVMe 盘做电源管理与自检优化；本机已换 SATA 盘，
这两项实际不生效，按需禁用即可。

> 换盘会改变磁盘容量和设备路径，[硬件文档](hardware.md) 里的分区布局只是当时的示例。

---

## 2. Intel 9560 蓝牙起不来（固件 `v0 c0`）· 已修复

**现象**

```
Bluetooth Controller:
    Address:            ← 空
    State: Off
    Firmware Version: v0 c0
```

也就是控制器被系统识别到了（USB `8087:0AAA`），但固件没加载，地址也没分配。

**原因**：macOS 26 (Tahoe) 对 Intel 蓝牙的兼容层收紧了，新的 `BlueTool` 流程在启动早期
就去读控制器状态，此时固件还没起来，于是一直卡在 `v0 c0`。

**解法**（`scripts/01-fix-bluetooth.command`）

1. `boot-args` 追加 `-ibtcompatbeta` —— 强制走兼容模式初始化路径；
2. 往 `NVRAM → 7C436110-...` 写入 `bluetoothInternalControllerInfo` = 28 个 `0x00`，
   清掉旧的（错误的）控制器缓存，让系统重新走一遍完整初始化。

**结果**：重启后 `Address` 有值，`State: On`，固件版本变成 `v256 c256`（即 0x100），
`Chipset: THIRD_PARTY_DONGLE`，A2DP/HID/BLE 服务全部注册成功；后续日常使用稳定。

> 注意：`-ibtcompatbeta` 是**过渡性**参数。等 OpenCore / IntelBluetoothFirmware 上游适配 Tahoe 之后
> 应当移除，否则可能在新版本上反而出问题。

---

## 3. 蓝牙键盘每次开机都要重新配对 · 已修复

**现象**：键盘（HUAWEI 超薄键盘）配对一次能用，重启后又要长按配对键重新连，系统里还残留多条重复的配对记录。

**原因**：黑苹果重启后 NVRAM 里的 `BluetoothLocalHostAddress` 丢失，
系统认为「这不是同一台主机」，于是所有已配对设备失效；同时 `AutoSeek*` 开关为 0，开机也不会主动回连。

**解法**（`scripts/02-fix-keyboard-autoconnect.command`）

从 `system_profiler SPBluetoothDataType` 读出当前控制器 MAC，去掉冒号后注入三项 NVRAM：

| Key | 值 | 作用 |
| --- | --- | --- |
| `BluetoothLocalHostAddress` | 控制器 MAC（12 位十六进制） | 让系统认得出「同一台主机」 |
| `BluetoothAutoSeekKeyboard` | `0x01` | 开机自动回连已配对键盘 |
| `BluetoothAutoSeekPointingDevice` | `0x01` | 开机自动回连鼠标/触控板 |

同时把这几个 key 登记到 `NVRAM → Delete`，避免旧值残留覆盖新值。

**结果**：重启后键盘在登录界面之前就能连上，不再需要重新配对。

> 万一还是不行：蓝牙设置里把键盘「移除设备」再重新配对一次 —— 旧的配对信息本身可能是坏的。
> 另外，若换了网卡/主板，MAC 会变，需要重跑一次脚本。

---

## 4. 关闭开机啰嗦模式

调试期 `boot-args` 是：

```
-v alcid=21 darkwake=8 lilucpu=10 keepsyms=1 debug=0x100
```

`-v` 让屏幕滚一堆内核日志，`debug=0x100` 保留调试输出。调通之后这两个都该去掉。

`scripts/03-disable-verbose-boot.command` 只做减法，保留 `alcid / darkwake / lilucpu / keepsyms / -ibtcompatbeta`：

```
alcid=21 darkwake=8 lilucpu=10 keepsyms=1 -ibtcompatbeta
```

---

## 5. USB 端口未定制（遗留问题）

脚本检查 `EFI/OC/Kexts` 时发现**没有 `USBMap.kext` / `USBPorts.kext`**，说明 USB 端口从未定制过。

影响：

- 蓝牙走的是 USB 内部端口（本机对应 `HS10` / Port 10）。蓝牙本身已按 §2 修好，
  但端口没映射时，睡眠唤醒后仍可能掉线；
- 摄像头、读卡器可能时好时坏；
- 睡眠可能秒醒（`XHCI` 唤醒事件）。

**待办**：用 [USBToolBox](https://github.com/USBToolBox/tool) 在 Windows 下（或用 macOS 版）导出端口表，
生成 `USBMap.kext` 放进 `Kexts/`，并在 `Kernel → Add` 里登记。重点确认内建蓝牙端口类型是 `Internal (255)`。

---

## 附：修复脚本的通用设计

三个脚本共用同一套骨架，改 `config.plist` 时都遵循：

1. `set -uo pipefail`，任何一步失败都保留日志；
2. 非 root 时用 `exec sudo -E` 自提权，并把日志路径通过环境变量传进去（否则 root 的 `$HOME` 会写到 `/var/root`）；
3. 挂载 → 备份 → 用 `plistlib` 读写（**不用** `PlistBuddy`，避免破坏二进制 plist 和 `<data>` 类型）→ 卸载；
4. 全流程 `tee` 到桌面日志，出问题直接把日志贴出来就能定位；
5. 支持 `--dry-run` 只预览不落盘。
