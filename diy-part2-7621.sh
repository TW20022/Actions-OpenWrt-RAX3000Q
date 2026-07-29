#!/bin/bash
# ==============================================================================
# diy-part2.sh: OpenWrt 打印机组件栈专属补丁（最终稳定版）
# ==============================================================================

echo "=== 开始执行 diy-part2.sh 打印链路补丁 ==="

# ------------------------------------------------------------------------------
# 1. libjbigkit：移除 GCC 13 不兼容的 -ansi / -pedantic
# ------------------------------------------------------------------------------
if [ -d "package/feeds/printing/libjbigkit" ]; then
    echo "-> 修复 libjbigkit 编译标志..."
    find package/feeds/printing/libjbigkit/ -type f \
        -exec sed -i 's/-ansi//g; s/-pedantic//g' {} +
fi

# ------------------------------------------------------------------------------
# 2. Ghostscript：彻底禁用 host 构建（最终解决 ghostscript host 失败）
# ------------------------------------------------------------------------------
GS_MK="package/feeds/printing/ghostscript/Makefile"
if [ -f "$GS_MK" ]; then
    echo "-> 禁用 ghostscript host 构建（不会影响 printing 链路）"

    # 禁用 Host/Compile
    sed -i 's/define Host\/Compile/define Host\/Compile_disabled/' "$GS_MK"

    # 禁用 Host/Install
    sed -i 's/define Host\/Install/define Host\/Install_disabled/' "$GS_MK"

    # 禁用 host 构建标志
    sed -i 's/PKG_BUILD_FLAGS:=no-mips16/PKG_BUILD_FLAGS:=no-mips16 no-host/' "$GS_MK"

    # 移除 host cups 依赖
    sed -i 's/DEPENDS:=/DEPENDS:= +TARGET_ghostscript/' "$GS_MK"

    # 关闭 cups 检测（多重兜底）
    sed -i '/CONFIGURE_ARGS/s/$/ --disable-cups/' "$GS_MK"
    sed -i '/HOST_CONFIGURE_ARGS/s/$/ --disable-cups/' "$GS_MK"

    echo "   -> ghostscript host 已完全禁用，只构建 target ghostscript"
fi

# ------------------------------------------------------------------------------
# 3. foomatic-filters：注入 TEXTTOPS 路径
# ------------------------------------------------------------------------------
FF_MK="package/feeds/printing/foomatic-filters/Makefile"
if [ -f "$FF_MK" ]; then
    echo "-> 修复 foomatic-filters TEXTTOPS..."
    sed -i '/CONFIGURE_ARGS/s/$/ TEXTTOPS=\/usr\/bin\/enscript/' "$FF_MK"
fi

# ------------------------------------------------------------------------------
# 4. gutenprint：修复 malloc/realloc 交叉编译检测
# ------------------------------------------------------------------------------
GP_MK="package/feeds/printing/gutenprint/Makefile"
if [ -f "$GP_MK" ]; then
    echo "-> 修复 gutenprint malloc/realloc 检测..."
    sed -i '/CONFIGURE_ARGS/s/$/ ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes/' "$GP_MK"
fi

# ------------------------------------------------------------------------------
# 5. 挂载自定义 files（如果存在）
# ------------------------------------------------------------------------------
if [ -d "$GITHUB_WORKSPACE/files" ]; then
    echo "-> 挂载自定义 files 目录..."
    cp -rf "$GITHUB_WORKSPACE/files/"* files/ 2>/dev/null || true
fi

echo "=== diy-part2.sh 执行完毕：打印链路补丁已全部应用 ==="
