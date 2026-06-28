#!/bin/bash
#
# OpenWrt DIY script part 1 (Before Update feeds)
# 仅保留 OpenClash + Argon 主题，PassWall 已彻底移除
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

# 1. 清理旧源残留
sed -i '/argonconfig/d' feeds.conf.default

# 2. 添加所需源（OpenClash + Argon 主题）
add_feed 'src-git openclash https://github.com/vernesong/OpenClash.git'
add_feed 'src-git argon https://github.com/jerrykuku/luci-theme-argon.git'

# 3. 更新并安装 feeds（仅针对已添加的源）
./scripts/feeds update openclash argon
./scripts/feeds install -a

# 4. 修复 /etc/config/luci 文件冲突（OpenWrt 通用问题，与 PassWall 无关）
BASE_FILES_DIR="package/base-files"
if [ -d "$BASE_FILES_DIR" ]; then
    find "$BASE_FILES_DIR" -type f -path "*/etc/config/luci" -exec rm -f {} \;
    sed -i '/\/etc\/config\/luci/d' "$BASE_FILES_DIR/Makefile" 2>/dev/null
    echo "✅ 已从 base-files 中移除 /etc/config/luci"
fi

LUCI_BASE_MK="feeds/luci/luci-base/Makefile"
if [ -f "$LUCI_BASE_MK" ]; then
    if ! grep -q "PKG_REPLACES:=" "$LUCI_BASE_MK"; then
        sed -i '/^PKG_NAME:=luci-base/a PKG_REPLACES:=base-files' "$LUCI_BASE_MK"
        echo "✅ 已为 luci-base 添加 PKG_REPLACES:=base-files"
    fi
fi

echo "✅ diy-part1.sh 执行完毕"
