#!/bin/bash

# 检查ffmpeg是否已安装
if ! command -v ffmpeg &> /dev/null; then
    echo "ffmpeg未安装，正在安装..."
    sudo apt update
    sudo apt install -y ffmpeg
fi

# 设置工作目录和输出文件
WORK_DIR=$(pwd)
OUTPUT_FILE="merged_output.ts"
TEMP_DIR="$WORK_DIR/temp_processing"
SEGMENT_SIZE=10 # 每次处理的文件数量

# 创建临时目录
mkdir -p "$TEMP_DIR"

# 获取所有TS文件并按名称排序
TS_FILES=($(ls -1 YZ电竞*.ts | sort))

echo "找到 ${#TS_FILES[@]} 个TS文件需要处理"

# 检查是否有足够的空间
TOTAL_SIZE=$(du -sb "${TS_FILES[@]}" | awk '{total += $1} END {print total}')
AVAIL_SPACE=$(df -B1 . | awk 'NR==2 {print $4}')

echo "文件总大小: $(numfmt --to=iec-i --suffix=B $TOTAL_SIZE)"
echo "可用空间: $(numfmt --to=iec-i --suffix=B $AVAIL_SPACE)"

if [ $AVAIL_SPACE -lt $((TOTAL_SIZE / 4)) ]; then
    echo "警告: 可用空间可能不足以完成处理"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "操作已取消"
        exit 1
    fi
fi

# 创建命名管道
PIPE1="$TEMP_DIR/pipe1"
PIPE2="$TEMP_DIR/pipe2"
mkfifo "$PIPE1" "$PIPE2"

# 初始化输出文件
> "$OUTPUT_FILE"

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
    echo "ffconcat version 1.0" > "$LIST_FILE"
    
    # 处理当前分段中的每个文件
    for ((i=start_idx; i<=end_idx; i++)); do
        current_file="${TS_FILES[$i]}"
        echo "正在处理文件 $((i+1))/${#TS_FILES[@]}: $current_file"
        
        # 修复时间戳并处理当前文件
        fixed_file="$TEMP_DIR/fixed_$(basename "$current_file")"
        
        # 使用ffmpeg修复时间戳
        echo "修复时间戳..."
        ffmpeg -i "$current_file" -c copy -bsf:v h264_mp4toannexb -f mpegts "$fixed_file"
        
        # 将修复后的文件添加到concat列表
        echo "file '$fixed_file'" >> "$LIST_FILE"
        
        # 删除原始文件以释放空间
        echo "删除原始文件 $current_file 以释放空间..."
        rm "$current_file"
    done
    
    # 合并当前分段的文件
    segment_output="$TEMP_DIR/segment_${segment}.ts"
    echo "合并分段 $((segment+1)) 的文件..."
    ffmpeg -f concat -safe 0 -i "$LIST_FILE" -c copy "$segment_output"
    
    # 删除修复后的临时文件
    for ((i=start_idx; i<=end_idx; i++)); do
        rm "$TEMP_DIR/fixed_$(basename "${TS_FILES[$i]}")"
    done
    
    # 将当前分段合并到主输出文件
    if [ $segment -eq 0 ]; then
        # 第一个分段直接作为输出文件
        mv "$segment_output" "$OUTPUT_FILE"
    else
        # 使用命名管道和concat协议合并
        temp_output="$TEMP_DIR/temp_output.ts"
        echo "将分段 $((segment+1)) 合并到主文件..."
        ffmpeg -i "concat:$OUTPUT_FILE|$segment_output" -c copy "$temp_output"
        mv "$temp_output" "$OUTPUT_FILE"
        rm "$segment_output"
    fi
    
    # 删除分段列表文件
    rm "$LIST_FILE"
    
    # 显示当前进度和空间状态
    echo "已完成: $((end_idx+1))/${#TS_FILES[@]} 文件"
    echo "当前输出文件大小: $(du -sh "$OUTPUT_FILE" | cut -f1)"
    echo "剩余空间: $(df -h . | awk 'NR==2 {print $4}')"
    echo "-----------------------------------"
done

# 清理临时文件和管道
rm -f "$PIPE1" "$PIPE2"
rm -rf "$TEMP_DIR"

echo "所有文件处理完成!"
echo "最终输出文件: $OUTPUT_FILE"
echo "最终文件大小: $(du -sh "$OUTPUT_FILE" | cut -f1)" 