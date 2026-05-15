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

# 1. 添加 PassWall 相关源（使用标准 ^%S 占位符，替代 ;master）
add_feed 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git^%S'
add_feed 'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git^%S'
# 可选：如果需要额外 PassWall 组件，取消注释下面一行
# add_feed 'src-git passwall_spec https://github.com/Openwrt-PassWall/openwrt-passwall-spec.git^%S'

# 2. 添加 OpenClash 源
add_feed 'src-git openclash https://github.com/vernesong/OpenClash.git^%S'

# 3. 添加 Argon 主题及其配置插件
add_feed 'src-git argon https://github.com/jerrykuku/luci-theme-argon.git^%S'
add_feed 'src-git argonconfig https://github.com/jerrykuku/luci-app-argon-config.git^%S'

# 4. (可选) 如果你需要更多插件，可以在下方按照相同格式继续添加
# add_feed 'src-git example https://github.com/example/example.git^%S'
