using BinaryBuilder

name = "LibSpatialIndex"
version = v"1.8.5"

# Collection of sources required to build LibSpatialIndex
sources = [
    ArchiveSource("https://github.com/libspatialindex/libspatialindex/releases/download/1.9.3/spatialindex-src-1.9.3.tar.bz2",
        "4a529431cfa80443ab4dcd45a4b25aebbabe1c0ce2fa1665039c80e999dcc50a"),
    DirectorySource("./patches"),
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir

cd spatialindex-src-*

patch < ${WORKSPACE}/srcdir/makefile.patch
rm Makefile.am.orig

if [ $target = "x86_64-w64-mingw32" ] || [ $target = "i686-w64-mingw32" ]; then
  patch < ${WORKSPACE}/srcdir/header-check.patch
fi

aclocal
autoconf
automake --add-missing --foreign

# Show options in the log
./configure --help

./configure --prefix=${prefix} --host=$target --build=${MACHTYPE} --enable-static=no
make
make install
install_license COPYING
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = expand_cxxstring_abis(supported_platforms(; experimental=true))

# The products that we will ensure are always built
products = [
    LibraryProduct("libspatialindex_c", :libspatialindex_c),
    LibraryProduct("libspatialindex", :libspatialindex),
]

# Dependencies that must be installed before this package can be built
dependencies = []

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6")
