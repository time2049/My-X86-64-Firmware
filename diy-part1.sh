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

# 1. 添加 PassWall 源（使用 main 分支以适配最新内核）
echo 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git;main' >> feeds.conf.default
echo 'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git;main' >> feeds.conf.default

# 2. 添加 OpenClash 源（全能代理必备）
echo 'src-git openclash https://github.com/vernesong/OpenClash.git' >> feeds.conf.default

# 3. 添加 Argon 主题及其配置插件
echo 'src-git argon https://github.com/jerrykuku/luci-theme-argon.git' >> feeds.conf.default
echo 'src-git argonconfig https://github.com/jerrykuku/luci-app-argon-config.git' >> feeds.conf.default

# 4. (可选) 如果你需要更多插件，可以在下方继续添加
