#!/usr/bin/env bash
# 一键安装脚本：把 claude-wrapper.sh / encrypt-token.sh 部署到 ~/.claude/，
# 并在你的 ~/.bashrc 里追加一行 source 加载 wrapper。
# 可选：立刻引导你把明文 token 加密成 ~/.claude/token.enc。
#
# 用法：
#   bash install.sh              # 交互式安装
#   bash install.sh --no-encrypt # 只部署脚本，不立刻加密 token
#   bash install.sh --uninstall  # 卸载（见 uninstall.sh）
#
# 幂等：重复运行不会重复写 .bashrc。

set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${CLAUDE_HOME:-$HOME/.claude}"
BASHRC="${BASHRC:-$HOME/.bashrc}"
MARK_BEGIN="# >>> claude-secret >>>"
MARK_END="# <<< claude-secret <<<"

do_encrypt=1
for arg in "$@"; do
    case "$arg" in
        --no-encrypt) do_encrypt=0 ;;
        --uninstall)  exec bash "$SRC_DIR/uninstall.sh" ;;
        -h|--help)
            sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "未知参数：$arg" >&2; exit 2 ;;
    esac
done

echo "[1/4] 检查依赖 ..."
for cmd in openssl bash; do
    command -v "$cmd" >/dev/null || { echo "缺少依赖：$cmd" >&2; exit 1; }
done

echo "[2/4] 部署脚本到 $TARGET_DIR ..."
mkdir -p "$TARGET_DIR"
install -m 0644 "$SRC_DIR/claude-wrapper.sh" "$TARGET_DIR/claude-wrapper.sh"
install -m 0755 "$SRC_DIR/encrypt-token.sh"  "$TARGET_DIR/encrypt-token.sh"

echo "[3/4] 更新 $BASHRC ..."
touch "$BASHRC"
if grep -qF "$MARK_BEGIN" "$BASHRC"; then
    echo "     已存在 claude-secret 片段，跳过写入。"
else
    {
        echo ""
        echo "$MARK_BEGIN"
        echo "# 加载 Claude Code 加密解锁包装函数（由 claude-secret/install.sh 添加）"
        echo "[ -f \"$TARGET_DIR/claude-wrapper.sh\" ] && source \"$TARGET_DIR/claude-wrapper.sh\""
        echo "$MARK_END"
    } >> "$BASHRC"
    echo "     已追加 source 行。"
fi

echo "[4/4] 处理 token ..."
if [[ "$do_encrypt" -eq 1 ]]; then
    if [[ -f "$TARGET_DIR/token.enc" ]]; then
        read -rp "     $TARGET_DIR/token.enc 已存在，是否覆盖？[y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || { echo "     跳过加密。"; do_encrypt=0; }
    fi
fi
if [[ "$do_encrypt" -eq 1 ]]; then
    CLAUDE_HOME="$TARGET_DIR" bash "$TARGET_DIR/encrypt-token.sh"
else
    echo "     未加密 token；稍后可手动执行：bash $TARGET_DIR/encrypt-token.sh"
fi

cat <<EOF

安装完成 ✅
  - wrapper : $TARGET_DIR/claude-wrapper.sh
  - 加密器  : $TARGET_DIR/encrypt-token.sh
  - 密文    : $TARGET_DIR/token.enc  $( [[ -f "$TARGET_DIR/token.enc" ]] && echo "(已生成)" || echo "(未生成)" )
  - bashrc  : $BASHRC 已追加 source 片段

在新终端（或执行 \`source $BASHRC\`）后，直接运行 \`claude\` 即可，
每次会提示输入解锁密码，token 只在本次 claude 进程期间存在。
EOF
