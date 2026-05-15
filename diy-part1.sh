#!/bin/bash
#
# Copyright (c) 2019-2026 P3TERX <https://p3terx.com>
#
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
# 注意：此脚本会在工作流的步骤 4 执行（在 feeds update 之前）
# 但脚本内部会主动执行 feeds update/install 以确保后续修改有效
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

# 0. 清理可能导致报错的旧源
sed -i '/argonconfig/d' feeds.conf.default

# 1. 添加 PassWall 相关源
add_feed 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git'
add_feed 'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git'

# 2. 添加 OpenClash 源
add_feed 'src-git openclash https://github.com/vernesong/OpenClash.git'

# 3. 添加 Argon 主题
add_feed 'src-git argon https://github.com/jerrykuku/luci-theme-argon.git'

# ==================== 关键修复区 ====================

# 4. 更新 feeds（必须，因为后续修改需要 feeds 中的文件）
echo "正在更新 feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# 5. 清理可能导致冲突的包源码（PassWall 相关）
rm -rf package/feeds/passwall_packages/shadowsocksr-libev
rm -rf package/feeds/passwall_packages/v2ray-geodata

# 6. 彻底解决 /etc/config/luci 文件冲突
# 方案 A：从 base-files 中删除该文件及其安装规则
BASE_FILES_DIR="package/base-files"
if [ -d "$BASE_FILES_DIR" ]; then
    find "$BASE_FILES_DIR" -type f -path "*/etc/config/luci" -exec rm -f {} \;
    sed -i '/\/etc\/config\/luci/d' "$BASE_FILES_DIR/Makefile"
    echo "✅ 已从 base-files 中移除 /etc/config/luci"
fi

# 方案 B：为 luci-base 添加 PKG_REPLACES（双重保险）
LUCI_BASE_MK="feeds/luci/luci-base/Makefile"
if [ -f "$LUCI_BASE_MK" ]; then
    if ! grep -q "PKG_REPLACES:=" "$LUCI_BASE_MK"; then
        sed -i '/^PKG_NAME:=luci-base/a PKG_REPLACES:=base-files' "$LUCI_BASE_MK"
        echo "✅ 已为 luci-base 添加 PKG_REPLACES:=base-files"
    fi
fi

# 7. 禁用 onionshare-cli（避免依赖缺失导致的潜在错误）
# 如果 .config 已存在，则取消选中；否则在后续 defconfig 时会被自动排除
if [ -f .config ] && grep -q "CONFIG_PACKAGE_onionshare-cli=y" .config; then
    ./scripts/config --unset CONFIG_PACKAGE_onionshare-cli
    ./scripts/config --unset CONFIG_PACKAGE_luci-app-onionshare-cli 2>/dev/null || true
    echo "✅ 已禁用 onionshare-cli"
fi

# 额外：强制删除 onionshare-cli 的源码（如果 feeds 已安装）
rm -rf feeds/packages/net/onionshare-cli 2>/dev/null || true

echo "✅ diy-part1.sh 执行完毕（所有冲突已处理）"
