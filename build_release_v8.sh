#!/bin/bash
# ================================================================
#  KOMPAK POS v8 — BUILD SCRIPT
#  Menghasilkan: APK arm64 (HP baru) + arm32 (HP lama)
#  Jalankan dari root folder proyek:
#    chmod +x build_release_v8.sh && ./build_release_v8.sh
# ================================================================

set -e  # stop on error

# ── Warna ──
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

ok()   { echo -e "  ${GREEN}✅${RESET}  $1"; }
err()  { echo -e "  ${RED}❌${RESET}  $1"; exit 1; }
info() { echo -e "  ${CYAN}ℹ️ ${RESET}  $1"; }
step() { echo -e "\n${BOLD}${CYAN}▶ $1${RESET}"; }

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║     KOMPAK POS v8 — Release Build Script            ║"
echo "║     arm64 (HP baru) + arm32 (HP lama)               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"

VERSION="v8"
RELEASE_DIR="release"
TIMESTAMP=$(date +%Y%m%d_%H%M)

# ── Step 0: Cek Flutter ──
step "Cek Flutter"
if ! command -v flutter &> /dev/null; then
    err "Flutter tidak ditemukan. Install dari: https://flutter.dev/docs/get-started/install"
fi
flutter --version
ok "Flutter tersedia"

# ── Step 1: Cek versi di pubspec.yaml ──
step "Verifikasi versi"
PUBSPEC_VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
info "Versi pubspec: $PUBSPEC_VERSION"

# ── Step 2: Clean ──
step "Flutter clean"
flutter clean
ok "Clean selesai"

# ── Step 3: Get dependencies ──
step "Flutter pub get"
flutter pub get
ok "Dependencies siap"

# ── Step 4: Siapkan folder release ──
step "Siapkan folder release"
mkdir -p "$RELEASE_DIR"
ok "Folder $RELEASE_DIR siap"

# ── Step 5: Build arm64 (HP baru — Snapdragon 8xx, Dimensity, dsb) ──
step "Build APK release — arm64 (HP baru)"
info "Target: armeabi-v7a di-exclude, hanya arm64-v8a"
flutter build apk --release \
    --target-platform android-arm64 \
    --split-per-abi
ok "Build arm64 selesai"

ARM64_SRC="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
ARM64_DST="$RELEASE_DIR/kompak-pos-${VERSION}-arm64.apk"

if [ -f "$ARM64_SRC" ]; then
    cp "$ARM64_SRC" "$ARM64_DST"
    SIZE=$(du -sh "$ARM64_DST" | cut -f1)
    ok "arm64 APK: $ARM64_DST ($SIZE)"
else
    err "arm64 APK tidak ditemukan di $ARM64_SRC"
fi

# ── Step 6: Build arm32 (HP lama — Snapdragon 4xx, 6xx lama, dsb) ──
step "Build APK release — arm32 (HP lama)"
info "Target: arm-v7a"
flutter build apk --release \
    --target-platform android-arm \
    --split-per-abi
ok "Build arm32 selesai"

ARM32_SRC="build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
ARM32_DST="$RELEASE_DIR/kompak-pos-${VERSION}-arm32.apk"

if [ -f "$ARM32_SRC" ]; then
    cp "$ARM32_SRC" "$ARM32_DST"
    SIZE=$(du -sh "$ARM32_DST" | cut -f1)
    ok "arm32 APK: $ARM32_DST ($SIZE)"
else
    err "arm32 APK tidak ditemukan di $ARM32_SRC"
fi

# ── BONUS: Build universal APK (compatible semua) ──
step "Build APK universal (fat APK — semua arsitektur)"
flutter build apk --release
FAT_SRC="build/app/outputs/flutter-apk/app-release.apk"
FAT_DST="$RELEASE_DIR/kompak-pos-${VERSION}-universal.apk"
if [ -f "$FAT_SRC" ]; then
    cp "$FAT_SRC" "$FAT_DST"
    SIZE=$(du -sh "$FAT_DST" | cut -f1)
    ok "Universal APK: $FAT_DST ($SIZE)"
fi

# ── Ringkasan ──
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  ✅ BUILD SELESAI — Kompak POS ${VERSION}${RESET}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "  ${BOLD}File APK:${RESET}"
ls -lh "$RELEASE_DIR"/kompak-pos-${VERSION}*.apk 2>/dev/null | awk '{print "    " $5 "  " $9}'

echo ""
echo -e "  ${BOLD}Perubahan v8:${RESET}"
echo -e "  ${YELLOW}🐛 Fix Bug #1:${RESET} 'produk terlaris all time' → top_products_alltime"
echo -e "  ${YELLOW}🐛 Fix Bug #2:${RESET} 'stok rendah' → stock_low (regex terlalu greedy)"
echo -e "  ${YELLOW}🐛 Fix Bug #3:${RESET} 'air mineral tinggal berapa' → stock_search"
echo -e "  ${YELLOW}🐛 Fix Bug #4:${RESET} 'sesi kasir' → session_info (bukan cashier_stats)"
echo -e "  ${YELLOW}🐛 Fix Bug #5:${RESET} Normalisasi whitespace 'penjualan  hari  ini'"
echo -e "  ${CYAN}✨ Fitur Baru:${RESET} Notifikasi Telegram saat Gemini API quota habis"
echo ""
echo -e "  ${BOLD}Distribusi:${RESET}"
echo -e "  • HP baru  (arm64)  : ${CYAN}kompak-pos-${VERSION}-arm64.apk${RESET}"
echo -e "  • HP lama  (arm32)  : ${CYAN}kompak-pos-${VERSION}-arm32.apk${RESET}"
echo -e "  • Semua HP (fat)    : ${CYAN}kompak-pos-${VERSION}-universal.apk${RESET}"
echo ""
