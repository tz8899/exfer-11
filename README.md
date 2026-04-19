# 克隆整个仓库
[git clone https://github.com/tz8899/exfer-mining-scripts.git](https://github.com/tz8899/exfer-11)

cd exfer-mining-scripts

# 赋予执行权限
chmod +x exfer-miner-final.sh

# 运行脚本 （一键启动）
./exfer-miner-final.sh quick

# 启动挖矿
./exfer-miner-final.sh start

# 停止挖矿
./exfer-miner-final.sh stop

# 查看挖矿状态（是否在运行）
./exfer-miner-final.sh status

# 查看钱包信息（地址、公钥）
./exfer-miner-final.sh info

# 查看余额
./exfer-miner-final.sh balance

# 发送支付（转账）
./exfer-miner-final.sh send
# 然后按提示输入：
# - 接收地址
# - 金额（如 "10 EXFER"）
# - 手续费（默认 "0.001 EXFER"）
# - 钱包密码

# 查看可用任务
./exfer-miner-final.sh tasks

# 自动求解任务赚取额外 EXFER
./exfer-miner-final.sh solve

# 实时监控面板（查看块高、进程、收入）
./exfer-miner-final.sh monitor
# 按 Ctrl+C 停止

# 查看日志（进入日志菜单）
./exfer-miner-final.sh logs
# 然后选择：
# 1. 最后 50 行
# 2. 最后 100 行
# 3. 最后 200 行
# 4. 实时查看
# 5. 错误信息
# 6. 日志大小信息

# 不带参数运行 - 进入菜单模式
./exfer-miner-final.sh

# 然后按数字选择：
# 【快速操作】
#   1. 一键启动
#   2. 启动挖矿
#   3. 停止挖矿
#   4. 挖矿状态
# 【钱包管理】
#   5. 查看钱包信息
#   6. 检查余额
#   7. 发送支付
# 【任务赚取】
#   8. 查看可用任务
#   9. 自动求解任务
# 【监控与日志】
#   10. 实时监控面板
#   11. 查看日志
# 【系统配置】
#   12. 安装 Exfer
#   13. 初始化节点
#   0. 退出
