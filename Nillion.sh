#!/bin/bash

# 脚本保存路径
SCRIPT_PATH="$HOME/Nillion.sh"

# 确保脚本以 root 权限运行
if [ "$(id -u)" -ne "0" ]; then
  echo "请以 root 用户或使用 sudo 运行此脚本"
  exit 1
fi

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由推特 @ferdie_jhovie 提供，免费开源，请勿相信收费"
        echo "================================================================"
        echo "节点社区 Telegram 群组: https://t.me/niuwuriji"
        echo "节点社区 Telegram 频道: https://t.me/niuwuriji"
        echo "节点社区 Discord 社群: https://discord.gg/GbMV5EcNWF"
        echo "退出脚本，请按键盘 ctrl+c 退出"
        echo "请选择要执行的操作:"
        echo "1) 安装节点"
        echo "2) 查询日志（如 rpc 错误则不会显示）"
        echo "3) 删除节点"
        echo "4) 更换 RPC 并重启节点"
        echo "5) 查看 public_key 和 account_id"
        echo "6) 更新节点脚本"
        echo "7) 退出"

        read -p "请输入选项 (1, 2, 3, 4, 5, 6, 7): " choice

        case $choice in
            1)
                install_node
                ;;
            2)
                query_logs
                ;;
            3)
                delete_node
                ;;
            4)
                change_rpc
                ;;
            5)
                view_credentials
                ;;
            6)
                update_script
                ;;
            7)
                echo "退出脚本。"
                exit 0
                ;;
            *)
                echo "无效选项，请输入 1、2、3、4、5、6 或 7。"
                ;;
        esac
    done
}

# 安装节点函数
function install_node() {
    # 检查是否有 Docker 已安装
    if command -v docker &> /dev/null; then
        echo "Docker 已安装。"
    else
        echo "Docker 未安装，正在进行安装..."

        # 更新软件包列表
        apt-get update

        # 安装必要的软件包以允许 apt 使用存储库通过 HTTPS
        apt-get install -y apt-transport-https ca-certificates curl software-properties-common

        # 添加 Docker 官方 GPG 密钥
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

        # 添加 Docker 存储库
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

        # 更新软件包列表
        apt-get update

        # 安装 Docker
        apt-get install -y docker-ce

        # 启动并启用 Docker 服务
        systemctl start docker
        systemctl enable docker

        echo "Docker 安装完成。"
    fi

    # 拉取指定的 Docker 镜像
    echo "正在拉取镜像 nillion/retailtoken-accuser:v1.0.0..."
    docker pull nillion/retailtoken-accuser:v1.0.0

    # 安装 jq
    echo "正在安装 jq..."
    apt-get install -y jq

    echo "jq 安装完成。"

    # 初始化目录和运行 Docker 容器
    echo "正在初始化配置..."

    # 创建目录
    mkdir -p ~/nillion/accuser

    # 运行 Docker 容器进行初始化
    docker run -v ~/nillion/accuser:/var/tmp nillion/retailtoken-accuser:v1.0.0 initialise

    echo "初始化完成。"

    # 提示用户保存重要信息
    echo "初始化完成。请查看以下文件以获取重要信息："
    echo "account_id 和 public_key 已保存到 ~/nillion/accuser 目录中的相关文件中。"
    echo "请务必保存这些信息，因为它们在后续操作中非常重要。"

    echo "你可以使用以下命令查看保存的文件内容："
    echo "cat ~/nillion/accuser/account_id"
    echo "cat ~/nillion/accuser/public_key"

    echo "记得妥善保存这些信息，并避免泄露。"

    # 等待用户按任意键继续
    read -p "按任意键继续进行下一步..."

    # 提供 RPC 链接选择
    echo "请选择一个 RPC 链接进行同步信息查询："
    echo "1) https://testnet-nillion-rpc.lavenderfive.com"
    echo "2) https://nillion-testnet-rpc.polkachu.com"
    echo "3) https://51.89.195.146:26657"

    read -p "请输入选项 (1, 2, 3): " option

    case $option in
        1)
            selected_rpc_url="https://testnet-nillion-rpc.lavenderfive.com"
            ;;
        2)
            selected_rpc_url="https://nillion-testnet-rpc.polkachu.com"
            ;;
        3)
            selected_rpc_url="https://51.89.195.146:26657"
            ;;
        *)
            echo "无效选项。请重新运行脚本并选择有效的选项。"
            exit 1
            ;;
    esac

    # 查询同步信息
    echo "正在从 $selected_rpc_url 查询同步信息..."
    sync_info=$(curl -s "$selected_rpc_url/status" | jq .result.sync_info)

    # 输出同步信息
    echo "同步信息："
    echo "$sync_info"

    # 提示用户填写开始区块
    read -p "请输入网页上显示的开始区块： " start_block

    # 提示用户是否继续
    read -p "节点是否已同步？（已同步请输入 'yes'，未同步请输入 'no'）： " sync_status

    if [ "$sync_status" = "yes" ]; then
        # 运行节点
        echo "正在运行节点..."
        docker run -d --name nillion_verifier -v ~/nillion/accuser:/var/tmp nillion/retailtoken-accuser:v1.0.0 accuse --rpc-endpoint "$selected_rpc_url" --block-start "$start_block"
        echo "节点正在运行。"
    else
        echo "节点未同步。脚本将退出。"
        exit 1
    fi
    
    # 等待用户按任意键以返回主菜单
    read -p "按任意键返回主菜单..."
}

# 查询日志函数
function query_logs() {
    # 查看 Docker 容器日志
    echo "正在查询 Docker 容器日志..."
    docker logs -f nillion_verifier --tail 100
}

# 删除节点函数
function delete_node() {
    echo "正在停止并删除 Docker 容器 nillion_verifier..."
    docker stop nillion_verifier
    docker rm nillion_verifier
    echo "节点已删除。"
}

# 更换 RPC 函数
function change_rpc() {
    echo "请选择一个新的 RPC 链接："
    echo "1) https://testnet-nillion-rpc.lavenderfive.com"
    echo "2) https://nillion-testnet-rpc.polkachu.com"
    echo "3) https://51.89.195.146:26657"

    read -p "请输入选项 (1, 2, 3): " option

    case $option in
        1)
            new_rpc_url="https://testnet-nillion-rpc.lavenderfive.com"
            ;;
        2)
            new_rpc_url="https://nillion-testnet-rpc.polkachu.com"
            ;;
        3)
            new_rpc_url="https://51.89.195.146:26657"
            ;;
        *)
            echo "无效选项。请重新运行脚本并选择有效的选项。"
            exit 1
            ;;
    esac

    read -p "请输入网页上显示的开始区块： " start_block

    echo "正在停止并删除现有 Docker 容器 nillion_verifier..."
    docker stop nillion_verifier
    docker rm nillion_verifier

    echo "正在运行新的 Docker 容器..."
    docker run -d --name nillion_verifier -v ~/nillion/accuser:/var/tmp nillion/retailtoken-accuser:v1.0.0 accuse --rpc-endpoint "$new_rpc_url" --block-start "$start_block"

    echo "节点已更新到新的 RPC。"
    
    # 等待用户按任意键返回主菜单
    read -p "按任意键继续返回主菜单..."
}

# 更新脚本函数
function update_script() {
    # 提供 RPC 链接选择
    echo "请选择一个新的 RPC 链接："
    echo "1) https://testnet-nillion-rpc.lavenderfive.com"
    echo "2) https://nillion-testnet-rpc.polkachu.com"
    echo "3) https://51.89.195.146:26657"

    read -p "请输入选项 (1, 2, 3): " option

    case $option in
        1)
            selected_rpc_url="https://testnet-nillion-rpc.lavenderfive.com"
            ;;
        2)
            selected_rpc_url="https://nillion-testnet-rpc.polkachu.com"
            ;;
        3)
            selected_rpc_url="https://51.89.195.146:26657"
            ;;
        *)
            echo "无效选项。请重新运行脚本并选择有效的选项。"
            exit 1
            ;;
    esac

    read -p "请输入当前高度低10000的区块高度： " start_block

    echo "正在停止并删除 Docker 容器 nillion_verifier..."
    docker stop nillion_verifier
    docker rm nillion_verifier

    echo "正在拉取新的 Docker 镜像 nillion/retailtoken-accuser:v1.0.1..."
    docker pull nillion/retailtoken-accuser:v1.0.1

    echo "正在运行新的 Docker 容器..."
    docker run -d --name nillion_verifier -v ~/nillion/accuser:/var/tmp nillion/retailtoken-accuser:v1.0.1 accuse --rpc-endpoint "$selected_rpc_url" --block-start "$start_block"

    echo "节点已更新并重新运行。"
    
    # 等待用户按任意键返回主菜单
    read -p "按任意键返回主菜单..."
}

# 查看凭据函数
function view_credentials() {
    echo "查看凭据（pub_key 和 address）"
    echo "pub_key 和 address 文件在 /root/nillion/accuser/credentials.json 目录中。"
    echo "以下是这些文件的内容："

    # JSON 文件路径
    JSON_FILE="/root/nillion/accuser/credentials.json"

    if [ -f "$JSON_FILE" ]; then
        # 使用 grep 和 sed 提取 pub_key
        echo "pub_key 文件内容："
        grep '"pub_key":' "$JSON_FILE" | sed 's/.*"pub_key": "\(.*\)".*/\1/'

        # 使用 grep 和 sed 提取 address
        echo "address 文件内容："
        grep '"address":' "$JSON_FILE" | sed 's/.*"address": "\(.*\)".*/\1/'
    else
        echo "$JSON_FILE 文件不存在。"
    fi

    # 等待用户按任意键返回主菜单
    read -p "按任意键返回主菜单..."
}

# 执行主菜单
main_menu
