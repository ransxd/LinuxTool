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

# 检查输入参数
if [ $# -eq 0 ]; then
    print_info "用法：$0 <视频文件>"
    exit 1
fi

video_file="$1"

# 检查文件是否存在
if [ ! -f "$video_file" ]; then
    print_error "文件 '$video_file' 不存在"
    exit 1
fi

print_info "开始验证视频文件: $video_file"
echo "========================================"

# 获取容器时长
container_duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_file")
print_info "容器总时长: $container_duration 秒"

# 获取视频流时长
video_duration=$(ffprobe -v error -select_streams v:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$video_file")
print_info "视频流时长: $video_duration 秒"

# 获取音频流时长
audio_duration=$(ffprobe -v error -select_streams a:0 -show_entries stream=duration -of default=noprint_wrappers=1:nokey=1 "$video_file")
print_info "音频流时长: $audio_duration 秒"

# 检查时间戳
print_info "检查时间戳信息..."
ffprobe -v error -select_streams v:0 -show_entries packet=pts_time,dts_time -of compact=p=0:nk=1 "$video_file" | head -10
echo "... (仅显示前10行)"

# 检查关键帧
print_info "检查关键帧分布..."
ffprobe -v error -select_streams v:0 -show_entries packet=pts_time,flags -of compact=p=0:nk=1 "$video_file" | grep K | head -10
echo "... (仅显示前10个关键帧)"

# 检查是否有负时间戳
print_info "检查是否存在负时间戳..."
negative_pts=$(ffprobe -v error -select_streams v:0 -show_entries packet=pts_time -of compact=p=0:nk=1 "$video_file" | awk '$1 < 0' | wc -l)
if [ "$negative_pts" -gt 0 ]; then
    print_error "发现 $negative_pts 个负时间戳！"
else
    print_success "未发现负时间戳。"
fi

# 检查时间戳跳变
print_info "检查时间戳跳变..."
ffprobe -v error -select_streams v:0 -show_entries packet=pts_time -of compact=p=0:nk=1 "$video_file" > /tmp/pts_temp.txt
jumps=$(awk 'NR>1 && ($1 - prev) > 0.5 {print NR, $1, prev, ($1-prev)}' prev=$1 /tmp/pts_temp.txt | head -5)
if [ -n "$jumps" ]; then
    print_error "发现时间戳跳变:"
    echo "$jumps"
    echo "... (仅显示前5个跳变)"
else
    print_success "未发现明显的时间戳跳变。"
fi
rm -f /tmp/pts_temp.txt

# 总结
echo "========================================"
print_info "验证总结:"
if [ -z "$video_duration" ] || [ -z "$audio_duration" ] || [ "$negative_pts" -gt 0 ]; then
    print_error "视频可能仍存在问题，建议进一步检查。"
else
    duration_diff=$(awk "BEGIN {print sqrt(($video_duration - $audio_duration)^2)}")
    if (( $(echo "$duration_diff > 1.0" | bc -l) )); then
        print_error "音视频时长差异较大 ($duration_diff 秒)，可能仍存在问题。"
    else
        print_success "视频验证通过！音视频时长一致，未发现明显问题。"
    fi
fi 