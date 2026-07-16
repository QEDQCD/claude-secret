#!/usr/bin/env bash
# 一次性脚本：把明文 token 加密成 $CLAUDE_HOME/token.enc（默认 /root/.claude/token.enc）
# 用法：bash encrypt-token.sh
# 运行后会提示你输入要加密的 token，以及一个自定义密码。

set -euo pipefail

ENC_FILE="${CLAUDE_ENC_FILE:-${CLAUDE_HOME:-$HOME/.claude}/token.enc}"
mkdir -p "$(dirname "$ENC_FILE")"

read -rsp "请粘贴要加密的 token: " TOKEN
echo
if [[ -z "$TOKEN" ]]; then
  echo "token 为空，已取消。" >&2
  exit 1
fi
read -rsp "设置解锁密码: " PASS
echo
read -rsp "再次确认密码: " PASS2
echo

if [[ "$PASS" != "$PASS2" ]]; then
  echo "两次密码不一致，已取消。" >&2
  exit 1
fi

# AES-256-CBC + PBKDF2 加盐加密。
# 在明文前加一个 magic 前缀，解密时用来校验密码是否正确（CBC 本身没有认证）。
printf 'CLAUDE-SECRET-V1:%s' "$TOKEN" | openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt \
  -pass pass:"$PASS" -out "$ENC_FILE"

chmod 600 "$ENC_FILE"
unset TOKEN PASS PASS2
echo "已加密写入 $ENC_FILE （权限 600）"
