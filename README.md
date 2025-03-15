# TS视频文件时间戳修复与合并工具

这个项目包含多个脚本，用于修复TS视频文件的时间戳跳变问题，并将多个TS文件合并为一个文件。这些脚本特别适用于硬盘空间有限的情况，因为它们会在处理过程中删除已处理的原始文件以释放空间。

## 功能特点

- 修复TS视频文件的时间戳跳变问题
- 合并多个TS文件为一个完整文件
- 处理过程中自动释放硬盘空间
- 提供多种处理方法适应不同场景
- 支持视频文件验证和时长修复
- 集成OneDrive云存储挂载功能

## 快速开始

### 从GitHub下载

```bash
# 克隆整个仓库
git clone https://github.com/ransxd/LinuxTool.git
cd LinuxTool
chmod +x *.sh

# 或者下载单个脚本（示例：下载时间戳修复脚本）
wget https://raw.githubusercontent.com/ransxd/LinuxTool/main/fix_timestamp_jumps.sh
chmod +x fix_timestamp_jumps.sh
```

### 直接运行（无需下载）

```bash
# 使用curl直接运行脚本（示例：运行时间戳修复脚本）
bash <(curl -s https://raw.githubusercontent.com/ransxd/LinuxTool/main/fix_timestamp_jumps.sh)

# 或者使用wget
bash <(wget -qO- https://raw.githubusercontent.com/ransxd/LinuxTool/main/fix_timestamp_jumps.sh)
```

## 脚本说明

### 主要处理脚本

#### 1. fix_timestamp_jumps.sh

专门针对时间戳跳变问题的脚本，使用ffmpeg的高级选项。

**特点**：
- 使用ffmpeg的特殊选项处理时间戳问题
- 分析每个文件的时间戳信息
- 使用-fflags +genpts和-avoid_negative_ts make_zero选项
- 最适合修复时间戳跳变问题

**下载链接**: [fix_timestamp_jumps.sh](https://raw.githubusercontent.com/ransxd/LinuxTool/main/fix_timestamp_jumps.sh)

#### 2. fix_ts_streaming.sh

使用分段处理方法，更加节省空间。

**特点**：
- 将文件分成多个小段进行处理
- 处理完一段后合并到主文件并删除临时文件
- 使用命名管道减少磁盘IO
- 适用于空间极其有限的情况

**下载链接**: [fix_ts_streaming.sh](https://raw.githubusercontent.com/ransxd/LinuxTool/main/fix_ts_streaming.sh)

#### 3. fix_ts_with_demuxer.sh

使用concat demuxer方法修复和合并TS文件。

**特点**：
- 先处理所有文件，然后一次性合并
- 使用concat demuxer，可能对某些文件更有效
- 需要更多临时空间

**下载链接**: [fix_ts_with_demuxer.sh](https://raw.githubusercontent.com/ransxd/LinuxTool/main/fix_ts_with_demuxer.sh)

#### 4. fix_and_merge_ts.sh

基本的TS文件修复和合并脚本，使用concat协议逐个处理文件。

**特点**：
- 逐个处理文件，处理完一个就删除一个
- 使用concat协议合并文件
- 适用于大多数简单情况

**下载链接**: [fix_and_merge_ts.sh](https://raw.githubusercontent.com/ransxd/LinuxTool/main/fix_and_merge_ts.sh)

### 辅助工具脚本

#### 5. verify_fix.sh

验证视频文件修复效果的脚本。

**特点**：
- 检查视频文件的时间戳连续性
- 分析视频流信息
- 提供详细的验证报告
- 帮助确认修复是否成功

**下载链接**: [verify_fix.sh](https://raw.githubusercontent.com/ransxd/LinuxTool/main/verify_fix.sh)

#### 6. fix_duration.sh

修复视频文件时长信息的脚本。

**特点**：
- 修正视频文件的时长元数据
- 支持多种输出格式（mp4、mkv、ts）
- 保持视频质量不变
- 解决某些播放器显示时长不正确的问题

**下载链接**: [fix_duration.sh](https://raw.githubusercontent.com/ransxd/LinuxTool/main/fix_duration.sh)

#### 7. setup-rclone-onedrive.sh

设置rclone挂载OneDrive云存储的脚本。

**特点**：
- 自动安装和配置rclone
- 设置OneDrive挂载点
- 创建系统服务实现开机自动挂载
- 方便将处理后的视频文件备份到云端

**下载链接**: [setup-rclone-onedrive.sh](https://raw.githubusercontent.com/ransxd/LinuxTool/main/setup-rclone-onedrive.sh)

## 使用方法

### 基本使用

1. 将脚本上传到您的Linux服务器（推荐Ubuntu系统）
2. 给脚本添加执行权限：
   ```
   chmod +x *.sh
   ```
3. 在包含TS文件的目录中运行相应脚本：
   ```
   ./fix_timestamp_jumps.sh
   ```

### 验证修复效果

处理完成后，可以使用验证脚本检查修复效果：
```
./verify_fix.sh 输出文件名.mp4
```

### 修复视频时长

如果视频时长显示不正确，可以使用时长修复脚本：
```
./fix_duration.sh 输入文件名.mp4 [输出格式]
```

### 设置OneDrive挂载

如需将处理后的文件备份到OneDrive：
```
sudo ./setup-rclone-onedrive.sh
```

## 推荐使用顺序

根据您的具体情况，推荐按以下顺序尝试这些脚本：

1. 首先尝试 `fix_timestamp_jumps.sh`，因为它专门针对时间戳跳变问题
2. 如果空间非常有限，尝试 `fix_ts_streaming.sh`
3. 如果上述方法不起作用，尝试 `fix_ts_with_demuxer.sh`
4. 如果问题仍然存在，尝试 `fix_and_merge_ts.sh`
5. 处理完成后使用 `verify_fix.sh` 验证效果
6. 如有需要，使用 `fix_duration.sh` 修复时长信息

## 系统要求

- Linux操作系统（推荐Ubuntu 18.04或更高版本）
- 已安装ffmpeg（脚本会检查并提示安装）
- 足够的临时存储空间（至少与最大TS文件相同）
- 对于OneDrive功能，需要root权限

## 注意事项

- 所有处理脚本都会删除原始文件，请确保您有备份
- 脚本会自动检查空间是否足够，如果不足会提示您
- 处理大文件可能需要较长时间，请耐心等待
- 如果遇到问题，可以查看ffmpeg的错误输出进行调试
- OneDrive挂载需要网络连接稳定

## 常见问题

1. **Q: 脚本执行时报错"command not found"**  
   A: 请确保已给脚本添加执行权限 `chmod +x *.sh`

2. **Q: 处理过程中空间不足**  
   A: 尝试使用 `fix_ts_streaming.sh` 脚本，它更节省空间

3. **Q: 修复后的视频播放仍有问题**  
   A: 使用 `verify_fix.sh` 检查修复效果，可能需要尝试其他修复脚本

4. **Q: OneDrive挂载失败**  
   A: 检查网络连接，确保已正确配置rclone

## 项目地址

GitHub仓库：[https://github.com/ransxd/LinuxTool](https://github.com/ransxd/LinuxTool) 