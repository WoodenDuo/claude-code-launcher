#!/bin/bash

# Claude Code 快捷启动器安装脚本
# 用法: source ./install-claude-wrapper.sh [别名]

# 检测是否用 source 执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] 2>/dev/null; then
    echo -e "\033[0;31m错误: 请使用 source 执行此脚本\033[0m"
    echo ""
    echo "正确用法:"
    echo "    source ./install-claude-wrapper.sh                    # 默认别名 cla"
    echo "    source ./install-claude-wrapper.sh zz                 # 自定义别名"
    echo "    source ./install-claude-wrapper.sh cla --skip-permissions  # 免授权模式"
    echo ""
    exit 1
fi

# 默认别名（不要用 cc，会和系统 C 编译器冲突）
ALIAS="${1:-cla}"
SKIP_PERMISSIONS="${2:-}"  # 第二个参数：--skip-permissions 启用免授权
SHELL_RC="$HOME/.zshrc"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Claude Code 快捷启动器安装 ===${NC}\n"

# 检查 shell 配置文件
if [[ ! -f "$SHELL_RC" ]]; then
    echo -e "${YELLOW}注意: $SHELL_RC 不存在，将创建${NC}"
    touch "$SHELL_RC"
fi

# 检查是否已安装
if grep -q "# Claude Code 快捷启动器" "$SHELL_RC" 2>/dev/null; then
    echo -e "${YELLOW}检测到已安装，将更新配置...${NC}"
    # 删除旧配置
    sed -i '' '/# Claude Code 快捷启动器/,/^# END Claude Code 快捷启动器/d' "$SHELL_RC" 2>/dev/null || \
    sed -i '/# Claude Code 快捷启动器/,/^# END Claude Code 快捷启动器/d' "$SHELL_RC"
fi

# 写入新配置
local skip_perm_flag=""
local skip_perm_note=""
if [[ "$SKIP_PERMISSIONS" == "--skip-permissions" ]]; then
    skip_perm_flag="--dangerously-skip-permissions"
    skip_perm_note="（免授权模式）"
fi

cat >> "$SHELL_RC" << SCRIPT

# Claude Code 快捷启动器
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
  local temp_config="/tmp/.claude-frozen-config-\$\$.json"
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

# END Claude Code 快捷启动器
SCRIPT

echo -e "${GREEN}✓ 安装完成！${NC}\n"
echo "可以使用 ${ALIAS} 命令启动 Claude Code 了"

# 在当前 shell 立即定义函数（无需 source ~/.zshrc）
source "$SHELL_RC"
