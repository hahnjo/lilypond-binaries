This repository contains a number of scripts to build and package binary distributions of LilyPond.
The basic idea is to build static libraries and only depend on very basic dynamic libraries (such as `libc`).
As a result, the binaries are forward-compatible and can be run on newer releases of the OS.

To make things concrete: A binary from CentOS 7 can be executed on newer GNU/Linux distributions.
This includes CentOS 8 and currently supported releases of Debian, Ubuntu, and likely others.
The same holds for binaries compiled on FreeBSD 11: They run fine on the current FreeBSD 12.

All of the above is implemented via portable (POSIX) shell scripts.
The advantage is that there is no need for a more complex language like Python.
Still, the approach currently works for GNU/Linux and FreeBSD and can likely be adapted for macOS.


How to use
----------

1. First you need an environment that would be able to build LilyPond from a release tarball.
Most prominently, this includes a recent compiler and things like fonts, TeX, MetaFont, etc.
Additionally you need gperf, [meson](https://mesonbuild.com/), and [ninja](https://ninja-build.org/) to build some dependencies.
These can be difficult to obtain on some distributions, especially newer versions of them.
As such `scripts/get_tools_gnu.sh` and `scripts/get_tools_meson_ninja.sh` conveniently install the ones above.
Use them if you can't get the tools otherwise; installation from the system's package manager should be preferred.

2. LilyPond depends on a number of runtime dependencies.
As explained above, the scripts build them as static libraries to produce independent libraries.
Run `./scripts/build_native_deps.sh` which downloads, extracts, builds, and installs them in the right order.

3. Eventually the setup is ready to compile LilyPond itself.
This works from tarballs, so either get an official one from https://lilypond.org or create one with `make dist`.
Then start the build with `LILYPOND_TAR=/path/to/lilypond.tar.gz ./scripts/build_lilypond.sh`.

4. Running `./scripts/package_tar.sh` produces two archives with the compiled binaries:
 * `lilypond-$os-$arch.tar.gz` is a minimal version with only LilyPond and required files.
 * `lilypond-$os-$arch-full.tar.gz` additionally contains the interpreter for Python and Guile and wrappers to start the various scripts with them.

Please note that the first two steps from above are actually independent of LilyPond.
This means you can keep the result around, reducing the time for rebuilds for another tarball of LilyPond.


mingw / Windows
---------------

The above procedure would probably also work under mingw, producing native binaries for Windows.
However compilation is apparently very slow, so there are scripts to cross-compile from GNU/Linux.
This needs a toolchain for cross-builds which you can get via `./scripts/mingw_install_toolchain.sh`.

Building the native dependencies is a bit more involved than the native case described above.
Most importantly you still need the result of `scripts/build_native_deps.sh`.
This is because some tools try to execute themselves during build.
Replacing these with the native tools is not complete yet, so the build might require [wine](https://www.winehq.org/) at some places.

Afterwards `./scripts/mingw_build_native_deps.sh` builds libraries for Windows.
Note that it switches `glib` to dynamic libraries because it doesn't work with static linking:
The libraries make use of `DllMain` for initialization which requires loadable libraries.
The script also skips Python because it is very hard to cross-compile, see below for an alternative.

Finally `./scripts/mingw_build_lilypond.sh` builds LilyPond for Windows.
Set the environment variable `LILYPOND_TAR=/path/to/lilypond.tar.gz` as above.
The result can be packaged via `./scripts/mingw_package_zip.sh` into `lilypond-mingw-x86_64.zip`.
Note that this is again a minimal version and does _NOT_ contain a Python interpreter.
If absolutely needed, the Python project provides an [embeddable package](https://docs.python.org/3.7/using/windows.html#the-embeddable-package) for recent versions of the language.
