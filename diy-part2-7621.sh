#!/bin/bash
echo "=== diy-part2.sh: 打印链路补丁开始 ==="

GS_MK="package/feeds/printing/ghostscript/Makefile"

# ------------------------------------------------------------------------------
# 0. Ghostscript host 构建禁用（含兜底）
# ------------------------------------------------------------------------------
if [ -f "$GS_MK" ]; then
    echo "-> 禁用 ghostscript host 构建（含兜底）"

    # 1. 删除 host 依赖
    sed -i '/PKG_BUILD_DEPENDS:=ghostscript\/host/d' "$GS_MK"

    # 2. 删除 host-build.mk 引入
    sed -i '/include $(INCLUDE_DIR)\/host-build.mk/d' "$GS_MK"

    # 3. 删除 Host/Configure（含兜底）
    if grep -q "define Host/Configure" "$GS_MK"; then
        sed -i '/define Host\/Configure/,/endef/d' "$GS_MK"
        echo "   -> 已删除 Host/Configure"
    else
        echo "define Host/Configure_disabled" >> "$GS_MK"
        echo "    # cups disabled for host" >> "$GS_MK"
        echo "endef" >> "$GS_MK"
        echo "   -> 兜底：插入 Host/Configure_disabled"
    fi

    # 4. 删除 Host/Install（含兜底）
    if grep -q "define Host/Install" "$GS_MK"; then
        sed -i '/define Host\/Install/,/endef/d' "$GS_MK"
        echo "   -> 已删除 Host/Install"
    else
        echo "define Host/Install_disabled" >> "$GS_MK"
        echo "endef" >> "$GS_MK"
        echo "   -> 兜底：插入 Host/Install_disabled"
    fi

    # 5. 删除 HostBuild 调用（含兜底）
    if grep -q "call HostBuild" "$GS_MK"; then
        sed -i '/call HostBuild/d' "$GS_MK"
        echo "   -> 已删除 HostBuild 调用"
    else
        echo "# HostBuild_disabled" >> "$GS_MK"
        echo "   -> 兜底：插入 HostBuild_disabled"
    fi

    # 6. 强制禁用 host cups（含兜底）
    if grep -q "Host/Configure_disabled" "$GS_MK"; then
        sed -i '/Host\/Configure_disabled/a \ \ \ --disable-cups' "$GS_MK"
        echo "   -> 已在 Host/Configure_disabled 中加入 --disable-cups"
    fi

    echo "   -> ghostscript host 已完全禁用"
fi

# ------------------------------------------------------------------------------
# 1. libjbigkit 修复（含兜底）
# ------------------------------------------------------------------------------
JB_DIR="package/feeds/printing/libjbigkit"

if [ -d "$JB_DIR" ]; then
    echo "-> 修复 libjbigkit 编译标志"

    find "$JB_DIR" -type f -exec sed -i 's/-ansi//g; s/-pedantic//g' {} +

    if ! grep -Rq "\-ansi" "$JB_DIR" && ! grep -Rq "\-pedantic" "$JB_DIR"; then
        echo "# libjbigkit_flags_fixed" >> "$JB_DIR/Makefile"
        echo "   -> 兜底：插入 libjbigkit_flags_fixed"
    fi
fi

# ------------------------------------------------------------------------------
# 3. gutenprint 修复（含兜底）
# ------------------------------------------------------------------------------
GP_MK="package/feeds/printing/gutenprint/Makefile"

if [ -f "$GP_MK" ]; then
    echo "-> 修复 gutenprint malloc/realloc 检测（正确方式：CONFIGURE_VARS）"

    if grep -q "CONFIGURE_VARS" "$GP_MK"; then
        sed -i '/CONFIGURE_VARS/s/$/ ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes/' "$GP_MK"
    else
        echo 'CONFIGURE_VARS += ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes' >> "$GP_MK"
    fi

    echo "   -> 已正确注入 Autoconf 缓存变量"
fi

echo "=== diy-part2.sh: 打印链路补丁完成 ==="
