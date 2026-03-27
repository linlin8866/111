bash <(curl -Ls https://raw.githubusercontent.com/linlin8866/111/main/ip.sh)


curl -L https://raw.githubusercontent.com/linlin8866/111/main/ip.sh -o /usr/bin/111ip && chmod +x /usr/bin/111ip



一键关闭ipv4

ip addr


ip -4 addr flush dev ens3 && ip -4 route flush dev ens3 && echo "✅ IPv4 已临时关闭，仅 IPv6 可用"

dhclient -4 ens3


# 【通用暴力命令：开机自动永久关闭 IPv4，只留 IPv6】
# 只需要修改下面第一行 IFACE="你的网卡名" 即可，例如 ens3、eth0、eth1、ens160 等

IFACE="ens3"  # ← 这里改成你实际网卡名，其他不动

cat > /etc/network/if-up.d/disable-ipv4 <<'EOF'
#!/bin/sh
IFACE="$IFACE"
if [ "$IFACE" = "$IFACE" ]; then
    ip -4 addr flush dev "$IFACE"
    ip -4 route flush dev "$IFACE"
fi
EOF

chmod +x /etc/network/if-up.d/disable-ipv4

# 立即关闭 IPv4（不重启也生效）
ip -4 addr flush dev "$IFACE"
ip -4 route flush dev "$IFACE"

echo "✅ 配置完成：开机自动关闭 $IFACE 的 IPv4，仅 IPv6 可用"



# 【恢复 IPv4 通用命令】
# 只改下面这行的网卡名，其他不动
IFACE="ens3"

# 删除开机禁用 IPv4 的脚本
rm -f /etc/network/if-up.d/disable-ipv4

# 重新获取 IPv4 地址
dhclient -4 "$IFACE"

echo "✅ IPv4 已恢复，网卡：$IFACE"
