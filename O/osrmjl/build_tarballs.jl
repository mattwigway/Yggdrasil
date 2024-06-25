# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "osrmjl"
version = v"0.2.1"

# Collection of sources required to complete build
sources = [
    GitSource("https://github.com/mattwigway/OSRM.jl.git", "52c90cf0e80408cfe9552f36e1e95816952d2716"),
    # Use the same SDK used to build OSRM
    ArchiveSource("https://github.com/realjf/MacOSX-SDKs/releases/download/v0.0.1/MacOSX12.3.sdk.tar.xz",
                  "a511c1cf1ebfe6fe3b8ec005374b9c05e89ac28b3d4eb468873f59800c02b030") 
]

sdk_update_script = raw"""
if [[ "${target}" == *-apple-darwin* ]]; then
    # Install a newer SDK which supports C++20
    pushd $WORKSPACE/srcdir/MacOSX12.*.sdk
    rm -rf /opt/${target}/${target}/sys-root/System
    rm -rf /opt/${target}/${target}/sys-root/usr/*
    cp -ra usr/* "/opt/${target}/${target}/sys-root/usr/."
    cp -ra System "/opt/${target}/${target}/sys-root/."
    popd
    export MACOSX_DEPLOYMENT_TARGET=12.3
fi
"""

# Bash recipe for building across all platforms
script = sdk_update_script * raw"""
cd $WORKSPACE/srcdir/OSRM.jl/cxx

mkdir build && cd build

cmake .. -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN%.*}_clang.cmake
cmake --build . -j${nproc}
cmake --install . --prefix="$prefix"

install_license ../../LICENSE
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
# We use the same platforms as OSRM_jll
platforms = supported_platforms(; exclude=p -> 
    (libc(p) == "musl") ||
    (nbits(p) == 32) ||
    Sys.iswindows(p) # Mingw version compatibility issues
    )

platforms = expand_cxxstring_abis(platforms)

# The products that we will ensure are always built
products = Product[
    # We are not dlopening because the build images use Julia 1.7, which can't dlopen SOs built
    # with GCC 12, which is required for OSRM. However, Julia 1.8+ can dlopen them (tested),
    # and that is what our compat entry says, so the dlopen failure can safely be ignored.
    LibraryProduct("libosrmjl", :libosrmjl, dont_dlopen=true)
]

# Dependencies that must be installed before this package can be built
dependencies = [

    Dependency("OSRM_jll"; compat="5.28.0"),
    Dependency("boost_jll"; compat="=1.79.0")
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies;
    preferred_gcc_version=v"12", julia_compat="1.8", clang_use_lld=false)
