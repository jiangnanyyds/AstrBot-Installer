#!/bin/bash

set -e  # 发生错误时立即退出

# 定义变量
BOT_DIR="/root/AstrBot"
SERVICE_FILE="/etc/systemd/system/astrbot.service"
PYTHON_VERSION="python3.12"

# 检查 apt 是否存在，如果不存在尝试修复
echo "检查 apt 是否已安装..."

if ! command -v apt &>/dev/null; then
    echo "错误：apt 命令未找到，尝试修复..."

    # 检查是否可以使用 dpkg 安装 apt
    if command -v dpkg &>/dev/null; then
        echo "dpkg 已安装，尝试修复 apt..."

        # 下载并安装 apt
        sudo dpkg --configure -a
        sudo apt-get install -f
        
        echo "apt 安装或修复完成"
    else
        echo "无法修复 apt，因为 dpkg 也未安装，建议重新安装操作系统或修复系统环境"
        exit 1
    fi
else
    echo "apt 已安装"
fi

# 修改 apt 源为国内镜像
echo "配置 apt 为国内镜像源..."

sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list > /dev/null <<EOF
# 国内源
deb https://mirrors.163.com/debian/ stable main contrib non-free
deb-src https://mirrors.163.com/debian/ stable main contrib non-free
deb https://mirrors.163.com/debian-security stable/updates main contrib non-free
deb-src https://mirrors.163.com/debian-security stable/updates main contrib non-free
deb https://mirrors.163.com/debian/ stable-updates main contrib non-free
deb-src https://mirrors.163.com/debian/ stable-updates main contrib non-free
deb https://mirrors.163.com/debian/ stable-backports main contrib non-free
deb-src https://mirrors.163.com/debian/ stable-backports main contrib non-free
EOF

# 更新系统并安装依赖
echo "更新系统并安装依赖..."
sudo apt update && sudo apt install -y git wget curl docker.io sudo

# 安装 Python 3.12，如果未能安装则尝试修复
echo "安装 Python 3.12..."

# 检查 Python 3.12 是否已安装
if ! command -v $PYTHON_VERSION &>/dev/null; then
    echo "$PYTHON_VERSION 未找到，尝试安装..."

    # 尝试添加 PPA 并安装 Python 3.12
    if command -v add-apt-repository &>/dev/null; then
        sudo add-apt-repository ppa:deadsnakes/ppa
        sudo apt update
    fi

    sudo apt install -y $PYTHON_VERSION $PYTHON_VERSION-venv $PYTHON_VERSION-dev

    # 如果 Python 安装失败，尝试手动编译安装
    if ! command -v $PYTHON_VERSION &>/dev/null; then
        echo "Python 3.12 安装失败，尝试手动编译安装..."
        
        # 下载 Python 3.12 源代码并编译安装
        cd /tmp
        wget https://www.python.org/ftp/python/3.12.0/Python-3.12.0.tgz
        tar -xvzf Python-3.12.0.tgz
        cd Python-3.12.0
        
        # 安装构建依赖
        sudo apt install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev curl
        
        # 编译并安装 Python
        ./configure --enable-optimizations
        make -j $(nproc)
        sudo make altinstall

        # 检查安装结果
        if ! command -v $PYTHON_VERSION &>/dev/null; then
            echo "手动安装 Python 3.12 失败，请检查系统兼容性。"
            exit 1
        fi
    fi
fi

# 确保 Python 版本正确
if ! command -v $PYTHON_VERSION &>/dev/null; then
    echo "错误：未能成功安装 $PYTHON_VERSION，请检查您的系统是否支持 Python 3.12。"
    exit 1
else
    echo "$PYTHON_VERSION 安装成功"
fi

# 启动并启用 Docker（如果未运行）
echo "启动 Docker 并设置开机自启..."
systemctl start docker
systemctl enable docker
echo "Docker 启动并设置为开机自启完成"

# 配置 Docker 国内镜像源
echo "配置 Docker 镜像加速器为国内源..."
mkdir -p ~/.docker
echo '{
  "registry-mirrors": ["https://registry.docker-cn.com"]
}' > ~/.docker/daemon.json
systemctl restart docker
echo "Docker 镜像加速器配置完成"

# 配置 pip 使用国内镜像源
echo "配置 pip 使用国内镜像源..."
mkdir -p ~/.pip
echo "[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple" > ~/.pip/pip.conf

# 克隆 AstrBot 仓库
if [ ! -d "$BOT_DIR" ]; then
    echo "正在克隆 AstrBot 仓库..."
    git clone https://github.com/Soulter/AstrBot.git $BOT_DIR
else
    echo "AstrBot 目录已存在，跳过克隆..."
fi

cd $BOT_DIR

# 创建虚拟环境并安装依赖
echo "创建 Python 虚拟环境..."
$PYTHON_VERSION -m venv venv
source venv/bin/activate

echo "安装 AstrBot 依赖..."
pip install --upgrade pip
pip install -r requirements.txt
echo "AstrBot 依赖安装完成"

# 创建 systemd 服务文件
echo "创建 systemd 服务文件..."
cat <<EOF > $SERVICE_FILE
[Unit]
Description=AstrBot Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$BOT_DIR
ExecStart=sudo -E $BOT_DIR/venv/bin/python $BOT_DIR/main.py
Restart=always
Environment=PATH=$BOT_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置并启动服务
echo "重新加载 systemd 并启动 AstrBot..."
systemctl daemon-reload
systemctl enable astrbot.service
systemctl start astrbot.service

# 检查服务状态
echo "AstrBot 部署完成，检查运行状态..."
systemctl status astrbot.service --no-pager

echo "AstrBot 已成功部署并设置为开机自启！"
systemctl status astrbot.service --no-pager
