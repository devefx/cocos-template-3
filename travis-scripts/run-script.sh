#!/bin/bash

# exit this script if any commmand fails
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$DIR"/..
COCOS2DX_ROOT="$PROJECT_ROOT"/frameworks/cocos2d-x
CPU_CORES=4

function do_retry()
{
    cmd=$@
    retry_times=5
    retry_wait=3
    c=0
    while [ $c -lt $((retry_times+1)) ]; do
        c=$((c+1))
        echo "Executing \"$cmd\", try $c"
        $cmd && return $?
        if [ ! $c -eq $retry_times ]; then
            echo "Command failed, will retry in $retry_wait secs"
            sleep $retry_wait
        else
            echo "Command failed, giving up."
            return 1
        fi
    done
}

function build_linux()
{
    CPU_CORES=`grep -c ^processor /proc/cpuinfo`
    echo "Building Linux ..."
    cd $PROJECT_ROOT
    mkdir -p linux-build
    cd linux-build
    cmake ..
    echo "cpu cores: ${CPU_CORES}"
    make -j${CPU_CORES} VERBOSE=1
}

function build_mac_cmake()
{
    NUM_OF_CORES=`getconf _NPROCESSORS_ONLN`
    echo "Building Mac ..."
    cd $PROJECT_ROOT
    mkdir -p mac_cmake_build
    cd mac_cmake_build
    cmake .. -GXcode
    # cmake --build .
    xcodebuild -project cocos-template-3.xcodeproj -alltargets -jobs $NUM_OF_CORES build  | xcpretty
    #the following commands must not be removed
    xcodebuild -project cocos-template-3.xcodeproj -alltargets -jobs $NUM_OF_CORES build
    exit 0
}

function build_android_cmake()
{
    # Build all samples
    echo "Building Android ..."
    source frameworks/environment.sh

    # build project
    pushd $PROJECT_ROOT/frameworks/runtime-src/proj.android
    do_retry ./gradlew assembleRelease -PPROP_BUILD_TYPE=cmake --parallel --info
    popd
}

function genernate_binding_codes()
{
    if [ $TRAVIS_OS_NAME == "linux" ]; then
        # print some log for libstdc++6
        strings /usr/lib/x86_64-linux-gnu/libstdc++.so.6 | grep GLIBC
        ls -l /usr/lib/x86_64-linux-gnu/libstdc++*
        dpkg-query -W libstdc++6
        ldd $COCOS2DX_ROOT/tools/bindings-generator/libclang/libclang.so
    fi

    if [ "$TRAVIS_OS_NAME" == "osx" ]; then
        eval "$(pyenv init -)"
    fi
    which python

    source frameworks/environment.sh

    # Generate binding glue codes

    echo "Create auto-generated luabinding glue codes."
    pushd "$COCOS2DX_ROOT/tools/tolua"
    python ./genbindings.py
    popd
}

function run()
{
    echo "Building ..."

    # export cocos console root
    export COCOS_CONSOLE_ROOT=$COCOS2DX_ROOT/tools/cocos2d-console/bin
    echo "export COCOS_CONSOLE_ROOT=${COCOS_CONSOLE_ROOT}" > environment.sh
    source environment.sh

    # disagreeing 
    ${COCOS_CONSOLE_ROOT}/cocos -v --agreement n
    
    # need to generate binding codes for all targets
    genernate_binding_codes

    # linux
    if [ $BUILD_TARGET == 'linux' ]; then
        build_linux
    fi

    # android
    if [ $BUILD_TARGET == 'android_cmake' ]; then
        build_android_cmake
    fi
}

run
