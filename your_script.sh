#!/bin/bash

# 定义变量
DOWNLOAD_DIR="./video"
IMG_DIR="./imgs"
LOG_FILE="/tmp/upload_log.txt"

# 参数
M3U8_URL=$1
OBS_VIDEO_PATH=$2
OBS_IMG_PATH=$3
IMG_DOWNLOAD_PATH=$4

# 华为云OBS配置信息
OBS_ENDPOINT="obs.ap-southeast-3.myhuaweicloud.com"
OBS_VIDEO_BUCKET="obs-mv-sg"
OBS_IMG_BUCKET="obs-imgs-sg"

# 确保下载目录存在
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$IMG_DIR"

# 清空日志文件
> "$LOG_FILE"

# 下载加密的m3u8文件
M3U8_FILE="${DOWNLOAD_DIR}/index.m3u8"
DECRYPTED_M3U8_FILE="${DOWNLOAD_DIR}/index_decrypt.m3u8"
echo "Downloading encrypted m3u8 file from $M3U8_URL"
curl -o "$M3U8_FILE" "$M3U8_URL"
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to download $M3U8_URL"
  exit 1
fi

# 解密m3u8文件
echo "Decrypting m3u8 file..."
openssl enc -d -aes-128-ecb -K 7361495a586334794d767130497a3536 -in "$M3U8_FILE" -out "$DECRYPTED_M3U8_FILE"
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to decrypt $M3U8_FILE"
  exit 1
fi

# 下载m3u8文件中的.ts文件
echo "Starting download of .ts files..."
while IFS= read -r line; do
  if [[ "$line" == *.ts ]]; then
    FILE_URL="$(dirname $M3U8_URL)/${line}"
    OUTPUT_FILE="${DOWNLOAD_DIR}/${line}"
    echo "Downloading $FILE_URL to $OUTPUT_FILE"
    curl -o "$OUTPUT_FILE" "$FILE_URL"
    if [[ $? -ne 0 ]]; then
      echo "Error: Failed to download $FILE_URL"
      exit 1
    fi
  fi
done < "$DECRYPTED_M3U8_FILE"

echo "Download completed."

# 下载图片文件
echo "Downloading image file from $IMG_DOWNLOAD_PATH"
IMG_URL="https://wp.xixhx.com${IMG_DOWNLOAD_PATH}"
IMG_OUTPUT_FILE="${IMG_DIR}/$(basename $IMG_DOWNLOAD_PATH)"
curl -o "$IMG_OUTPUT_FILE" "$IMG_URL"
if [[ $? -ne 0 ]]; then
  echo "Error: Failed to download $IMG_URL"
  exit 1
fi
echo "Downloaded $IMG_URL to $IMG_OUTPUT_FILE"

# 上传视频文件到华为云OBS，包括index.m3u8和index_decrypt.m3u8
echo "Starting upload of video files to Huawei OBS..."
for file in "$DOWNLOAD_DIR"/*; do
  filename=$(basename "$file")
  /tmp/data/obsutil cp "$file" "obs://${OBS_VIDEO_BUCKET}${OBS_VIDEO_PATH}/${filename}"
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to upload $file to Huawei OBS"
    exit 1
  fi
  echo "Uploaded ${file} to obs://${OBS_VIDEO_BUCKET}${OBS_VIDEO_PATH}/${filename}" >> "$LOG_FILE"
done

echo "Video files upload completed."

# 上传图片文件到华为云OBS
echo "Starting upload of image files to Huawei OBS..."
for file in "$IMG_DIR"/*; do
  filename=$(basename "$file")
  /tmp/data/obsutil cp "$file" "obs://${OBS_IMG_BUCKET}${OBS_IMG_PATH}/${filename}"
  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to upload $file to Huawei OBS"
    exit 1
  fi
  echo "Uploaded ${file} to obs://${OBS_IMG_BUCKET}${OBS_IMG_PATH}/${filename}" >> "$LOG_FILE"
done

echo "Image files upload completed."

echo "All tasks completed. Log file created at $LOG_FILE"

#用之前先配置：./obsutil config -i=AK -k=SK -e=endpoint
#用法：your_script.sh 加密的m3u8地址 obs桶 obs图片桶 图片地址
#bash your_script.sh https://example.com/path/to/index.m3u8 /path/to/video/obs /path/to/img/obs /uploads/images/movies/2024-05-08/1715165462363.jpeg
