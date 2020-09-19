#!/bin/bash

# 谷歌云开启公私钥本地ssh登陆
# ssh-keygen -t rsa -C $user
# ssh user@host_ip -i ~/.ssh/id_rsa.pub

# 浏览器直接代理上网
# chromium-browser --proxy-server="socks5://127.0.0.1:1080"

# 添加swapfile
# sudo -i
# dd if=/dev/zero of=/swapfile bs=1024 count=1048576
# mkswap /swapfile
# chmod 600 /swapfile
# swapon /swapfile
# echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
# free -m  # 检查swapfile

# 开启TCP BBR加速
# echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
# echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
# sysctl -p
# 查看内核是否已开启BBR
# sysctl net.ipv4.tcp_available_congestion_control
# sysctl net.ipv4.tcp_congestion_control
# lsmod | grep bbr

# 设置本地ss-local开机自动运行
# sudo systemctl enable shadowsocks-libev-local@ss
# 将ss.json拷贝至/etc/shadowsocks-libev/目录下
# sudo systemctl restart shadowsocks-libev-local@ss
# 查看运行状态
# systemctl status shadowsocks-libev-local@ss

read -p "please input you server_port[1-6666]: " port
read -p "please input you password: " password
which ss-server &>/dev/null || apt install -y shadowsocks-libev
which obfs-server &>/dev/null || apt install -y simple-obfs
cat > /etc/shadowsocks-libev/config.json << EOF
{
    "server":"0.0.0.0",
    "server_port":${port},
    "local_port":1080,
    "password":"${password}",
    "timeout":600,
    "method":"aes-256-gcm",
    "fast_open":false,
    "plugin":"obfs-server",
    "plugin_opts":"obfs=tls"
}
EOF
systemctl status shadowsocks-libev | grep -q 'inactive' && \
systemctl enable shadowsocks-libev 1 > /dev/null
systemctl restart shadowsocks-libev

echo "恭喜你，在你的本地电脑主目录下新建ss.json文件并复制以下信息，然后运行ss-local -c ~/ss.json:"
cat << EOF
{
    "server":"你的服务器IP地址",
    "server_port":${port},
    "local_port":1080,
    "password":"${password}",
    "timeout":600,
    "method":"aes-256-gcm",
    "fast_open":false,
    "plugin":"obfs-local",
    "plugin_opts":"obfs=tls;www.amazon.com"
}
EOF
