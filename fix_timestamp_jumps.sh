#!/bin/bash

# 设置日志文件
LOG_FILE="timestamp_fix_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "开始执行时间戳修复脚本 - $(date)"
echo "系统信息:"
free -h
echo "CPU信息:"
lscpu | grep -E "CPU\(s\)|Core\(s\)|Thread\(s\)|Model name"

# 检查ffmpeg是否已安装
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg未安装，正在安装..."
    sudo apt update
    sudo apt install -y ffmpeg
fi

# 设置工作目录和临时目录
WORK_DIR=$(pwd)
TEMP_DIR="$WORK_DIR/temp_processing"
SEGMENT_SIZE=2 # 每次处理的文件数量，设置较小以节省空间

# 创建临时目录
mkdir -p "$TEMP_DIR"

# 获取所有TS文件并按名称排序
TS_FILES=($(ls -1 *.ts | sort))

if [ ${#TS_FILES[@]} -eq 0 ]; then
    echo "错误: 当前目录下没有找到TS文件" | tee -a "$LOG_FILE"
    exit 1
fi

# 设置输出文件名为第一个文件的名称（但扩展名改为mp4）
FIRST_FILENAME=$(basename "${TS_FILES[0]}" .ts)
OUTPUT_FILE="${FIRST_FILENAME}.mp4"

echo "找到 ${#TS_FILES[@]} 个TS文件需要处理"
echo "输出文件将命名为: $OUTPUT_FILE"

# 检查是否有足够的空间
TOTAL_SIZE=$(du -sb "${TS_FILES[@]}" | awk '{total += $1} END {print total}')
AVAIL_SPACE=$(df -B1 . | awk 'NR==2 {print $4}')

echo "文件总大小: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE)"
echo "可用空间: $(numfmt --to=iec-i --suffix=B $AVAIL_SPACE)"

if [ $AVAIL_SPACE -lt $((TOTAL_SIZE / 2)) ]; then
    echo "警告: 可用空间可能不足以完成处理"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "操作已取消"
        exit 1
    fi
fi

# 创建临时TS输出文件
TEMP_TS_OUTPUT="$TEMP_DIR/temp_merged.ts"
> "$TEMP_TS_OUTPUT"

# 分段处理文件
total_segments=$(( (${#TS_FILES[@]} + SEGMENT_SIZE - 1) / SEGMENT_SIZE ))
for ((segment=0; segment<total_segments; segment++)); do
    start_idx=$((segment * SEGMENT_SIZE))
    end_idx=$(( (segment + 1) * SEGMENT_SIZE - 1 ))
    
    # 确保end_idx不超过文件数组的最大索引
    if [ $end_idx -ge ${#TS_FILES[@]} ]; then
        end_idx=$((${#TS_FILES[@]} - 1))
    fi
    
    echo "处理分段 $((segment+1))/$total_segments (文件 $((start_idx+1)) 到 $((end_idx+1)))"
    
    # 为当前分段创建concat列表
    LIST_FILE="$TEMP_DIR/segment_${segment}_list.txt"
    > "$LIST_FILE"
    
    # 处理当前分段中的每个文件
    for ((i=start_idx; i<=end_idx; i++)); do
        current_file="${TS_FILES[$i]}"
        echo "正在处理文件 $((i+1))/${#TS_FILES[@]}: $current_file"
        
        # 分析文件的时间戳信息
        echo "分析时间戳信息..."
        ffprobe -v error -show_entries packet=pts_time,dts_time -select_streams v -of csv=p=0 "$current_file" > "$TEMP_DIR/timestamps_$(basename "$current_file").txt" 2>> "$LOG_FILE"
        
        # 修复时间戳并处理当前文件
        fixed_file="$TEMP_DIR/fixed_$(basename "$current_file")"
        
        # 使用ffmpeg修复时间戳 - 使用特殊选项处理时间戳跳变
        echo "修复时间戳..."
        if ! ffmpeg -i "$current_file" -c copy -bsf:v h264_mp4toannexb -fflags +genpts -avoid_negative_ts make_zero -f mpegts "$fixed_file" 2>> "$LOG_FILE"; then
            echo "错误: 处理文件 $current_file 时出错，详细信息请查看日志文件 $LOG_FILE" | tee -a "$LOG_FILE"
            exit 1
        fi
        
        # 将修复后的文件路径添加到concat列表
        echo "file '$fixed_file'" >> "$LIST_FILE"
        
        # 删除原始文件以释放空间
        echo "删除原始文件 $current_file 以释放空间..."
        rm "$current_file"
    done
    
    # 合并当前分段的文件
    segment_output="$TEMP_DIR/segment_${segment}.ts"
    echo "合并分段 $((segment+1)) 的文件..."
    if ! ffmpeg -f concat -safe 0 -i "$LIST_FILE" -c copy -fflags +genpts -avoid_negative_ts make_zero "$segment_output" 2>> "$LOG_FILE"; then
        echo "错误: 合并分段 $((segment+1)) 时出错，详细信息请查看日志文件 $LOG_FILE" | tee -a "$LOG_FILE"
        exit 1
    fi
    
    # 删除修复后的临时文件
    for ((i=start_idx; i<=end_idx; i++)); do
        rm "$TEMP_DIR/fixed_$(basename "${TS_FILES[$i]}")"
    done
    
    # 将当前分段合并到主输出文件
    if [ $segment -eq 0 ]; then
        # 第一个分段直接作为临时输出文件
        mv "$segment_output" "$TEMP_TS_OUTPUT"
    else
        # 使用concat协议合并，并应用时间戳修复选项
        temp_output="$TEMP_DIR/temp_output.ts"
        echo "将分段 $((segment+1)) 合并到主文件..."
        if ! ffmpeg -i "concat:$TEMP_TS_OUTPUT|$segment_output" -c copy -fflags +genpts -avoid_negative_ts make_zero "$temp_output" 2>> "$LOG_FILE"; then
            echo "错误: 合并主文件时出错，详细信息请查看日志文件 $LOG_FILE" | tee -a "$LOG_FILE"
            exit 1
        fi
        mv "$temp_output" "$TEMP_TS_OUTPUT"
        rm "$segment_output"
    fi
    
    # 删除分段列表文件
    rm "$LIST_FILE"
    
    # 显示当前进度和空间状态
    echo "已完成: $((end_idx+1))/${#TS_FILES[@]} 文件"
    echo "当前临时文件大小: $(du -sh "$TEMP_TS_OUTPUT" | cut -f1)"
    echo "剩余空间: $(df -h . | awk 'NR==2 {print $4}')"
    echo "-----------------------------------"
done

# 将最终的TS文件转换为MP4格式
echo "将合并后的TS文件转换为MP4格式..."
if ! ffmpeg -i "$TEMP_TS_OUTPUT" -c copy -movflags faststart "$OUTPUT_FILE" 2>> "$LOG_FILE"; then
    echo "错误: 转换为MP4格式时出错，详细信息请查看日志文件 $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

# 清理临时文件
rm -rf "$TEMP_DIR"

echo "所有文件处理完成!"
echo "最终输出文件: $OUTPUT_FILE"
echo "最终文件大小: $(du -sh "$OUTPUT_FILE" | cut -f1)"
echo "处理日志已保存至: $LOG_FILE"
echo "结束执行时间: $(date)" 