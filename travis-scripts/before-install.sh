#!/bin/bash

# exit this script if any commmand fails
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
COCOS2DX_ROOT="$DIR/../frameworks/cocos2d-x"
CURL="curl --retry 999 --retry-max-time 0"

function install_android_ndk()
{
    if [ "$TRAVIS_OS_NAME" == "windows" ] ; then
        python -m pip install retry
    else
        sudo python -m pip install retry
    fi
    
    echo "Setup android..."

    if [ "$BUILD_TARGET" == "android_ndk-build" ]\
        || [ "$BUILD_TARGET" == "android_lua_ndk-build" ]\
        || [ "$BUILD_TARGET" == "android_cmake" ]\
        || [ "$BUILD_TARGET" == "android_js_cmake" ]\
        || [ "$BUILD_TARGET" == "android_lua_cmake" ] ; then
        python $COCOS2DX_ROOT/tools/appveyor-scripts/setup_android.py
    else
        python $COCOS2DX_ROOT/tools/appveyor-scripts/setup_android.py --ndk_only
    fi
}

function install_linux_environment()
{
    mkdir -p $HOME/bin
    pushd $HOME/bin

    echo "GCC version: `gcc --version`"
    # install new version cmake
    CMAKE_VERSION="3.7.2"
    CMAKE_DOWNLOAD_URL="https://cmake.org/files/v3.7/cmake-${CMAKE_VERSION}.tar.gz"
    echo "Download ${CMAKE_DOWNLOAD_URL}"
    ${CURL} -O ${CMAKE_DOWNLOAD_URL}
    tar -zxf "cmake-${CMAKE_VERSION}.tar.gz"
    cd "cmake-${CMAKE_VERSION}"
    ./configure > /dev/null
    make -j2 > /dev/null
    sudo make install > /dev/null
    echo "CMake Version: `cmake --version`"
    cd ..

    # install new version binutils
    BINUTILS_VERSION="2.28"
    BINUTILS_URL="http://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.gz"
    echo "Download ${BINUTILS_URL}"
    ${CURL} -O ${BINUTILS_URL}
    tar -zxf "binutils-${BINUTILS_VERSION}.tar.gz"
    cd "binutils-${BINUTILS_VERSION}"
    ./configure > /dev/null
    make -j2 > /dev/null
    sudo make install > /dev/null
    echo "ld Version: `ld --version`"
    echo "which ld: `which ld`"
    sudo rm /usr/bin/ld
    popd
    echo "Installing linux dependence packages ..."
    echo -e "y" | bash $COCOS2DX_ROOT/build/install-deps-linux.sh
    echo "Installing linux dependence packages finished!"

    ld --version
}

function download_deps()
{
    # install dpes
    pushd $COCOS2DX_ROOT
    python download-deps.py -r=yes
    popd
    echo "Downloading cocos2d-x dependence finished!"
}

function install_python_module_for_osx()
{
    pip install PyYAML
    sudo pip install Cheetah
}

function install_python_module_for_windows()
{
    choco install python2
    export PATH="/c/Python27:/c/Python27/Scripts:$PATH"
    python --version
    echo "Installing python modules finished!"
}

function install_latest_python()
{
    python -V
    eval "$(pyenv init -)"
    pyenv install 2.7.14
    pyenv global 2.7.14
    python -V
}

# set up environment according os and target
function install_environement()
{
    echo "Building ..."

    if [ "$TRAVIS_OS_NAME" == "linux" ]; then
        sudo apt-get update
        sudo apt-get install ninja-build
        ninja --version
        if [ "$BUILD_TARGET" == "linux" ]; then
            install_linux_environment
        fi
    fi

    if [ "$TRAVIS_OS_NAME" == "osx" ]; then
        install_latest_python
        install_python_module_for_osx
    fi

    if [ "$TRAVIS_OS_NAME" == "windows" ]; then
        install_python_module_for_windows
    fi

    # use NDK's clang to generate binding codes
    install_android_ndk
    download_deps
}


install_environement

echo "before-install.sh execution finished!"
