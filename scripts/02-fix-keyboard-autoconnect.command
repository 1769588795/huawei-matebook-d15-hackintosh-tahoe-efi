#!/bin/bash
# =====================================================================
# 修复蓝牙键盘每次开机需要重新配对（黑苹果 / macOS 26）
#
# 原理: 往 OpenCore config.plist 的 NVRAM 注入
#   - BluetoothLocalHostAddress        蓝牙控制器 MAC（自动从当前系统读取）
#   - BluetoothAutoSeekKeyboard  = 01  开机自动连接已配对键盘
#   - BluetoothAutoSeekPointingDevice=01 开机自动连接已配对鼠标/触控板
#
# 用法: 双击运行；或 sudo bash scripts/02-fix-keyboard-autoconnect.command --dry-run
# =====================================================================
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    export BT_LOG="$HOME/Desktop/键盘自动连接-日志.txt"
    echo "需要管理员权限，请输入登录密码（输入时不显示字符）…"
    exec sudo -E /bin/bash "$0" "$@"
fi
BT_LOG="${BT_LOG:-/tmp/fix-keyboard.log}"
exec > >(tee "$BT_LOG") 2>&1

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1
STAMP=$(date +%Y%m%d-%H%M%S)

echo "=================================================================="
echo " 修复蓝牙键盘自动连接  $(date '+%Y-%m-%d %H:%M:%S')"
[ "$DRY" = "1" ] && echo " *** 预览模式：不修改任何文件 ***"
echo "=================================================================="
echo

# ---- 读取当前蓝牙控制器 MAC ----
MAC_RAW=$(system_profiler SPBluetoothDataType 2>/dev/null \
    | grep -m1 "Address:" | awk -F': ' '{print $2}')
if ! echo "$MAC_RAW" | grep -qE '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'; then
    echo "  ✗ 读取蓝牙控制器地址失败（当前读到: ${MAC_RAW:-空}）。"
    echo "    请确认蓝牙已打开，把这段日志发我。"
    echo; read -n 1 -s -r -p "按任意键关闭…"; exit 1
fi
MAC_HEX=$(echo "$MAC_RAW" | tr -d ':')
echo "[1/3] 蓝牙控制器地址: $MAC_RAW  →  注入值: $MAC_HEX"

# ---- 找 config.plist ----
echo
echo "[2/3] 查找 OpenCore 配置…"
CFG=""
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
[ -z "$EFI_LIST" ] && { echo "  ✗ 没找到 EFI 分区"; echo; read -n 1 -s -r -p "按任意键关闭…"; exit 1; }

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
    found=$(find "$mnt" -maxdepth 3 -iname "config.plist" 2>/dev/null | head -1)
    if [ -n "$found" ]; then CFG="$found"; echo "  ✓ 配置: $CFG"; break; fi
done
[ -z "$CFG" ] && { echo "  ✗ 没找到 config.plist"; echo; read -n 1 -s -r -p "按任意键关闭…"; exit 1; }

# ---- 备份 + 注入 ----
echo
echo "[3/3] 备份并注入 NVRAM 变量…"
BACKUP_DIR=$(dirname "$BT_LOG")/efi-backup-$STAMP
mkdir -p "$BACKUP_DIR"
if [ "$DRY" = "1" ]; then echo "  (预览) 将备份到 $BACKUP_DIR"; else
    cp "$CFG" "$BACKUP_DIR/config.plist.bak" && echo "  ✓ 已备份到 $BACKUP_DIR"
fi

python3 - "$CFG" "$MAC_HEX" "$DRY" <<'PY'
import sys, plistlib
cfg, mac, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
with open(cfg, "rb") as f:
    data = plistlib.load(f)

GUID = "7C436110-AB2A-4BBB-A880-FE41995C9F82"
add  = data.setdefault("NVRAM", {}).setdefault("Add", {}).setdefault(GUID, {})
dele = data.setdefault("NVRAM", {}).setdefault("Delete", {}).setdefault(GUID, [])

payload = {
    # 控制器 MAC（ASCII 字符串，无冒号）
    "BluetoothLocalHostAddress": mac.encode("ascii"),
    # 开机自动连接键盘 / 指点设备（1 字节 0x01）
    "BluetoothAutoSeekKeyboard": b"\x01",
    "BluetoothAutoSeekPointingDevice": b"\x01",
}

for k, v in payload.items():
    cur = add.get(k)
    if cur == v:
        print(f"  · {k} 已是目标值，跳过")
        continue
    if cur is not None:
        print(f"  · {k}: {cur!r} -> {v!r}")
    else:
        print(f"  · 新增 {k} = {v!r}")

if dry:
    print("  (预览) 未写入文件")
    raise SystemExit(0)

add.update(payload)
for k in payload:
    if k not in dele:
        dele.append(k)
with open(cfg, "wb") as f:
    plistlib.dump(data, f)
print("  ✓ 已写入 config.plist")
PY

echo
echo "=================================================================="
if [ "$DRY" = "1" ]; then
    echo " 预览结束，未做任何修改。"
else
    echo " ✓ 完成。请【完整重启】。"
    echo "   重启后键盘应在进系统前/刚进系统时自动连上，不再需要重新配对。"
    echo "   若仍不行，说明配对本身没存住——在蓝牙设置里删掉键盘重新配对一次即可。"
fi
echo "=================================================================="
echo
read -n 1 -s -r -p "按任意键关闭本窗口…"
