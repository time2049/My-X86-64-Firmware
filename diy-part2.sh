#!/bin/bash

# 1. 修改默认管理 IP
sed -i 's/192.168.1.1/10.1.1.1/g' package/base-files/files/bin/config_generate

# 2. 固化默认语言和 Argon 主题
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

# 3. 自动更新 PassWall 核心组件 (Go 语言)
update_go_package() {
    local pkg_name=$1
    local github_repo=$2
    local makefile_path="feeds/passwall_packages/$pkg_name/Makefile"
    [ -f "$makefile_path" ] || return 0
    local latest_version=$(curl --silent "https://api.github.com/repos/$github_repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/^v//')
    if [ -n "$latest_version" ]; then
        sed -i "s|PKG_VERSION:=.*|PKG_VERSION:=$latest_version|g" "$makefile_path"
        sed -i "s|PKG_HASH:=.*|PKG_HASH:=skip|g" "$makefile_path"
    fi
}
update_go_package "xray-core" "XTLS/Xray-core"
update_go_package "sing-box" "SagerNet/sing-box"
update_go_package "hysteria" "apernet/hysteria"

# 4. 【核心改动】J1900 CPU 温度显示插件集成
# 注入驱动支持
echo 'CONFIG_PACKAGE_kmod-coretemp=y' >> .config
echo 'CONFIG_PACKAGE_kmod-it87=y' >> .config
echo 'CONFIG_PACKAGE_lm-sensors=y' >> .config
echo 'CONFIG_PACKAGE_sensorconf=y' >> .config

# 针对 25 分支 (Master) 的温度显示补丁
# 这个命令会自动寻找状态页面的 CPU 负载行，并在其下方插入温度显示代码
sed -i '/<tr><td width="33%"><%:CPU usage (%)%><\/td><td><%=pcpuinfo%>%><\/td><\/tr>/a \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ <tr><td width="33%"><%:CPU Temperature%><\/td><td><%=luci.sys.exec("sensors | grep Core | cut -c16-22")%>度<\/td><\/tr>' feeds/luci/modules/luci-mod-status/luasrc/view/admin_status/index.htm

# 5. 修复 UPnP 列表显示 Bug (小z特别定制)
sed -i 's/option enable_upnp 0/option enable_upnp 1/g' package/feeds/luci/luci-app-upnp/root/etc/config/upnpd

# 6. 消除警告并刷新配置
echo '# CONFIG_PACKAGE_onionshare-cli is not set' >> .config
make defconfig
