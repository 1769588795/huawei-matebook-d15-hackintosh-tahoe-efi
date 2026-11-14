# 把这份 EFI 适配到你自己的机器

> 这份 EFI 是从**一台特定机器**导出并脱敏的。直接整包复制到另一台笔记本上，大概率起不来，
> 即使起来了也会有各种半残的硬件。本页按「必须改 / 可以复用 / 怎么验证 / 出问题查哪儿」组织，
> 目标是让你少走弯路，而不是给一份万能配置。

先查 [机型 × 可用性汇总表](compatibility.md)，看有没有人用过和你相近的配置；
本仓库另有 [English README](../README.en.md)，方便分享给不使用中文的人。
只想要 EFI 文件的话，[v1.0 Release](https://github.com/1769588795/huawei-matebook-d15-hackintosh-tahoe-efi/releases/latest)
里有可直接解压的 `EFI-v1.0.zip`。

---

## 0. 先判断值不值得参考

**比较接近、值得参考**：Comet Lake-U（10 代低压 U）、Intel UHD 620 核显、I2C HID 触控板、
Intel Wireless-AC 9560 无线网卡，尤其是 HUAWEI MateBook D 15（2020）及 BIOS 相近的机型。

**别直接套**：带独立显卡的机型、其它代 CPU / 平台、PS/2 触控板机型、AMD 平台。
这些情况下 ACPI 表、设备路径、帧缓冲补丁全都不一样，照抄只会浪费时间。

**最先确认的是硬盘，不是 EFI**：原装 Samsung **PM981 / PM981a** 不支持 macOS，
不换盘根本进不了安装器。见 [hardware.md](hardware.md) 的「原装 PM981 必须更换」。

---

## 1. 必须改（不改基本起不来，或有实际风险）

| 项目 | 为什么 | 怎么做 |
| --- | --- | --- |
| SMBIOS 四项 | 仓库里是占位符，直接用会跟别人撞号、iServices 被封 | 用 GenSMBIOS 生成**成套**的 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM`，见 [README 第 1 步](../README.md) |
| USB 端口映射 | 本仓库**没有** `USBMap.kext`；本机不测也能日常用（U 盘 / 鼠标正常，代价是摄像头不可用），但端口布局每台机器都不同，别的机器可能牵连蓝牙、摄像头、睡眠 | [USBToolBox](https://github.com/USBToolBox/tool) 导出端口表，内建蓝牙端口类型设 `Internal (255)`，登记进 `Kernel → Add` |
| ACPI 表 | 多个 SSDT 是按本机 DSDT 写的，路径名对不上就无效甚至报错 | 重点重做 `SSDT-BAT0-HUAWEI`、`SSDT-BrightFN`、`SSDT-GPI0-GPHD`、`SSDT-I2CxConf`、`SSDT-PNLFCFL`、`SSDT-PTSWAK-SLEEP`；用 SSDTTime / 自行提取 DSDT |
| DVMT / 显存 | BIOS 锁死 32 MB 时核显容易黑屏、花屏 | BIOS 里调到 ≥ 64 MB；调不了就用 `framebuffer-patch-enable` + `framebuffer-stolenmem` |
| 蓝牙 NVRAM 的 MAC | `BluetoothLocalHostAddress` 是这台机器的控制器地址 | 换机后重跑 `scripts/02-fix-keyboard-autoconnect.command` |
| `-ibtcompatbeta` | 过渡性参数，上游适配 Tahoe 后可能反而出问题 | 每次升级 OpenCore / macOS 都复核一次是否还需要 |

> ⚠️ **隐私**：不要把你自己机器真实的 SMBIOS、蓝牙 MAC 连同 `config.plist` 一起提交或发给别人。
> 尤其注意 `config.plist.old` / `.old2` 这类编辑器备份不会被自动脱敏，见 [CONTRIBUTING.md](../CONTRIBUTING.md)。

---

## 2. 相对可以放心复用的部分

- **驱动组合与加载顺序**：`config.plist → Kernel → Add` 里已启用的顺序可供参考
  （`Lilu` → `VirtualSMC` → `WhateverGreen` / `AppleALC` → … → `VoodooPS2Controller` →
  `VoodooI2C` 系列 → `IntelBluetoothFirmware` / `IntelBTPatcher` / `BlueToolFixup` → `AirportItlwm`）。
  依赖关系别打乱，Lilu 必须在依赖它的插件之前。
- **Intel 蓝牙的修复思路**：`-ibtcompatbeta` + 清 `bluetoothInternalControllerInfo` + 注入本机 MAC，
  见 [踩坑记录 §2](quirks-and-fixes.md)。
- **Wi-Fi**：`AirportItlwm.kext` 已启用并验证可用，但它与 macOS 版本绑定，升级系统前先找对应版本。
- **I2C 触控板**：若你的机器也是 I2C HID，`VoodooI2C` + `VoodooI2CHID` + `VoodooInput` 这套组合可作起点
  （本机只启用了 `VoodooI2C` 内的 `VoodooInput`，避免重复加载）。
- **修复脚本的骨架**：挂载 EFI → 备份 → 用 `plistlib` 改 plist → 卸载，带 `--dry-run`，改起来比手改安全。
- `NVMeFix.kext` + `SSDT-NVME.aml`：只在用 NVMe 盘时有用；本机已换 SATA 盘，实际不生效。

---

## 3. 建议的验证顺序

一次只改一件事，改完就验证，别一口气全换：

1. 只填 SMBIOS，加 `-v` 引导，先确认能进安装器、能装完系统；
2. 进系统后逐项验收：显卡加速 → 声卡 → Wi-Fi → 蓝牙 → 触控板 → 电池 → 睡眠唤醒；
   **安装阶段别急着关 `-v`** —— 卡住时开机日志是唯一线索，全部验收完再跑 `scripts/03`；
3. 哪一项不工作，先按第 4 节速查，再改对应 SSDT / kext，一次只动一处；
4. 全部稳定后，用 `scripts/03` 去掉 `-v` / `debug=0x100`；
5. 最后做 USB 端口定制，解决睡眠唤醒后的蓝牙掉线等问题。

---

## 4. 故障速查

| 现象 | 优先排查方向 | 参考 |
| --- | --- | --- |
| 卡在 `EndRandomSeed` / 出现禁行标志 | BIOS 开关、CFG Lock、Secure Boot、OpenCore 版本与 `config.plist` 是否匹配 | [hardware.md](hardware.md) BIOS 章节 |
| 安装器看不到硬盘 | **PM981 没换**；AHCI 未开；`NVMeFix` / 磁盘相关 SSDT 不适用 | [换盘说明](hardware.md) |
| 蓝牙 `v0 c0`、地址为空 | `-ibtcompatbeta` 未加；旧控制器缓存未清 | [踩坑 §2](quirks-and-fixes.md) |
| 蓝牙键盘每次开机要重配 | `BluetoothLocalHostAddress` 丢失、`AutoSeek*` 为 0 | [踩坑 §3](quirks-and-fixes.md) |
| Wi-Fi 突然消失 | `AirportItlwm` 与当前 macOS 版本不匹配 | README 已知问题 |
| 触控板完全不动 | 触控板总线是 I2C 还是 PS/2 判断错了；GPIO pinning / `SSDT-GPI0-GPHD` / `SSDT-I2CxConf` 不适用 | 第 1 节 ACPI 表 |
| 睡眠秒醒、唤醒后蓝牙掉线 | USB 端口未定制 | [踩坑 §5](quirks-and-fixes.md) |
| 亮度键 / 电池百分比异常 | `SSDT-BrightFN` / `SSDT-BAT0-HUAWEI` 是本机专用 | 第 1 节 ACPI 表 |
| iCloud 登录报 `-16` | SMBIOS 四项不成套，或用了仓库里的占位符 | [README 第 1 步](../README.md) |

> 这些是排查方向，不是保证能修好的万能解。请配合 OpenCore 官方调试文档、
> `-v` 日志和 `EFI/OC/Logs/` 一起看。**不要**把含真实序列号的日志或配置直接贴到公开场合。

---

## 5. 帮后面的人少踩一个坑

如果你的机器成功跑起来了（或者卡在某一步），欢迎按 [CONTRIBUTING.md](../CONTRIBUTING.md)
的模板报一下机型、BIOS 版本、换的什么盘、改了哪几处 —— 也可以直接填
[兼容性反馈表单](https://github.com/1769588795/huawei-matebook-d15-hackintosh-tahoe-efi/issues/new?template=compatibility-report.yml)，
结果会汇总进 [兼容性表](compatibility.md)。哪怕只写一句「某某机型 + 这版 EFI 能进安装器」，
对下一个人都有用。目前这台机器的 BIOS 版本仍缺记录，欢迎补充（摄像头已确认不可用，硬盘已确认为宏碁 Acer SA100 480GB）。
