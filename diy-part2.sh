#!/bin/bash
#
# Copyright (c) 2019-2026 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# ==================== 1. 修改默认管理 IP ====================
# 将默认 IP 从 192.168.1.1 改为 10.1.1.1
sed -i 's/192.168.1.1/10.1.1.1/g' package/base-files/files/bin/config_generate

# ==================== 2. 固化中文语言与 Argon 主题 ====================
# 确保系统重置后依然默认显示中文和 Argon 主题
mkdir -p package/base-files/files/etc/config
cat << 'EOF' > package/base-files/files/etc/config/luci
config core 'main'
	option lang 'zh-cn'
	option mediaurlbase '/luci-static/argon'
	option resourcebase '/luci-static/resources'

config internal 'themes'
	option Argon '/luci-static/argon'
	option Bootstrap '/luci-static/bootstrap'
EOF

# ==================== 3. 自动更新 PassWall 核心组件 ====================
# 自动拉取 GitHub 最新版 Xray/Sing-box/Hysteria，保证节点协议最新
update_go_package() {
    local pkg_name=$1
    local github_repo=$2
    local makefile_path="feeds/passwall_packages/$pkg_name/Makefile"
    [ -f "$makefile_path" ] || return 0
    echo "🔄 正在检查 $pkg_name 最新版本..."
    local latest_version=$(curl --silent "https://api.github.com/repos/$github_repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
    if [ -n "$latest_version" ]; then
        local current_version=$(grep 'PKG_VERSION:=' "$makefile_path" | cut -d'=' -f2)
        if [ "$latest_version" != "$current_version" ]; then
            sed -i "s|PKG_VERSION:=.*|PKG_VERSION:=$latest_version|g" "$makefile_path"
            sed -i "s|PKG_HASH:=.*|PKG_HASH:=skip|g" "$makefile_path"
            echo "   ✅ $pkg_name 已更新至 $latest_version"
        fi
    fi
}
update_go_package "xray-core" "XTLS/Xray-core"
update_go_package "sing-box" "SagerNet/sing-box"
update_go_package "hysteria" "apernet/hysteria"

# ==================== 4. CPU 温度显示集成 (适配 files 目录) ====================
# 注入 x86 CPU 温度传感器驱动
echo 'CONFIG_PACKAGE_kmod-coretemp=y' >> .config
echo 'CONFIG_PACKAGE_kmod-it87=y' >> .config
echo 'CONFIG_PACKAGE_lm-sensors=y' >> .config

# 自动将你上传到仓库的 index.htm 覆盖到源码路径，实现首页显示温度
TARGET_INDEX="feeds/luci/modules/luci-mod-status/luasrc/view/admin_status/index.htm"
if [ -f "files/usr/lib/lua/luci/view/admin_status/index.htm" ]; then
    cp -f "files/usr/lib/lua/luci/view/admin_status/index.htm" "$TARGET_INDEX"
    echo "✅ 已成功应用自定义温度显示模板 (index.htm)"
else
    echo "⚠️ 警告：未在 files 目录找到 index.htm，首页可能不显示温度"
fi

# ==================== 5. 最后的配置刷新 ====================
# 自动处理依赖冲突
make defconfig
