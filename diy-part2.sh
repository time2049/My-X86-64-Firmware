#!/bin/bash
#
# Copyright (c) 2019-2026 P3TERX <https://p3terx.com>
#
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
# 注意：此脚本在工作流的步骤 7 执行（在 feeds install 之后，make defconfig 之前）
#

# ==================== 【特制】Golang 编译防炸内核环境修复 ====================
echo "🧹 正在清理可能冲突的 Go 缓存与旧依赖..."
rm -rf feeder/packages/lang/golang
rm -rf dl/go-mod-cache

# 强制开启 Go 模块支持并配置全局代理，防止 sing-box/Xray 编译时拉取底层依赖失败
export GO111MODULE=on
export GOPROXY=https://proxy.golang.org,direct
export GOMODCACHE=$GITHUB_WORKSPACE/openwrt/dl/go-mod-cache
# ============================================================================

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
# 注意：强制升级新版核心后，上面配置的 GOPROXY 会确保新依赖下载成功
update_go_package "xray-core" "XTLS/Xray-core"
update_go_package "sing-box" "SagerNet/sing-box"
update_go_package "hysteria" "apernet/hysteria"

# 4. 针对 J1900 软路由编译环境的 ccache 与硬件支持注入
# 这里的配置会在后面的 make defconfig 中被自动识别并扩展到 .config
if [ -f ".config" ]; then
    echo "⚙️ 检测到已有初始 .config，注入硬件优化参数..."
    sed -i 's/CONFIG_CCACHE=n/CONFIG_CCACHE=y/g' .config 2>/dev/null || true
    grep -q '^CONFIG_CCACHE=y' .config || echo 'CONFIG_CCACHE=y' >> .config
    echo 'CONFIG_PACKAGE_kmod-coretemp=y' >> .config
    echo 'CONFIG_PACKAGE_kmod-it87=y' >> .config
    echo 'CONFIG_PACKAGE_lm-sensors=y' >> .config
    echo 'CONFIG_NODEJS_GCC_X64_LEVEL=2' >> .config
else
    # 如果此时没有 .config，我们先提前写入，等下一步的 make defconfig 来融合它
    echo "CONFIG_CCACHE=y" > .config
    echo 'CONFIG_PACKAGE_kmod-coretemp=y' >> .config
    echo 'CONFIG_PACKAGE_kmod-it87=y' >> .config
    echo 'CONFIG_PACKAGE_lm-sensors=y' >> .config
    echo 'CONFIG_NODEJS_GCC_X64_LEVEL=2' >> .config
fi

# 5. 首页温度模板应用
TARGET_INDEX="feeds/luci/modules/luci-mod-status/luasrc/view/admin_status/index.htm"
if [ -f "files/usr/lib/lua/luci/view/admin_status/index.htm" ]; then
    cp -f "files/usr/lib/lua/luci/view/admin_status/index.htm" "$TARGET_INDEX"
    echo "✅ 已应用自定义温度显示模板"
fi

# 6. 添加其他必要插件（例如 Argon 配置插件）
# 放到 package/lean 目录下，确保一定能被 OpenWrt 的编译机制扫描到
mkdir -p package/lean
git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/lean/luci-app-argon-config
echo "✅ 已添加 luci-app-argon-config"

echo "🚀 diy-part2.sh 执行完毕"
