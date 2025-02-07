#!/bin/bash

set -e  # 发生错误时立即退出

# 定义变量
BOT_DIR="/root/AstrBot"
SERVICE_FILE="/etc/systemd/system/astrbot.service"
PYTHON_VERSION="python3.12"

# 更新系统并安装依赖
echo "更新系统并安装 Python..."
apt update && apt install -y $PYTHON_VERSION $PYTHON_VERSION-venv git wget curl

# 确保 Python 版本正确
if ! command -v $PYTHON_VERSION &>/dev/null; then
    echo "错误：未能成功安装 $PYTHON_VERSION，请检查您的系统是否支持 Python 3.12。"
    exit 1
fi

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
ExecStart=$BOT_DIR/venv/bin/python $BOT_DIR/main.py
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

