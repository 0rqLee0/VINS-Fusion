#!/bin/bash
# 一键运行 VINS-Fusion KAIST 数据集 (双目+IMU+GPS) 并保存 TUM 格式轨迹
#
# 用法: ./run_kaist.sh <bag文件路径> [选项]
# 示例:
#   ./run_kaist.sh /root/datasets/kaist/urban28.bag
#   ./run_kaist.sh /root/datasets/kaist/urban28.bag --no-gps
#   ./run_kaist.sh /root/datasets/kaist/urban28.bag --gps-topic /navsat/fix
#   ./run_kaist.sh /root/datasets/kaist/urban28.bag --loop --rviz
#
# 输出: /root/output/<数据集名>.csv, /root/output/<数据集名>_tum.txt
#       启用GPS时还有: /root/output/<数据集名>_global.csv, /root/output/<数据集名>_global_tum.txt

set -e

# 默认参数
CONFIG="kaist_stereo_imu_config"
OUTPUT_DIR="/root/output"
ENABLE_RVIZ="false"
ENABLE_LOOP="false"
ENABLE_GPS="true"
GPS_TOPIC="/gps"
BAG_FILE=""

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)    CONFIG="$2"; shift 2 ;;
        --output)    OUTPUT_DIR="$2"; shift 2 ;;
        --rviz)      ENABLE_RVIZ="true"; shift ;;
        --loop)      ENABLE_LOOP="true"; shift ;;
        --no-gps)    ENABLE_GPS="false"; shift ;;
        --gps-topic) GPS_TOPIC="$2"; shift 2 ;;
        --help|-h)
            head -11 "$0" | tail -10
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
    echo "用法: ./run_kaist.sh <bag文件路径> [--config <配置名>] [--loop] [--rviz] [--no-gps] [--gps-topic <话题>]"
    exit 1
fi

# 从bag文件名提取序列名
BAG_NAME=$(basename "$BAG_FILE" .bag)

# 准备输出目录
mkdir -p "$OUTPUT_DIR"

source /opt/ros/noetic/setup.bash
source /root/catkin_ws/devel/setup.bash

echo "========================================"
echo " VINS-Fusion KAIST 自动运行"
echo "========================================"
echo " 配置:     $CONFIG"
echo " Bag:      $BAG_FILE"
echo " GPS融合:  $ENABLE_GPS"
echo " GPS话题:  $GPS_TOPIC"
echo " 回环检测: $ENABLE_LOOP"
echo " Rviz:     $ENABLE_RVIZ"
echo " 输出目录: $OUTPUT_DIR"
echo "========================================"

# 配置文件路径
CONFIG_DIR="/root/catkin_ws/src/VINS-Fusion/config/kaist"
CONFIG_FILE="${CONFIG_DIR}/${CONFIG}.yaml"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "错误: 配置文件不存在: $CONFIG_FILE"
    exit 1
fi

# 在配置文件同目录创建临时配置, 修改 output_path
TMP_CONFIG="${CONFIG_DIR}/_run_${CONFIG}.yaml"
sed "s|output_path:.*|output_path: \"${OUTPUT_DIR}/\"|" "$CONFIG_FILE" > "$TMP_CONFIG"

# 清理旧的全局融合输出
GLOBAL_CSV="$OUTPUT_DIR/${BAG_NAME}_global.csv"
rm -f "$GLOBAL_CSV"

# 运行 launch
roslaunch vins kaist_run.launch \
    config_path:="$TMP_CONFIG" \
    bag_file:="$BAG_FILE" \
    enable_rviz:="$ENABLE_RVIZ" \
    enable_loop:="$ENABLE_LOOP" \
    enable_gps:="$ENABLE_GPS" \
    gps_topic:="$GPS_TOPIC" \
    output_path:="$GLOBAL_CSV" || true

# 清理临时配置
rm -f "$TMP_CONFIG"

# 等待写入完成
sleep 1

# 转换 VIO 轨迹
VIO_CSV="$OUTPUT_DIR/vio.csv"
CSV_FILE="$OUTPUT_DIR/${BAG_NAME}.csv"
TUM_FILE="$OUTPUT_DIR/${BAG_NAME}_tum.txt"

if [[ -f "$VIO_CSV" && -s "$VIO_CSV" ]]; then
    mv "$VIO_CSV" "$CSV_FILE"

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
    echo " VIO 轨迹完成! ($LINES 帧)"
    echo " CSV 轨迹: $CSV_FILE"
    echo " TUM 轨迹: $TUM_FILE"
else
    echo "警告: 未找到VIO输出轨迹, 可能运行失败"
fi

# 转换 GPS全局融合轨迹
GLOBAL_TUM="$OUTPUT_DIR/${BAG_NAME}_global_tum.txt"

if [[ -f "$GLOBAL_CSV" && -s "$GLOBAL_CSV" ]]; then
    awk -F',' '{
        if (NF >= 7 && $1 ~ /^[0-9]/) {
            gsub(/[ \t]/, "", $1);
            gsub(/[ \t]/, "", $2);
            gsub(/[ \t]/, "", $3);
            gsub(/[ \t]/, "", $4);
            gsub(/[ \t]/, "", $5);
            gsub(/[ \t]/, "", $6);
            gsub(/[ \t]/, "", $7);
            printf "%.6f %s %s %s %s %s %s %s\n", $1/1e9, $2, $3, $4, $6, $7, $8, $5
        }
    }' "$GLOBAL_CSV" > "$GLOBAL_TUM"

    GLINES=$(wc -l < "$GLOBAL_TUM")
    echo " GPS全局轨迹完成! ($GLINES 帧)"
    echo " CSV 轨迹: $GLOBAL_CSV"
    echo " TUM 轨迹: $GLOBAL_TUM"
fi

echo "========================================"
