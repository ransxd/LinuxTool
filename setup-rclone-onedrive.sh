#!/bin/bash

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 让用户输入挂载路径
echo -e "${YELLOW}请输入OneDrive的挂载路径:${NC}"
read -p "输入挂载路径(默认: /root/OD): " MOUNT_PATH
MOUNT_PATH=${MOUNT_PATH:-/root/OD}

echo -e "${GREEN}开始设置rclone挂载OneDrive到${MOUNT_PATH}${NC}"

# 检查是否以root运行
if [ "$(id -u)" != "0" ]; then
   echo -e "${RED}此脚本需要以root权限运行，请使用sudo或切换到root用户${NC}"
   exit 1
fi

# 检查并安装rclone
if ! command -v rclone &> /dev/null; then
    echo -e "${YELLOW}rclone未安装，正在安装...${NC}"
    curl https://rclone.org/install.sh | bash
    if [ $? -ne 0 ]; then
        echo -e "${RED}rclone安装失败，请手动安装后重试${NC}"
        exit 1
    fi
    echo -e "${GREEN}rclone安装成功${NC}"
else
    echo -e "${GREEN}rclone已安装${NC}"
fi

# 创建挂载点和缓存目录
echo -e "${YELLOW}创建挂载点和缓存目录...${NC}"
mkdir -p ${MOUNT_PATH}
mkdir -p /var/cache/rclone
chmod 700 /var/cache/rclone

# 检查已配置的远程存储
echo -e "${YELLOW}检查已配置的rclone远程存储...${NC}"
REMOTES=$(rclone listremotes)
echo -e "${GREEN}已配置的远程存储:${NC}"

# 创建远程存储数组
declare -a REMOTE_ARRAY
i=1
while read -r remote; do
    remote=${remote%:}
    REMOTE_ARRAY[$i]=$remote
    echo -e "$i) $remote"
    ((i++))
done <<< "$REMOTES"

# 让用户通过数字选择远程存储
echo -e "${YELLOW}请选择要挂载的OneDrive远程存储:${NC}"
read -p "输入选项编号(1-$((i-1))): " REMOTE_NUM

# 验证输入
if ! [[ "$REMOTE_NUM" =~ ^[0-9]+$ ]] || [ "$REMOTE_NUM" -lt 1 ] || [ "$REMOTE_NUM" -ge "$i" ]; then
    echo -e "${RED}错误: 无效的选项${NC}"
    exit 1
fi

# 获取选择的远程存储名称
REMOTE_NAME=${REMOTE_ARRAY[$REMOTE_NUM]}
echo -e "${GREEN}将使用 '${REMOTE_NAME}' 远程存储${NC}"

# 创建systemd服务文件
echo -e "${YELLOW}创建systemd服务文件...${NC}"
SERVICE_NAME="rclone-onedrive-$(echo $REMOTE_NAME | tr '[:upper:]' '[:lower:]')"
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=RClone OneDrive Mount (${REMOTE_NAME})
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/rclone mount ${REMOTE_NAME}: ${MOUNT_PATH} \\
  --vfs-cache-mode writes \\
  --buffer-size 64M \\
  --dir-cache-time 5m \\
  --vfs-read-chunk-size 32M \\
  --vfs-read-chunk-size-limit 1G \\
  --checkers 8 \\
  --transfers 4 \\
  --log-level INFO \\
  --log-file /var/log/rclone-${REMOTE_NAME}.log \\
  --cache-dir /var/cache/rclone \\
  --vfs-cache-max-size 5G \\
  --vfs-cache-max-age 4h \\
  --allow-other \\
  --attr-timeout 5m
ExecStop=/bin/fusermount -u ${MOUNT_PATH}
Restart=on-abort
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd配置并启用服务
echo -e "${YELLOW}启用并启动${SERVICE_NAME}服务...${NC}"
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

# 检查服务状态
sleep 3
if systemctl is-active --quiet ${SERVICE_NAME}; then
    echo -e "${GREEN}${SERVICE_NAME}服务已成功启动${NC}"
    echo -e "${GREEN}OneDrive已挂载到${MOUNT_PATH}${NC}"
    echo -e "${GREEN}缓存设置：最大空间5GB，最大缓存时间4小时${NC}"
    echo -e "${YELLOW}您可以使用以下命令检查挂载状态：${NC}"
    echo -e "  df -h ${MOUNT_PATH}"
    echo -e "  mount | grep rclone"
    echo -e "${YELLOW}您可以使用以下命令查看rclone日志：${NC}"
    echo -e "  tail -f /var/log/rclone-${REMOTE_NAME}.log"
else
    echo -e "${RED}${SERVICE_NAME}服务启动失败，请检查日志：${NC}"
    echo -e "  journalctl -u ${SERVICE_NAME}"
fi

echo -e "${GREEN}设置完成！${NC}"
