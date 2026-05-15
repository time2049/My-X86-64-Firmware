#!/bin/bash
#
# Copyright (c) 2019-2026 P3TERX <https://p3terx.com>
#
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
# 注意：此脚本在工作流的步骤 7 执行（在 feeds install 之后，make defconfig 之前）
#

# 1. 修改默认管理 IP
sed -i 's/192.168.1.1/10.1.1.1/g' package/base-files/files/bin/config_generate

# 2. 固化中文语言与 Argon 主题（通过 uci-defaults 脚本，不产生文件冲突）
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-custom-luci
#!/bin/sh
uci set luci.main.lang='zh-cn'
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-luci
echo "✅ 已添加 uci-defaults 脚本，首次启动将自动设置语言和主题"

# 3. 自动更新 PassWall 核心组件（Xray/sing-box/hysteria）
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

# 4. 添加 CPU 温度与硬件加速支持（适用于 J1900 等）
echo 'CONFIG_PACKAGE_kmod-coretemp=y' >> .config
echo 'CONFIG_PACKAGE_kmod-it87=y' >> .config
echo 'CONFIG_PACKAGE_lm-sensors=y' >> .config
echo 'CONFIG_NODEJS_GCC_X64_LEVEL=2' >> .config

# 5. 首页温度模板应用（如果你有自定义模板文件）
TARGET_INDEX="feeds/luci/modules/luci-mod-status/luasrc/view/admin_status/index.htm"
if [ -f "files/usr/lib/lua/luci/view/admin_status/index.htm" ]; then
    cp -f "files/usr/lib/lua/luci/view/admin_status/index.htm" "$TARGET_INDEX"
    echo "✅ 已应用自定义温度显示模板"
fi

# 6. 添加其他必要插件（例如 Argon 配置插件）
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config
echo "✅ 已添加 luci-app-argon-config"

# 7. 最后刷新 feeds（确保所有自定义包被识别）
./scripts/feeds install -a

echo "🚀 diy-part2.sh 执行完毕"
