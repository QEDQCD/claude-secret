#!/usr/bin/env bash
# 卸载脚本：删除部署的 wrapper / 加密器，并移除 ~/.bashrc 里由 install.sh 写入的片段。
# 默认保留 token.enc（真正的密文），除非加 --purge。
#
# 用法：
#   bash uninstall.sh          # 只删脚本和 bashrc 片段
#   bash uninstall.sh --purge  # 连 token.enc 一起删

set -euo pipefail

TARGET_DIR="${CLAUDE_HOME:-$HOME/.claude}"
BASHRC="${BASHRC:-$HOME/.bashrc}"
MARK_BEGIN="# >>> claude-secret >>>"
MARK_END="# <<< claude-secret <<<"

purge=0
for arg in "$@"; do
    case "$arg" in
        --purge) purge=1 ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "未知参数：$arg" >&2; exit 2 ;;
    esac
done

echo "[1/2] 删除部署文件 ..."
rm -f "$TARGET_DIR/claude-wrapper.sh" "$TARGET_DIR/encrypt-token.sh"
if [[ "$purge" -eq 1 ]]; then
    rm -f "$TARGET_DIR/token.enc"
    echo "     已删除 token.enc"
else
    [[ -f "$TARGET_DIR/token.enc" ]] && echo "     保留 $TARGET_DIR/token.enc（如需删除加 --purge）"
fi

echo "[2/2] 清理 $BASHRC 中的 claude-secret 片段 ..."
if [[ -f "$BASHRC" ]] && grep -qF "$MARK_BEGIN" "$BASHRC"; then
    tmp="$(mktemp)"
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
        $0==b {skip=1; next}
        $0==e {skip=0; next}
        !skip
    ' "$BASHRC" > "$tmp"
    # 顺手压掉尾部多余空行
    sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$tmp" || true
    mv "$tmp" "$BASHRC"
    echo "     已移除。"
else
    echo "     未发现 claude-secret 片段，跳过。"
fi

echo "卸载完成 ✅ （在新终端生效，或执行 source $BASHRC）"
