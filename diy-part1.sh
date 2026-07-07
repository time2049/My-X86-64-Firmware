#!/bin/bash
#
# OpenWrt DIY script part 1 (Before Update feeds)
#

# 清理旧源可能存在的脏数据（防止重名包冲突）
sed -i '/argonconfig/d' feeds.conf.default
sed -i '/openclash/d' feeds.conf.default
sed -i '/argon/d' feeds.conf.default

# 1. 建立自定义本地包存放目录
mkdir -p package/custom

# 2. 🌟 移除 OpenClash 源码克隆逻辑
# 核心原因：源码编译在 APK 体系下会被忽略。我们已将其转移至 diy-part2.sh
# 通过动态下载官方原生 .apk 离线包并放入固件预装区，开机自动本地安装。

# 3. 把可以正常完美编译的 Argon 主题及配置后台拉取下来
if [ ! -d "package/custom/luci-theme-argon" ]; then
    git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/custom/luci-theme-argon
    echo "✅ Argon 主题克隆成功"
fi

if [ ! -d "package/custom/luci-app-argon-config" ]; then
    git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/custom/luci-app-argon-config
    echo "✅ Argon 配置后台克隆成功"
fi

echo "🚀 diy-part1.sh 预处理完毕"
