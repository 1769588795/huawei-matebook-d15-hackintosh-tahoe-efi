# 硬件与 BIOS 设置

## 硬件清单

| 部件 | 型号 / 参数 | macOS 下状态 |
| --- | --- | --- |
| 机型 | HUAWEI MateBook D 15（2020 款） | — |
| CPU | Intel Core i5-10210U · 4C/8T · Comet Lake-U · 6 MB L3 | 原生电源管理，变频正常 |
| 核显 | Intel UHD Graphics 620（`0x9B41`） | `device-id` 注入 + WhateverGreen，QE/CI 正常 |
| 独显 | 无 / 已屏蔽 | — |
| 内存 | 16 GB DDR4 | 正常 |
| 存储 | 宏碁（Acer）SATA 固态硬盘（替换原装 Samsung PM981 / PM981a） | 正常，见下方「原装 PM981 必须更换」 |
| 无线网卡 | Intel Wireless-AC 9560 | ✅ Wi-Fi（`AirportItlwm`）与蓝牙均验证可用，蓝牙修复见 [踩坑记录](quirks-and-fixes.md) |
| 声卡 | Realtek 板载（`alcid=21`） | 扬声器 / 耳机自动切换 |
| 触控板 | 板载 I2C HID 触控板 | ✅ 可用（VoodooI2C + VoodooI2CHID + VoodooInput） |
| SMBIOS | `MacBookPro16,1`（仿冒） | 与真实硬件不符，仅用于骗过系统检查 |

当前系统：**macOS 26.7.2（25G332）**，产品名 `macintosh`。

> 该机型报告为 `MacBook Pro (16-inch, 2019)`、`System Firmware 2094.80.5.0.0`，
> 这些都是 SMBIOS 仿冒的结果，**不要**据此判断真实机型。

## 原装 PM981 必须更换

MateBook D 15（2020）原配的 **Samsung PM981 / PM981a（OEM NVMe 固态硬盘）不支持黑苹果 / macOS**。
这属于盘本身与 Apple NVMe 驱动的兼容性问题，改 `config.plist`、加 `NVMeFix`、换 SMBIOS 都绕不过去：

- 典型表现：安装器里看不到目标盘，或安装过程卡死 / 反复重启；
- 即便勉强装上，也容易出现随机 I/O 报错、休眠唤醒失败、长时间使用后掉盘。

**解法只有一个：物理换盘。** 本机实际换上的是 **宏碁（Acer）SATA 固态硬盘**，装好 macOS 后长期日常使用正常。
按机器实际接口，可选方案：

| 方案 | 说明 |
| --- | --- |
| **2.5" SATA SSD（本机采用：宏碁 Acer）** | 走 AHCI，macOS 原生支持最好，最省心 |
| M.2 NVMe SSD | 选主控与 macOS 兼容的常见型号，**不要**再用 PM981 / PM981a |

换盘后再安装 macOS、部署本仓库的 EFI。EFI 里仍保留 `NVMeFix.kext` 与 `SSDT-NVME.aml`，
用于改善兼容 NVMe 盘的电源管理与自检；本机已换 SATA 盘，这两项实际不生效，可按需禁用。

> 换盘会改变容量与设备路径，下面的分区布局是早期记录（当时为 480 GB 盘），请以你自己的
> `diskutil list` 为准。宏碁盘的具体型号与容量未记录，欢迎 PR 补充。

## BIOS 设置

### 必须关闭

| 项 | 原因 |
| --- | --- |
| Secure Boot | 否则 OpenCore 无法加载未签名引导 |
| CFG Lock | 不解锁需在 `Kernel → Quirks` 打开 `AppleCpuPmCfgLock` / `AppleXcpmCfgLock` |
| VT-d | 或保留但启用 `DisableIoMapper` |
| Fast Boot | 快速启动会跳过 USB 初始化，影响引导 |

### 必须开启

| 项 | 原因 |
| --- | --- |
| AHCI | 硬盘模式 |
| XHCI Hand-off | USB 控制器交接给系统 |
| Above 4G Decoding | 大显存映射，Comet Lake 必需 |
| UEFI Only / CSM Off | 纯 UEFI 引导 |

### 建议

- 显存（DVMT）设为 **64 MB 或以上**；若 BIOS 锁死 32 MB，需用 `framebuffer-patch-enable` + `framebuffer-stolenmem` 补丁。
- 关闭「Intel Platform Trust Technology (PTT)」，避免 TPM 相关报错。

## 分区布局（参考）

```
/dev/disk0   512 GB   Windows（EFI 314 MB + MSR + 系统盘）—— 双系统时的另一块盘
/dev/disk1   480 GB   macOS
  ├─ disk1s1  EFI 209.7 MB   ← OpenCore 在这里
  └─ disk1s2  APFS Container
       ├─ macintosh (系统)
       ├─ macintosh - 数据
       ├─ Preboot / Recovery / VM
```

> 双硬盘双系统：OpenCore 装在 macOS 这块盘的 ESP 上，由 BIOS 启动顺序指向它，
> 再由 OpenCore 的 `Misc → BlessOverride` / 启动项菜单转发到 Windows。
