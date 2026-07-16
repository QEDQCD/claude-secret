# claude-secret

给 [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/overview) 用的**本地 token 加密方案**：把 `ANTHROPIC_AUTH_TOKEN` 以 AES-256-CBC + PBKDF2 加密成密文文件，`claude` 命令被包装成一个 shell 函数——每次运行都会先向你要一次解锁密码，token 只在本次 `claude` 进程活着的时候存在，退出后立即从环境里清掉，不在 shell 会话或磁盘上以明文残留。

适合的场景：多人共用机器 / 担心 `~/.bashrc`、`history`、备份里泄露 token，但又不想把 token 放到 KMS 之类的重方案里。

---

## 目录结构

```
claude-secret/
├── claude-wrapper.sh   # claude 函数（source 到 shell）
├── encrypt-token.sh    # 生成 / 更新加密文件的交互式脚本
├── install.sh          # 一键安装
├── uninstall.sh        # 卸载
└── README.md
```

## 依赖

- `bash`（4+）
- `openssl`（用来 AES-256-CBC + PBKDF2 加解密）
- 已经装好的 `claude` CLI（`npm i -g @anthropic-ai/claude-code` 之类）

## 一键安装

```bash
git clone <this repo>        # 或者直接把这几个文件拷过来
cd claude-secret
bash install.sh
```

`install.sh` 会做四件事：

1. 检查 `openssl` / `bash` 依赖。
2. 把 `claude-wrapper.sh` 和 `encrypt-token.sh` 复制到 `~/.claude/`（可用 `CLAUDE_HOME` 环境变量覆盖）。
3. 在你的 `~/.bashrc` 里追加一段带标记的 `source` 行（幂等，重复安装不会重复写）。
4. 立刻交互式跑一次 `encrypt-token.sh`，让你把明文 token 加密成 `~/.claude/token.enc`（想跳过就加 `--no-encrypt`）。

装完之后，**开个新终端**（或 `source ~/.bashrc`），直接：

```bash
claude
# 请输入密钥密码: ******
# ... 正常进入 Claude Code
```

## 手动安装（不想跑 install.sh）

```bash
mkdir -p ~/.claude
cp claude-wrapper.sh encrypt-token.sh ~/.claude/
bash ~/.claude/encrypt-token.sh                     # 生成 ~/.claude/token.enc
echo 'source ~/.claude/claude-wrapper.sh' >> ~/.bashrc
source ~/.bashrc
```

## 换 token / 改密码

直接重新跑一次加密脚本覆盖 `token.enc`：

```bash
bash ~/.claude/encrypt-token.sh
```

## 卸载

```bash
bash uninstall.sh           # 只删脚本 + 清理 bashrc 片段，保留 token.enc
bash uninstall.sh --purge   # 连 token.enc 也删掉
```

## 可配置的环境变量

包装函数和脚本都认这几个环境变量，方便在非默认路径下用：

| 变量 | 默认值 | 说明 |
|---|---|---|
| `CLAUDE_HOME`      | `~/.claude`                | 脚本与密文的部署目录 |
| `CLAUDE_ENC_FILE`  | `$CLAUDE_HOME/token.enc`   | 密文文件路径 |
| `CLAUDE_REAL_BIN`  | 自动探测                    | 真实的 `claude` 可执行文件路径（当自动探测不到时指定） |

自动探测顺序：`CLAUDE_REAL_BIN` → `/root/.nvm/versions/node/*/bin/claude` → `/usr/local/node-*/bin/claude` → `/usr/local/bin/claude` → `/opt/homebrew/bin/claude` → `PATH` 里第一个 `claude`。

如果你的 `claude` 装在别的位置，导出一下就行：

```bash
export CLAUDE_REAL_BIN=/your/path/to/claude
```

## 加密细节

- 算法：`openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt`
- 明文里加了一个 `CLAUDE-SECRET-V1:` magic 前缀，解密后由 wrapper 校验——用来防止 AES-CBC 无认证时"密码错也能解出 16 字节乱码"被当成 token 直接注入。
- 密文文件权限：`600`
- 解密只在内存里发生，token 通过环境变量 `ANTHROPIC_AUTH_TOKEN` 传给子进程 `claude`，包装函数 `return` 前 `unset` 掉。
- **注意**：这套方案能防"静态泄露"（`.bashrc`、备份、`history`、误 `cat`），但防不了 root/同 UID 恶意进程通过 `/proc/<pid>/environ` 读 `claude` 子进程的环境变量。真要严防内存态窃取，得配合 Linux capabilities / seccomp / 单独用户来跑。

## FAQ

**Q：`zsh` / `fish` 能用吗？**
`claude-wrapper.sh` 是 bash 语法（`[[ ]]`、`local`、`read -rsp`）。zsh 一般也能跑，改成 `source` 到 `~/.zshrc` 即可；fish 需要自己翻译一遍。

**Q：为什么每次都要输密码，不能缓存一段时间？**
这就是设计目标（"方案 B"）：token 不进入 shell 环境，只活在 `claude` 进程里。想要"输一次记 N 分钟"的话，可以自己把解密结果缓存到内存文件系统 / `gpg-agent` / `keyring`，但那属于另一种权衡。

**Q：密码忘了怎么办？**
没有找回。重新拿到明文 token 之后重新加密一次即可（`bash ~/.claude/encrypt-token.sh`）。
