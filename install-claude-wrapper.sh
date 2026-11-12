#!/bin/bash

# Claude Code 配置固化器 安装脚本
# 用法: source ./install-claude-wrapper.sh [别名] [--skip-permissions] [--shell=zsh|bash] [--rc=路径]
# 支持 macOS(zsh/bash) 与 Linux(bash/zsh)

# 检测是否用 source 执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] 2>/dev/null; then
    echo "错误: 请使用 source 执行此脚本"
    echo ""
    echo "正确用法:"
    echo "    source ./install-claude-wrapper.sh                          # 默认别名 cla，自动识别 shell"
    echo "    source ./install-claude-wrapper.sh zz                       # 自定义别名"
    echo "    source ./install-claude-wrapper.sh cla --skip-permissions   # 免授权模式"
    echo "    source ./install-claude-wrapper.sh --shell=bash             # 强制按 bash 安装"
    echo "    source ./install-claude-wrapper.sh --rc=/path/to/rc         # 指定 rc 文件"
    echo ""
    exit 1
fi

# ---------- 参数解析 ----------
ALIAS=""
SKIP_PERMISSIONS=""
SHELL_OVERRIDE=""
RC_OVERRIDE=""

for arg in "$@"; do
    case "$arg" in
        --skip-permissions)
            SKIP_PERMISSIONS=1
            ;;
        --shell=*)
            SHELL_OVERRIDE="${arg#*=}"
            ;;
        --rc=*)
            RC_OVERRIDE="${arg#*=}"
            ;;
        -h|--help)
            echo "用法: source install-claude-wrapper.sh [别名] [--skip-permissions] [--shell=zsh|bash] [--rc=路径]"
            return 0 2>/dev/null || exit 0
            ;;
        -*)
            echo "未知参数: $arg"
            return 1 2>/dev/null || exit 1
            ;;
        *)
            if [[ -z "$ALIAS" ]]; then
                ALIAS="$arg"
            else
                echo "多余参数: $arg"
                return 1 2>/dev/null || exit 1
            fi
            ;;
    esac
done

ALIAS="${ALIAS:-cla}"

# ---------- 识别 shell 与 rc 文件 ----------
if [[ -z "$SHELL_OVERRIDE" ]]; then
    case "$(basename "${SHELL:-unknown}")" in
        zsh)  SHELL_OVERRIDE="zsh" ;;
        *)    SHELL_OVERRIDE="bash" ;;
    esac
fi

if [[ -n "$RC_OVERRIDE" ]]; then
    SHELL_RC="$RC_OVERRIDE"
elif [[ "$SHELL_OVERRIDE" == "zsh" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$(uname -s)" == "Darwin" ]]; then
    SHELL_RC="$HOME/.bash_profile"   # macOS 的登录 bash 读这个
else
    SHELL_RC="$HOME/.bashrc"         # Linux 的交互 bash 读这个
fi

case "$SHELL_RC" in
    "~/"*) SHELL_RC="$HOME/${SHELL_RC#\~/}" ;;
esac

# ---------- 颜色 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Claude Code 配置固化器 安装 ===${NC}\n"
echo "别名      : ${ALIAS}"
echo "shell     : ${SHELL_OVERRIDE}"
echo "rc 文件   : ${SHELL_RC}"
echo "免授权    : ${SKIP_PERMISSIONS:+是}"
echo ""

# 检查 shell 配置文件
if [[ ! -f "$SHELL_RC" ]]; then
    echo -e "${YELLOW}注意: $SHELL_RC 不存在，将创建${NC}"
    touch "$SHELL_RC"
fi

# 检查是否已安装（顺带清理旧名称写下的段）
if grep -q "# Claude Code 快捷启动器" "$SHELL_RC" 2>/dev/null; then
    echo -e "${YELLOW}检测到旧版安装，将替换为新版...${NC}"
    sed -i '' '/# Claude Code 快捷启动器/,/^# END Claude Code 快捷启动器/d' "$SHELL_RC" 2>/dev/null || \
    sed -i '/# Claude Code 快捷启动器/,/^# END Claude Code 快捷启动器/d' "$SHELL_RC"
fi

if grep -q "# Claude Code 配置固化器" "$SHELL_RC" 2>/dev/null; then
    echo -e "${YELLOW}检测到已安装，将更新配置...${NC}"
    sed -i '' '/# Claude Code 配置固化器/,/^# END Claude Code 配置固化器/d' "$SHELL_RC" 2>/dev/null || \
    sed -i '/# Claude Code 配置固化器/,/^# END Claude Code 配置固化器/d' "$SHELL_RC"
fi

# ---------- 写入函数 ----------
skip_perm_flag=""
skip_perm_note=""
if [[ -n "$SKIP_PERMISSIONS" ]]; then
    skip_perm_flag="--dangerously-skip-permissions"
    skip_perm_note="（免授权模式）"
fi

cat >> "$SHELL_RC" << SCRIPT

# Claude Code 配置固化器
# 启动时固化当前全局配置，后续修改全局配置不影响已启动的会话
# 安装时间: $(date '+%Y-%m-%d %H:%M:%S')${skip_perm_note}

${ALIAS}() {
  local global_config="\$HOME/.claude/settings.json"

  if [[ ! -f "\$global_config" ]]; then
    claude ${skip_perm_flag} "\$@"
    return
  fi

  # 检查依赖工具
  if ! command -v python3 &>/dev/null && ! command -v python &>/dev/null && ! command -v jq &>/dev/null; then
    echo -e "\033[0;33m警告: 未找到 python 或 jq，无法固化配置，直接启动 claude\033[0m"
    claude ${skip_perm_flag} "\$@"
    return
  fi

  # 读取当前全局配置中的 env 部分
  local env_json=""
  if command -v python3 &>/dev/null; then
    env_json=\$(python3 -c "
import json, os
with open(os.path.expanduser('~/.claude/settings.json')) as f:
    config = json.load(f)
print(json.dumps(config.get('env', {})))
" 2>/dev/null)
  elif command -v python &>/dev/null; then
    env_json=\$(python -c "
import json, os
with open(os.path.expanduser('~/.claude/settings.json')) as f:
    config = json.load(f)
print(json.dumps(config.get('env', {})))
" 2>/dev/null)
  elif command -v jq &>/dev/null; then
    env_json=\$(jq -c '.env // {}' "\$global_config" 2>/dev/null)
  fi

  # 创建临时配置文件
  local tmp_dir="\${TMPDIR:-/tmp}"
  tmp_dir="\${tmp_dir%/}"
  local temp_config="\$tmp_dir/.claude-frozen-config-\$\$.json"
  echo "{\\"env\\": \$env_json}" > "\$temp_config"

  # 捕获退出信号，确保清理临时文件
  trap "rm -f \"\$temp_config\"" EXIT INT TERM

  # 使用 --settings 参数指定配置文件
  claude ${skip_perm_flag} --settings "\$temp_config" "\$@"
  local exit_code=\$?

  # 清理 trap 和临时文件
  trap - EXIT INT TERM
  rm -f "\$temp_config"

  return \$exit_code
}

# END Claude Code 配置固化器
SCRIPT

echo -e "${GREEN}✓ 安装完成！${NC}"
echo "现在执行 ${ALIAS} 即可启动 Claude Code（新开终端也已生效）"

# 在当前 shell 立即定义函数（无需重启终端）
[[ -f "$SHELL_RC" ]] && source "$SHELL_RC" >/dev/null 2>&1
