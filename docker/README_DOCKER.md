# VINS-Fusion Docker 使用文档 (ROS Noetic)

本文档介绍如何在 Docker 容器中运行 VINS-Fusion，适用于宿主机为 ROS2 Humble 或无 ROS1 环境的情况。

## 环境要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Ubuntu 20.04 / 22.04 / 24.04 |
| Docker | >= 20.10 |
| 显示 | X11（rviz 可视化需要） |
| 磁盘空间 | 约 5 GB（镜像构建后） |

## 目录结构

```
docker/
├── Dockerfile.noetic    # ROS Noetic 版 Dockerfile
├── run_noetic.sh        # 一键启动脚本
├── Dockerfile           # 原版 (ROS Kinetic，已弃用)
├── run.sh               # 原版启动脚本
└── Makefile             # 原版构建
```

---

## 快速开始

### 第一步：构建镜像

在项目根目录执行：

```bash
cd /home/lee/vinsFusion_ws/VINS-Fusion
docker build -f docker/Dockerfile.noetic -t vins-fusion-noetic .
```

> 构建过程会编译 Ceres Solver 2.1.0 和 VINS-Fusion，首次构建约需 10-20 分钟。

### 第二步：启动容器

所有数据集目录 `/home/lee/Documents/Datasets_VSLAM` 会整体挂载到容器内 `/root/datasets/`：

```bash
cd /home/lee/vinsFusion_ws/VINS-Fusion/docker
./run_noetic.sh
```

> 默认挂载 `/home/lee/Documents/Datasets_VSLAM`，也可指定其他路径：`./run_noetic.sh /path/to/datasets`

容器内数据集路径映射：

| 宿主机路径 | 容器内路径 |
|-----------|-----------|
| `/home/lee/Documents/Datasets_VSLAM/TUM/` | `/root/datasets/TUM/` |

---

## 容器内操作

### 一键运行（推荐）

容器内提供 `run_euroc` 命令，自动完成 roscore 启动、VINS 运行、bag 回放、TUM 轨迹保存：

```bash
# 双目 + IMU（默认配置）
run_euroc /root/datasets/euroc_mav/MH_01_easy.bag

# 单目 + IMU
run_euroc /root/datasets/euroc_mav/MH_01_easy.bag --config euroc_mono_imu_config

# 双目 + IMU
run_euroc /root/datasets/euroc_mav/MH_01_easy.bag --config euroc_stereo_imu_config

# 启用回环检测
run_euroc /root/datasets/euroc_mav/MH_01_easy.bag --loop

# 启用 rviz 可视化
run_euroc /root/datasets/euroc_mav/MH_01_easy.bag --rviz
```

运行完成后输出：

```
/root/output/
├── MH_01_easy_tum.txt      # TUM 格式轨迹 (timestamp x y z qx qy qz qw)
└── MH_01_easy.csv          # VINS 原始 CSV 轨迹
```

TUM 轨迹文件同时保存在宿主机 `~/Results/vinsFusion_output/` 目录下。

### KAIST 数据集 (双目 + IMU + GPS)

容器内提供 `run_kaist` 命令，支持 GPS 全局融合：

```bash
# 默认配置 (双目+IMU+GPS)
run_kaist /root/datasets/kaist/urban28.bag

# 指定GPS话题名 (默认 /gps)
run_kaist /root/datasets/KAIST/urban28.bag --gps-topic /navsat/fix

# 不使用GPS
run_kaist /root/datasets/KAIST/urban28.bag --no-gps

# 启用回环检测和rviz
run_kaist /root/datasets/KAIST/urban28.bag --loop --rviz
```

运行完成后输出：

```
/root/output/
├── urban28.csv                # VINS VIO 轨迹
├── urban28_tum.txt            # VIO TUM 格式轨迹
├── urban28_global.csv         # GPS全局融合轨迹
└── urban28_global_tum.txt     # GPS全局融合 TUM 格式轨迹
```

### rpng_plane (Table) 数据集 (单目 + IMU)

容器内提供 `run_rpng_plane` 命令：

```bash
# 默认配置 (单目+IMU)
run_rpng_plane /root/datasets/table/table_01.bag

# 启用回环检测和rviz
run_rpng_plane /root/datasets/table/table_01.bag --loop --rviz
```

运行完成后输出：

```
/root/output/
├── table.csv              # VINS 原始 CSV 轨迹
└── table_tum.txt          # TUM 格式轨迹
```

### 手动运行（多终端方式）

如需更灵活的控制，可手动启动各节点。每个新终端先进入容器：

```bash
docker exec -it vins_fusion bash
source /root/catkin_ws/devel/setup.bash
```

**终端 1** — roscore：`roscore`

**终端 2** — VINS 节点：

```bash
rosrun vins vins_node /root/catkin_ws/src/VINS-Fusion/config/euroc/euroc_stereo_imu_config.yaml
```

**终端 3** — rviz（可选）：

```bash
rviz -d /root/catkin_ws/src/VINS-Fusion/config/vins_rviz_config.rviz
```

**终端 4** — 回放 bag：

```bash
rosbag play /root/datasets/euroc_mav/MH_01_easy.bag
```

---