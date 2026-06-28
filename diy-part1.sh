#!/bin/bash
#
# OpenWrt DIY script part 1 (Before Update feeds)
#

# 清理旧源可能存在的脏数据
sed -i '/argonconfig/d' feeds.conf.default
sed -i '/openclash/d' feeds.conf.default
sed -i '/argon/d' feeds.conf.default

# 1. 建立自定义本地包存放目录
mkdir -p package/custom

# 2. 直接将 OpenClash 作为独立包克隆，而不是作为 feed 源
# 这是目前最稳妥、不会破坏 main 分支 Makefile 的做法
if [ ! -d "package/custom/OpenClash" ]; then
    git clone --depth 1 -b master https://github.com/vernesong/OpenClash.git package/custom/OpenClash
    echo "✅ OpenClash 克隆成功"
fi

# 3. 同样的，把 Argon 主题也直接作为本地包克隆
if [ ! -d "package/custom/luci-theme-argon" ]; then
    git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/custom/luci-theme-argon
    echo "✅ Argon 主题克隆成功"
fi

echo "🚀 diy-part1.sh 预处理完毕"
