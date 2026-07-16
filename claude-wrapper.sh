# === Claude Code 加密解锁包装函数 ===
# 运行 `claude` 时先输密码解密 token，注入环境变量后再启动真正的 claude。
# 每次运行 claude 都要求输入密码：token 仅在本次进程存活期间存在，
# claude 退出后立即清除，不在 shell 会话内残留（方案 B）。
#
# 可通过环境变量覆盖：
#   CLAUDE_REAL_BIN   真实 claude 可执行文件的绝对路径
#   CLAUDE_ENC_FILE   加密 token 文件路径（默认 /root/.claude/token.enc）
claude() {
    local enc_file="${CLAUDE_ENC_FILE:-${CLAUDE_HOME:-$HOME/.claude}/token.enc}"

    # 定位真实的 claude 可执行文件：
    # 1) 显式 CLAUDE_REAL_BIN
    # 2) 常见安装路径
    # 3) PATH 中排除本函数后的第一个 claude
    local real_claude="${CLAUDE_REAL_BIN:-}"
    if [[ -z "$real_claude" ]]; then
        local cand
        for cand in \
            /root/.nvm/versions/node/*/bin/claude \
            /usr/local/node-*/bin/claude \
            /usr/local/bin/claude \
            /opt/homebrew/bin/claude
        do
            [[ -x "$cand" ]] && real_claude="$cand" && break
        done
    fi
    if [[ -z "$real_claude" ]]; then
        # 从 PATH 里找一个不是当前 shell 函数的 claude
        real_claude="$(type -aP claude 2>/dev/null | head -n1)"
    fi
    if [[ -z "$real_claude" || ! -x "$real_claude" ]]; then
        echo "找不到 claude 可执行文件，请设置 CLAUDE_REAL_BIN 环境变量。" >&2
        return 1
    fi

    if [[ ! -f "$enc_file" ]]; then
        echo "找不到加密文件 $enc_file，请先运行 encrypt-token.sh" >&2
        return 1
    fi

    local pass plain
    read -rsp "请输入密钥密码: " pass
    echo
    plain="$(openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
                -pass pass:"$pass" -in "$enc_file" 2>/dev/null)"
    unset pass
    # 校验 magic 前缀，抵御 CBC 无认证时"密码错也能出 16 字节乱码"
    local magic="CLAUDE-SECRET-V1:"
    if [[ "${plain:0:${#magic}}" != "$magic" ]]; then
        unset plain
        echo "解密失败：密码错误或文件损坏。" >&2
        return 1
    fi
    local token="${plain:${#magic}}"
    unset plain
    if [[ -z "$token" ]]; then
        echo "解密出的 token 为空，请重新加密。" >&2
        return 1
    fi

    # 仅为本次 claude 调用注入 token，运行结束后立即清除
    local rc
    ANTHROPIC_AUTH_TOKEN="$token" command "$real_claude" "$@"
    rc=$?
    unset token
    unset ANTHROPIC_AUTH_TOKEN
    return $rc
}
# === end ===
