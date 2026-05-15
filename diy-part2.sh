#!/bin/bash

# ==================== 1. 修改默认管理 IP ====================
sed -i 's/192.168.1.1/10.1.1.1/g' package/base-files/files/bin/config_generate

# ==================== 2. 固化默认语言和 Argon 主题（重置不丢失）====================
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

# 强制选中语言包和主题（确保编译进固件）
echo 'CONFIG_PACKAGE_luci-i18n-base-zh-cn=y' >> .config
echo 'CONFIG_PACKAGE_luci-theme-argon=y' >> .config
echo 'CONFIG_PACKAGE_luci-app-argon-config=y' >> .config
echo 'CONFIG_PACKAGE_luci-i18n-argon-config-zh-cn=y' >> .config

# ==================== 3. 自动更新 PassWall 核心组件 ====================
update_go_package() {
    local pkg_name=$1
    local github_repo=$2
    local makefile_path="feeds/passwall_packages/$pkg_name/Makefile"
    [ -f "$makefile_path" ] || { echo "⚠️ 跳过 $pkg_name（路径不存在）"; return 0; }
    echo "🔄 检查 $pkg_name 最新版本..."
    local latest_version=$(curl --silent --connect-timeout 5 --max-time 10 "https://api.github.com/repos/$github_repo/releases/latest" | \
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
    if [ -n "$latest_version" ]; then
        local current_version=$(grep 'PKG_VERSION:=' "$makefile_path" | cut -d'=' -f2)
        if [ "$latest_version" != "$current_version" ]; then
            echo "   ✅ 更新 $pkg_name: $current_version -> $latest_version"
            sed -i "s|PKG_VERSION:=.*|PKG_VERSION:=$latest_version|g" "$makefile_path"
            sed -i "s|PKG_HASH:=.*|PKG_HASH:=skip|g" "$makefile_path"
        fi
    fi
}

update_go_package "xray-core" "XTLS/Xray-core"
update_go_package "sing-box" "SagerNet/sing-box"
update_go_package "hysteria" "apernet/hysteria"

# ==================== 4. 添加 CPU 温度显示（x86） ====================
echo 'CONFIG_PACKAGE_kmod-coretemp=y' >> .config
echo 'CONFIG_PACKAGE_kmod-it87=y' >> .config
echo 'CONFIG_PACKAGE_lm-sensors=y' >> .config

# 创建模块自动加载文件
mkdir -p package/base-files/files/etc/modules.d
echo "coretemp" > package/base-files/files/etc/modules.d/coretemp

# 复制自定义 index.htm（温度显示模板）
TARGET_INDEX="feeds/luci/modules/luci-mod-status/luasrc/view/admin_status/index.htm"
CUSTOM_SOURCE="$GITHUB_WORKSPACE/files/usr/lib/lua/luci/view/admin_status/index.htm"
if [ -f "$CUSTOM_SOURCE" ]; then
    cp -f "$CUSTOM_SOURCE" "$TARGET_INDEX"
    echo "✅ CPU 温度显示模板已覆盖"
else
    echo "⚠️ 未找到自定义 index.htm，温度显示可能无效"
fi

# ==================== 5. 消除编译警告并刷新配置 ====================
echo '# CONFIG_PACKAGE_onionshare-cli is not set' >> .config
make defconfig
