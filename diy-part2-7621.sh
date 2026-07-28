#!/bin/bash
# ==============================================================================
# diy-part2.sh: OpenWrt 打印机组件栈专属定制与 GCC 13+ 兼容性修复脚本
# ==============================================================================

echo "=== 开始执行 diy-part2.sh 预处理与补丁植入 ==="

# ------------------------------------------------------------------------------
# 1. libjbigkit 目标路径动态软链接适配与硬编码修复
# ------------------------------------------------------------------------------
mkdir -p staging_dir build_dir
REAL_TARGET_STAGING=$(ls -d staging_dir/target-* 2>/dev/null | head -n 1)
REAL_TARGET_BUILD=$(ls -d build_dir/target-* 2>/dev/null | head -n 1)

if [ -n "$REAL_TARGET_STAGING" ]; then
    mkdir -p "$REAL_TARGET_STAGING/usr/lib" "$REAL_TARGET_STAGING/usr/include"
    TARGET_STAGING_NAME=$(basename "$REAL_TARGET_STAGING")
    [ ! -e "staging_dir/$TARGET_STAGING_NAME" ] && ln -sf "$TARGET_STAGING_NAME" staging_dir/target-mipsel_24kc_musl 2>/dev/null || true
fi

if [ -n "$REAL_TARGET_BUILD" ]; then
    TARGET_BUILD_NAME=$(basename "$REAL_TARGET_BUILD")
    [ ! -e "build_dir/$TARGET_BUILD_NAME" ] && ln -sf "$TARGET_BUILD_NAME" build_dir/target-mipsel_24kc_musl 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 2. 修复 libjbigkit 在 GCC 13+ 下的 -ansi / -pedantic 严格模式拦截
# ------------------------------------------------------------------------------
if [ -d "package/feeds/printing/libjbigkit" ]; then
    echo "-> 正在修复 libjbigkit C 编译标志..."
    find package/feeds/printing/libjbigkit/ -type f \( -name "Makefile" -o -name "*.patch" \) -exec sed -i 's/-ansi//g; s/-pedantic//g' {} + || true
fi

# ------------------------------------------------------------------------------
# 3. Ghostscript GCC 13+ 隐式声明与严格错误容错补丁
# ------------------------------------------------------------------------------
if [ -d "package/feeds/printing/ghostscript" ]; then
    echo "-> 正在应用 Ghostscript 编译兼容补丁..."
    sed -i 's/HOST_CONFIGURE_ARGS:=/HOST_CONFIGURE_ARGS:= HOST_CFLAGS="-Wno-error -Wno-implicit-function-declaration" /g' package/feeds/printing/ghostscript/Makefile || true
fi

# ------------------------------------------------------------------------------
# 4. foomatic-filters 注入 TEXTTOPS 路径
# ------------------------------------------------------------------------------
if [ -d "package/feeds/printing/foomatic-filters" ]; then
    echo "-> 正在为 foomatic-filters 配置 TEXTTOPS 路径..."
    sed -i 's/CONFIGURE_ARGS+=/CONFIGURE_ARGS+= TEXTTOPS=\/usr\/bin\/enscript /g' package/feeds/printing/foomatic-filters/Makefile || true
fi

# ------------------------------------------------------------------------------
# 5. gutenprint 交叉编译 malloc/realloc 检测补丁
# ------------------------------------------------------------------------------
if [ -d "package/feeds/printing/gutenprint" ]; then
    echo "-> 正在修复 gutenprint 交叉编译检查项..."
    sed -i 's/CONFIGURE_ARGS+=/CONFIGURE_ARGS+= ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes /g' package/feeds/printing/gutenprint/Makefile || true
fi

# ------------------------------------------------------------------------------
# 6. 本地静态文件/补丁搬运（如果有自定义 files 目录）
# ------------------------------------------------------------------------------
if [ -d "$GITHUB_WORKSPACE/files" ]; then
    echo "-> 正在挂载自定义 files 静态目录..."
    cp -rf "$GITHUB_WORKSPACE/files/*" files/ 2>/dev/null || true
fi

echo "=== diy-part2.sh 执行完毕，准备开始编译 ==="
