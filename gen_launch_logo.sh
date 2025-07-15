#!/bin/bash
# 一键生成iOS和Android启动logo图片（适配ImageMagick 7+）

# iOS 启动图
magick assets/logo.svg -background none -resize 168x168 ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png
magick assets/logo.svg -background none -resize 336x336 ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png
magick assets/logo.svg -background none -resize 504x504 ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png

# Android 启动logo（各分辨率）
magick assets/logo.svg -background none -resize 48x48 android/app/src/main/res/mipmap-mdpi/ic_launcher.png
magick assets/logo.svg -background none -resize 72x72 android/app/src/main/res/mipmap-hdpi/ic_launcher.png
magick assets/logo.svg -background none -resize 96x96 android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
magick assets/logo.svg -background none -resize 144x144 android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
magick assets/logo.svg -background none -resize 192x192 android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

echo "所有启动logo已生成并覆盖到对应目录！" 