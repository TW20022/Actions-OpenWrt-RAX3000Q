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
# 2. foomatic-filters 修复（含兜底）
# ------------------------------------------------------------------------------
FF_MK="package/feeds/printing/foomatic-filters/Makefile"

if [ -f "$FF_MK" ]; then
    echo "-> 禁用 foomatic-filters 的 texttops 检测（正确修复）"

    # 删除你之前插入的 TEXTTOPS=/usr/bin/enscript
    sed -i 's/TEXTTOPS=\/usr\/bin\/enscript//g' "$FF_MK"

    # 正确做法：禁用 texttops 检测，让它走内部 fallback
    sed -i '/CONFIGURE_ARGS/s/$/ --disable-texttops/' "$FF_MK"

    # 兜底：如果没有 CONFIGURE_ARGS，则插入一行
    if ! grep -q "CONFIGURE_ARGS" "$FF_MK"; then
        echo 'CONFIGURE_ARGS += --disable-texttops' >> "$FF_MK"
    fi
fi


# ------------------------------------------------------------------------------
# splix 修复补丁（仅修改 splix，不影响其他 printing 包）
# ------------------------------------------------------------------------------
SPLIX_MK="package/feeds/printing/splix/Makefile"

if [ -f "$SPLIX_MK" ]; then
    echo "-> 修复 splix: C++ 标准 / JBIG 库名 / include 路径"

    # 1. 修复 C++ 标准：新版 splix 仍是 C++03 风格，不能强行用 C++14
    sed -i 's/-std=gnu++14/-std=gnu++03/' "$SPLIX_MK"

    # 2. 修复 JBIG 库名：OpenWrt 24.10 的 libjbigkit 导出的是 libjbig.so
    sed -i 's/-ljbig85/-ljbig/' "$SPLIX_MK"

    # 3. 确保 include 路径正确传递（cups/image.h 依赖）
    # 如果已经存在则不会重复添加
    if ! grep -q 'I$(STAGING_DIR)/usr/include' "$SPLIX_MK"; then
        sed -i '/TARGET_CXXFLAGS/s/$/ -I$(STAGING_DIR)\/usr\/include/' "$SPLIX_MK"
    fi

    echo "   -> splix 修复补丁应用完成"
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
