#!/bin/bash
# =====================================================================
# 关闭开机啰嗦模式（可选收尾）
# 从 OpenCore config.plist 的 boot-args 中移除 -v 与 debug=0x100
# 保留 alcid / darkwake / lilucpu / keepsyms / -ibtcompatbeta 等原有参数
#
# 用法: 双击运行；或 sudo bash scripts/03-disable-verbose-boot.command --dry-run
# =====================================================================
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    export BT_LOG="$HOME/Desktop/开机静默-日志.txt"
    echo "需要管理员权限，请输入登录密码（输入时不显示字符）…"
    exec sudo -E /bin/bash "$0" "$@"
fi
BT_LOG="${BT_LOG:-/tmp/cleanup-bootargs.log}"
exec > >(tee "$BT_LOG") 2>&1

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1
STAMP=$(date +%Y%m%d-%H%M%S)

echo "=================================================================="
echo " 关闭开机啰嗦模式  $(date '+%Y-%m-%d %H:%M:%S')"
[ "$DRY" = "1" ] && echo " *** 预览模式：不修改任何文件 ***"
echo "=================================================================="
echo

echo "[1/3] 查找 OpenCore 的 EFI 分区…"
EFI_DEV=""; CFG=""
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
    if [ -n "$found" ]; then EFI_DEV="$dev"; CFG="$found"; echo "  ✓ 配置: $CFG"; break; fi
done

[ -z "$CFG" ] && { echo "  ✗ 没找到 config.plist"; echo; read -n 1 -s -r -p "按任意键关闭…"; exit 1; }

echo
echo "[2/3] 备份…"
BACKUP_DIR=$(dirname "$BT_LOG")/efi-backup-$STAMP
mkdir -p "$BACKUP_DIR"
if [ "$DRY" = "1" ]; then echo "  (预览) 将备份到 $BACKUP_DIR"; else
    cp "$CFG" "$BACKUP_DIR/config.plist.bak" && echo "  ✓ 已备份到 $BACKUP_DIR"
fi

echo
echo "[3/3] 清理启动参数…"
python3 - "$CFG" "$DRY" <<'PY'
import sys, plistlib
cfg, dry = sys.argv[1], sys.argv[2] == "1"
with open(cfg, "rb") as f:
    data = plistlib.load(f)

GUID = "7C436110-AB2A-4BBB-A880-FE41995C9F82"
add = data.get("NVRAM", {}).get("Add", {}).get(GUID, {})
old = add.get("boot-args")
if old is None:
    print("  · config.plist 里没有设置 boot-args（可能靠 NVRAM 原生值），无需修改。")
    raise SystemExit(0)

args = old.split()
DROP = {"-v", "debug=0x100"}
new_args = [a for a in args if a not in DROP]
removed = [a for a in args if a in DROP]

print("  原参数: %s" % old)
if not removed:
    print("  · 已经是干净状态，无需修改。")
    raise SystemExit(0)
print("  将移除: %s" % " ".join(removed))
print("  新参数: %s" % " ".join(new_args))

if dry:
    print("  (预览) 未写入文件")
    raise SystemExit(0)

add["boot-args"] = " ".join(new_args)
# 补齐 NVRAM Delete 登记，避免旧值残留
dele = data.setdefault("NVRAM", {}).setdefault("Delete", {}).setdefault(GUID, [])
if "boot-args" not in dele:
    dele.append("boot-args")
with open(cfg, "wb") as f:
    plistlib.dump(data, f)
print("  ✓ 已写入 config.plist")
PY

echo
echo "=================================================================="
if [ "$DRY" = "1" ]; then
    echo " 预览结束，未做任何修改。"
else
    echo " ✓ 完成。重启后开机不再显示代码滚动。"
    echo "   出问题可把 $BACKUP_DIR/config.plist.bak 拷回 EFI 恢复。"
fi
echo "=================================================================="
echo
read -n 1 -s -r -p "按任意键关闭本窗口…"
