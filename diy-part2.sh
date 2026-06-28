#!/bin/bash
#
# OpenWrt DIY script part 2 (After Update feeds)
# 仅保留通用优化 + OpenClash 支持，PassWall 相关已全部移除
#

# ==================== Golang 编译环境优化（对 OpenClash 也有用） ====================
echo "🧹 清理可能冲突的 Go 缓存..."
rm -rf feeds/packages/lang/golang 2>/dev/null
rm -rf dl/go-mod-cache 2>/dev/null

export GO111MODULE=on
export GOPROXY=https://proxy.golang.org,direct
export GOMODCACHE=$GITHUB_WORKSPACE/openwrt/dl/go-mod-cache
# ===================================================================================

# 1. 修改默认管理 IP
sed -i 's/192.168.1.1/10.1.1.1/g' package/base-files/files/bin/config_generate

# 2. 固化中文语言与 Argon 主题（uci-defaults 脚本，无文件冲突）
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-custom-luci
#!/bin/sh
uci set luci.main.lang='zh-cn'
uci set luci.main.mediaurlbase='/luci-static/argon'
uci commit luci
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-luci
echo "✅ 已添加 uci-defaults 脚本（语言 + Argon 主题）"

# 3. J1900 硬件优化（ccache + 传感器支持）
if [ -f ".config" ]; then
    sed -i 's/CONFIG_CCACHE=n/CONFIG_CCACHE=y/g' .config 2>/dev/null || true
    grep -q '^CONFIG_CCACHE=y' .config || echo 'CONFIG_CCACHE=y' >> .config
    grep -q 'CONFIG_PACKAGE_kmod-coretemp' .config || echo 'CONFIG_PACKAGE_kmod-coretemp=y' >> .config
    grep -q 'CONFIG_PACKAGE_kmod-it87' .config || echo 'CONFIG_PACKAGE_kmod-it87=y' >> .config
    grep -q 'CONFIG_PACKAGE_lm-sensors' .config || echo 'CONFIG_PACKAGE_lm-sensors=y' >> .config
    grep -q 'CONFIG_NODEJS_GCC_X64_LEVEL' .config || echo 'CONFIG_NODEJS_GCC_X64_LEVEL=2' >> .config
else
    cat > .config << EOF
CONFIG_CCACHE=y
CONFIG_PACKAGE_kmod-coretemp=y
CONFIG_PACKAGE_kmod-it87=y
CONFIG_PACKAGE_lm-sensors=y
CONFIG_NODEJS_GCC_X64_LEVEL=2
EOF
fi
echo "✅ 已注入 J1900 硬件优化参数"

# 4. 添加 Argon 配置插件（从 Git 直接拉取，确保存在）
mkdir -p package/lean
if [ ! -d "package/lean/luci-app-argon-config" ]; then
    git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/lean/luci-app-argon-config
    echo "✅ 已添加 luci-app-argon-config"
else
    echo "✅ luci-app-argon-config 已存在"
fi

# 5. （可选）首页温度显示模板 - 如果你有自定义文件则应用
TARGET_INDEX="feeds/luci/modules/luci-mod-status/luasrc/view/admin_status/index.htm"
if [ -f "files/usr/lib/lua/luci/view/admin_status/index.htm" ]; then
    cp -f "files/usr/lib/lua/luci/view/admin_status/index.htm" "$TARGET_INDEX" 2>/dev/null
    echo "✅ 已应用自定义温度显示模板"
fi

echo "🚀 diy-part2.sh 执行完毕（仅通用优化 + OpenClash）"
