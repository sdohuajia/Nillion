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
        echo "2) 查询日志"
        echo "3) 删除节点"
        echo "4) 更换 RPC 并重启节点"
        echo "5) 查看 public_key 和 account_id"
        echo "6) 更新节点脚本"
        echo "7) 迁移验证者（9.24前的用户可用）"
        echo "8) 退出"

        read -p "请输入选项 (1, 2, 3, 4, 5, 6, 7, 8): " choice

        case $choice in
            1) install_node ;;
            2) query_logs ;;
            3) delete_node ;;
            4) change_rpc ;;
            5) view_credentials ;;
            6) update_script ;;
            7) migrate_validator ;;
            9) echo "退出脚本。"; exit 0 ;;
            *) echo "无效选项，请输入 1、2、3、4、5、6、7、8或9。" ;;
        esac
    done
}

# 迁移验证者函数
function migrate_validator() {
    echo "正在停止并删除 Docker 容器 nillion_verifier..."
    docker stop nillion_verifier
    docker rm nillion_verifier

    echo "正在迁移验证者..."
    docker run -v ./nillion/accuser:/var/tmp nillion/verifier:v1.0.1 verify --rpc-endpoint "https://nillion-testnet-rpc.polkachu.com"
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
    echo "正在拉取镜像 nillion/verifier:v1.0.1..."
    docker pull nillion/verifier:v1.0.1

    # 安装 jq
    echo "正在安装 jq..."
    apt-get install -y jq
    echo "jq 安装完成。"

    # 初始化目录和运行 Docker 容器
    echo "正在初始化配置..."
    mkdir -p nillion/verifier
    docker run -v ./nillion/verifier:/var/tmp nillion/verifier:v1.0.1 initialise
    echo "初始化完成。"

    # 提示用户保存重要信息
    echo "初始化完成。请查看以下文件以获取重要信息："
    echo "account_id 和 public_key 已保存到 ~/nillion/verifier 目录中的相关文件中。"
    echo "请务必保存这些信息，因为它们在后续操作中非常重要。"

    echo "你可以使用以下命令查看保存的文件内容："
    echo "cat ~/nillion/verifier/account_id"
    echo "cat ~/nillion/verifier/public_key"

    echo "记得妥善保存这些信息，并避免泄露。"

    # 等待用户按任意键继续
    read -p "按任意键继续进行下一步..."

    # 使用固定的 RPC 链接
    selected_rpc_url="https://nillion-testnet-rpc.polkachu.com"

    # 查询同步信息
    echo "正在从 $selected_rpc_url 查询同步信息..."
    sync_info=$(curl -s "$selected_rpc_url/status" | jq .result.sync_info)

    # 输出同步信息
    echo "同步信息："
    echo "$sync_info"

    # 提示用户是否继续
    read -p "节点是否已同步？（已同步请输入 'yes'，未同步请输入 'no'）： " sync_status

    if [ "$sync_status" = "yes" ]; then
        # 运行节点
        echo "正在运行节点..."
        docker run -v ./nillion/verifier:/var/tmp nillion/verifier:v1.0.1 verify --rpc-endpoint "https://nillion-testnet-rpc.polkachu.com"
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
    echo "正在查询 nillion_verifier 容器的日志..."

    # 检查容器是否存在
    if [ "$(docker ps -q -f name=nillion_verifier)" ]; then
        docker logs -f nillion_verifier --tail 100
    else
        echo "没有运行的 nillion_verifier 容器。"
    fi

    # 等待用户按任意键以返回主菜单
    read -p "按任意键返回主菜单..."
}

# 删除节点函数
function delete_node() {
    echo "正在备份 /root/nillion/verifier 目录..."
    tar -czf /root/nillion/verifier_backup_$(date +%F).tar.gz /root/nillion/verifier
    echo "备份完成。"

    echo "正在停止并删除 Docker 容器 nillion_verifier..."
    docker stop nillion_verifier
    docker rm nillion_verifier
    echo "节点已删除。"

    # 等待用户按任意键以返回主菜单
    read -p "按任意键返回主菜单..."
}

# 更换 RPC 函数
function change_rpc() {
    echo "请选择要使用的 RPC 链接："
    echo "1) https://testnet-nillion-rpc.lavenderfive.com"
    echo "2) https://nillion-testnet-rpc.polkachu.com"
    echo "3) https://nillion-testnet.rpc.kjnodes.com"

    read -p "请输入数字 (1-3): " choice

    case $choice in
        1)
            new_rpc_url="https://testnet-nillion-rpc.lavenderfive.com"
            ;;
        2)
            new_rpc_url="https://nillion-testnet-rpc.polkachu.com"
            ;;
        3)
            new_rpc_url="https://nillion-testnet.rpc.kjnodes.com"
            ;;
        *)
            echo "无效的选择，请重试。"
            return
            ;;
    esac

    echo "正在停止并删除现有 Docker 容器 nillion_verifier..."
    docker stop nillion_verifier
    docker rm nillion_verifier

    echo "正在运行新的 Docker 容器..."
    docker run -v ./nillion/verifier:/var/tmp nillion/verifier:v1.0.1 verify --rpc-endpoint "$new_rpc_url"

    echo "节点已更新到新的 RPC：$new_rpc_url"
    
    # 等待用户按任意键返回主菜单
    read -p "按任意键继续返回主菜单..."
}

# 更新脚本函数
function update_script() {
    # 拉取镜像
    echo "正在拉取镜像 nillion/verifier:v1.0.1..."
    docker pull nillion/verifier:v1.0.1

    echo "更新完成。"

    # 等待用户按任意键返回主菜单
    read -p "按任意键返回主菜单..."
}

# 查看凭证函数
function view_credentials() {
    echo "account_id 和 public_key 已保存到 ~/nillion/accuser 目录中的相关文件中。"
    echo "你可以使用以下命令查看保存的文件内容："
    echo "cat ~/nillion/verifier/account_id"
    echo "cat ~/nillion/verifier/public_key"

    # 等待用户按任意键返回主菜单
    read -p "按任意键返回主菜单..."
}

# 启动主菜单
main_menu
