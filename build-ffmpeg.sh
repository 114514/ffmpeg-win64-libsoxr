#!/usr/bin/env bash
# =============================================================================
# Unofficial FFmpeg 8.0.3 (libsoxr) — Windows x64 cross-build, one-shot script
# Idempotent: safe to re-run. Everything auto-downloaded under ./_build
# Result: dist/ffmpeg.exe, dist/ffprobe.exe (+ licences & verification)
# =============================================================================
set -euo pipefail

FFMPEG_VER="8.0.3"
SOXR_COMMIT="945b592b70470e29f917f4de89b4281fbbd540c0"
ROOT="$(cd "$(dirname "$0")" && pwd)"
B="$ROOT/_build"; PREFIX="$B/prefix"; DIST="$ROOT/dist"
mkdir -p "$B" "$DIST"

log(){ echo -e "\n==== $* ====\n"; }

# ---- 0. host tools ------------------------------------------------------------
for t in git curl tar make file ar xxd cmp; do command -v "$t" >/dev/null || {
  echo "Missing host tool: $t (install: sudo dnf/apt install …)"; exit 1; }; done

# ---- 1. mingw-w64 toolchain (Debian bookworm debs, unpacked, no apt needed) ---
TC="$B/toolchain/root"
if [ ! -x "$TC/usr/bin/x86_64-w64-mingw32-gcc-win32" ]; then
  log "fetching mingw-w64 toolchain (bookworm)"
  mkdir -p "$B/toolchain"; cd "$B/toolchain"
  BASE="https://ftp.debian.org/debian/pool/main"
  # gcc needs libisl/libmpc on the host; keep paths portable
  for f in \
    b/binutils-mingw-w64/binutils-mingw-w64-x86-64_2.40-2+10.4_amd64.deb \
    g/gcc-mingw-w64/gcc-mingw-w64-base_12.2.0-14+deb12u1+25.2+b1_amd64.deb \
    g/gcc-mingw-w64/gcc-mingw-w64-x86-64-win32_12.2.0-14+deb12u1+25.2+b1_amd64.deb \
    g/gcc-mingw-w64/gcc-mingw-w64-x86-64-win32-runtime_12.2.0-14+deb12u1+25.2+b1_amd64.deb \
    m/mingw-w64/mingw-w64-x86-64-dev_10.0.0-3_all.deb \
    m/mingw-w64/mingw-w64-common_10.0.0-3_all.deb ; do
      curl -fsSLO "$BASE/$f" || { echo "download failed: $f"; exit 1; }
  done
  # host-side libs required by cc1 (gcc's own binary)
  curl -fsSLO "$BASE/i/isl/libisl23_0.25-1.1_amd64.deb"
  curl -fsSLO "$BASE/m/mpclib3/libmpc3_1.3.1-1_amd64.deb"
  curl -fsSLO "$BASE/m/mpfr4/libmpfr6_4.2.0-1_amd64.deb"
  for d in *.deb; do ar x "$d"; tar -xf data.tar.* -C root 2>/dev/null; rm -f data.tar.* control.tar.* debian-binary; done
  # gcc looks up its target sysroot relative to its prefix: make it see ../x86_64-w64-mingw32
fi
export TC
export LD_LIBRARY_PATH="$TC/usr/lib/x86_64-linux-gnu:$TC/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$TC/usr/bin:$PATH"

# ---- 2. cmake (Kitware binary; works on glibc>=2.17) --------------------------
CM="$B/tools/bin/cmake"
[ -x "$CM" ] || { log "fetching cmake 3.28.6"; cd "$B"
  curl -fSL -o cmake.tar.gz https://github.com/Kitware/CMake/releases/download/v3.28.6/cmake-3.28.6-linux-x86_64.tar.gz
  mkdir -p tools && tar -xzf cmake.tar.gz -C tools --strip-components=1; }

# ---- 3. libsoxr (static) ------------------------------------------------------
if [ ! -f "$PREFIX/lib/libsoxr.a" ]; then
  log "building libsoxr (static, no OpenMP)"
  cd "$B"
  [ -d soxr-src ] || git clone -q https://github.com/chirlu/soxr soxr-src
  (cd soxr-src && git checkout -q "$SOXR_COMMIT")
  "$CM" -S soxr-src -B soxr-build -G 'Unix Makefiles' \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc-win32 \
    -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres \
    -DCMAKE_FIND_ROOT_PATH="$TC/usr/x86_64-w64-mingw32" \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
    -DWITH_OPENMP=OFF -DBUILD_TESTS=OFF -DBUILD_EXAMPLES=OFF \
    -DWITH_LSR_BINDINGS=OFF -DCMAKE_C_FLAGS='-O3' \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" >/dev/null
  "$CM" --build soxr-build -j"$(nproc)" >/dev/null
  "$CM" --install soxr-build >/dev/null
  # soxr 0.1.3 does not generate soxr.pc under WIN32; write one (as BtbN does)
  mkdir -p "$PREFIX/lib/pkgconfig"
  cat > "$PREFIX/lib/pkgconfig/soxr.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include
Name: soxr
Description: SoX resampler library
Version: 0.1.3
Libs: -L\${libdir} -lsoxr
Libs.private: -lwinmm
Cflags: -I\${includedir}
EOF
fi

# ---- 4. FFmpeg ----------------------------------------------------------------
log "building ffmpeg $FFMPEG_VER"
cd "$B"
[ -d "ffmpeg-$FFMPEG_VER" ] || { curl -fSL -o ffmpeg.tar.xz "https://ffmpeg.org/releases/ffmpeg-$FFMPEG_VER.tar.xz"; tar -xf ffmpeg.tar.xz; }
cd "ffmpeg-$FFMPEG_VER"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
./configure \
  --target-os=mingw32 --arch=x86_64 --enable-cross-compile \
  --cross-prefix=x86_64-w64-mingw32- --cc=x86_64-w64-mingw32-gcc-win32 \
  --pkg-config=pkg-config \
  --disable-everything --disable-doc --disable-debug --disable-network --disable-autodetect \
  --enable-small --enable-ffmpeg --enable-ffprobe \
  --enable-decoder=aac,ac3,flac,mp3,pcm_s16le,pcm_f32le,vorbis,opus \
  --enable-demuxer=aac,ac3,flac,mp3,wav,ogg,mov \
  --enable-protocol=file \
  --enable-filter=aresample,anull \
  --enable-libsoxr \
  --disable-w32threads \
  --enable-static --disable-shared \
  --extra-cflags="-O3 -static-libgcc -I$PREFIX/include" \
  --extra-ldflags="-static -static-libgcc -L$PREFIX/lib" \
  || { echo "configure failed"; tail -30 ffbuild/config.log; exit 1; }
make -j"$(nproc)" >/dev/null

# ---- 5. dist + verification ---------------------------------------------------
log "assembling dist/"
cp -f ffmpeg.exe ffprobe.exe "$DIST/"
cp -f COPYING.LGPLv2.1 COPYING.GPLv2 COPYING.GPLv3 "$DIST/" 2>/dev/null || true
cp -f ../soxr-src/COPYING "$DIST/soxr-COPYING" 2>/dev/null || true
OBJDUMP=x86_64-w64-mingw32-objdump
{
  echo "== [A] Architecture =="; file "$DIST/ffmpeg.exe" "$DIST/ffprobe.exe"
  echo; echo "== [B] Import DLLs =="
  for e in ffmpeg.exe ffprobe.exe; do echo "-- $e --"; $OBJDUMP -p "$DIST/$e" | grep "DLL Name"; done
  echo; echo "== [C] libsoxr statically linked (from unstripped build) =="
  x86_64-w64-mingw32-nm ffmpeg_g.exe | grep -E " T soxr_(create|process|delete|version|oneshot)"
  echo; echo "== [D] Forbidden DLLs =="
  for dll in libgcc_s_seh-1.dll libwinpthread-1.dll libgomp-1.dll libstdc++-6.dll VCRUNTIME140.dll ucrtbase.dll; do
    $OBJDUMP -p "$DIST/ffmpeg.exe" | grep -qi "$dll" && echo "FOUND(bad): $dll" || echo "not present(ok): $dll"; done
  echo; echo "== [E] sha256 =="; sha256sum "$DIST/ffmpeg.exe" "$DIST/ffprobe.exe"
} > "$DIST/DEPENDENCIES.txt"
cat "$DIST/DEPENDENCIES.txt"
log "DONE — see $DIST/"
