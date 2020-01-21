. "$(dirname $0)/common.sh"

DEPENDENCIES="$ROOT/dependencies"
SRC="$DEPENDENCIES/src"
BUILD="$DEPENDENCIES/build"
INSTALL="$DEPENDENCIES/install"

EXPAT_VERSION="2.2.9"
EXPAT_ARCHIVE="expat-$EXPAT_VERSION.tar.xz"
url_version="$(echo $EXPAT_VERSION | sed "s/\\./_/g")"
EXPAT_URL="https://github.com/libexpat/libexpat/releases/download/R_$url_version/$EXPAT_ARCHIVE"
EXPAT_DIR="expat-$EXPAT_VERSION"
EXPAT_INSTALL="$INSTALL/$EXPAT_DIR"

FREETYPE_VERSION="2.10.1"
FREETYPE_ARCHIVE="freetype-$FREETYPE_VERSION.tar.xz"
FREETYPE_URL="https://download.savannah.gnu.org/releases/freetype/$FREETYPE_ARCHIVE"
FREETYPE_DIR="freetype-$FREETYPE_VERSION"
FREETYPE_INSTALL="$INSTALL/$FREETYPE_DIR"

UTIL_LINUX_VERSION="2.34"
UTIL_LINUX_ARCHIVE="util-linux-$UTIL_LINUX_VERSION.tar.xz"
UTIL_LINUX_URL="https://www.kernel.org/pub/linux/utils/util-linux/v$UTIL_LINUX_VERSION/$UTIL_LINUX_ARCHIVE"
UTIL_LINUX_DIR="util-linux-$UTIL_LINUX_VERSION"
UTIL_LINUX_INSTALL="$INSTALL/$UTIL_LINUX_DIR"

FONTCONFIG_VERSION="2.13.1"
FONTCONFIG_ARCHIVE="fontconfig-$FONTCONFIG_VERSION.tar.bz2"
FONTCONFIG_URL="https://www.freedesktop.org/software/fontconfig/release/$FONTCONFIG_ARCHIVE"
FONTCONFIG_DIR="fontconfig-$FONTCONFIG_VERSION"
FONTCONFIG_INSTALL="$INSTALL/$FONTCONFIG_DIR"

GHOSTSCRIPT_VERSION="9.50"
GHOSTSCRIPT_ARCHIVE="ghostscript-$GHOSTSCRIPT_VERSION.tar.gz"
url_version="$(echo $GHOSTSCRIPT_VERSION | sed "s/\\.//g")"
GHOSTSCRIPT_URL="https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs$url_version/$GHOSTSCRIPT_ARCHIVE"
GHOSTSCRIPT_DIR="ghostscript-$GHOSTSCRIPT_VERSION"
GHOSTSCRIPT_INSTALL="$INSTALL/$GHOSTSCRIPT_DIR"

LIBFFI_VERSION="3.2.1"
LIBFFI_ARCHIVE="libffi-$LIBFFI_VERSION.tar.gz"
LIBFFI_URL="https://sourceware.org/pub/libffi/$LIBFFI_ARCHIVE"
LIBFFI_DIR="libffi-$LIBFFI_VERSION"
LIBFFI_INSTALL="$INSTALL/$LIBFFI_DIR"

ZLIB_VERSION="1.2.11"
ZLIB_ARCHIVE="zlib-$ZLIB_VERSION.tar.xz"
ZLIB_URL="https://www.zlib.net/$ZLIB_ARCHIVE"
ZLIB_DIR="zlib-$ZLIB_VERSION"
ZLIB_INSTALL="$INSTALL/$ZLIB_DIR"

GLIB2_VERSION_MAJOR="2.62"
GLIB2_VERSION_PATCH="2"
GLIB2_VERSION="$GLIB2_VERSION_MAJOR.$GLIB2_VERSION_PATCH"
GLIB2_ARCHIVE="glib-$GLIB2_VERSION.tar.xz"
GLIB2_URL="https://download.gnome.org/sources/glib/$GLIB2_VERSION_MAJOR/$GLIB2_ARCHIVE"
GLIB2_DIR="glib-$GLIB2_VERSION"
GLIB2_INSTALL="$INSTALL/$GLIB2_DIR"

GMP_VERSION="6.1.2"
GMP_ARCHIVE="gmp-$GMP_VERSION.tar.lz"
GMP_URL="https://gmplib.org/download/gmp/$GMP_ARCHIVE"
GMP_DIR="gmp-$GMP_VERSION"
GMP_INSTALL="$INSTALL/$GMP_DIR"

LIBTOOL_VERSION="2.4.6"
LIBTOOL_ARCHIVE="libtool-$LIBTOOL_VERSION.tar.xz"
LIBTOOL_URL="https://ftp.gnu.org/gnu/libtool/$LIBTOOL_ARCHIVE"
LIBTOOL_DIR="libtool-$LIBTOOL_VERSION"
LIBTOOL_INSTALL="$INSTALL/$LIBTOOL_DIR"

GUILE_VERSION_MAJOR="1.8"
GUILE_VERSION_PATCH="8"
GUILE_VERSION="$GUILE_VERSION_MAJOR.$GUILE_VERSION_PATCH"
GUILE_ARCHIVE="guile-$GUILE_VERSION.tar.gz"
GUILE_URL="https://ftp.gnu.org/gnu/guile/$GUILE_ARCHIVE"
GUILE_DIR="guile-$GUILE_VERSION"
GUILE_INSTALL="$INSTALL/$GUILE_DIR"

PIXMAN_VERSION="0.38.4"
PIXMAN_ARCHIVE="pixman-$PIXMAN_VERSION.tar.gz"
PIXMAN_URL="https://cairographics.org/releases/$PIXMAN_ARCHIVE"
PIXMAN_DIR="pixman-$PIXMAN_VERSION"
PIXMAN_INSTALL="$INSTALL/$PIXMAN_DIR"

CAIRO_VERSION="1.16.0"
CAIRO_ARCHIVE="cairo-$CAIRO_VERSION.tar.xz"
CAIRO_URL="https://cairographics.org/releases/$CAIRO_ARCHIVE"
CAIRO_DIR="cairo-$CAIRO_VERSION"
CAIRO_INSTALL="$INSTALL/$CAIRO_DIR"

HARFBUZZ_VERSION="2.6.4"
HARFBUZZ_ARCHIVE="harfbuzz-$HARFBUZZ_VERSION.tar.xz"
HARFBUZZ_URL="https://www.freedesktop.org/software/harfbuzz/release/$HARFBUZZ_ARCHIVE"
HARFBUZZ_DIR="harfbuzz-$HARFBUZZ_VERSION"
HARFBUZZ_INSTALL="$INSTALL/$HARFBUZZ_DIR"

PANGO_VERSION_MAJOR="1.44"
PANGO_VERSION_PATCH="7"
PANGO_VERSION="$PANGO_VERSION_MAJOR.$PANGO_VERSION_PATCH"
PANGO_ARCHIVE="pango-$PANGO_VERSION.tar.xz"
PANGO_URL="http://ftp.gnome.org/pub/GNOME/sources/pango/$PANGO_VERSION_MAJOR/$PANGO_ARCHIVE"
PANGO_DIR="pango-$PANGO_VERSION"
PANGO_INSTALL="$INSTALL/$PANGO_DIR"

PYTHON_VERSION_MAJOR="2.7"
PYTHON_VERSION_PATCH="17"
PYTHON_VERSION="$PYTHON_VERSION_MAJOR.$PYTHON_VERSION_PATCH"
PYTHON_ARCHIVE="Python-$PYTHON_VERSION.tar.xz"
PYTHON_URL="https://www.python.org/ftp/python/$PYTHON_VERSION/$PYTHON_ARCHIVE"
PYTHON_DIR="Python-$PYTHON_VERSION"
PYTHON_INSTALL="$INSTALL/$PYTHON_DIR"
