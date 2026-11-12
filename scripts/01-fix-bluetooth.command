#!/bin/bash
# =====================================================================
# 黑苹果 Intel 蓝牙修复脚本 v2  (macOS 26 Tahoe / Intel 9560)
# 机器: MacBookPro16,1 仿冒 / i5-10210U / Intel 9560 (蓝牙 USB 8087:0AAA)
#
# v2 修复: 改用分区类型(EFI)精确定位 EFI 分区, 不再依赖文本匹配;
#          全流程写入桌面日志, 结束不自动关窗。
#
# 用法: 双击运行 / sudo bash scripts/01-fix-bluetooth.command [--dry-run]
#       --dry-run 只预览, 不改任何文件
# =====================================================================
set -uo pipefail

# ---- 提升权限（保留原始用户的桌面路径用于日志）----
if [ "$(id -u)" -ne 0 ]; then
    export BT_LOG="$HOME/Desktop/修复蓝牙-日志.txt"
    echo "需要管理员权限，请输入登录密码（输入时不显示字符）…"
    exec sudo -E /bin/bash "$0" "$@"
fi
BT_LOG="${BT_LOG:-/tmp/fix-bluetooth.log}"
exec > >(tee "$BT_LOG") 2>&1

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1
STAMP=$(date +%Y%m%d-%H%M%S)

echo "=================================================================="
echo " 黑苹果 Intel 蓝牙修复  $(date '+%Y-%m-%d %H:%M:%S')"
[ "$DRY" = "1" ] && echo " *** 预览模式：只显示将要做的事，不修改任何文件 ***"
echo "=================================================================="
echo

# ---------------------------------------------------------------
# 1. 找到装有 OpenCore 的 EFI 分区
# ---------------------------------------------------------------
echo "[1/4] 查找 OpenCore 的 EFI 分区…"

EFI_DEV=""; EFI_MNT=""
EFI_LIST=$(python3 - <<'PY'
import subprocess, plistlib
out = subprocess.run(["diskutil","list","-plist"], capture_output=True).stdout
d = plistlib.loads(out)
ids = []
for disk in d.get("AllDisksAndPartitions", []):
    for p in disk.get("Partitions", []):
        if (p.get("Content") or "").upper() == "EFI":
            ids.append(p["DeviceIdentifier"])
print(" ".join(ids))
PY
)

if [ -z "$EFI_LIST" ]; then
    echo "  ✗ 系统里没有任何 EFI 分区？这不正常，请把日志发我。"
    echo; read -n 1 -s -r -p "按任意键关闭…"; exit 1
fi
echo "  发现 EFI 分区: $EFI_LIST"

for dev in $EFI_LIST; do
    diskutil mount "$dev" >/dev/null 2>&1
    mnt=$(diskutil info -plist "$dev" 2>/dev/null | python3 -c '
import sys,plistlib
try:
    print(plistlib.loads(sys.stdin.buffer.read()).get("MountPoint") or "")
except Exception:
    print("")
')
    [ -z "$mnt" ] && [ -d /Volumes/EFI ] && mnt=/Volumes/EFI
    [ -z "$mnt" ] && continue
    echo "  · $dev 挂在 $mnt"

    # 在 EFI 分区里找 config.plist（最多下钻 3 层）
    found=$(find "$mnt" -maxdepth 3 -iname "config.plist" 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        EFI_DEV="$dev"; EFI_MNT="$mnt"; CFG="$found"
        break
    fi
done

if [ -z "$EFI_DEV" ]; then
    echo "  ✗ 所有 EFI 分区里都没找到 config.plist。"
    echo "    已挂载的 EFI 内容如下，请把这段发给开发者："
    for d in $(ls -d /Volumes/*/ 2>/dev/null); do
        [ -d "$d/EFI" ] && { echo "    --- $d ---"; find "$d" -maxdepth 3 2>/dev/null | head -30; }
    done
    echo; read -n 1 -s -r -p "按任意键关闭…"; exit 1
fi

OC_DIR=$(dirname "$(dirname "$CFG")")     # .../EFI/OC
echo "  ✓ OpenCore 配置: $CFG"
echo "  ✓ 所在分区: $EFI_DEV"

# ---------------------------------------------------------------
# 2. 备份
# ---------------------------------------------------------------
echo
echo "[2/4] 备份配置…"
BACKUP_DIR=$(dirname "$BT_LOG")/efi-backup-$STAMP
mkdir -p "$BACKUP_DIR"
cp "$CFG" "$BACKUP_DIR/config.plist.bak" && echo "  ✓ 已备份到 $BACKUP_DIR"
for k in "$OC_DIR"/Kexts/*USB*.kext; do
    [ -f "$k/Contents/Info.plist" ] && cp "$k/Contents/Info.plist" "$BACKUP_DIR/$(basename "$k").Info.plist" 2>/dev/null
done

# ---------------------------------------------------------------
# 3. 改 config.plist：NVRAM 变量 + 启动参数
# ---------------------------------------------------------------
echo
echo "[3/4] 修改 config.plist（NVRAM 变量 + 启动参数）…"
python3 - "$CFG" "$DRY" <<'PY'
import sys, plistlib, copy
cfg, dry = sys.argv[1], sys.argv[2] == "1"
with open(cfg, "rb") as f:
    data = plistlib.load(f)
orig = copy.deepcopy(data)
GUID = "7C436110-AB2A-4BBB-A880-FE41995C9F82"
changes = []

nv  = data.setdefault("NVRAM", {})
add = nv.setdefault("Add", {}).setdefault(GUID, {})
dele= nv.setdefault("Delete", {}).setdefault(GUID, [])

cur = add.get("boot-args", "")
if "-ibtcompatbeta" not in cur:
    add["boot-args"] = (cur + " -ibtcompatbeta").strip()
    changes.append(f"启动参数: '{cur}'  ->  '{add['boot-args']}'")

if add.get("bluetoothInternalControllerInfo") != b"\x00" * 14:
    add["bluetoothInternalControllerInfo"] = b"\x00" * 14
    changes.append("新增 bluetoothInternalControllerInfo = 28 个 0")
if add.get("bluetoothExternalDongleFailed") != b"\x00":
    add["bluetoothExternalDongleFailed"] = b"\x00"
    changes.append("新增 bluetoothExternalDongleFailed = 00")
for k in ("bluetoothInternalControllerInfo", "bluetoothExternalDongleFailed"):
    if k not in dele:
        dele.append(k)

if data == orig:
    print("  = 已是目标状态，无需改动")
else:
    for c in changes: print("  · " + c)
    if dry:
        print("  （预览模式：未写入）")
    else:
        with open(cfg, "wb") as f: plistlib.dump(data, f)
        print("  ✓ 已写入 config.plist")
PY

# ---------------------------------------------------------------
# 4. 改 USB 定制：蓝牙端口类型 = 255
# ---------------------------------------------------------------
echo
echo "[4/4] 检查 USB 定制里的蓝牙端口（Port 10 / HS10）…"
python3 - "$OC_DIR" "$DRY" <<'PY'
import sys, os, plistlib, glob, copy
oc, dry = sys.argv[1], sys.argv[2] == "1"
BT_PORT = b"\x0a\x00\x00\x00"
cands = sorted(set(glob.glob(os.path.join(oc, "Kexts", "*USB*.kext"))))
if not cands:
    print("  ! EFI/OC/Kexts 里没有 USBMap/USBPorts，说明 USB 端口未做定制。")
    print("    这种情况下蓝牙控制器可能仍起不来，需要另外用 USBToolBox 重新定制。")
    sys.exit(0)
done_any = False
for kext in cands:
    info = os.path.join(kext, "Contents/Info.plist")
    if not os.path.exists(info): continue
    with open(info, "rb") as f: pl = plistlib.load(f)
    orig = copy.deepcopy(pl); hit = False
    for pname, pers in (pl.get("IOKitPersonalities") or {}).items():
        ports = ((pers.get("IOProviderMergeProperties") or {}).get("ports")) or {}
        for portname, port in ports.items():
            if isinstance(port, dict) and port.get("port") == BT_PORT:
                old = port.get("UsbConnector")
                if old != 255:
                    port["UsbConnector"] = 255
                    print(f"  · {os.path.basename(kext)}: {portname}(Port 10) 类型 {old} -> 255(内置)")
                    hit = True
                else:
                    print(f"  = {os.path.basename(kext)}: {portname} 已正确")
                done_any = True
    if hit:
        if dry: print("  （预览模式：未写入）")
        else:
            with open(info, "wb") as f: plistlib.dump(pl, f)
            print(f"  ✓ 已写入 {os.path.basename(kext)}")
if not done_any:
    print("  ! 没在 USB 定制里找到 Port 10 这个端口定义，稍后需手工确认。")
PY

# ---------------------------------------------------------------
# 收尾
# ---------------------------------------------------------------
diskutil unmount "$EFI_DEV" >/dev/null 2>&1 && echo && echo "  EFI 分区已卸载"

echo
echo "=================================================================="
if [ "$DRY" = "1" ]; then
    echo " 预览结束，未修改任何文件。"
    echo " 确认无误后，在同目录执行： sudo bash 修复蓝牙.command"
else
    echo " 完成。请【完整重启】电脑（不是注销）。"
    echo
    echo " 重启后自检命令："
    echo "   system_profiler SPBluetoothDataType | head -20"
    echo " 正常应看到 Address 有值、State: On、固件不是 v0 c0。"
    echo
    echo " 备份位置： $BACKUP_DIR"
fi
echo " 运行日志： $BT_LOG"
echo "=================================================================="
echo
read -n 1 -s -r -p "按任意键关闭本窗口…"
echo
