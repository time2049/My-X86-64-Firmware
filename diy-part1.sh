#!/bin/bash
#
# Copyright (c) 2019-2026 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
#

# 防止重复添加相同源的函数
add_feed() {
    local feed_line="$1"
    if ! grep -Fxq "$feed_line" feeds.conf.default; then
        echo "$feed_line" >> feeds.conf.default
        echo "✅ 已添加源: $feed_line"
    else
        echo "⚠️ 源已存在，跳过: $feed_line"
    fi
}

# 0. 清理可能导致报错的旧源（如果有）
sed -i '/argonconfig/d' feeds.conf.default

# 1. 添加 PassWall 相关源
add_feed 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git'
add_feed 'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git'

# 2. 添加 OpenClash 源
add_feed 'src-git openclash https://github.com/vernesong/OpenClash.git'

# 3. 添加 Argon 主题
# 注意：大部分源码已经自带 Argon，如果你的 .config 里能选，其实这一行也可以不加
add_feed 'src-git argon https://github.com/jerrykuku/luci-theme-argon.git'

# 4. 修复：不再通过 src-git 添加 argonconfig（防止 index missing 报错）
# 如果你真的需要这个插件，建议在 diy-part2.sh 中通过 git clone 方式下载到 package 目录
