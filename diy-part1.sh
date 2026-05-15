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

# 0. 清理可能导致报错的旧源（如果有）
sed -i '/argonconfig/d' feeds.conf.default

# 1. 添加 PassWall 相关源
add_feed 'src-git passwall_packages https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git'
add_feed 'src-git passwall_luci https://github.com/Openwrt-Passwall/openwrt-passwall.git'

# 2. 添加 OpenClash 源
add_feed 'src-git openclash https://github.com/vernesong/OpenClash.git'

# 3. 添加 Argon 主题
add_feed 'src-git argon https://github.com/jerrykuku/luci-theme-argon.git'

# ========== 以下是新增的编译错误修复 ==========

# 4. 更新 feeds（必须，否则后续修改文件可能不存在）
echo "正在更新 feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# 5. 清理可能导致冲突的包源码（passwall 相关）
rm -rf package/feeds/passwall_packages/shadowsocksr-libev
rm -rf package/feeds/passwall_packages/v2ray-geodata

# 6. 解决 luci-base 与 base-files 的 /etc/config/luci 文件冲突
# 方法 A：从 base-files 中彻底删除该文件
BASE_FILES_DIR="package/base-files"
if [ -d "$BASE_FILES_DIR" ]; then
    # 删除物理文件
    find "$BASE_FILES_DIR" -type f -path "*/etc/config/luci" -exec rm -f {} \;
    # 从 Makefile 中删除安装该文件的规则
    sed -i '/\/etc\/config\/luci/d' "$BASE_FILES_DIR/Makefile"
    echo "✅ 已从 base-files 移除 /etc/config/luci"
else
    echo "⚠️ 未找到 $BASE_FILES_DIR，跳过 base-files 清理"
fi

# 方法 B：为 luci-base 添加 PKG_REPLACES（双重保险）
LUCI_BASE_MK="feeds/luci/luci-base/Makefile"
if [ -f "$LUCI_BASE_MK" ]; then
    if ! grep -q "PKG_REPLACES:=" "$LUCI_BASE_MK"; then
        sed -i '/^PKG_NAME:=luci-base/a PKG_REPLACES:=base-files' "$LUCI_BASE_MK"
        echo "✅ 已为 luci-base 添加 PKG_REPLACES:=base-files"
    else
        echo "⚠️ PKG_REPLACES 已存在，跳过"
    fi
else
    echo "⚠️ 未找到 $LUCI_BASE_MK，请检查 feeds 是否成功安装"
fi

# 7. 禁用 onionshare-cli（它的依赖 python3-pysocks/python3-unidecode 在官方 feeds 中不存在）
# 如果 .config 文件存在，则取消选中该包
if [ -f .config ]; then
    if grep -q "CONFIG_PACKAGE_onionshare-cli=y" .config; then
        ./scripts/config --unset CONFIG_PACKAGE_onionshare-cli
        ./scripts/config --unset CONFIG_PACKAGE_luci-app-onionshare-cli 2>/dev/null || true
        echo "✅ 已禁用 onionshare-cli"
    fi
else
    echo "⚠️ .config 不存在，将在 defconfig 后自动禁用（建议运行 make defconfig 或 make menuconfig）"
    # 创建一个临时 .config 避免后续报错（可选）
    # make defconfig
fi

echo "✅ diy-part1.sh 所有修复已应用"
