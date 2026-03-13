#!/bin/bash
# 一键运行 VINS-Fusion EuRoC 数据集并保存 TUM 格式轨迹
#
# 用法: ./run_euroc.sh <bag文件路径> [选项]
# 示例:
#   ./run_euroc.sh /root/datasets/euroc_mav/MH_01_easy.bag
#   ./run_euroc.sh /root/datasets/euroc_mav/MH_01_easy.bag --config euroc_mono_imu_config
#   ./run_euroc.sh /root/datasets/euroc_mav/MH_01_easy.bag --loop --rviz
#
# 输出: /root/output/<数据集名>.csv, /root/output/<数据集名>_tum.txt

set -e

# 默认参数
CONFIG="euroc_stereo_imu_config"
OUTPUT_DIR="/root/output"
ENABLE_RVIZ="false"
ENABLE_LOOP="false"
BAG_FILE=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)  CONFIG="$2"; shift 2 ;;
        --output)  OUTPUT_DIR="$2"; shift 2 ;;
        --rviz)    ENABLE_RVIZ="true"; shift ;;
        --loop)    ENABLE_LOOP="true"; shift ;;
        --help|-h)
            head -9 "$0" | tail -8
            exit 0 ;;
        *)
            if [[ -z "$BAG_FILE" ]]; then
                BAG_FILE="$1"; shift
            else
                echo "未知参数: $1"; exit 1
            fi ;;
    esac
done

if [[ -z "$BAG_FILE" ]]; then
    echo "错误: 请指定bag文件路径"
    echo "用法: ./run_euroc.sh <bag文件路径> [--config <配置名>] [--loop] [--rviz]"
    exit 1
fi

# 从bag文件名提取序列名
BAG_NAME=$(basename "$BAG_FILE" .bag)

# 准备输出目录
mkdir -p "$OUTPUT_DIR"

source /opt/ros/noetic/setup.bash
source /root/catkin_ws/devel/setup.bash

echo "========================================"
echo " VINS-Fusion EuRoC 自动运行"
echo "========================================"
echo " 配置:     $CONFIG"
echo " Bag:      $BAG_FILE"
echo " 回环检测: $ENABLE_LOOP"
echo " Rviz:     $ENABLE_RVIZ"
echo " 输出目录: $OUTPUT_DIR"
echo "========================================"

# 配置文件路径 (VINS 用配置文件所在目录来定位相机标定文件, 不能移到别处)
CONFIG_DIR="/root/catkin_ws/src/VINS-Fusion/config/euroc"
CONFIG_FILE="${CONFIG_DIR}/${CONFIG}.yaml"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "错误: 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 在配置文件同目录创建临时配置, 修改 output_path
TMP_CONFIG="${CONFIG_DIR}/_run_${CONFIG}.yaml"
sed "s|output_path:.*|output_path: \"${OUTPUT_DIR}/\"|" "$CONFIG_FILE" > "$TMP_CONFIG"

# 运行 launch
roslaunch vins euroc_run.launch \
    config_path:="$TMP_CONFIG" \
    bag_file:="$BAG_FILE" \
    enable_rviz:="$ENABLE_RVIZ" \
    enable_loop:="$ENABLE_LOOP" || true

# 清理临时配置
rm -f "$TMP_CONFIG"

# 等待写入完成
sleep 1

# 重命名 vio.csv 并转换为 TUM 格式
VIO_CSV="$OUTPUT_DIR/vio.csv"
CSV_FILE="$OUTPUT_DIR/${BAG_NAME}.csv"
TUM_FILE="$OUTPUT_DIR/${BAG_NAME}.txt"

if [[ -f "$VIO_CSV" && -s "$VIO_CSV" ]]; then
    # 重命名 vio.csv -> <数据集名>.csv
    mv "$VIO_CSV" "$CSV_FILE"

    # 转换 csv -> TUM 格式
    # csv 格式:  timestamp_ns, x, y, z, qw, qx, qy, qz, vx, vy, vz,
    # TUM 格式:  timestamp_s x y z qx qy qz qw
    awk -F',' '{
        if (NF >= 8 && $1 ~ /^[0-9]/) {
            gsub(/[ \t]/, "", $1);
            gsub(/[ \t]/, "", $2);
            gsub(/[ \t]/, "", $3);
            gsub(/[ \t]/, "", $4);
            gsub(/[ \t]/, "", $5);
            gsub(/[ \t]/, "", $6);
            gsub(/[ \t]/, "", $7);
            gsub(/[ \t]/, "", $8);
            printf "%.6f %s %s %s %s %s %s %s\n", $1/1e9, $2, $3, $4, $6, $7, $8, $5
        }
    }' "$CSV_FILE" > "$TUM_FILE"

    LINES=$(wc -l < "$TUM_FILE")
    echo "========================================"
    echo " 完成! ($LINES 帧)"
    echo " CSV 轨迹: $CSV_FILE"
    echo " TUM 轨迹: $TUM_FILE"
    echo "========================================"
else
    echo "警告: 未找到输出轨迹, 可能运行失败"
    rm -f "$VIO_CSV"
    exit 1
fi
