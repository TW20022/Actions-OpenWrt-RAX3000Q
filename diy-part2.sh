#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# ==========================================
# 1. 修复 dnsmasq-full 循环依赖错误
# ==========================================
# 清理所有显式勾选的 dnsmasq_full_ 子项，避免与第三方插件反向 select 锁死
sed -i '/CONFIG_PACKAGE_dnsmasq_full_/d' .config
# 仅保留纯净的 dnsmasq-full 总开关，让系统自动推导底层依赖树
echo "CONFIG_PACKAGE_dnsmasq-full=y" >> .config
