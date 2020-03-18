#!/bin/bash
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

echo "恭喜你，在你的本地电脑/home路径下新建ss.json文件，并填写如下信息，然后运行ss-local -c ~/ss.json:"
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
