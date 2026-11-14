# 机型 × 可用性兼容性汇总

> 一张持续更新的表：**谁在哪台机器上、用哪块盘、跑成了什么**。
> 这不是兼容性承诺 —— 两台机器的 ACPI 表、USB 端口布局、BIOS 版本几乎不可能完全一样，
> 照抄 EFI 前请先看 [适配指南](adaptation-guide.md)。

**目前只有 1 份实测样本**（原机主，随 v1.0 发布）。你的记录，无论成败，都会让下一个人少踩一个坑：

- [提交一条兼容性记录](https://github.com/1769588795/huawei-matebook-d15-hackintosh-tahoe-efi/issues/new?template=compatibility-report.yml)（表单中英文都行）
- [去 Discussions 聊一句](https://github.com/1769588795/huawei-matebook-d15-hackintosh-tahoe-efi/discussions)
- [参与改进 / 反馈模板](../CONTRIBUTING.md) · [English README](../README.en.md)

### 图例

| 符号 | 含义 |
| --- | --- |
| ✅ | 报告者确认可用 |
| 🟡 | 部分可用 / 有条件（见备注） |
| ❌ | 确认不可用 |
| ❓ | 未验证或报告未提及 |
| — | 该机型无此硬件 |

---

## 1. 机型记录

一行一台机器。**「社区报告」未经维护者在真机复核**，只代表报告者自己的结果。

| 机型 / BIOS | CPU | 硬盘 | macOS | OpenCore | 整体结果 | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| HUAWEI MateBook D 15 (2020) / BIOS 版本未记录 | i5-10210U · UHD 620 · 16 GB | 宏碁 Acer SA100 480GB SATA SSD（替换原装 PM981，PM981 保留跑 Windows） | 26.7.2 (25G332) | 随仓库 EFI | ✅ 安装成功并长期日常使用 | 原机主实测 · v1.0 |

> 还缺的信息：这台机器的 **BIOS 版本**。原机主补充后会更新本表。

## 2. 部件可用性矩阵（上面这台实测机型）

| 部件 | 状态 | 依赖 / 备注 |
| --- | --- | --- |
| 安装 / APFS / 启动 | ✅ | **换盘之后**才成立，见第 3 节 |
| CPU 电源管理 | ✅ | Comet Lake-U，`lilucpu=10` |
| 核显加速（QE/CI） | ✅ | UHD 620，WhateverGreen |
| Wi-Fi | ✅ | Intel AC 9560 + `AirportItlwm.kext`；**与 macOS 版本绑定**，升级系统前先找对应版本 |
| 蓝牙 | ✅ | `IntelBluetoothFirmware` + `BlueToolFixup` + `-ibtcompatbeta`；详见 [踩坑记录](quirks-and-fixes.md) |
| 蓝牙键鼠开机自动回连 | ✅ | `BluetoothLocalHostAddress` + `AutoSeek*`，`scripts/02` |
| 触控板 | ✅ | `VoodooI2C` + `VoodooI2CHID` + `VoodooInput`；指针与点击确认，多指手势未逐项验证 |
| 声卡 | ✅ | AppleALC `alcid=21`，扬声器 / 耳机 |
| 睡眠 / 唤醒 | 🟡 | 换盘后基本正常，但 **USB 端口未定制**，唤醒后蓝牙偶发掉线 |
| USB 端口 | ✅ | 未做 `USBMap.kext` 定制，但 U 盘 / 鼠标接收器实测即插即用、日常正常 |
| 摄像头 | ❌ | 板载 USB 摄像头未被驱动，大概率与端口未映射有关，见 [踩坑 §5](quirks-and-fixes.md) |
| 电池读数 | ✅ | 剩余电量 / 百分比正常显示；`SSDT-BAT0-HUAWEI.aml` + `SMCBatteryManager.kext` |
| 独立显卡 | — | 该机型无独显；带独显的机器**不要直接套**这份 EFI |

详细的硬件清单与 BIOS 开关见 [hardware.md](hardware.md)。

## 3. 硬性前置条件 / 常见失败

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 安装器看不到硬盘、装上后掉盘 | 原装 **Samsung PM981 / PM981a** 不支持 macOS | **物理换盘**。本机换的是宏碁 Acer SA100 480GB SATA 固态；也可选主控兼容的 M.2 NVMe，别再用 PM981 |
| 用占位符 `config.plist` 登录 iCloud / iMessage 失败 | SMBIOS 已脱敏 | 用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成四项成套值 |
| 换了 EFI 仍卡在启动 | ACPI / USB / 设备路径因机而异 | 按 [适配指南](adaptation-guide.md) 逐项核对，别整包照抄 |
| 卡住了却看不到日志 | 啰嗦模式被人为关掉 | 本仓库 EFI **默认带 `-v debug=0x100`**；若被删，用 `scripts/04` 开回来，拍下卡住时最后几行 |
| 升级 macOS 后 Wi-Fi 失效 | `AirportItlwm` 与系统版本绑定 | 换对应版本的 kext，或改用 `itlwm` + HeliPort |

EFI 里保留的 `NVMeFix.kext` + `SSDT-NVME.aml` 只对 NVMe 盘有意义；本机走 SATA，这两项实际不生效，可按需禁用。

---

## 怎么把你的机型加进来

最简单的方式是填 **[兼容性反馈表单](https://github.com/1769588795/huawei-matebook-d15-hackintosh-tahoe-efi/issues/new?template=compatibility-report.yml)**，
也可以直接 PR 改本文件，在「机型记录」表追加一行。请至少给出：

1. **机型 + 年份 / 硬件版本**、BIOS 版本
2. **硬盘**（是不是换过盘、换成什么）
3. **macOS 版本**与整体结果
4. 哪些部件 ✅ / ❌，以及为跑通改了什么

维护者会按「原机主实测 / 社区报告（未复核）」标注来源，并把有共性的结论同步进
[README 硬件表](../README.md) 与 [适配指南](adaptation-guide.md)。只写「不能用」而没有环境信息的记录无法收录。

> ⚠️ **提交前脱敏**：不要贴真实 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` / 蓝牙 MAC /
> Apple ID / 主机名，也不要上传 `config.plist.old*` 备份。公开 Issue 会被搜索引擎收录，且 Git 历史
> 无法真正抹除。规则见 [CONTRIBUTING.md](../CONTRIBUTING.md)。

---

黑苹果违反 Apple 的最终用户许可协议（EULA），本仓库仅供学习与个人研究。
汇总表里的第三方报告由各自的报告者负责，按原样呈现，不代表维护者验证过。
