# Third-Party Notices

This project is an integration layer. The first-party code (the Swift
`G2010Manager`, the shell runtime in `harness/`, and documentation) is licensed
under **GPL-3.0-or-later** (see [`LICENSE`](LICENSE)).

However, the runtime it builds and the DMG it packages **bundle and redistribute
several upstream components**, each under its own license. Those components remain
governed by their original licenses; nothing in this repository re-licences them.

## Runtime / bundled components

| Component | Origin | License | Notes |
|---|---|---|---|
| Gutenprint (`rastertogutenprint.5.3`, XML DB) | SourceForge `gimp-print`, tag `gutenprint-5_3_3` | **GPL-2.0-or-later** | Raster→Canon BJ filter + model data |
| SANE `sane-backends` (`scanimage`, `libsane`, pixma backend) | sane-backends | **GPL-2.0-or-later** | Scanner engine; `pixma` backend speaks Canon's scanner protocol |
| CUPS (`ippeveprinter`, `libcups`) | OpenPrinting CUPS (Homebrew, keg-only) | **Apache-2.0 WITH LLVM-exception** | Standalone IPP server |
| libusb | libusb | **LGPL-2.1-or-later** | USB access for SANE |
| OpenSSL (`libssl`, `libcrypto`) | openssl@3 | **Apache-2.0** | Dependency of `libcups` |
| libpng | libpng | **libpng-2.0** (permissive) | Image decode for scanning |
| libjpeg-turbo | libjpeg-turbo | **IJG AND Zlib AND BSD-3-Clause** | Image decode for scanning |

## Reference-only components (not bundled, not redistributed)

| Component | Origin | License | Notes |
|---|---|---|---|
| Canon `cnijfilter2` | Canon (GPL Linux driver) | **GPL** | Kept in `cnijfilter2-src/` only as *protocol ground truth* for the IVEC/BJRaster3 dialect; not compiled into or shipped with this project |

## Apple-provided system components (invoked, not bundled)

These ship with macOS and are invoked at runtime. They are **not** redistributed
by this project and remain under Apple's licenses:

- `/usr/libexec/cups/filter/cgpdftoraster` (PDF → CUPS raster)
- `/usr/libexec/cups/backend/usb` (USB transport)
- CUPS client tools: `lpstat`, `lpadmin`, `lpoptions`, `cancel`

## GPL compliance

Because the packaged DMG redistributes GPL-2.0-or-later binaries (Gutenprint,
SANE), the corresponding machine-readable source must be made available to
recipients of the DMG:

- Gutenprint source: fetch tag `gutenprint-5_3_3` — see
  [`docs/06-BUILD-NOTES.md`](docs/06-BUILD-NOTES.md) for the exact clone/build
  procedure used here.
- SANE source: available from the SANE project (https://gitlab.com/sane-project/backends)
  matching the Homebrew version bundled.

If you redistribute a built DMG, provide or point to the matching sources, or a
written offer to supply them, as required by the GPL.

## Trademarks

"Canon", "PIXMA", and "G2010" are trademarks of Canon Inc. This project is not
affiliated with, endorsed by, or sponsored by Canon. Apple, macOS, and AirPrint are
trademarks of Apple Inc.
