## libsoxr embedded

`ffmpeg.exe -version` reports `--enable-libsoxr`. High-quality SoX resampler
available as:

```
ffmpeg -af aresample=48000:resampler=soxr
```

## Verification (this exact binary)

* `PE32+ ... x86-64 ... for MS Windows` (both ffmpeg.exe and ffprobe.exe)
* imports: `KERNEL32.dll`, `msvcrt.dll`, `SHELL32.dll`, `bcrypt.dll` only
* soxr symbols statically linked: soxr_create / soxr_process / soxr_delete /
  soxr_version / soxr_oneshot (verified with nm on the unstripped binary)
* none of: libgcc_s_seh-1 / libwinpthread-1 / libgomp-1 / libstdc++-6 /
  VCRUNTIME140 / ucrtbase present
* full output: `DEPENDENCIES.txt` in the release assets
