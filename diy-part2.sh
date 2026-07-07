#!/bin/bash
# OpenWrt DIY script part 2 (After Update feeds)

# 1. 精准修改默认管理 IP
sed -i 's/192.168.1.1/10.1.1.1/g' package/base-files/files/bin/config_generate

# 2. 核心修复1：直接修改 x86 架构的默认核心打包列表，强行将中文包合并进系统镜像（治愈漏中文字套）
sed -i 's/DEFAULT_PACKAGES +=/DEFAULT_PACKAGES += luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn luci-i18n-package-manager-zh-cn/g' target/linux/x86/Makefile

# 3. UCI 终极初始化防线（锁死 IP 与主题）并在首次开机时自动安装预埋的 OpenClash 原生 APK
mkdir -p package/base-files/files/etc/uci-defaults
cat << 'EOF' > package/base-files/files/etc/uci-defaults/99-init-settings
#!/bin/sh
uci set network.lan.ipaddr='10.1.1.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network

uci set luci.main.lang=zh_cn
uci set luci.main.mediaurlbase=/luci-static/argon
uci commit luci

# 🌟 核心开机自启：使用通配符匹配 /root/ 下的原名 .apk
# 首次开机无网环境下强制释放并强制本地安装，安装完自行销毁
if [ -f /root/luci-app-openclash*.apk ]; then
    apk add --force-overwrite --clean-protected --allow-untrusted /root/luci-app-openclash*.apk
    rm -f /root/luci-app-openclash*.apk
fi

rm -f /var/run/fw4.lock /var/run/luci-reload.lock
exit 0
EOF
chmod +x package/base-files/files/etc/uci-defaults/99-init-settings

# 4. 剔除导致编译冲突的 onionshare
[ -d "feeds/packages/net/onionshare-cli" ] && rm -rf feeds/packages/net/onionshare-cli

# 5. 🌟 预埋编译期下载：结合传入的 Token，精准抓取官方 Release 里的最新原名 .apk 包放入 /root
echo "📥 正在编译期在线抓取 OpenClash 官方最新原生 .apk 包..."
mkdir -p package/base-files/files/root

AUTH_HEADER=""
if [ -n "$GITHUB_TOKEN" ]; then
    AUTH_HEADER="-H \"Authorization: Bearer $GITHUB_TOKEN\""
fi

eval curl -L --retry 3 $AUTH_HEADER https://api.github.com/repos/vernesong/OpenClash/releases/latest -o /tmp/oc_version

if [ -f "/tmp/oc_version" ]; then
    # 精准提取以 .apk 结尾的完整下载直链
    download_url=$(grep -o '"browser_download_url": "[^"]*' /tmp/oc_version | grep '\.apk' | head -n 1 | sed 's/"browser_download_url": "//')
    if [ -n "$download_url" ]; then
        # 保持官方自带版本号的原文件名（如 luci-app-openclash-0.47.116.apk）下载保存
        file_name=$(basename "$download_url")
        eval curl -L --retry 3 $AUTH_HEADER "$download_url" -o "package/base-files/files/root/$file_name"
        echo "✅ OpenClash 原生包 [$file_name] 成功打包进固件预装区"
    else
        echo "❌ 未能解析到最新的 .apk 下载链接"
    fi
else
    echo "❌ 获取 OpenClash 版本号超时"
fi

# 6. 🌟 纯 nftables 架构依赖全家桶（全面对接新版 [nftables for apk] 需求）
cat << 'EOF' >> .config
# ======== OpenWrt APK 全局语言强依赖构建宏 ========
CONFIG_BUILD_NLS=y
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_LUCI_LANG_zh-cn=y
CONFIG_PACKAGE_luci=y
CONFIG_PACKAGE_luci-base=y
CONFIG_PACKAGE_luci-compat=y
CONFIG_PACKAGE_luci-i18n-base-zh-cn=y
CONFIG_PACKAGE_luci-i18n-firewall-zh-cn=y
CONFIG_PACKAGE_luci-app-package-manager=y
CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn=y

# ======== 主题本地配置 ========
CONFIG_PACKAGE_luci-theme-argon=y
CONFIG_PACKAGE_luci-app-argon-config=y
CONFIG_PACKAGE_luci-i18n-argon-config-zh-cn=y

# ======== 纯 nftables 架构依赖全家桶 ========
CONFIG_PACKAGE_bash=y
CONFIG_PACKAGE_dnsmasq-full=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_ca-bundle=y
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_unzip=y
CONFIG_PACKAGE_ruby=y
CONFIG_PACKAGE_ruby-yaml=y
CONFIG_PACKAGE_ruby-psych=y
CONFIG_PACKAGE_ruby-dbm=y
CONFIG_PACKAGE_ruby-pstore=y

# 内核路由及 nftables TProxy 转发核心模块
CONFIG_PACKAGE_kmod-tun=y
CONFIG_PACKAGE_kmod-inet-diag=y
CONFIG_PACKAGE_kmod-nft-tproxy=y

# 确保旧版 iptables 完全关闭，防止规则冲突
CONFIG_PACKAGE_iptables=n
CONFIG_PACKAGE_iptables-mod-tproxy=n

# ======== J1900 物理硬件驱动 ========
CONFIG_PACKAGE_kmod-coretemp=y
CONFIG_PACKAGE_kmod-it87=y
CONFIG_PACKAGE_lm-sensors=y
CONFIG_PACKAGE_kmod-ppp=y
CONFIG_PACKAGE_kmod-pppox=y
CONFIG_PACKAGE_kmod-pppoe=y
EOF

echo "✅ diy-part2.sh 执行完毕。"
