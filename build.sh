#!/usr/bin/env bash
set -e

COMPILER="${COMPILER:-aosp21}"
KERNEL_VARIANT="${KERNEL_VARIANT:-aosp}"

KERNEL_TREE="${KERNEL_TREE:-https://github.com/Sayemx18/kernel_xiaomi_sm8250.git}"

export ARCH=arm64
export SUBARCH=ARM64
export KBUILD_BUILD_USER="sayem"
export KBUILD_BUILD_HOST="Sayemx18"
export KBUILD_BUILD_TIMESTAMP="$(TZ=UTC-7 date)"
export USE_CCACHE=1
export CCACHE_EXEC=/usr/bin/ccache

WORKDIR="$(pwd)"
TOOLCHAIN="$WORKDIR/toolchain"
OUT="$WORKDIR/artifacts/$KERNEL_VARIANT"

mkdir -p "$TOOLCHAIN" "$OUT"

# ---------- TOOLCHAIN ----------
if [ ! -d "$TOOLCHAIN/bin" ]; then
  case "$COMPILER" in
    aosp)
      wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r547379.tar.gz -O clang.tar.gz
      tar -xf clang.tar.gz -C "$TOOLCHAIN"
      ;;
    aosp-21)
      wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/ebcc6c3bef363bc539ea39f45b6abae1dce6ff1a/clang-r574158.tar.gz -O clang.tar.gz
      tar -xf clang.tar.gz -C "$TOOLCHAIN"
      ;;
    neutron)
      wget https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/10032024/neutron-clang-10032024.tar.zst -O clang.tar.zst
      unzstd clang.tar.zst
      tar -xf clang.tar -C "$TOOLCHAIN"
      ;;
    zyc)
      wget https://github.com/ZyCromerZ/Clang/releases/download/20.0.0git-20250129-release/Clang-20.0.0git-20250129.tar.gz -O clang.tar.gz
      tar -xf clang.tar.gz -C "$TOOLCHAIN"
      ;;
  esac
fi

export PATH="$TOOLCHAIN/bin:$PATH"

# ---------- KERNEL ----------
if [ ! -d k_tree ]; then
  git clone --progress --recurse-submodules "$KERNEL_TREE" -b base k_tree
fi

cd k_tree
git clean -fdx

git cherry-pick 313faa8ccdb50fbbf375b66e5e724bc972647ab9 || true

if [[ "$KERNEL_VARIANT" == "aosp5k" || "$KERNEL_VARIANT" == "miui5k" ]]; then
  git cherry-pick 1cdb6ca2c3ef5de1d2e3b0955dea40add27c2749 || true
fi

if [[ "$KERNEL_VARIANT" == "miui" || "$KERNEL_VARIANT" == "miui5k" ]]; then
  git cherry-pick 2184d03ff9cdc3374f5b947cc7cd78f89cf705ad || true
fi

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
  -j$(nproc --all)

find out/arch/arm64/boot/dts -name '*.dtb' -exec cat {} + > out/arch/arm64/boot/dtb

# ---------- OUTPUT ----------
if [[ "$KERNEL_VARIANT" == "aosp" ]]; then
  cp out/arch/arm64/boot/Image "$OUT/"
  cp out/arch/arm64/boot/dtb "$OUT/"
  cp out/arch/arm64/boot/dtbo.img "$OUT/stock-dtbo.img"
elif [[ "$KERNEL_VARIANT" == "aosp5k" ]]; then
  cp out/arch/arm64/boot/dtbo.img "$OUT/5k-dtbo.img"
elif [[ "$KERNEL_VARIANT" == "miui" ]]; then
  cp out/arch/arm64/boot/dtbo.img "$OUT/miui-dtbo.img"
else
  cp out/arch/arm64/boot/dtbo.img "$OUT/miui-5k-dtbo.img"
fi
