# 发布到 GitHub 指引

> 给帮忙上传的朋友看的。整个流程大约 5 分钟，不需要懂黑苹果。

---

## 0. 先做三项检查（重要）

这个仓库的 `config.plist` 里带有**原机器的主板序列号**风险，上传前一定要确认已脱敏，
否则会被人冒用 Apple ID 身份（iMessage / FaceTime / 查找）。

```bash
cd huawei-matebook-d15-hackintosh-tahoe-efi

# ① 应该能看到占位符
grep -c "REPLACE_WITH_GENSMBIOS" EFI/OC/config.plist

# ② 不应该出现真实序列号（正常输出为空）
grep -oE "SystemSerialNumber</key>[[:space:]]*<string>[^<]+" EFI/OC/config.plist

# ③ 不应该有 Apple 固件目录（正常输出为空）
ls -d EFI/OC/Apple 2>/dev/null

# ④ 不应该有旧版配置备份（正常输出为空）
find . \( -name "*.old*" -o -name "config.plist.*" \) -type f
```

如果 ① 是 0，或者 ② 打出了具体值 —— **先停下**，回到 `scripts/00-export-efi.command` 重新导出。

> ⚠️ **第 ④ 项最容易漏**：`config.plist.old` / `.old2` 这类编辑器自动备份**不会**被导出脚本脱敏，
> 里面往往原样保留着真实 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` 和蓝牙 MAC。
> 只检查主 `config.plist` 是不够的 —— 一旦推上公开仓库，等于把可用于冒充这台 Mac 身份的
> 整套 SMBIOS 凭据公开，且 Git 历史无法真正抹除。发现备份文件请直接移出仓库，不要用 `git rm` 了事。
> 本仓库的 `.gitignore` 已加入 `*.old*` 与 `EFI/OC/config.plist.*` 规则作兜底。

硬件清单里仍标 ❓ 的项目（摄像头、电池等）欢迎 PR 补充；机型、触控板、蓝牙与硬盘兼容性状态已由原机主确认。

---

## 1. 建本地仓库并提交

```bash
cd huawei-matebook-d15-hackintosh-tahoe-efi

git init
git add .
git status                 # 扫一眼，别把 zip / 日志 / Apple 目录带进去
git commit -m "Initial commit: HUAWEI MateBook D 15 hackintosh OpenCore EFI for macOS Tahoe"
```

建议先把默认分支改成 `main`：

```bash
git branch -M main
```

## 2. 在 GitHub 建空仓库

网页 → New repository →

| 字段 | 建议值 |
| --- | --- |
| Repository name | `huawei-matebook-d15-hackintosh-tahoe-efi` |
| Description | `OpenCore EFI for HUAWEI MateBook D 15 (2020) Hackintosh running macOS 26 Tahoe - i5-10210U, Comet Lake, ACPI, kexts and fix scripts` |
| Visibility | Public |
| Initialize with README / .gitignore / license | **全部不勾**（本地已有，勾了会冲突） |

> 仓库名刻意包含 `huawei` `matebook` `d15` `hackintosh` `tahoe` `efi` 这几个词，
> GitHub 搜索主要匹配仓库名、描述、topics 和 README，这样别人搜这些关键词更容易找到。

建好后 GitHub 会给一段命令，用 `push an existing repository` 那一组：

```bash
git remote add origin https://github.com/<你的用户名>/huawei-matebook-d15-hackintosh-tahoe-efi.git
git push -u origin main
```

## 3. 仓库设置（可选项，但建议做）

- **Topics**（右上 About 齿轮）：`hackintosh` `opencore` `opencore-efi` `efi` `macos` `macos-tahoe` `tahoe` `huawei` `matebook` `matebook-d15` `comet-lake` `i5-10210u` `intel-wifi`
- **About → Description**：用上面那句英文
- **Releases**：如果你之后更新了 EFI，打个 `v1.0` tag 方便别人下载：

```bash
git tag -a v1.0 -m "Working EFI, macOS 26.7.2"
git push origin v1.0
```

---

## 4. 上传前的法律提醒

- **不要**上传 macOS 安装镜像、Apple 原版固件（`EFI/OC/Apple/`）、或者任何从 Apple 安装包提取的文件。
- README 里已经写了免责声明（违反 Apple EULA、仅供学习、不保证可用），**别删掉**。
- 第三方 kext（Lilu / WhateverGreen / VirtualSMC / AppleALC）各自是 BSD-3 或 MIT，
  保留它们的原始文件头即可，MIT LICENSE 只覆盖本项目自己的脚本和文档。

---

## 5. 已经帮你准备好的东西

| 文件 | 说明 |
| --- | --- |
| `README.md` | 主文档：硬件表、启动参数解释、三步使用说明、已知问题、致谢 |
| `docs/hardware.md` | 详细硬件清单 + PM981 换盘说明 + BIOS 开关清单 + 分区布局 |
| `docs/quirks-and-fixes.md` | 状态速查表 + 踩坑过程（PM981 换盘、蓝牙固件 v0 c0、键盘重配对、啰嗦模式、USB 端口） |
| `scripts/01~03` | 已在真机验证过的修复脚本，带 `--dry-run` |
| `scripts/00` | 从本机导出 EFI + 自动脱敏序列号 |
| `LICENSE` | MIT |
| `.gitignore` | 挡掉 `.DS_Store`、zip、备份目录、日志，以及**含真实序列号的 `*.old*` / `config.plist.*`** |

## 常见问题

**push 被拒（`rejected — fetch first`）**：建仓库时勾了 README，导致远端已有提交。
`git pull --rebase origin main` 再 push 即可。

**大文件报错（`this exceeds GitHub's file size limit`）**：说明 `EFI/OC/Apple/` 或某个 zip 混进来了。
`git rm -r --cached EFI/OC/Apple` 后重新 commit。

**想要私有仓库**：把 Visibility 选 Private 也一样能用，只是别人看不到。
