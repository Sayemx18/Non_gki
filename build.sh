#!/usr/bin/env bash
set -e

COMPILER="${COMPILER:-aosp21}"            # aosp | aosp-21 | neutron | zyc
KERNEL_VARIANT="${KERNEL_VARIANT:-aosp}" # aosp | miui | aosp5k | miui5k

KERNEL_TREE="${KERNEL_TREE:-https://github.com/Sayemx18/kernel_xiaomi_sm8250.git}"
ANYKERNEL_URL="${ANYKERNEL_URL:-https://github.com/Sayemx18/AnyKernel3.git}"

# =========================
# ENV
# =========================
export ARCH=arm64
export SUBARCH=ARM64
export KBUILD_BUILD_USER="sayem"
export KBUILD_BUILD_HOST="Sayemx18"
export KBUILD_BUILD_TIMESTAMP="$(TZ=UTC-7 date)"
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache

WORKDIR="$(pwd)"
TOOLCHAIN="$WORKDIR/toolchain"
ARTIFACTS="$WORKDIR/artifacts/$KERNEL_VARIANT"

mkdir -p "$TOOLCHAIN" "$ARTIFACTS"

echo "================================="
echo " Variant : $KERNEL_VARIANT"
echo " Compiler: $COMPILER"
echo "================================="

# =========================
# TOOLCHAIN
# =========================
if [ ! -d "$TOOLCHAIN/bin" ]; then
  case "$COMPILER" in
    aosp)
      wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r547379.tar.gz -O clang.tar.gz
      tar -xf clang.tar.gz -C "$TOOLCHAIN"
      ;;
    aosp-21)
      wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/ebcc6c3bef363bc539ea39f45b6abae1dce6ff1a/clang-r574158.tar.gz -O clang.tar.gz
      tar -xf clang.tar.gz -C "$TOOLCHAIN"
      ;;
    neutron)
      wget -q https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/10032024/neutron-clang-10032024.tar.zst -O clang.tar.zst
      unzstd clang.tar.zst
      tar -xf clang.tar -C "$TOOLCHAIN"
      ;;
    zyc)
      wget -q https://github.com/ZyCromerZ/Clang/releases/download/20.0.0git-20250129-release/Clang-20.0.0git-20250129.tar.gz -O clang.tar.gz
      tar -xf clang.tar.gz -C "$TOOLCHAIN"
      ;;
  esac
fi

export PATH="$TOOLCHAIN/bin:$PATH"

# =========================
# KERNEL SOURCE
# =========================
if [ ! -d k_tree ]; then
  git clone --recurse-submodules "$KERNEL_TREE" -b base k_tree
fi

cd k_tree
git config --global user.email "sayemxx18@gmail.com"
git config --global user.name "sayem"

git reset --hard
git clean -fdx

# Common revert
git cherry-pick 313faa8ccdb50fbbf375b66e5e724bc972647ab9 || true

# Variant patches
if [[ "$KERNEL_VARIANT" == "aosp5k" || "$KERNEL_VARIANT" == "miui5k" ]]; then
  git cherry-pick 1cdb6ca2c3ef5de1d2e3b0955dea40add27c2749 || true
fi

if [[ "$KERNEL_VARIANT" == "miui" || "$KERNEL_VARIANT" == "miui5k" ]]; then
  git cherry-pick 2184d03ff9cdc3374f5b947cc7cd78f89cf705ad || true
fi

# =========================
# BUILD
# =========================
make O=out alioth_defconfig

scripts/config --file out/.config \
  -e KSU \
  -e KSU_MANUAL_HOOK \
  -e THERMAL_DIMMING \
  -e FAKE_UNAME_5_15

make O=out \
  LLVM=1 LLVM_IAS=1 \
  CC="ccache clang" \
  HOSTCC=clang HOSTCXX=clang++ \
  CROSS_COMPILE=aarch64-linux-gnu- \
  CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
  CLANG_TRIPLE=aarch64-linux-gnu- \
  -j$(nproc)

find out/arch/arm64/boot/dts -name '*.dtb' -exec cat {} + > out/arch/arm64/boot/dtb

# =========================
# ARTIFACTS
# =========================
if [[ "$KERNEL_VARIANT" == "aosp" ]]; then
  cp out/arch/arm64/boot/Image "$ARTIFACTS/"
  cp out/arch/arm64/boot/dtb "$ARTIFACTS/"
  cp out/arch/arm64/boot/dtbo.img "$ARTIFACTS/stock-dtbo.img"
elif [[ "$KERNEL_VARIANT" == "aosp5k" ]]; then
  cp out/arch/arm64/boot/dtbo.img "$ARTIFACTS/5k-dtbo.img"
elif [[ "$KERNEL_VARIANT" == "miui" ]]; then
  cp out/arch/arm64/boot/dtbo.img "$ARTIFACTS/miui-dtbo.img"
else
  cp out/arch/arm64/boot/dtbo.img "$ARTIFACTS/miui-5k-dtbo.img"
fi

cd "$WORKDIR"

# =========================
# ANYKERNEL ZIP
# =========================
rm -rf AnyKernel3
git clone --depth=1 "$ANYKERNEL_URL" AnyKernel3
cp -r artifacts/* AnyKernel3/

ZIP_NAME="Raikiri-Kernel-v1.1-$(date +%Y%m%d).zip"
cd AnyKernel3
zip -r "../$ZIP_NAME" . -x ".git/*" ".github/*"

echo "DONE → $ZIP_NAME"