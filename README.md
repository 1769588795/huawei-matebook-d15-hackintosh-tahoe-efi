# HUAWEI MateBook D 15 (2020) Hackintosh · macOS 26 Tahoe · OpenCore EFI

> 一台 HUAWEI MateBook D 15（2020 款，Intel i5-10210U / Comet Lake-U）的黑苹果（Hackintosh）配置与踩坑记录。
> macOS 26 Tahoe + OpenCore EFI，已在真机长期日常使用；含 SSDT、kext、脱敏后的 `config.plist` 与修复脚本。
>
> Keywords: Huawei MateBook D 15 hackintosh, macOS Tahoe, OpenCore EFI, i5-10210U,
> Samsung PM981 unsupported, SATA / NVMe SSD compatibility, Intel 9560 Bluetooth fixed, I2C trackpad.

[![macOS](https://img.shields.io/badge/macOS-26.7.2-000000)](#)
[![OpenCore](https://img.shields.io/badge/OpenCore-EFI-blue)](#)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## ⚠️ 先读这一段

1. **本仓库不包含任何 Apple 版权文件**，也不提供 macOS 安装镜像。
2. **`config.plist` 里的序列号已全部脱敏为占位符**，直接使用无法登录 iCloud / iMessage，
   你需要用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成属于自己的一套。
3. 黑苹果违反 Apple 的最终用户许可协议（EULA），仅供**学习与个人研究**，请勿用于商业用途。
4. **原装 Samsung PM981 / PM981a NVMe 固态硬盘不支持 macOS**，装系统前必须换成兼容的
   SATA SSD 或 NVMe SSD；这一步不做，后面的 EFI 都用不上。详见 [docs/hardware.md](docs/hardware.md)。
5. 照抄配置不保证能在你的机器上启动。**不同主板/BIOS 版本差异极大**，请自行调整。
6. `EFI/OC/Kexts/` 与 `EFI/OC/Resources/` 内是第三方开源驱动的**预编译二进制**及主题资源
   （其中 `IntelBluetoothFirmware.kext` 内含 Intel 专有蓝牙固件）。它们不归本仓库的 MIT 许可证覆盖，
   各自遵循上游条款；若你所在地区/用途不允许再分发，请删除对应文件并自行从上游获取。

---

## 硬件配置

| 部件 | 型号 | 状态 |
| --- | --- | --- |
| 机型 | HUAWEI MateBook D 15（2020 款） | — |
| CPU | Intel Core i5-10210U（4 核 8 线程，Comet Lake-U） | ✅ 原生电源管理 |
| 核显 | Intel UHD Graphics 620 | ✅ 硬件加速（QE/CI） |
| 内存 | 16 GB | ✅ |
| 硬盘 | 兼容的 SATA SSD 或 NVMe SSD（原装 `PM981` 已更换） | ✅ |
| 无线/蓝牙 | Intel Wireless-AC 9560（BT USB `8087:0AAA`） | ✅ 蓝牙已修复；Wi-Fi 待验证 |
| 声卡 | 板载 Realtek（`alcid=21`） | ✅ 扬声器/耳机 |
| 触控板 | 板载 I2C HID 触控板 | ✅ 可用 |
| 摄像头 | — | ❓ 待补充 |
| 电池 | — | ❓ 待补充 |
| 系统版本 | macOS 26.7.2（25G332） | ✅ |
| SMBIOS 伪装 | `MacBookPro16,1` | ✅ |

> **关于硬盘**：本机原配的 Samsung **PM981 / PM981a** 在 macOS 下不受支持，已更换为兼容的
> SATA SSD 或 NVMe SSD 后才完成安装与日常使用。换盘是这台机器装黑苹果的**前置条件**，
> 详见 [docs/hardware.md](docs/hardware.md) 与 [踩坑记录](docs/quirks-and-fixes.md)。
>
> **关于蓝牙与触控板**：蓝牙由 `IntelBluetoothFirmware` + `BlueToolFixup` + `-ibtcompatbeta`
> 修复完成，触控板由 `VoodooI2C` + `VoodooI2CHID` + `VoodooInput` 驱动，均已在日常使用中验证可用。
>
> ❓ 表示该项目未做验证或原作者未记录，欢迎 PR 补充。

---

## 目录结构

```
.
├── EFI/                    # OpenCore 引导文件（运行 scripts/00 从本机导出）
│   ├── BOOT/
│   └── OC/
│       ├── ACPI/
│       ├── Drivers/
│       ├── Kexts/
│       └── config.plist    # 序列号已脱敏
├── scripts/                # 本机调试/修复脚本（双击运行，自动提权）
│   ├── 00-export-efi.command
│   ├── 01-fix-bluetooth.command
│   ├── 02-fix-keyboard-autoconnect.command
│   └── 03-disable-verbose-boot.command
├── docs/
│   ├── hardware.md         # 详细硬件与 BIOS 设置
│   └── quirks-and-fixes.md # 踩坑记录：PM981 换盘 / 蓝牙 / 键盘 / 啰嗦模式 / USB
├── PUBLISH.md              # 发布到 GitHub 的操作指引
└── LICENSE
```

---

## 启动参数

`NVRAM → 7C436110-AB2A-4BBB-A880-FE41995C9F82 → boot-args`

```
alcid=21 darkwake=8 lilucpu=10 keepsyms=1 -ibtcompatbeta
```

| 参数 | 作用 |
| --- | --- |
| `alcid=21` | AppleALC 声卡布局 ID，对应本机耳机/扬声器节点 |
| `darkwake=8` | 睡眠唤醒策略，避免合盖后立刻被唤醒 |
| `lilucpu=10` | 让 Lilu 按 Comet Lake（10 代）处理 CPU 相关补丁 |
| `keepsyms=1` | panic 时保留符号，方便排错，日常可留 |
| `-ibtcompatbeta` | 让 Intel 蓝牙在新版 macOS 上走兼容模式，解决固件 `v0 c0`、地址为空 |

调试期曾用 `-v debug=0x100`，现已由 `scripts/03` 清除（闭嘴模式）。需要排障时再加回来。

---

## 使用步骤

### 1. 生成你自己的 SMBIOS

```bash
git clone https://github.com/corpnewt/GenSMBIOS && cd GenSMBIOS && ./GenSMBIOS.command
```

选 `MacBookPro16,1`，把生成的四项写回 `EFI/OC/config.plist → PlatformInfo → Generic`：

| 字段 | 说明 |
| --- | --- |
| `SystemSerialNumber` | 序列号 |
| `MLB` | 主板序列号 |
| `SystemUUID` | 硬件 UUID |
| `ROM` | 网卡 MAC（12 位十六进制，建议直接用你的板载网卡 MAC） |

> 四项必须**成套**，混用会导致 iServices 直接封号（`-16` 错误码）。

### 2. 替换 EFI

把本仓库的 `EFI/` 整个拷到你自己的 ESP（EFI 分区，FAT32，建议 ≥ 200 MB）：

```bash
diskutil list                                  # 找到你的 EFI 分区，如 disk0s1
sudo diskutil mount disk0s1                    # 挂载
sudo cp -R EFI/* /Volumes/EFI/EFI/             # 覆盖
sudo diskutil unmount disk0s1
```

BIOS 里需要关闭：Secure Boot、CFG Lock（或在内核补丁里绕过）、VT-d（或用 `DisableIoMapper`）。
需要开启：AHCI、XHCI Hand-off、Above 4G Decoding。详见 [docs/hardware.md](docs/hardware.md)。

### 3. 按需跑修复脚本

脚本会自动定位 EFI 分区、备份 `config.plist`、改完再卸载，**改动前都会备份到桌面 `efi-backup-*`**。

```bash
bash scripts/01-fix-bluetooth.command --dry-run   # 先预览
bash scripts/01-fix-bluetooth.command             # 真正执行
```

| 脚本 | 做什么 |
| --- | --- |
| `01-fix-bluetooth.command` | 追加 `-ibtcompatbeta`，清零 `bluetoothInternalControllerInfo`，让 Intel 9560 蓝牙起得来 |
| `02-fix-keyboard-autoconnect.command` | 注入 `BluetoothLocalHostAddress` + `AutoSeekKeyboard/PointingDevice`，开机自动连蓝牙键鼠，不用每次重配 |
| `03-disable-verbose-boot.command` | 从 `boot-args` 移除 `-v` 与 `debug=0x100`，关闭开机代码滚动 |

### 双击没反应？

macOS 对 `.command` 的默认处理偶尔会被改掉（装过 VS Code / Xcode 之后很常见），
双击变成「用编辑器打开」而不是执行。这时候改用终端跑，任何情况都有效：

```bash
cd 仓库根目录
sudo bash scripts/00-export-efi.command
```

也可以强制指定用终端打开：

```bash
open -a Terminal scripts/00-export-efi.command
```

若提示 `Permission denied`，补一下执行权限：`chmod +x scripts/*.command`。

---

## 已知问题

- **USB 端口未定制**：`EFI/OC/Kexts` 里没有 `USBMap.kext` / `USBPorts.kext`。
  蓝牙虽已修复，睡眠唤醒后仍可能掉线；摄像头、睡眠也可能受影响。建议用 [USBToolBox](https://github.com/USBToolBox/tool) 重新定制后再注入。
- **Wi-Fi 未验证**：Intel 9560 需 `itlwm` + `HeliPort` 或 `AirportItlwm`（后者对版本敏感）。
- **触控板手势未逐项验证**：指针与点击已确认可用，多指手势等行为请以你的实际机型为准。
- **SMBIOS 为仿冒值**：`MacBookPro16,1` 与本机实际硬件不符，`关于本机` 显示信息仅供参考。

---

## 致谢

[OpenCore](https://github.com/acidanthera/OpenCorePkg) · [Lilu](https://github.com/acidanthera/Lilu) ·
[WhateverGreen](https://github.com/acidanthera/WhateverGreen) · [VirtualSMC](https://github.com/acidanthera/VirtualSMC) ·
[AppleALC](https://github.com/acidanthera/AppleALC) · [USBToolBox](https://github.com/USBToolBox/tool)

这些组件各自遵循其原始许可证（多为 BSD-3-Clause / MIT），本仓库的 MIT 许可证仅覆盖**脚本与文档**。

---

## License

脚本与文档：[MIT](LICENSE) —— 随便用，出事别找我。
