# HUAWEI MateBook D 15 (2020) Hackintosh · macOS 26 Tahoe · OpenCore EFI

[中文文档 (Chinese README)](README.md)

> A working OpenCore EFI and configuration notes for a HUAWEI MateBook D 15 (2020,
> Intel i5-10210U / Comet Lake-U) running macOS 26 Tahoe — daily-driven on real hardware.
> Includes SSDTs, kexts, a sanitized `config.plist`, and the fix scripts used on this machine.
>
> Keywords: Huawei MateBook D 15 hackintosh, macOS Tahoe, OpenCore EFI, i5-10210U,
> Samsung PM981 unsupported on hackintosh, Acer SATA SSD replacement,
> Intel 9560 Wi-Fi and Bluetooth working, I2C trackpad.

---

## Read this first

1. **No Apple copyrighted files** and no macOS installer images are included.
2. **All SMBIOS values in `config.plist` are placeholders.** Generate your own set with
   [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS), or iCloud / iMessage will not work.
3. Hackintoshing violates Apple's EULA. **Study and personal research only**, not commercial use.
4. **The stock Samsung PM981 / PM981a NVMe SSD is not supported by macOS.** Replace the drive
   before installing macOS — nothing else in this EFI helps until you do. This machine now runs an
   **Acer SATA SSD**. See [docs/hardware.md](docs/hardware.md).
5. **Copying this EFI does not guarantee a boot.** ACPI tables, USB port layout and device paths
   differ between boards and BIOS versions. See the [adaptation guide](docs/adaptation-guide.md).
6. `EFI/OC/Kexts/` and `EFI/OC/Resources/` contain prebuilt third-party binaries and theme assets
   (`IntelBluetoothFirmware.kext` includes proprietary Intel Bluetooth firmware). They are **not**
   covered by this repository's MIT license — follow each upstream license.

---

## Hardware

| Part | Model | Status |
| --- | --- | --- |
| Laptop | HUAWEI MateBook D 15 (2020) | — |
| CPU | Intel Core i5-10210U · 4C/8T · Comet Lake-U | Native power management |
| iGPU | Intel UHD Graphics 620 | Hardware acceleration (QE/CI) |
| RAM | 16 GB | Working |
| Storage | Acer SATA SSD (replaced the stock PM981) | Working, daily use |
| Wi-Fi / Bluetooth | Intel Wireless-AC 9560 (BT USB `8087:0AAA`) | Both working |
| Audio | Onboard Realtek (`alcid=21`) | Speakers / headphone jack |
| Trackpad | I2C HID trackpad | Working |
| Camera | — | Not verified |
| Battery status | — | Not verified |
| macOS | 26.7.2 (25G332) | Working |
| SMBIOS | `MacBookPro16,1` (spoofed) | Working |

**Verified working:** Wi-Fi (`AirportItlwm.kext`), Bluetooth (`IntelBluetoothFirmware` +
`BlueToolFixup` + `-ibtcompatbeta`), I2C trackpad (`VoodooI2C` + `VoodooI2CHID` + `VoodooInput`),
audio, graphics acceleration, CPU power management, installation / APFS / sleep-wake after the
drive swap.

**Not verified:** camera, battery reporting, individual multi-touch gestures.

---

## Quick start

### 1. Generate your own SMBIOS

```bash
git clone https://github.com/corpnewt/GenSMBIOS && cd GenSMBIOS && ./GenSMBIOS.command
```

Pick `MacBookPro16,1` and write all four values into
`EFI/OC/config.plist → PlatformInfo → Generic`: `SystemSerialNumber`, `MLB`, `SystemUUID`, `ROM`.
They must be generated **as a matched set** — mixing values leads to iServices error `-16`.

### 2. Copy the EFI to your ESP

```bash
diskutil list
sudo diskutil mount disk0s1
sudo cp -R EFI/* /Volumes/EFI/EFI/
sudo diskutil unmount disk0s1
```

In BIOS: disable Secure Boot, CFG Lock, VT-d (or enable `DisableIoMapper`), Fast Boot;
enable AHCI, XHCI Hand-off, Above 4G Decoding, UEFI only. See [docs/hardware.md](docs/hardware.md).

### 3. Run the fix scripts if needed

Scripts locate the EFI partition, back up `config.plist` to the Desktop, edit it, then unmount.
They support `--dry-run`.

| Script | Purpose |
| --- | --- |
| `01-fix-bluetooth.command` | Adds `-ibtcompatbeta`, clears `bluetoothInternalControllerInfo` (fixes firmware `v0 c0`) |
| `02-fix-keyboard-autoconnect.command` | Injects `BluetoothLocalHostAddress` + `AutoSeek*` for keyboard/mouse auto-reconnect |
| `03-disable-verbose-boot.command` | Removes `-v` and `debug=0x100` from `boot-args` |

If double-clicking a `.command` opens an editor instead, run it from Terminal:
`sudo bash scripts/01-fix-bluetooth.command`.

### 4. Adapt it to your machine

See [docs/adaptation-guide.md](docs/adaptation-guide.md) — SMBIOS, USB mapping, ACPI tables and
framebuffer settings are machine-specific and must be reviewed.

---

## boot-args

`NVRAM → 7C436110-AB2A-4BBB-A880-FE41995C9F82 → boot-args`

```
alcid=21 darkwake=8 lilucpu=10 keepsyms=1 -ibtcompatbeta
```

| Flag | Purpose |
| --- | --- |
| `alcid=21` | AppleALC layout ID for this machine's audio codec |
| `darkwake=8` | Sleep/wake policy |
| `lilucpu=10` | Treat CPU as Comet Lake (10th gen) |
| `keepsyms=1` | Keep symbols on panic for debugging |
| `-ibtcompatbeta` | Compatibility init path for Intel Bluetooth on newer macOS |

> `-ibtcompatbeta` is a transitional workaround. Remove it once upstream
> OpenCore / IntelBluetoothFirmware properly supports Tahoe.

---

## Known issues

- **USB ports are not mapped** — no `USBMap.kext` / `USBPorts.kext`. Bluetooth works but may drop
  after sleep; camera and sleep can be affected. Map ports with
  [USBToolBox](https://github.com/USBToolBox/tool).
- **`AirportItlwm` is macOS-version-specific** — check for a matching build before upgrading macOS.
- **Multi-touch gestures not individually verified** — pointer and clicks work.
- **SMBIOS is spoofed** — `About This Mac` information is not the real hardware.

---

## Helping others

If this EFI helped you, a Star makes the repo easier to find. A short
[Discussion](https://github.com/1769588795/huawei-matebook-d15-hackintosh-tahoe-efi/discussions)
or Issue with your laptop model, BIOS version, the drive you used and what worked / didn't helps
the next person far more than a silent clone.
See [CONTRIBUTING.md](CONTRIBUTING.md) for the report template and the privacy rules.

---

## Credits

[OpenCore](https://github.com/acidanthera/OpenCorePkg) · [Lilu](https://github.com/acidanthera/Lilu) ·
[WhateverGreen](https://github.com/acidanthera/WhateverGreen) · [VirtualSMC](https://github.com/acidanthera/VirtualSMC) ·
[AppleALC](https://github.com/acidanthera/AppleALC) · [USBToolBox](https://github.com/USBToolBox/tool)

These components keep their original licenses (mostly BSD-3-Clause / MIT). This repository's
[MIT license](LICENSE) covers **only the scripts and documentation**.
