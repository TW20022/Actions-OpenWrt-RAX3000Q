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
# 3. Ghostscript GCC 13+ 隐式声明与严格错误容错补丁（带多重兜底）
# ------------------------------------------------------------------------------
MAKEFILE_GS="package/feeds/printing/ghostscript/Makefile"
if [ -f "${MAKEFILE_GS}" ]; then
    echo "-> 正在应用 Ghostscript 编译兼容补丁..."
    
    # 策略 A：如果存在 HOST_CONFIGURE_ARGS:= 或 HOST_CONFIGURE_ARGS =，在其后追加 HOST_CFLAGS
    if grep -q '^HOST_CONFIGURE_ARGS' "${MAKEFILE_GS}"; then
        sed -i '/^HOST_CONFIGURE_ARGS/s/$/ HOST_CFLAGS="-Wno-error -Wno-implicit-function-declaration"/' "${MAKEFILE_GS}"
        echo "   -> 策略 A 成功：已追加到现有 HOST_CONFIGURE_ARGS"
        
    # 策略 B：如果全局能匹配到 HOST_CONFIGURE_ARGS，则进行模糊追加
    elif grep -q 'HOST_CONFIGURE_ARGS' "${MAKEFILE_GS}"; then
        sed -i '/HOST_CONFIGURE_ARGS/s/$/ HOST_CFLAGS="-Wno-error -Wno-implicit-function-declaration"/' "${MAKEFILE_GS}"
        echo "   -> 策略 B 成功：已追加到 HOST_CONFIGURE_ARGS 定义中"
        
    # 策略 C（终极兜底）：如果压根没有该变量，直接在 Host/Configure 块中强行插入
    else
        echo "   -> 警告：未找到标准 HOST_CONFIGURE_ARGS，采用终极策略强制插入..."
        sed -i '/define Host\/Configure/a \    HOST_CONFIGURE_ARGS += HOST_CFLAGS="-Wno-error -Wno-implicit-function-declaration"' "${MAKEFILE_GS}" || \
        echo 'HOST_CONFIGURE_ARGS += HOST_CFLAGS="-Wno-error -Wno-implicit-function-declaration"' >> "${MAKEFILE_GS}"
    fi
else
    echo "-> 提示：未检测到 ghostscript 目录或 Makefile，跳过该项修复。"
fi
# ------------------------------------------------------------------------------
# 4. foomatic-filters 注入 TEXTTOPS 路径（带多重兜底）
# ------------------------------------------------------------------------------
MAKEFILE_FOOMATIC="package/feeds/printing/foomatic-filters/Makefile"
if [ -f "${MAKEFILE_FOOMATIC}" ]; then
    echo "-> 正在为 foomatic-filters 配置 TEXTTOPS 路径..."
    
    # 策略 A：如果文件中原本就存在 CONFIGURE_ARGS+=，直接在后面追加
    if grep -q '^CONFIGURE_ARGS+=' "${MAKEFILE_FOOMATIC}"; then
        sed -i '/^CONFIGURE_ARGS+=/s/$/ TEXTTOPS=\/usr\/bin\/enscript/' "${MAKEFILE_FOOMATIC}"
        echo "   -> 策略 A 成功：已追加到现有 CONFIGURE_ARGS+="
        
    # 策略 B：如果只有 CONFIGURE_ARGS:= 或 CONFIGURE_ARGS =，尝试匹配它
    elif grep -q 'CONFIGURE_ARGS' "${MAKEFILE_FOOMATIC}"; then
        sed -i '/CONFIGURE_ARGS/s/$/ TEXTTOPS=\/usr\/bin\/enscript/' "${MAKEFILE_FOOMATIC}"
        echo "   -> 策略 B 成功：已追加到 CONFIGURE_ARGS 定义中"
        
    # 策略 C（终极兜底）：如果压根找不到 CONFIGURE_ARGS 变量，直接在 Package/configure 定义块下方强行插入一行
    else
        echo "   -> 警告：未找到标准 CONFIGURE_ARGS，采用终极策略强制插入..."
        sed -i '/define Build\/Configure/a \    CONFIGURE_ARGS += TEXTTOPS=/usr/bin/enscript' "${MAKEFILE_FOOMATIC}" || \
        echo "TEXTTOPS=/usr/bin/enscript" >> "${MAKEFILE_FOOMATIC}"
    fi
else
    echo "-> 提示：未检测到 foomatic-filters 目录或 Makefile，跳过该项修复。"
fi

# ------------------------------------------------------------------------------
# 5. gutenprint 交叉编译 malloc/realloc 检测补丁（带多重兜底）
# ------------------------------------------------------------------------------
MAKEFILE_GUTENPRINT="package/feeds/printing/gutenprint/Makefile"
if [ -f "${MAKEFILE_GUTENPRINT}" ]; then
    echo "-> 正在修复 gutenprint 交叉编译检查项..."
    
    # 策略 A：如果文件中存在标准 CONFIGURE_ARGS+=，直接在其后追加
    if grep -q '^CONFIGURE_ARGS+=' "${MAKEFILE_GUTENPRINT}"; then
        sed -i '/^CONFIGURE_ARGS+=/s/$/ ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes/' "${MAKEFILE_GUTENPRINT}"
        echo "   -> 策略 A 成功：已追加到现有 CONFIGURE_ARGS+="
        
    # 策略 B：如果存在其他形式的 CONFIGURE_ARGS 定义，进行模糊匹配追加
    elif grep -q 'CONFIGURE_ARGS' "${MAKEFILE_GUTENPRINT}"; then
        sed -i '/CONFIGURE_ARGS/s/$/ ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes/' "${MAKEFILE_GUTENPRINT}"
        echo "   -> 策略 B 成功：已追加到 CONFIGURE_ARGS 定义中"
        
    # 策略 C（终极兜底）：如果未找到标准变量，直接在 Build/Configure 阶段强行注入
    else
        echo "   -> 警告：未找到标准 CONFIGURE_ARGS，采用终极策略强制插入..."
        sed -i '/define Build\/Configure/a \    CONFIGURE_ARGS += ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes' "${MAKEFILE_GUTENPRINT}" || \
        echo "CONFIGURE_ARGS += ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes" >> "${MAKEFILE_GUTENPRINT}"
    fi
else
    echo "-> 提示：未检测到 gutenprint 目录或 Makefile，跳过该项修复。"
fi

# ------------------------------------------------------------------------------
# 6. 本地静态文件/补丁搬运（如果有自定义 files 目录）
# ------------------------------------------------------------------------------
if [ -d "$GITHUB_WORKSPACE/files" ]; then
    echo "-> 正在挂载自定义 files 静态目录..."
    cp -rf "$GITHUB_WORKSPACE/files/*" files/ 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 7. 修复 Ghostscript hostpkg 寻找 cups 依赖报错
# ------------------------------------------------------------------------------
MAKEFILE_GS="package/feeds/printing/ghostscript/Makefile"
if [ -f "${MAKEFILE_GS}" ]; then
    echo "Patching ghostscript host configure: add --disable-cups"
    # host 参数
    if grep -q '^HOST_CONFIGURE_ARGS' "${MAKEFILE_GS}"; then
        sed -i '/^HOST_CONFIGURE_ARGS/s/$/ --disable-cups/' "${MAKEFILE_GS}"
    else
        sed -i '/^define Host\/Configure/i HOST_CONFIGURE_ARGS:= --disable-cups' "${MAKEFILE_GS}"
    fi
    # 同步给target编译也加上（可选，建议开启保持一致）
    if grep -q '^CONFIGURE_ARGS' "${MAKEFILE_GS}"; then
        sed -i '/^CONFIGURE_ARGS/s/$/ --disable-cups/' "${MAKEFILE_GS}"
    fi
fi

echo "=== diy-part2.sh 执行完毕，准备开始编译 ==="
