#!/bin/bash

# --- 常量定义 ---
readonly INV="hosts.yml"
readonly PB="site.yml"

# ==========================================================
# 严格检查流程：工具准备 -> 静态分析 -> 语法校验 -> 逻辑干跑
# ==========================================================

echo "--------------------------------------"
echo "🛠️ 正在进行三重严格检查..."
echo "--------------------------------------"

# 1. 确保环境就绪 (自动安装 ansible-lint)
if ! command -v ansible-lint &> /dev/null; then
    echo "⚠️ 检测到未安装 ansible-lint，正在尝试自动安装..."
    sudo apt update && sudo apt install -y ansible-lint
    
    if ! command -v ansible-lint &> /dev/null; then
        echo -e "\n❌ 无法自动安装 ansible-lint，请手动执行: sudo apt install ansible-lint"
        exit 1
    fi
    echo -e "✅ ansible-lint 安装成功。\n"
fi

# 2. 静态代码分析 (检测变量名空格、最佳实践等)
echo ">>> [1/3] 正在执行 ansible-lint 静态分析..."
if ! ansible-lint "$PB"; then
    echo -e "\n❌ 静态分析未通过，请检查代码规范 (如变量命名、缩进等)。"
    exit 1
fi

# 3. 基础语法校验
echo ">>> [2/3] 正在执行语法校验..."
if ! ansible-playbook -i "$INV" "$PB" --syntax-check; then
    echo -e "\n❌ 语法校验失败。"
    exit 1
fi

# 4. 逻辑干跑 (Dry Run - 触发变量合并，检测非法变量名)
# 此步骤会加载 host_vars 目录下的所有变量，能捕捉到私钥文件误读或变量名带空格的问题
echo ">>> [3/3] 正在执行 --check 模拟运行 (逻辑干跑)..."
if ! ansible-playbook -i "$INV" "$PB" --check; then
    echo -e "\n❌ 模拟运行失败！检测到运行时错误 (例如变量冲突、私钥读取异常或 secrets.yml 命名错误)。"
    exit 1
fi

echo -e "\n✅ 三重检查全部通过！准备开始正式部署...\n"

# ==========================================================
# 执行正式 Playbook
# ==========================================================
ansible-playbook -i "$INV" "$PB"
