#!/bin/bash
# 纯 Docker 内运行 VINS-Fusion (ROS Noetic)
#
# 用法: ./run_noetic.sh [数据集根目录]
# 示例:
#   ./run_noetic.sh                                    # 使用默认数据集路径
#   ./run_noetic.sh /home/lee/Documents/Datasets_VSLAM # 指定数据集路径
#
# 容器内:
#   run_euroc /root/datasets/euroc_mav/MH_01_easy.bag  # 一键运行并输出TUM轨迹

set -e

DATASETS_PATH="${1:-/home/lee/Documents/Datasets_VSLAM}"
OUTPUT_PATH="${2:-$HOME/Results/vinsFusion_output}"
IMAGE_NAME="vins-fusion-noetic"
CONTAINER_NAME="vins_fusion"

mkdir -p "$OUTPUT_PATH"

# 允许 X11 显示 (rviz 需要)
xhost +local:docker 2>/dev/null || true

docker run -it --rm \
    --name "$CONTAINER_NAME" \
    --net=host \
    --env DISPLAY="$DISPLAY" \
    --volume /tmp/.X11-unix:/tmp/.X11-unix:rw \
    --volume "$DATASETS_PATH":/root/datasets:ro \
    --volume "$OUTPUT_PATH":/root/output:rw \
    "$IMAGE_NAME" \
    bash
