# ffmpeg-win64-libsoxr (unofficial)

Unofficial **Windows x64 build of FFmpeg 8.0.3 with libsoxr 0.1.3 statically
linked** — the high-quality SoX resampler baked into the `aresample` filter.

> **Not affiliated with or endorsed by the FFmpeg or SoX projects.**
> Binaries are distributed via GitHub Releases (see below).

## Download

Get `ffmpeg-win64-libsoxr-v8.0.3.zip` from this repository's **Releases**
page. Inside:

| file | purpose |
|---|---|
| `ffmpeg.exe` / `ffprobe.exe` | 64-bit static binaries, no redistributable needed |
| `COPYING.LGPLv2.1` / `COPYING.GPLv2` / `COPYING.GPLv3` | FFmpeg licence texts |
| `soxr-COPYING` / `soxr-LICENCE` | libsoxr licence texts |
| `THIRD-PARTY-NOTICES.txt` | combined notices (FFmpeg + libsoxr + embedded FFT code) |
| `SOURCE.txt` | source URLs, commit hash, exact configure line |
| `DEPENDENCIES.txt` | architecture / import-DLL / export verification output |

## Why this build

* **`--enable-libsoxr`**: `ffmpeg -af aresample=48000:resampler=soxr` works.
* **Statically linked, msvcrt CRT**: imports only Windows system DLLs —
  `KERNEL32.dll`, `msvcrt.dll`, `SHELL32.dll`, `bcrypt.dll`. No
  `libgcc_s_seh-1.dll`, no `libwinpthread-1.dll`, no `libgomp-1.dll`, no UCRT.
* **LGPL profile** (no `--enable-gpl`): suitable for closed-source apps that
  dynamically load or ship the exe alongside, subject to LGPL terms.
* Minimal feature set on purpose (audio-focused): decode aac/ac3/flac/mp3/
  pcm/vorbis/opus, demux wav/mp3/flac/ogg/mov/aac/ac3, `aresample` + `anull`
  filters, file protocol. Small, auditable binaries.

## Reproduce

```bash
./build-ffmpeg.sh        # fetches toolchain, libsoxr, ffmpeg; verifies; assembles dist/
```

The script is idempotent and pins: FFmpeg 8.0.3 tarball + soxr commit
`945b592b70470e29f917f4de89b4281fbbd540c0` + GCC 12.2.0 (msvcrt).

## License

FFmpeg is LGPL-2.1+ (this build applies v2.1; no GPL options enabled).
libsoxr is LGPL-2.1-or-later (v2.1 applied). See `THIRD-PARTY-NOTICES.txt`
for pffft/FFTpack/Ooura FFT notices embedded in soxr.

## Resampler usage

```bash
# resample to 48 kHz using the SoX resampler:
ffmpeg.exe -i input.wav -af aresample=48000:resampler=soxr out.wav
```
