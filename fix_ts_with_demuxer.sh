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
LIST_FILE="$TEMP_DIR/concat_list.txt"

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

if [ $AVAIL_SPACE -lt $((TOTAL_SIZE / 2)) ]; then
    echo "警告: 可用空间可能不足以完成处理"
    read -p "是否继续? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "操作已取消"
        exit 1
    fi
fi

# 创建concat列表文件
echo "ffconcat version 1.0" > "$LIST_FILE"

# 逐个处理文件
for ((i=0; i<${#TS_FILES[@]}; i++)); do
    current_file="${TS_FILES[$i]}"
    echo "正在处理文件 $((i+1))/${#TS_FILES[@]}: $current_file"
    
    # 修复时间戳并处理当前文件
    fixed_file="$TEMP_DIR/fixed_$(basename "$current_file")"
    
    # 使用ffmpeg修复时间戳
    echo "修复时间戳..."
    ffmpeg -i "$current_file" -c copy -bsf:v h264_mp4toannexb -f mpegts "$fixed_file"
    
    # 将修复后的文件添加到concat列表
    echo "file '$fixed_file'" >> "$LIST_FILE"
    
    # 如果不是第一个文件，可以删除原始文件以释放空间
    if [ $i -gt 0 ] || [ ${#TS_FILES[@]} -eq 1 ]; then
        echo "删除原始文件 $current_file 以释放空间..."
        rm "$current_file"
    fi
    
    # 显示当前进度和空间状态
    echo "已处理: $((i+1))/${#TS_FILES[@]} 文件"
    echo "剩余空间: $(df -h . | awk 'NR==2 {print $4}')"
    echo "-----------------------------------"
done

# 使用concat demuxer合并所有修复后的文件
echo "合并所有文件..."
ffmpeg -f concat -safe 0 -i "$LIST_FILE" -c copy "$OUTPUT_FILE"

# 删除第一个原始文件（如果还存在）
if [ -f "${TS_FILES[0]}" ]; then
    echo "删除最后一个原始文件 ${TS_FILES[0]}..."
    rm "${TS_FILES[0]}"
fi

# 清理临时文件
echo "清理临时文件..."
rm -rf "$TEMP_DIR"

echo "所有文件处理完成!"
echo "最终输出文件: $OUTPUT_FILE"
echo "最终文件大小: $(du -sh "$OUTPUT_FILE" | cut -f1)" 