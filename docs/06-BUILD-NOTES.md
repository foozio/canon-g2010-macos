# 06 — Build notes: reproducing the native Gutenprint driver

Exact procedure used on 2026-08-22 to produce the arm64 filter this project
runs on. Works on any Apple Silicon Mac with Xcode Command Line Tools,
Homebrew, and internet access. **No sudo required at any point.**

## 0. Prerequisites

```bash
brew install autoconf automake libtool pkg-config
# gettext is usually already present; install if configure complains
```

## 1. Fetch the exact source tag

SourceForge's file-download endpoints block scripted access, but their **git**
server does not — clone the release tag directly:

```bash
cd ~/Downloads/Codes/g2010i          # or wherever you keep the project
git clone --depth 1 --branch gutenprint-5_3_3 \
    https://git.code.sf.net/p/gimp-print/source gutenprint-src
```

(`gutenprint-5_3_5` also exists upstream; 5_3_3 is what community reports
validate for the G2000 series.)

## 2. Configure

Do **not** use `./autogen.sh`: it dies on macOS (Apple's `/usr/bin/libtool`
shadows GNU libtool during its checks, and it demands `glib-mkenums`).
By the time autogen fails, `autoreconf` has *already completed* — so run the
generated `configure` directly:

```bash
cd gutenprint-src
PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH" \
./configure \
    --prefix="$HOME/gp" \
    --without-gimp2 \
    --disable-libgutenprintui2 \
    --disable-samples \
    --disable-test \
    --disable-translated-cups-ppds \
    --without-doc
```

Flag rationale:

| Flag | Why |
|---|---|
| `--prefix=$HOME/gp` | everything lands in your home dir; no root needed; paths baked into the binary stay valid |
| `--without-doc` | **mandatory** — default build needs dvips/jadetex/db2html and dies at `html-stamp` |
| `--disable-translated-cups-ppds` | skip ~100 locale PPDs we don't need |
| rest | trim GIMP plugin / samples / test harness |

## 3. Build & install

```bash
make -j8

# make install tries to write /usr/libexec/cups/backend (root-owned).
# Redirect those targets into your prefix:
PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH" \
make install \
    cupsexec_backenddir="$HOME/gp/cupsexec/backend" \
    cupsexec_driverdir="$HOME/gp/cupsexec/driver" \
    cupsexec_filterdir="$HOME/gp/cupsexec/filter"
```

The install ends with a harmless `install-exec-hook` error trying to `chmod`
the root-owned backend path — ignore it once these exist:

```bash
ls -la ~/gp/sbin/cups-genppd.5.3
file ~/gp/cupsexec/filter/rastertogutenprint.5.3   # expect: arm64
otool -L ~/gp/cupsexec/filter/rastertogutenprint.5.3 | head   # libs resolve under ~/gp
chmod -R a+rX "$HOME/gp"
```

## 4. Generate the printer PPD

```bash
cd <project-root>
~/gp/sbin/cups-genppd.5.3 -p G2010_gutenprint bjc-G2000-series
gunzip -kf G2010_gutenprint/stp-bjc-G2000-series.5.3.ppd.gz

# Point the PPD at OUR filter location (absolute path):
sed -i '' 's|100 rastertogutenprint.5.3|100 '"$HOME"'/gp/cupsexec/filter/rastertogutenprint.5.3|' \
    G2010_gutenprint/stp-bjc-G2000-series.5.3.ppd
```

Driver choice: `bjc-G2000-series` covers the G2010 hardware family
(list siblings via `cups-genppd.5.3 -M | grep -i g2`). Marked EXPERIMENTAL
upstream; validated in practice here and by years of Linux use.

## 5. Wire up the service

See [02-ARCHITECTURE.md](02-ARCHITECTURE.md) for the design and
[03-OPERATIONS.md](03-OPERATIONS.md) for the commands. Short version:

1. Install and start the launchd-owned runtime with
   `harness/printserver-control.sh restart` (port 8632,
   `-f application/pdf`, installed pipeline command hook).
2. Register the system queue and make it default:
   ```bash
   lpadmin -p G2010IPP -E -v "ipp://localhost:8632/ipp/print" -m everywhere
   lpoptions -d G2010IPP
   ```
3. Print a test page.

## 6. Upgrading / rebuilding

- Re-run from step 2 after changing flags; `make install` overwrites cleanly.
- The PPD only embeds the filter *path*, so a rebuilt binary takes effect on
  the next job with no queue changes.
