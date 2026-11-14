# 参与改进

想让这份配置帮到更多同机型的人，**最有用的往往不是改代码，而是补一条真实记录**。
这台机器的 EFI 已经在日常使用中跑通了，但只有一台机器的样本；你的机型、BIOS 版本、
换的什么盘、哪一项能用哪一项不能，对下一个人价值很大。

[English README](README.en.md) · [适配指南](docs/adaptation-guide.md) · [硬件清单](docs/hardware.md)

---

## 三种最需要的贡献

1. **报告兼容性**：你的机型 / BIOS 版本 / macOS 版本 / 换的什么盘 / 哪些硬件工作、哪些不工作。
   失败的案例同样有价值，能帮别人少踩一个坑。
2. **补全缺失信息**：硬件表里还标 ❓ 的**摄像头**、**电池状态**，以及**宏碁 SATA 固态硬盘的具体型号与容量**。
3. **说明配置差异**：如果你为自己的机器改了 SSDT / kext / boot-args，写清改了什么、为什么、结果如何。

顺手点个 Star 也算贡献——它能让这个仓库在同机型搜索里排得更靠前。

---

## 反馈模板

复制下面这段去开 [Discussion](https://github.com/1769588795/huawei-matebook-d15-hackintosh-tahoe-efi/discussions)
或 Issue 即可，不确定的项留空：

```text
机型 / 型号：        （例：HUAWEI MateBook D 15 2020 / 其它品牌型号）
CPU / 显卡：
BIOS 版本：
macOS 版本：         （例：26.7.2）
硬盘：               （原装 PM981？换成了什么盘 / 型号 / 容量）
OpenCore 版本：
用了本仓库的哪些部分：（整包 EFI / 只参考 kext 组合 / 只跑脚本）

✅ 可用：
❌ 不可用：
🔧 为了跑通改了什么：

备注 / 截图 / 报错日志：
```

---

## ⚠️ 提交前必看：不要上传真实 SMBIOS

这是本仓库发布时踩过的坑，务必看完：

- **不要**提交含真实 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` / 蓝牙 MAC 的 `config.plist`；
  这些值成套泄露后可用于冒充这台 Mac 的身份，且 **Git 历史无法真正抹除**。
- **特别小心 `config.plist.old` / `.old2` 这类编辑器自动备份**：它们不会被导出脚本脱敏，
  原样保留真实值。`.gitignore` 已加入 `*.old*` 与 `EFI/OC/config.plist.*` 兜底，但别只依赖它。
- 提交前按 [PUBLISH.md 第 ④ 项](PUBLISH.md) 再扫一遍；发现备份文件请**移出仓库**，别用 `git rm` 了事。
- 贴日志、`system_profiler` 输出、截图前，先检查有没有序列号、MAC、Apple ID、用户名、主机名。

---

## PR 约定

- 文档改动直接提 PR 即可；改 `EFI/` 下二进制或 `config.plist` 请附「改了什么 + 验证环境 + 结果」。
- **不要**提交：`EFI/OC/Apple/`（Apple 固件）、macOS 安装镜像、任何 Apple 安装包提取的文件、
  zip / 日志 / `.DS_Store`、含真实 SMBIOS 的配置或备份。
- commit message 说清「改了什么、为什么」即可，中英文都行。
- 新增文档请同时考虑：这条信息对**没有这台机器的人**是否也有用？如果只是本机专属的修补，
  请注明适用条件，别写成通用结论。

---

## 许可证

脚本与文档为 [MIT](LICENSE)；`EFI/OC/Kexts/` 与 `EFI/OC/Resources/` 内的第三方预编译二进制
及主题资源遵循各自上游条款，不在 MIT 覆盖范围内。提交第三方文件时请保留原始文件头与许可证。
