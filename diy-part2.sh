#!/bin/bash
#
# Copyright (c) 2019-2026 P3TERX <https://p3terx.com>
#
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# 1. 修改默认管理 IP
sed -i 's/192.168.1.1/10.1.1.1/g' package/base-files/files/bin/config_generate

# 2. 固化中文语言与 Argon 主题
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

# 3. 自动更新 PassWall 核心组件
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

# 4. CPU 温度与硬件加速支持
echo 'CONFIG_PACKAGE_kmod-coretemp=y' >> .config
echo 'CONFIG_PACKAGE_kmod-it87=y' >> .config
echo 'CONFIG_PACKAGE_lm-sensors=y' >> .config
# J1900 建议开启 AES 指令集优化 (如果源码支持)
echo 'CONFIG_NODEJS_GCC_X64_LEVEL=2' >> .config

# 5. 首页温度模板应用
TARGET_INDEX="feeds/luci/modules/luci-mod-status/luasrc/view/admin_status/index.htm"
if [ -f "files/usr/lib/lua/luci/view/admin_status/index.htm" ]; then
    cp -f "files/usr/lib/lua/luci/view/admin_status/index.htm" "$TARGET_INDEX"
    echo "✅ 已成功应用自定义温度显示模板"
fi

# 6. 修复编译失败：解决依赖缺失与冲突
# 先安装缺失的包，再删掉冲突的源码，最后刷新全部 feeds
./scripts/feeds install python3-pysocks
./scripts/feeds install python3-unidecode
rm -rf feeds/packages/net/onionshare-cli
./scripts/feeds install -a

echo "🚀 DIY 脚本执行完成"
