#!/bin/bash
# 文件名: diy2.sh

set -e

echo "开始执行 RAX3000-QY 专属标签克隆与 Netlink 修复脚本..."
echo "========================================="

# ==================== 0. 创建必要目录与静态文件目录 ====================
mkdir -p files/etc/config
mkdir -p files/etc/hosts.d
mkdir -p files/etc/uci-defaults

# ==================== 1. System 配置（主机名：定制为 RAX3000-QY） ====================
cat > files/etc/config/system << 'EOF'
config system
    option hostname 'RAX3000-QY'
    option zonename 'Asia/Shanghai'
    option timezone 'CST-8'

config timeserver 'ntp'
    option enabled '1'
    list server 'ntp1.aliyun.com'
    list server 'time1.cloud.tencent.com'
EOF
echo "✅ 主机名: RAX3000-QY"

# ==================== 2. 默认 IP 修改（对应标签：192.168.10.1） ====================
if [ -f package/base-files/files/bin/config_generate ]; then
    sed -i 's/192.168.1.1/192.168.10.1/g' package/base-files/files/bin/config_generate
    echo "✅ 管理 IP 修改为: 192.168.10.1"
fi

# ==================== 3. 局域网网址劫持（对应标签：http://cmcc.wifi） ====================
cat > files/etc/hosts.d/cmcc-wifi << 'EOF'
192.168.10.1 cmcc.wifi
EOF
echo "✅ 网址劫持配置成功: http://cmcc.wifi"

# ==================== 4. 修复 hostapd ap_isolate ====================
echo ""
echo "=== 修复 hostapd ap_isolate 问题 ==="

HOSTAPD_SH="package/network/services/hostapd/files/hostapd.sh"
if [ -f "$HOSTAPD_SH" ]; then
    # 将 ap_isolate=$isolate 改为 ap_isolate=0（保持语法完整）
    sed -i 's/append bss_conf "ap_isolate=\$isolate"/append bss_conf "ap_isolate=0"/' "$HOSTAPD_SH"
    echo "✓ hostapd ap_isolate 修复完成"
else
    echo "⚠ 未找到 hostapd.sh"
fi

# ==================== 5. 无线配置修改（锁定标签参数及无线高级调优） ====================
echo ""
echo "=== 修改无线配置 ==="

# 定义 MAC80211_SH 变量（关键！必须在修改之前定义）
MAC80211_SH="package/kernel/mac80211/files/lib/wifi/mac80211.sh"

# 检查文件是否存在，如果不存在则尝试其他路径
if [ ! -f "$MAC80211_SH" ]; then
    MAC80211_SH="package/network/services/hostapd/files/mac80211.sh"
fi

if [ ! -f "$MAC80211_SH" ]; then
    echo "⚠ 未找到 mac80211.sh，跳过无线配置"
else
    echo "找到文件: $MAC80211_SH"
    
    # 移除原源码可能默认生成的 SSID 逻辑
    sed -i '/set wireless.default_radio${devidx}.ssid=/d' "$MAC80211_SH"
    
    # 在无线配置文件 commit 前，统一硬编码注入标签数据、MAC地址克隆及高级链路参数
    sed -i '/uci -q commit wireless/i\
		# 1. 统一设置默认无线名称（对应标签：CMCC-6DD7）\
		uci set wireless.default_radio${devidx}.ssid="CMCC-6DD7"\
		# 2. 统一设置无线密码（对应标签：945DA4DF，加密选psk2）\
		uci set wireless.default_radio${devidx}.encryption="psk2"\
		uci set wireless.default_radio${devidx}.key="945DA4DF"\
		# 3. 克隆并锁定硬件物理 MAC 地址（对应标签：04:4F:7A:67:6D:D7）\
		uci set wireless.radio${devidx}.macaddr="04:4F:7A:67:6D:D7"\
		# 4. 2.4G 专属调优：信道自动 | 频宽 HE40\
		if [ "$mode_band" = "2g" ]; then\
			uci set wireless.radio${devidx}.channel="auto"\
			uci set wireless.radio${devidx}.htmode="HE40"\
		fi\
		# 5. 5G 专属调优：信道固定 149（规避 DFS 雷达搜台慢）| 满血频宽 HE160\
		if [ "$mode_band" = "5g" ]; then\
			uci set wireless.radio${devidx}.channel="149"\
			uci set wireless.radio${devidx}.htmode="HE160"\
		fi\
		# 6. 通用调优：开启 MU-MIMO 束波 | 注入无损 RTS/Frag 减小隐藏节点多设备冲突\
		uci set wireless.radio${devidx}.mu_beamformer=1\
		uci set wireless.radio${devidx}.rts=2347\
		uci set wireless.radio${devidx}.frag=1500\
' "$MAC80211_SH"

    echo "✅ 无线配置修改完成"

    # 验证
    echo ""
    echo "验证配置修改结果..."
    grep -q 'uci set wireless.default_radio${devidx}.ssid="CMCC-6DD7"' "$MAC80211_SH" || { echo "✗ SSID 标签同步失败"; exit 1; }
    grep -q 'uci set wireless.default_radio${devidx}.key="945DA4DF"' "$MAC80211_SH" || { echo "✗ 无线密码标签同步失败"; exit 1; }
    grep -q 'uci set wireless.radio${devidx}.macaddr="04:4F:7A:67:6D:D7"' "$MAC80211_SH" || { echo "✗ 物理 MAC 地址锁定失败"; exit 1; }
    grep -q 'uci set wireless.radio${devidx}.htmode="HE160"' "$MAC80211_SH" || { echo "✗ HE160 调优参数注入失败"; exit 1; }
    grep -q 'uci set wireless.radio${devidx}.rts=2347' "$MAC80211_SH" || { echo "✗ RTS 冲突优化参数注入失败"; exit 1; }
    echo "✓ 所有无线配置验证通过"
fi

# ==================== 6. 创建开机首次运行脚本（双重保险及管理账号 admin/密码 845?A4DF 锁定） ====================
# ==================== 6. 创建开机首次运行脚本（解决原厂 MAC 提取与隔离修复） ====================
cat > files/etc/uci-defaults/99-fix-ap-isolate << 'EOF'
#!/bin/sh

# 1. 动态提取原厂“0:ART”分区中的真实 MAC 地址，修复系统读取不到的问题
# 查找系统当前挂载的 ART 分区号（防止刷机后序号变动）
ART_MTD=$(grep -E '"0:ART"|"art"|"ART"' /proc/mtd | cut -d: -f1)

if [ -n "$ART_MTD" ]; then
    # 高通原厂物理 MAC 通常存放在 ART 分区的最前 6 个字节
    # 使用 hexdump 提取并格式化为标准 MAC 格式 (aa:bb:cc:dd:ee:ff)
    REAL_MAC=$(hexdump -v -n 6 -e '1/1 "%02X:"' /dev/${ART_MTD} | sed 's/:$//')
    
    # 健壮性检查：如果提取出来的不是空值且符合MAC格式，则强制写入系统
    if [ -n "$REAL_MAC" ] && [ "$(echo "$REAL_MAC" | wc -c)" -eq 18 ]; then
        uci set network.lan.macaddr="$REAL_MAC"
        uci set wireless.radio0.macaddr="$REAL_MAC"
        
        # WAN 口 MAC 自动在原厂基础上 +1
        WAN_MAC=$(macaddr_add "$REAL_MAC" 1 2>/dev/null || echo "$REAL_MAC")
        uci set network.wan.macaddr="$WAN_MAC"
        uci set wireless.radio1.macaddr="$WAN_MAC"
        
        uci commit network
        uci commit wireless
    fi
fi

# 2. 强制将默认 root 用户名重命名为 admin（对应标签）
if grep -q "^root:" /etc/passwd; then
    sed -i 's/^root:/admin:/' /etc/passwd
    sed -i 's/^root:/admin:/' /etc/shadow
fi

# 3. 强行锁定 admin 的管理密码为 845?A4DF
# 使用 @ 作为 sed 分隔符，完美避开密文里斜杠 (/) 引起的转义崩溃
NEW_PRESET_PASS=$(openssl passwd -6 "845?A4DF")
sed -i "s@^admin:[^:]*:@admin:${NEW_PRESET_PASS}:@" files/etc/shadow 2>/dev/null || sed -i "s@^admin:[^:]*:@admin:${NEW_PRESET_PASS}:@" /etc/shadow

# 4. 运行时动态巡检：强制关闭高通私有无线驱动可能带来的局域网隔离
sleep 4
if ls /var/run/hostapd-phy*.conf >/dev/null 2>&1; then
    for conf in /var/run/hostapd-phy*.conf; do
        if grep -q "ap_isolate=1" "$conf"; then
            sed -i 's/ap_isolate=1/ap_isolate=0/g' "$conf"
            /etc/init.d/hostapd restart >/dev/null 2>&1
        fi
    done
fi

exit 0
EOF
chmod +x files/etc/uci-defaults/99-fix-ap-isolate
echo "✅ 创建开机备用修复与账号管理脚本"

# ==================== 7. 尝试修复 Netlink 属性警告问题（编译菜单级干预） ====================
echo ""
echo "=== 尝试干预 .config 修复 Netlink 属性长度警告 ==="
if [ -f .config ]; then
    # 如果勾选了容易因为缺少高级 Wi-Fi 6 特性宏定义而与内核起冲突的精简版无线组件
    if grep -q "CONFIG_PACKAGE_wpad-basic-wolfssl=y" .config; then
        sed -i 's/CONFIG_PACKAGE_wpad-basic-wolfssl=y/# CONFIG_PACKAGE_wpad-basic-wolfssl is not set/' .config
        # 强制替换为具备完整无线协议特性的全功能版组件 wpad-openssl
        echo "CONFIG_PACKAGE_wpad-openssl=y" >> .config
        echo "✓ 检测到 wpad-basic-wolfssl，已强制替换升级为 wpad-openssl 以尝试对齐 Netlink"
    elif grep -q "CONFIG_PACKAGE_wpad-wolfssl=y" .config; then
        sed -i 's/CONFIG_PACKAGE_wpad-wolfssl=y/# CONFIG_PACKAGE_wpad-wolfssl is not set/' .config
        echo "CONFIG_PACKAGE_wpad-openssl=y" >> .config
        echo "✓ 检测到 wpad-wolfssl，已强制切换为 wpad-openssl 尝试避开内核不一致属性"
    else
        echo "CONFIG_PACKAGE_wpad-openssl=y" >> .config
        echo "✓ 默认注入 wpad-openssl 全功能无线协议栈"
    fi
else
    echo "⚠ 当前阶段未检测到 .config 文件（可能在 diy1 阶段或核心菜单前），建议在 Actions 流程中关注组件选择"
fi

echo ""
echo "========================================="
echo "配置摘要（已完全与外壳标签数据对齐）:"
echo "  - 管理账号: admin | 管理密码: 845?A4DF"
echo "  - 管理网络: 192.168.10.1 | 管理网址: http://cmcc.wifi"
echo "  - 无线SSID: CMCC-6DD7 | 无线密码: 945DA4DF"
echo "  - 物理 MAC 克隆锁定: 04:4F:7A:67:6D:D7"
echo "  - ap_isolate: 编译期+开机巡检双向关闭 (强制互通=0)"
echo "  - Netlink 警告干预: 已强制选入全功能 wpad-openssl 协议栈尝试对齐内核结构体"
echo "========================================="
