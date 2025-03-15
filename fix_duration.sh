#!/bin/bash

# 设置错误时立即退出
set -e

# 彩色输出函数
print_info() {
    echo -e "\033[1;34m[信息]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[成功]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[错误]\033[0m $1"
}

# 检查是否安装了ffmpeg
if ! command -v ffmpeg &> /dev/null; then
    print_error "未安装ffmpeg。请先安装ffmpeg。"
    exit 1
fi

# 检查输入参数
if [ $# -eq 0 ]; then
    print_info "用法：$0 <输入视频文件> [输出格式(可选)]"
    print_info "输出格式默认为mp4，可选：mp4, mkv, ts"
    exit 1
fi

input_file="$1"
format="mp4"

# 检查是否指定了输出格式
if [ $# -ge 2 ]; then
    if [[ "$2" =~ ^(mp4|mkv|ts)$ ]]; then
        format="$2"
    else
        print_error "不支持的输出格式: $2。支持的格式: mp4, mkv, ts"
        exit 1
    fi
fi

output_file="${input_file%.*}_fixed.$format"

# 检查输入文件是否存在
if [ ! -f "$input_file" ]; then
    print_error "输入文件 '$input_file' 不存在"
    exit 1
fi

# 检查磁盘空间
input_size=$(du -m "$input_file" | cut -f1)
available_space=$(df -m . | tail -1 | awk '{print $4}')

if [ "$available_space" -lt "$input_size" ]; then
    print_error "磁盘空间不足。需要至少 ${input_size}MB，但只有 ${available_space}MB 可用。"
    exit 1
fi

print_info "开始修复视频时长..."
print_info "输入文件: $input_file"
print_info "输出文件: $output_file"

# 使用ffmpeg重新编码修复视频 - 简化参数，不再尝试获取原始视频信息
ffmpeg -y -i "$input_file" \
    -c:v libx264 \
    -preset faster \
    -crf 22 \
    -profile:v high \
    -level 4.1 \
    -pix_fmt yuv420p \
    -c:a aac \
    -b:a 192k \
    -fflags +genpts \
    -max_interleave_delta 0 \
    -avoid_negative_ts make_zero \
    -analyzeduration 200M \
    -probesize 200M \
    -fps_mode cfr \
    -movflags +faststart \
    -metadata title="Fixed Video" \
    "$output_file"

# 检查是否成功
if [ $? -eq 0 ]; then
    print_success "视频修复完成！"
    print_success "修复后的文件：$output_file"
    
    # 显示修复前后的视频信息
    echo -e "\n原始视频信息："
    ffmpeg -i "$input_file" 2>&1 | grep "Duration"
    echo -e "\n修复后视频信息："
    ffmpeg -i "$output_file" 2>&1 | grep "Duration"
    
    # 显示文件大小对比
    original_size=$(du -h "$input_file" | cut -f1)
    new_size=$(du -h "$output_file" | cut -f1)
    print_info "原始文件大小: $original_size"
    print_info "修复后文件大小: $new_size"
else
    print_error "视频修复失败！"
fi 