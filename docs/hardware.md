# 硬件与 BIOS 设置

## 硬件清单

| 部件 | 型号 / 参数 | macOS 下状态 |
| --- | --- | --- |
| 机型 | HUAWEI MateBook D 15（2020 款） | — |
| CPU | Intel Core i5-10210U · 4C/8T · Comet Lake-U · 6 MB L3 | 原生电源管理，变频正常 |
| 核显 | Intel UHD Graphics 620（`0x9B41`） | `device-id` 注入 + WhateverGreen，QE/CI 正常 |
| 独显 | 无 / 已屏蔽 | — |
| 内存 | 16 GB DDR4 | 正常 |
| 存储 | NVMe SSD 480 GB（APFS 容器 479.9 GB） | 正常 |
| 无线网卡 | Intel Wireless-AC 9560 | ⚠️ 蓝牙见 [quirks-and-fixes.md](quirks-and-fixes.md)，Wi-Fi 待验证 |
| 声卡 | Realtek 板载（`alcid=21`） | 扬声器 / 耳机自动切换 |
| SMBIOS | `MacBookPro16,1`（仿冒） | 与真实硬件不符，仅用于骗过系统检查 |

当前系统：**macOS 26.7.2（25G332）**，产品名 `macintosh`。

> 该机型报告为 `MacBook Pro (16-inch, 2019)`、`System Firmware 2094.80.5.0.0`，
> 这些都是 SMBIOS 仿冒的结果，**不要**据此判断真实机型。

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
