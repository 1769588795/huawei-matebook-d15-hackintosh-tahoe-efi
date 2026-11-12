#!/bin/bash
# =====================================================================
# 把本机的 OpenCore EFI 导出到本仓库，并自动脱敏序列号
#
# 做三件事：
#   1. 挂载 EFI 分区，把 EFI/OC 与 EFI/BOOT 整份复制到本仓库 EFI/ 下
#   2. 抹掉 config.plist 里属于「这台机器」的隐私值
#      （序列号 / MLB / UUID / ROM / 蓝牙 MAC）
#   3. 把权限交还给当前用户，并打成一个 zip 放到桌面
#
# 用法: 双击运行（会提示输入登录密码）
#       sudo bash scripts/00-export-efi.command --dry-run   只预览
# =====================================================================
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
    export ORIG_USER="${USER}"
    echo "需要管理员权限来挂载 EFI 分区，请输入登录密码（输入时不显示字符）…"
    exec sudo -E /bin/bash "$0" "$@"
fi
ORIG_USER="${ORIG_USER:-$(stat -f %Su /dev/console)}"
# 提权后 $HOME 可能变成 /var/root，显式还原成原用户的目录
ORIG_HOME=$(eval echo "~$ORIG_USER")
[ -d "$ORIG_HOME/Desktop" ] || ORIG_HOME="$HOME"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG="$ORIG_HOME/Desktop/导出EFI-日志.txt"
exec > >(tee "$LOG") 2>&1

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

echo "=================================================================="
echo " 导出 OpenCore EFI → 仓库    $(date '+%Y-%m-%d %H:%M:%S')"
[ "$DRY" = "1" ] && echo " *** 预览模式：不复制、不修改任何文件 ***"
echo " 仓库: $REPO_ROOT"
echo "=================================================================="
echo

# ---------------------------------------------------------------
# 1. 定位 EFI 分区
# ---------------------------------------------------------------
echo "[1/4] 查找 OpenCore 所在的 EFI 分区…"
EFI_DEV=""; EFI_MNT=""; CFG=""
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
[ -z "$EFI_LIST" ] && { echo "  ✗ 没有找到任何 EFI 分区"; echo; read -n 1 -s -r -p "按任意键关闭…"; exit 1; }
echo "  发现 EFI 分区: $EFI_LIST"

for dev in $EFI_LIST; do
    diskutil mount "$dev" >/dev/null 2>&1
    mnt=$(diskutil info -plist "$dev" 2>/dev/null | python3 -c '
import sys,plistlib
try: print(plistlib.loads(sys.stdin.buffer.read()).get("MountPoint") or "")
except Exception: print("")
')
    [ -z "$mnt" ] && [ -d /Volumes/EFI ] && mnt=/Volumes/EFI
    [ -z "$mnt" ] && continue
    found=$(find "$mnt" -maxdepth 3 -iname "config.plist" 2>/dev/null | head -1)
    if [ -n "$found" ]; then EFI_DEV="$dev"; EFI_MNT="$mnt"; CFG="$found"; echo "  ✓ $dev → $mnt"; break; fi
done
[ -z "$CFG" ] && { echo "  ✗ 所有 EFI 分区里都没有 config.plist，无法导出。"; echo; read -n 1 -s -r -p "按任意键关闭…"; exit 1; }

ESP_ROOT="$EFI_MNT/EFI"
[ -d "$ESP_ROOT/OC" ] || { echo "  ✗ $ESP_ROOT/OC 不存在，这不是 OpenCore 的 ESP"; echo; read -n 1 -s -r -p "按任意键关闭…"; exit 1; }
echo "  ✓ OpenCore: $ESP_ROOT/OC"
echo "  · 体积: $(du -sh "$ESP_ROOT" 2>/dev/null | awk '{print $1}')"

# ---------------------------------------------------------------
# 2. 复制到仓库
# ---------------------------------------------------------------
echo
echo "[2/4] 复制 EFI 到仓库…"
if [ "$DRY" = "1" ]; then
    echo "  (预览) 将复制 $ESP_ROOT/{OC,BOOT} → $REPO_ROOT/EFI/"
    echo "  (预览) 排除: Apple/ .DS_Store .Spotlight-V100 _backup"
else
    mkdir -p "$REPO_ROOT/EFI"
    for sub in OC BOOT; do
        [ -d "$ESP_ROOT/$sub" ] || { echo "  · 跳过 $sub（不存在）"; continue; }
        rm -rf "${REPO_ROOT:?}/EFI/$sub"
        # Apple 固件目录体积大且有版权，不收
        rsync -a \
            --exclude 'Apple/' \
            --exclude '.DS_Store' \
            --exclude '.Spotlight-V100' \
            --exclude '.fseventsd' \
            --exclude '*_backup*' \
            --exclude 'OC/Logs/' \
            "$ESP_ROOT/$sub" "$REPO_ROOT/EFI/" && echo "  ✓ $sub"
    done
    # OpenCore 在 ESP 根下有时还有 .contentVisibility 之类，忽略
fi

# ---------------------------------------------------------------
# 3. 脱敏
# ---------------------------------------------------------------
echo
echo "[3/4] 脱敏 config.plist…"
NEW_CFG="$REPO_ROOT/EFI/OC/config.plist"
if [ "$DRY" = "1" ]; then
    echo "  (预览) 将抹除 SystemSerialNumber / MLB / SystemUUID / ROM / 蓝牙 MAC"
else
    [ -f "$NEW_CFG" ] || { echo "  ✗ 没复制到 config.plist，跳过"; }
    if [ -f "$NEW_CFG" ]; then
        python3 - "$NEW_CFG" <<'PY'
import sys, plistlib
p = sys.argv[1]
with open(p, "rb") as f:
    d = plistlib.load(f)

PH = {
    "SystemSerialNumber": "REPLACE_WITH_GENSMBIOS",
    "MLB":                "REPLACE_WITH_GENSMBIOS",
    "SystemUUID":         "00000000-0000-0000-0000-000000000000",
    "ROM":                b"\x00" * 6,
}
gen = d.get("PlatformInfo", {}).get("Generic", {})
for k, v in PH.items():
    if k in gen:
        print(f"  · PlatformInfo.Generic.{k}: 已替换为占位符")
        gen[k] = v

# 蓝牙控制器 MAC 是设备指纹，去掉，让使用者自己跑 02 脚本注入
GUID = "7C436110-AB2A-4BBB-A880-FE41995C9F82"
nvr = d.get("NVRAM", {}).get("Add", {}).get(GUID, {})
if "BluetoothLocalHostAddress" in nvr:
    del nvr["BluetoothLocalHostAddress"]
    print("  · NVRAM.BluetoothLocalHostAddress: 已删除（用 scripts/02 重新注入）")
    dl = d.setdefault("NVRAM", {}).setdefault("Delete", {}).setdefault(GUID, [])
    if "BluetoothLocalHostAddress" not in dl:
        dl.append("BluetoothLocalHostAddress")
if "bluetoothInternalControllerInfo" in nvr:
    print("  · NVRAM.bluetoothInternalControllerInfo: 保留（全 0，无隐私）")

with open(p, "wb") as f:
    plistlib.dump(d, f)
print("  ✓ 已写回")
PY
        # 残留检查
        if grep -aoE '\b[A-Z0-9]{11,12}\b' "$NEW_CFG" | grep -qvE 'REPLACE_WITH|GENSMBIOS' ; then
            echo "  ⚠ 仍检测到疑似 11~12 位大写字串，发布前请手动 grep 确认："
            grep -aoE '\b[A-Z0-9]{11,12}\b' "$NEW_CFG" | sort -u | head -10 | sed 's/^/      /'
        fi
    fi
fi

# ---------------------------------------------------------------
# 4. 交还权限 + 打包
# ---------------------------------------------------------------
echo
echo "[4/4] 收尾…"
if [ "$DRY" != "1" ]; then
    chown -R "$ORIG_USER":staff "$REPO_ROOT" 2>/dev/null && echo "  ✓ 权限已交还给 $ORIG_USER"
    find "$REPO_ROOT" -name '.DS_Store' -delete 2>/dev/null

    ZIP="$ORIG_HOME/Desktop/$(basename "$REPO_ROOT").zip"
    rm -f "$ZIP"
    ( cd "$(dirname "$REPO_ROOT")" && ditto -c -k --sequesterRsrc --keepParent "$(basename "$REPO_ROOT")" "$ZIP" ) \
        && echo "  ✓ 已打包: $ZIP ($(du -h "$ZIP" | awk '{print $1}'))"

    diskutil unmount "$EFI_DEV" >/dev/null 2>&1 && echo "  ✓ 已卸载 $EFI_DEV"
fi

echo
echo "=================================================================="
if [ "$DRY" = "1" ]; then
    echo " 预览结束，未做任何修改。"
else
    echo " ✓ 导出完成。"
    echo
    echo " 检查这两处再发出去："
    echo "   1. EFI/OC/config.plist 里搜 REPLACE_WITH_GENSMBIOS 应该能搜到，"
    echo "      搜 SystemSerialNumber 不应该出现真实序列号。"
    echo "   2. EFI/ 里不应有 Apple/ 目录（有就删掉，体积大且有版权）。"
    echo
    echo " 打包文件: $ZIP"
    echo " 仓库位置: $REPO_ROOT"
    echo " 下一步: 看 PUBLISH.md"
fi
echo "=================================================================="
echo
read -n 1 -s -r -p "按任意键关闭本窗口…"
