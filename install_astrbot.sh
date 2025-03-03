#!/bin/bash

set -e  # 发生错误时立即退出

# 定义变量
BOT_DIR="/root/AstrBot"
SERVICE_FILE="/etc/systemd/system/astrbot.service"
PYTHON_VERSION="python3.12"

# 更新 APT 源（可选：使用阿里云源）
echo "配置 Ubuntu APT 源..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb http://archive.ubuntu.com/ubuntu $(lsb_release -cs) main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $(lsb_release -cs)-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $(lsb_release -cs)-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu $(lsb_release -cs)-security main restricted universe multiverse
EOF

# 更新系统并安装依赖
echo "更新系统并安装依赖..."
sudo apt update && sudo apt install -y git wget curl software-properties-common apt-transport-https ca-certificates

# 安装 Python 3.12
echo "安装 Python 3.12..."
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt update && sudo apt install -y $PYTHON_VERSION $PYTHON_VERSION-venv $PYTHON_VERSION-dev

echo "$PYTHON_VERSION 安装成功"

# 安装 Docker（官方方式）
echo "安装 Docker..."
sudo apt remove -y docker docker-engine docker.io containerd runc || true
sudo apt update
sudo apt install -y docker.io
systemctl start docker
systemctl enable docker

echo "Docker 安装完成"

# 配置 pip 使用国内镜像源
echo "配置 pip 国内源..."
mkdir -p ~/.pip
tee ~/.pip/pip.conf > /dev/null <<EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
EOF

echo "pip 国内源配置完成"

# 克隆 AstrBot 仓库
if [ ! -d "$BOT_DIR" ]; then
    echo "正在克隆 AstrBot 仓库..."
    git clone https://github.com/Soulter/AstrBot.git $BOT_DIR
else
    echo "AstrBot 目录已存在，跳过克隆..."
fi

cd $BOT_DIR

# 创建 Python 虚拟环境并安装依赖
echo "创建 Python 虚拟环境..."
$PYTHON_VERSION -m venv venv
source venv/bin/activate

echo "安装 AstrBot 依赖..."
pip install --upgrade pip
pip install -r requirements.txt

echo "AstrBot 依赖安装完成"

# 创建 systemd 服务文件
echo "创建 systemd 服务文件..."
tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=AstrBot Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$BOT_DIR
ExecStart=$BOT_DIR/venv/bin/python $BOT_DIR/main.py
Restart=always
Environment=PATH=$BOT_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin

[Install]
WantedBy=multi-user.target
EOF

# 启动 AstrBot 服务
echo "启动 AstrBot 服务..."
systemctl daemon-reload
systemctl enable astrbot.service
systemctl start astrbot.service
systemctl status astrbot.service --no-pager

echo "AstrBot 已成功部署并设置为开机自启！"
