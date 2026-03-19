#!/bin/bash

CONFIG="/etc/wireguard/proxy.conf"
SOCKS5="127.0.0.1:40000"
DEFAULT_EP="engage.cloudflareclient.com:2408"

clear
echo "====================================="
echo " 🚀 WARP 智能优选脚本（官方IP + 自动选协议）"
echo "====================================="
echo " 1 智能优选（自动选 IPv4/IPv6）"
echo " 2 强制优选 IPv4（官方解析）"
echo " 3 强制优选 IPv6（官方解析）"
echo " 4 测试当前代理"
echo " 5 恢复默认官方节点"
echo "====================================="
read -p "请选择 [1/2/3/4/5]: " opt

# 测试单个节点延迟
test_node() {
    local EP=$1
    echo -n "🧪 测试 $EP ... "
    systemctl stop wireproxy >/dev/null 2>&1
    sed -i "s|Endpoint =.*|Endpoint = $EP|" $CONFIG
    systemctl restart wireproxy >/dev/null 2>&1
    sleep 2

    # 用下载测速取延迟
    local cost=$(curl --socks5 $SOCKS5 https://speed.cloudflare.com/__down?bytes=50000 -m 8 -o /dev/null -w "%{time_total}\n" 2>/dev/null)
    if (( $(echo "$cost > 0 && $cost < 8" | bc -l) )); then
        echo "✅ 延迟: ${cost}s"
        echo "$cost $EP" >> /tmp/warp_result.txt
        return 0
    else
        echo "❌ 不可用"
        return 1
    fi
}

# 解析官方域名IP
resolve_official() {
    local TYPE=$1
    if [ "$TYPE" = "4" ]; then
        dig +short $DEFAULT_EP A | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
    else
        dig +short $DEFAULT_EP AAAA | grep -E '^[0-9a-fA-F:]+$' | sed 's/^/[/; s/$/]/'
    fi
}

# 自动选最快
find_fastest() {
    rm -f /tmp/warp_result.txt
    local LIST=("$@")
    for ip in "${LIST[@]}"; do
        test_node "${ip}:2408"
    done

    local FASTEST=$(sort -n /tmp/warp_result.txt | head -n1 | awk '{print $2}')
    if [ -n "$FASTEST" ]; then
        sed -i "s|Endpoint =.*|Endpoint = $FASTEST|" $CONFIG
        systemctl restart wireproxy
        sleep 2
        echo -e "\n🚀 已切换到最快官方节点: $FASTEST"
        curl --socks5 $SOCKS5 https://ipinfo.io -m 8
    else
        echo -e "\n⚠️  无可用节点，恢复默认..."
        sed -i "s|Endpoint =.*|Endpoint = $DEFAULT_EP|" $CONFIG
        systemctl restart wireproxy
    fi
}

# 检测网络连通性
check_network() {
    local has_ipv4=0
    local has_ipv6=0

    # 检测 IPv4 连通性
    ping -4 -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 && has_ipv4=1
    # 检测 IPv6 连通性
    ping -6 -c 1 -W 2 2606:4700:4700::1111 >/dev/null 2>&1 && has_ipv6=1

    echo "📡 网络检测结果："
    echo "   IPv4 连通性: $( [ $has_ipv4 -eq 1 ] && echo "✅" || echo "❌" )"
    echo "   IPv6 连通性: $( [ $has_ipv6 -eq 1 ] && echo "✅" || echo "❌" )"

    if [ $has_ipv4 -eq 1 ] && [ $has_ipv6 -eq 1 ]; then
        echo "🔍 同时支持 IPv4/IPv6，优先测速 IPv6"
        return 2
    elif [ $has_ipv4 -eq 1 ]; then
        echo "🔍 仅支持 IPv4"
        return 1
    elif [ $has_ipv6 -eq 1 ]; then
        echo "🔍 仅支持 IPv6"
        return 2
    else
        echo "❌ 无网络连接"
        return 0
    fi
}

case $opt in
    1)
        echo -e "\n🧠 智能模式：自动检测网络..."
        check_network
        net_type=$?
        if [ $net_type -eq 0 ]; then
            exit 1
        elif [ $net_type -eq 1 ]; then
            echo -e "\n🔥 解析官方 IPv4 节点..."
            IPV4=($(resolve_official 4))
            if [ ${#IPV4[@]} -eq 0 ]; then
                echo "❌ 未解析到 IPv4，恢复默认"
                sed -i "s|Endpoint =.*|Endpoint = $DEFAULT_EP|" $CONFIG
                systemctl restart wireproxy
                exit 1
            fi
            echo "✅ 解析到 ${#IPV4[@]} 个 IPv4 节点"
            find_fastest "${IPV4[@]}"
        else
            echo -e "\n🔥 解析官方 IPv6 节点..."
            IPV6=($(resolve_official 6))
            if [ ${#IPV6[@]} -eq 0 ]; then
                echo "❌ 未解析到 IPv6，恢复默认"
                sed -i "s|Endpoint =.*|Endpoint = $DEFAULT_EP|" $CONFIG
                systemctl restart wireproxy
                exit 1
            fi
            echo "✅ 解析到 ${#IPV6[@]} 个 IPv6 节点"
            find_fastest "${IPV6[@]}"
        fi
        ;;
    2)
        echo -e "\n🔥 强制优选 IPv4（官方解析）..."
        IPV4=($(resolve_official 4))
        if [ ${#IPV4[@]} -eq 0 ]; then
            echo "❌ 未解析到 IPv4，恢复默认"
            sed -i "s|Endpoint =.*|Endpoint = $DEFAULT_EP|" $CONFIG
            systemctl restart wireproxy
            exit 1
        fi
        echo "✅ 解析到 ${#IPV4[@]} 个 IPv4 节点"
        find_fastest "${IPV4[@]}"
        ;;
    3)
        echo -e "\n🔥 强制优选 IPv6（官方解析）..."
        IPV6=($(resolve_official 6))
        if [ ${#IPV6[@]} -eq 0 ]; then
            echo "❌ 未解析到 IPv6，恢复默认"
            sed -i "s|Endpoint =.*|Endpoint = $DEFAULT_EP|" $CONFIG
            systemctl restart wireproxy
            exit 1
        fi
        echo "✅ 解析到 ${#IPV6[@]} 个 IPv6 节点"
        find_fastest "${IPV6[@]}"
        ;;
    4)
        echo -e "\n📶 测试当前代理..."
        curl --socks5 $SOCKS5 https://ipinfo.io -m 8
        ;;
    5)
        sed -i "s|Endpoint =.*|Endpoint = $DEFAULT_EP|" $CONFIG
        systemctl restart wireproxy
        sleep 2
        echo -e "\n✅ 已恢复默认节点"
        curl --socks5 $SOCKS5 https://ipinfo.io -m 8
        ;;
    *)
        echo "❌ 输入错误"
        ;;
esac
