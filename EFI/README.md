# EFI

这个目录用来存放 OpenCore 引导文件（`BOOT/` 与 `OC/`）。

## 关于这份 EFI

这里收录的是从**实际运行正常的那台机器**导出、并完成脱敏后的完整 OpenCore EFI。
换一台机器，ACPI 表、USB 端口布局、设备路径都对不上，请勿原样照搬。

## 怎么更新 / 重新导出

在目标机器上双击运行：

```bash
scripts/00-export-efi.command
```

脚本会：

1. 挂载 EFI 分区，把 `EFI/OC`、`EFI/BOOT` 整份复制到本目录
2. 自动排除 `Apple/`（Apple 固件，体积大且有版权，**绝对不要上传**）
3. 抹掉 `config.plist` 里属于本机的隐私值：
   - `PlatformInfo → Generic → SystemSerialNumber / MLB / SystemUUID / ROM`
   - `NVRAM → BluetoothLocalHostAddress`（蓝牙 MAC 是设备指纹）
4. 把文件权限交还给你，并打一个 zip 到桌面

导出后目录结构应当是这样：

```
EFI/
├── BOOT/
│   └── BOOTx64.efi
└── OC/
    ├── ACPI/          # SSDT-*.aml
    ├── Drivers/       # OpenRuntime.efi, HfsPlus.efi ...
    ├── Kexts/         # Lilu, VirtualSMC, WhateverGreen, AppleALC ...
    ├── Resources/
    ├── Tools/
    └── config.plist   # 序列号已脱敏
```

## 发布前务必确认

```bash
grep -c "REPLACE_WITH_GENSMBIOS" EFI/OC/config.plist   # 应该 ≥ 1
find . \( -name "*.old*" -o -name "config.plist.*" \) -type f   # 必须为空
ls -d EFI/OC/Apple 2>/dev/null                        # 不该存在
git status --short                                    # 逐行确认，别把备份带进去
```

`config.plist.old` / `.old2` 这类备份**没有**经过脱敏，含真实序列号与网卡 MAC，泄露后无法从 Git 历史中彻底清除，务必在提交前移出仓库。

另外，`EFI/OC/Logs/`、`EFI/OC/.contentFlush` 之类的运行时垃圾也顺手删掉。
