# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder

name = "OSRM"
version = v"5.27.2"

sources = [
    GitSource(
        "https://github.com/Project-OSRM/osrm-backend.git",
        "de2f39296053412ec2f5668f2e7362f3cfbc4da8"
    ),
    # Use newer SDK on macOS for C++20 support (notably std::unordered_set::contains())
    # Copied from the build script for Charon
    ArchiveSource("https://github.com/phracker/MacOSX-SDKs/releases/download/11.3/MacOSX11.3.sdk.tar.xz",
        "cd4f08a75577145b8f05245a2975f7c81401d75e9535dcffbb879ee1deefcbf4"),
    DirectorySource("./bundled")
]

# Bash recipe for building across all platforms
script = raw"""
cd $WORKSPACE/srcdir/osrm-backend

if [[ "${target}" == *-apple-darwin* ]]; then
    pushd $WORKSPACE/srcdir/MacOSX11.*.sdk
    rm -rf /opt/${target}/${target}/sys-root/System
    rm -rf /opt/${target}/${target}/sys-root/usr/include/libxml2/libxml
    cp -ra usr/* "/opt/${target}/${target}/sys-root/usr/."
    cp -ra System "/opt/${target}/${target}/sys-root/."
    popd
    export MACOSX_DEPLOYMENT_TARGET=11.3
fi

# -Wno-array-bounds to work around GCC bug, see https://github.com/Project-OSRM/osrm-backend/issues/6704
atomic_patch -p1 ../gcc-wno-array-bounds.patch

mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=$prefix \
    -DCMAKE_TOOLCHAIN_FILE="${CMAKE_TARGET_TOOLCHAIN}" \
    ..
cmake --build . --parallel ${nproc}
make --install .
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = expand_cxxstring_abis(supported_platforms(; experimental=true))

# The products that we will ensure are always built
products = [
    LibraryProduct("libosrm", :libosrm),
    ExecutableProduct("osrm-extract", :osrmextract),
    ExecutableProduct("osrm-partition", :osrmpartition),
    ExecutableProduct("osrm-customize", :osrmcustomize),
    ExecutableProduct("osrm-contract", :osrmcustomize),
    FileProduct("share/profiles/car.lua", :profilecar),
    FileProduct("share/profiles/bicycle.lua", :profilebicycle),
    FileProduct("share/profiles/foot.lua", :profilecar)
]

# Dependencies that must be installed before this package can be built
dependencies = [
    # need at least 1.80 for GCC 12
    Dependency("boost_jll"; compat="1.85.0"),
    Dependency("oneTBB_jll"; compat="2021.12.0"),
    Dependency("Expat_jll"; compat="2.6.2"),
    Dependency("Lua_jll"; compat="5.4.6"),
    Dependency("Bzip2_jll"; compat="1.0.8")
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; julia_compat="1.6",
    # GCC 12 is used to build OSRM on OSRM CI infrastructure, so is most likely work
    preferred_gcc_version=v"12")
