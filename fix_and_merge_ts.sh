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

# 初始化输出文件
> "$OUTPUT_FILE"

# 处理每个文件
for ((i=0; i<${#TS_FILES[@]}; i++)); do
    current_file="${TS_FILES[$i]}"
    echo "正在处理文件 $((i+1))/${#TS_FILES[@]}: $current_file"
    
    # 修复时间戳并处理当前文件
    fixed_file="$TEMP_DIR/fixed_$(basename "$current_file")"
    
    # 使用ffmpeg修复时间戳
    echo "修复时间戳..."
    ffmpeg -i "$current_file" -c copy -bsf:v h264_mp4toannexb -f mpegts "$fixed_file"
    
    if [ $i -eq 0 ]; then
        # 第一个文件直接复制到输出
        cp "$fixed_file" "$OUTPUT_FILE"
    else
        # 创建临时合并文件
        temp_output="$TEMP_DIR/temp_output.ts"
        
        # 使用concat协议合并
        echo "合并到主文件..."
        ffmpeg -i "concat:$OUTPUT_FILE|$fixed_file" -c copy -bsf:a aac_adtstoasc "$temp_output"
        
        # 替换输出文件
        mv "$temp_output" "$OUTPUT_FILE"
    fi
    
    # 删除临时修复文件
    rm "$fixed_file"
    
    # 删除原始文件以释放空间
    echo "删除原始文件 $current_file 以释放空间..."
    rm "$current_file"
    
    # 显示当前进度和空间状态
    echo "已完成: $((i+1))/${#TS_FILES[@]} 文件"
    echo "当前输出文件大小: $(du -sh "$OUTPUT_FILE" | cut -f1)"
    echo "剩余空间: $(df -h . | awk 'NR==2 {print $4}')"
    echo "-----------------------------------"
done

# 清理临时目录
rm -rf "$TEMP_DIR"

echo "所有文件处理完成!"
echo "最终输出文件: $OUTPUT_FILE"
echo "最终文件大小: $(du -sh "$OUTPUT_FILE" | cut -f1)" 