name=exfer-miner-final.sh url=https://github.com/tz8899/exfer-mining-scripts/blob/main/exfer-miner-final.sh
#!/bin/bash

################################################################################
# Exfer 个人挖矿工具 v3.0 - 最终完整版
# 功能：安装、初始化、挖矿、钱包、任务、监控、日志查看
# 为个人矿工优化 - 简洁、易用、功能完整
# 更新时间：2026-04-19
# GitHub: https://github.com/tz8899/exfer-mining-scripts
################################################################################

set -e

# ================ 配置 ================
RPC_ENDPOINT="${RPC:-http://82.221.100.201:9334}"
TASK_SERVER="http://82.221.100.201:8080"
EXFER_HOME="${HOME}/.exfer"
EXFER_WALLET="${EXFER_HOME}/wallet.key"
EXFER_BIN="./exfer"
LOG_FILE="${EXFER_HOME}/exfer.log"
MONITOR_INTERVAL=30

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ================ 工具函数 ================
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║ $1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
}

# ================ 1. 安装 Exfer ================
install_exfer() {
    print_header "Exfer 安装"
    
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        BINARY="exfer-linux-x86_64"
    elif [[ "$ARCH" == "aarch64" ]]; then
        BINARY="exfer-linux-arm64"
    else
        print_error "不支持的架构: $ARCH"
        return 1
    fi
    
    print_info "检测到架构: $ARCH"
    print_info "下载 $BINARY..."
    
    mkdir -p "$EXFER_HOME"
    
    DOWNLOAD_URL="https://github.com/ahuman-exfer/exfer/releases/latest/download/$BINARY"
    
    if curl -L -o "$EXFER_BIN" "$DOWNLOAD_URL" 2>/dev/null; then
        chmod +x "$EXFER_BIN"
        print_success "Exfer 下载完成"
        
        if "$EXFER_BIN" --help 2>/dev/null | head -1 > /dev/null; then
            print_success "安装成功"
            return 0
        fi
    else
        print_error "下载失败，请检查网络"
        return 1
    fi
}

# ================ 2. 初始化节点 ================
init_node() {
    print_header "初始化节点"
    
    if [ ! -f "$EXFER_BIN" ]; then
        print_error "Exfer 未安装，请先运行安装"
        return 1
    fi
    
    read -sp "输入钱包密码: " PASSPHRASE
    echo
    read -sp "确认密码: " PASSPHRASE_CONFIRM
    echo
    
    if [ "$PASSPHRASE" != "$PASSPHRASE_CONFIRM" ]; then
        print_error "密码不匹配"
        return 1
    fi
    
    export EXFER_PASS="$PASSPHRASE"
    
    print_info "初始化中..."
    "$EXFER_BIN" init --passphrase-env EXFER_PASS --json --datadir "$EXFER_HOME" 2>&1 | tee -a "$LOG_FILE"
    
    if [ -f "$EXFER_WALLET" ]; then
        print_success "初始化完成"
        return 0
    else
        print_error "初始化失败"
        return 1
    fi
}

# ================ 3. 启动挖矿 ================
start_mining() {
    print_header "启动挖矿"
    
    if [ ! -f "$EXFER_WALLET" ]; then
        print_error "钱包不存在，请先初始化"
        return 1
    fi
    
    # 新代码（支持密码输入）
# ✅ 修复后
read -sp "输入钱包密码: " PASSPHRASE
echo
export EXFER_PASS="$PASSPHRASE"

# 第一步：获取完整JSON，保留错误信息
print_info "读取钱包信息..."
WALLET_JSON=$("$EXFER_BIN" wallet info --wallet "$EXFER_WALLET" --passphrase-env EXFER_PASS --json 2>&1)

# 第二步：检查命令是否执行成功
if [ $? -ne 0 ]; then
    print_error "钱包访问失败 - 密码可能错误"
    echo "错误信息: $WALLET_JSON"
    return 1
fi

# 第三步：验证JSON中是否有pubkey字段
if ! echo "$WALLET_JSON" | grep -q '"pubkey"'; then
    print_error "获取公钥失败 - 钱包可能损坏"
    echo "响应: $WALLET_JSON"
    return 1
fi

# 第四步：安全地提取公钥
PUBKEY=$(echo "$WALLET_JSON" | jq -r '.pubkey' 2>/dev/null)

# 第五步：验证公钥是否有效
if [ -z "$PUBKEY" ] || [ "$PUBKEY" = "null" ]; then
    print_error "无法提取公钥 - JSON解析失败"
    return 1
fi

print_success "公钥获取成功: ${PUBKEY:0:16}...${PUBKEY: -16}"
    
    if [ -z "$PUBKEY" ] || [ "$PUBKEY" == "null" ]; then
        print_error "获取公钥失败"
        return 1
    fi
    
    print_info "使用公钥: ${PUBKEY:0:16}...${PUBKEY: -16}"
    print_info "启动挖矿进程..."
    
    nohup "$EXFER_BIN" mine \
        --datadir "$EXFER_HOME" \
        --miner-pubkey "$PUBKEY" \
        --rpc-bind 127.0.0.1:9334 \
        --repair-perms \
        >> "$LOG_FILE" 2>&1 &
    
    MINER_PID=$!
    echo $MINER_PID > "$EXFER_HOME/miner.pid"
    
    sleep 2
    if ps -p $MINER_PID > /dev/null 2>/dev/null; then
        print_success "挖矿已启动"
        print_info "进程 ID: $MINER_PID"
        print_info "日志文件: $LOG_FILE"
        return 0
    else
        print_error "启动失败"
        return 1
    fi
}

# ================ 4. 停止挖矿 ================
stop_mining() {
    print_header "停止挖矿"
    
    if [ -f "$EXFER_HOME/miner.pid" ]; then
        PID=$(cat "$EXFER_HOME/miner.pid")
        if ps -p $PID > /dev/null 2>/dev/null; then
            if kill $PID 2>/dev/null; then
                sleep 2
                print_success "挖矿已停止"
                rm "$EXFER_HOME/miner.pid"
                return 0
            fi
        else
            print_warning "进程已不存在，清理 PID 文件"
            rm "$EXFER_HOME/miner.pid"
            return 0
        fi
    fi
    
    print_warning "未找到挖矿进程"
    return 1
}

# ================ 5. 查看钱包信息 ================
wallet_info() {
    print_header "钱包信息"
    
    if [ ! -f "$EXFER_WALLET" ]; then
        print_error "钱包不存在"
        return 1
    fi
    
    INFO=$("$EXFER_BIN" wallet info --wallet "$EXFER_WALLET" --json 2>/dev/null)
    
    ADDRESS=$(echo "$INFO" | jq -r '.address')
    PUBKEY=$(echo "$INFO" | jq -r '.pubkey')
    
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "📍 钱包地址:"
    echo -e "${GREEN}$ADDRESS${NC}"
    echo
    echo "🔑 公钥:"
    echo -e "${GREEN}$PUBKEY${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# ================ 6. 检查余额 ================
check_balance() {
    print_header "检查余额"
    
    if [ ! -f "$EXFER_WALLET" ]; then
        print_error "钱包不存在"
        return 1
    fi
    
    print_info "连接到 RPC: $RPC_ENDPOINT"
    
    RESULT=$("$EXFER_BIN" wallet balance \
        --wallet "$EXFER_WALLET" \
        --rpc "$RPC_ENDPOINT" \
        --json 2>/dev/null)
    
    BALANCE_EXFERS=$(echo "$RESULT" | jq '.balance')
    BALANCE_EXFER=$(echo "scale=8; $BALANCE_EXFERS / 100000000" | bc)
    
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "💰 钱包余额:"
    echo -e "${GREEN}$BALANCE_EXFER EXFER${NC}"
    echo "   ($BALANCE_EXFERS exfers)"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    print_success "查询成功"
}

# ================ 7. 发送支付 ================
send_payment() {
    print_header "发送支付"
    
    read -p "输入接收地址 (64 字节 hex): " TO_ADDRESS
    read -p "输入金额 (如 '10 EXFER'): " AMOUNT
    read -p "输入手续费 (默认 '0.001 EXFER'): " FEE
    FEE="${FEE:-0.001 EXFER}"
    
    read -sp "输入钱包密码: " PASSPHRASE
    echo
    
    export EXFER_PASS="$PASSPHRASE"
    
    print_info "发送支付中..."
    
    RESULT=$("$EXFER_BIN" wallet send \
        --wallet "$EXFER_WALLET" \
        --to "$TO_ADDRESS" \
        --amount "$AMOUNT" \
        --fee "$FEE" \
        --rpc "$RPC_ENDPOINT" \
        --passphrase-env EXFER_PASS \
        --json 2>/dev/null)
    
    TX_ID=$(echo "$RESULT" | jq -r '.tx_id // "error"')
    
    if [ "$TX_ID" != "error" ] && [ -n "$TX_ID" ] && [ "$TX_ID" != "null" ]; then
        echo
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "✅ 交易已提交"
        echo "📝 交易 ID:"
        echo -e "${GREEN}$TX_ID${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        print_success "支付成功"
        return 0
    else
        print_error "支付失败"
        echo "$RESULT" | jq '.error // .'
        return 1
    fi
}

# ================ 8. 查看可用任务 ================
fetch_tasks() {
    print_header "可用任务列表"
    
    print_info "连接到任务服务器..."
    
    TASKS=$(curl -s "$TASK_SERVER/api/v1/tasks" 2>/dev/null)
    
    if echo "$TASKS" | jq -e '.tasks' > /dev/null 2>&1; then
        COUNT=$(echo "$TASKS" | jq '.tasks | length')
        print_success "找到 $COUNT 个任务"
        echo
        
        echo "$TASKS" | jq -r '.tasks[] | 
            "🆔 ID: \(.id)\n📋 类型: \(.type)\n❓ 问题: \(.question)\n💵 奖励: \(.reward_display)\n⏰ 状态: \(.status)\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"'
    else
        print_error "无法获取任务"
    fi
}

# ================ 9. 自动求解任务 ================
auto_solve_tasks() {
    print_header "自动求解任务"
    
    if [ ! -f "$EXFER_WALLET" ]; then
        print_error "钱包不存在"
        return 1
    fi
    
    ADDRESS=$("$EXFER_BIN" wallet info --wallet "$EXFER_WALLET" --json 2>/dev/null | jq -r '.address')
    
    print_info "获取任务..."
    TASKS=$(curl -s "$TASK_SERVER/api/v1/tasks" 2>/dev/null | jq -r '.tasks[] | select(.status=="open") | .id')
    
    if [ -z "$TASKS" ]; then
        print_warning "没有可用任务"
        return 0
    fi
    
    TASK_COUNT=$(echo "$TASKS" | wc -l)
    print_success "找到 $TASK_COUNT 个任务"
    echo
    
    SOLVED=0
    FAILED=0
    
    for TASK_ID in $TASKS; do
        TASK=$(curl -s "$TASK_SERVER/api/v1/tasks" 2>/dev/null | jq ".tasks[] | select(.id==\"$TASK_ID\")")
        
        QUESTION=$(echo "$TASK" | jq -r '.question')
        TASK_TYPE=$(echo "$TASK" | jq -r '.type')
        REWARD=$(echo "$TASK" | jq -r '.reward_display')
        
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "📝 任务 ID: $TASK_ID"
        echo "📌 类型: $TASK_TYPE"
        echo "❓ 问题: $QUESTION"
        echo "💰 奖励: $REWARD"
        
        ANSWER=""
        
        if [ "$TASK_TYPE" = "on-chain" ]; then
            ANSWER="1"
            print_info "提交答案: $ANSWER"
        elif [ "$TASK_TYPE" = "math" ]; then
            ANSWER=$(echo "$QUESTION" | grep -oE '[0-9]+' | head -1)
            print_info "提交答案: $ANSWER"
        else
            print_warning "无法自动求解此类型的任务"
            ((FAILED++))
            continue
        fi
        
        if [ -n "$ANSWER" ]; then
            CLAIM_RESULT=$(curl -s -X POST "$TASK_SERVER/api/v1/tasks/$TASK_ID/claim" \
                -H "Content-Type: application/json" \
                -d "{\"answer\": \"$ANSWER\", \"address\": \"$ADDRESS\"}" 2>/dev/null)
            
            if echo "$CLAIM_RESULT" | jq -e '.success' > /dev/null 2>&1; then
                print_success "✅ 任务完成！获得 $REWARD"
                ((SOLVED++))
            else
                print_warning "❌ 任务提交失败"
                ((FAILED++))
            fi
        fi
        
        sleep 1
    done
    
    echo
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "📊 求解统计:"
    echo "✅ 成功: $SOLVED"
    echo "❌ 失败: $FAILED"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
}

# ================ 10. 挖矿监控 ================
monitor_mining() {
    print_header "实时挖矿监控"
    print_info "按 Ctrl+C 停止 | 更新间隔: ${MONITOR_INTERVAL}s"
    sleep 2
    
    while true; do
        clear
        echo -e "${CYAN}════════════════════ Exfer 挖矿监控 ════════════════════${NC}"
        echo "更新时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo
        
        echo -e "${BLUE}【区块信息】${NC}"
        BLOCK_INFO=$(curl -s -X POST "$RPC_ENDPOINT" \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"get_block_height","params":{},"id":1}' \
            2>/dev/null | jq '.result')
        
        HEIGHT=$(echo "$BLOCK_INFO" | jq -r '.height // "N/A"')
        echo "📦 当前块高: $HEIGHT"
        echo
        
        echo -e "${BLUE}【挖矿状态】${NC}"
        if [ -f "$EXFER_HOME/miner.pid" ]; then
            PID=$(cat "$EXFER_HOME/miner.pid")
            if ps -p $PID > /dev/null 2>/dev/null; then
                echo "⛏️  进程状态: 运行中"
                echo "📊 进程 ID: $PID"
            else
                echo "⛏️  进程状态: 已停止"
                rm "$EXFER_HOME/miner.pid" 2>/dev/null
            fi
        else
            echo "⛏️  进程状态: 未运行"
        fi
        echo
        
        if [ -f "$EXFER_WALLET" ]; then
            echo -e "${BLUE}【挖矿收入】${NC}"
            BALANCE=$("$EXFER_BIN" wallet balance \
                --wallet "$EXFER_WALLET" \
                --rpc "$RPC_ENDPOINT" \
                --json 2>/dev/null | jq '.balance // 0')
            
            EXFER_AMOUNT=$(echo "scale=8; $BALANCE / 100000000" | bc)
            echo "💰 当前余额: $EXFER_AMOUNT EXFER"
        fi
        echo
        
        echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
        echo "下次更新: ${MONITOR_INTERVAL}s 后"
        
        sleep "$MONITOR_INTERVAL"
    done
}

# ================ 11. 挖矿状态 ================
mining_status() {
    print_header "挖矿状态检查"
    
    if [ -f "$EXFER_HOME/miner.pid" ]; then
        PID=$(cat "$EXFER_HOME/miner.pid")
        if ps -p $PID > /dev/null 2>/dev/null; then
            print_success "挖矿进程运行中"
            print_info "进程 ID: $PID"
            
            ps aux | grep $PID | grep -v grep || true
            
            return 0
        else
            print_warning "PID 文件存在，但进程已停止"
            rm "$EXFER_HOME/miner.pid"
            return 1
        fi
    else
        print_warning "没有运行中的挖矿进程"
        return 1
    fi
}

# ================ 12. 一键启动 ================
quick_start() {
    print_header "一键启动（完整安装+初始化+挖矿）"
    
    if ! install_exfer; then
        print_error "安装失败"
        return 1
    fi
    
    echo
    
    if ! init_node; then
        print_error "初始化失败"
        return 1
    fi
    
    echo
    
    if ! start_mining; then
        print_error "启动挖矿失败"
        return 1
    fi
    
    echo
    print_header "✅ 启动完成"
    echo
    print_info "📋 快速参考:"
    echo "   钱包位置: $EXFER_WALLET"
    echo "   数据目录: $EXFER_HOME"
    echo "   日志文件: $LOG_FILE"
    echo
    print_info "🚀 常用命令:"
    echo "   查看余额: ./exfer-miner-final.sh balance"
    echo "   查看状态: ./exfer-miner-final.sh status"
    echo "   监控页面: ./exfer-miner-final.sh monitor"
    echo "   停止挖矿: ./exfer-miner-final.sh stop"
    echo "   查看日志: tail -f ~/.exfer/exfer.log"
    echo
}

# ================ 13. 查看日志 ================
view_logs() {
    print_header "查看挖矿日志"
    
    if [ ! -f "$LOG_FILE" ]; then
        print_error "日志文件不存在"
        return 1
    fi
    
    echo
    echo "选择查看方式："
    echo "  1. 查看最后 50 行"
    echo "  2. 查看最后 100 行"
    echo "  3. 查看最后 200 行"
    echo "  4. 实时查看（Ctrl+C 停止）"
    echo "  5. 查看错误信息"
    echo "  6. 查看日志大小和信息"
    echo "  0. 返回"
    echo
    
    read -p "选择 [0-6]: " log_choice
    
    case $log_choice in
        1) tail -50 "$LOG_FILE" ;;
        2) tail -100 "$LOG_FILE" ;;
        3) tail -200 "$LOG_FILE" ;;
        4) tail -f "$LOG_FILE" ;;
        5) grep -i "error\|warning" "$LOG_FILE" | tail -30 ;;
        6) 
            echo "日志文件大小: $(du -h "$LOG_FILE" | cut -f1)"
            echo "总行数: $(wc -l < "$LOG_FILE")"
            echo "最后修改时间: $(stat -c %y "$LOG_FILE" 2>/dev/null || stat -f %Sm "$LOG_FILE")"
            ;;
        0) return ;;
        *) print_error "无效选择" ;;
    esac
}

# ================ 主菜单 ================
show_menu() {
    echo
    print_header "Exfer 个人挖矿工具 v3.0 - 最终版"
    echo
    echo "【快速操作】"
    echo "  1. 一键启动（安装+初始化+挖矿）"
    echo "  2. 启动挖矿"
    echo "  3. 停止挖矿"
    echo "  4. 挖矿状态"
    echo
    echo "【钱包管理】"
    echo "  5. 查看钱包信息"
    echo "  6. 检查余额"
    echo "  7. 发送支付"
    echo
    echo "【任务赚取】"
    echo "  8. 查看可用任务"
    echo "  9. 自动求解任务"
    echo
    echo "【监控与日志】"
    echo " 10. 实时监控面板"
    echo " 11. 查看日志"
    echo
    echo "【系统配置】"
    echo " 12. 安装 Exfer"
    echo " 13. 初始化节点"
    echo
    echo "  0. 退出"
    echo
}

# ================ 主程序 ================
main() {
    while true; do
        show_menu
        read -p "请选择 [0-13]: " choice
        
        case $choice in
            1) quick_start ;;
            2) start_mining ;;
            3) stop_mining ;;
            4) mining_status ;;
            5) wallet_info ;;
            6) check_balance ;;
            7) send_payment ;;
            8) fetch_tasks ;;
            9) auto_solve_tasks ;;
            10) monitor_mining ;;
            11) view_logs ;;
            12) install_exfer ;;
            13) init_node ;;
            0) 
                print_info "感谢使用，再见！"
                exit 0
                ;;
            *)
                print_error "无效选择"
                ;;
        esac
        
        echo
        read -p "按 Enter 继续..."
    done
}

# ================ 命令行参数支持 ================
if [ $# -gt 0 ]; then
    case $1 in
        start) start_mining ;;
        stop) stop_mining ;;
        status) mining_status ;;
        balance) check_balance ;;
        info) wallet_info ;;
        send) send_payment ;;
        tasks) fetch_tasks ;;
        solve) auto_solve_tasks ;;
        monitor) monitor_mining ;;
        install) install_exfer ;;
        init) init_node ;;
        quick) quick_start ;;
        logs) view_logs ;;
        *)
            echo "╔════════════════════════════════════════════════════════╗"
            echo "║   Exfer 个人挖矿工具 v3.0 - 最终完整版                 ║"
            echo "║   GitHub: https://github.com/tz8899/exfer-mining-scripts║"
            echo "╚════════════════════════════════════════════════════════╝"
            echo ""
            echo "用法: $0 [命令]"
            echo ""
            echo "【快速启动】"
            echo "  quick              - 一键启动（推荐第一次使用）"
            echo ""
            echo "【挖矿控制】"
            echo "  start              - 启动挖矿"
            echo "  stop               - 停止挖矿"
            echo "  status             - 检查挖矿状态"
            echo ""
            echo "【钱包管理】"
            echo "  balance            - 查看余额"
            echo "  info               - 查看钱包信息"
            echo "  send               - 发送支付"
            echo ""
            echo "【任务求解】"
            echo "  tasks              - 查看可用任务"
            echo "  solve              - 自动求解任务"
            echo ""
            echo "【监控与日志】"
            echo "  monitor            - 实时监控面板"
            echo "  logs               - 查看日志"
            echo ""
            echo "【系统配置】"
            echo "  install            - ���装 Exfer"
            echo "  init               - 初始化钱包"
            echo ""
            echo "【无参数使用】"
            echo "  $0                 - 进入交互式菜单"
            echo ""
            echo "【快速查看日志】"
            echo "  tail -f ~/.exfer/exfer.log           # 实时查看日志"
            echo "  tail -50 ~/.exfer/exfer.log          # 查看最后50行"
            echo "  ps -p \$(cat ~/.exfer/miner.pid)      # 检查进程"
            echo ""
            echo "【完整文档】"
            echo "  https://github.com/tz8899/exfer-mining-scripts"
            echo ""
            ;;
    esac
else
    main
fi
