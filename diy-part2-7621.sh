#!/bin/bash
echo "=== diy-part2.sh: 打印链路补丁 ==="

# ------------------------------------------------------------------------------
# 1. libjbigkit 修复
# ------------------------------------------------------------------------------
if [ -d "package/feeds/printing/libjbigkit" ]; then
    echo "-> 修复 libjbigkit 编译标志..."
    find package/feeds/printing/libjbigkit/ -type f \
        -exec sed -i 's/-ansi//g; s/-pedantic//g' {} +
fi

# ------------------------------------------------------------------------------
# 2. Ghostscript：安全禁用 host（保留你的兜底）
# ------------------------------------------------------------------------------
GS_MK="package/feeds/printing/ghostscript/Makefile"
if [ -f "$GS_MK" ]; then
    echo "-> 禁用 ghostscript host 构建"

    # 策略 A：禁用 Host/Compile
    if grep -q "define Host/Compile" "$GS_MK"; then
        sed -i 's/define Host\/Compile/define Host\/Compile_disabled/' "$GS_MK"
        echo "   -> 已禁用 Host/Compile"
    
    # 策略 B：禁用 Host/Install
    elif grep -q "define Host/Install" "$GS_MK"; then
        sed -i 's/define Host\/Install/define Host\/Install_disabled/' "$GS_MK"
        echo "   -> 已禁用 Host/Install"

    # 策略 C：兜底（你的原始逻辑）
    else
        echo "   -> 未找到 Host/Compile/Install，执行兜底策略"
        sed -i '/define Host\/Configure/a define Host\/Compile_disabled' "$GS_MK"
        sed -i '/define Host\/Configure/a define Host\/Install_disabled' "$GS_MK"
    fi

    # 禁用 host 构建标志
    sed -i 's/PKG_BUILD_FLAGS:=no-mips16/PKG_BUILD_FLAGS:=no-mips16 no-host/' "$GS_MK"

    # 关闭 cups 检测
    sed -i '/CONFIGURE_ARGS/s/$/ --disable-cups/' "$GS_MK"
    sed -i '/HOST_CONFIGURE_ARGS/s/$/ --disable-cups/' "$GS_MK"
fi

# ------------------------------------------------------------------------------
# 3. foomatic-filters 修复
# ------------------------------------------------------------------------------
FF_MK="package/feeds/printing/foomatic-filters/Makefile"
if [ -f "$FF_MK" ]; then
    echo "-> 修复 foomatic-filters TEXTTOPS..."
    sed -i '/CONFIGURE_ARGS/s/$/ TEXTTOPS=\/usr\/bin\/enscript/' "$FF_MK"
fi

# ------------------------------------------------------------------------------
# 4. gutenprint 修复
# ------------------------------------------------------------------------------
GP_MK="package/feeds/printing/gutenprint/Makefile"
if [ -f "$GP_MK" ]; then
    echo "-> 修复 gutenprint malloc/realloc 检测..."
    sed -i '/CONFIGURE_ARGS/s/$/ ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes/' "$GP_MK"
fi

echo "=== diy-part2.sh 完成 ==="
