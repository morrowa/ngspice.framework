#!/bin/bash

# ain't perfect but it's the best we got
set -euo pipefail

PROJECT_DIR=$(pwd)

ARCHIVE_NAME=ngspice-35.tar.gz
EXPECTED_SHA1=61a39d0aa75f43a2325d444f7d837c978053ec39 

mkdir -p download_cache
if [[ -f download_cache/$ARCHIVE_NAME ]]; then
	echo "using cached ngspice source"
else
	echo "downloading ngspice source..."
	curl -fsSL -o download_cache/$ARCHIVE_NAME 'https://sourceforge.net/projects/ngspice/files/ng-spice-rework/35/ngspice-35.tar.gz/download'
	echo "done!"
fi

DOWNLOAD_SHA=$(openssl dgst -sha1 download_cache/$ARCHIVE_NAME)
if [[ ${DOWNLOAD_SHA:(-40)} != $EXPECTED_SHA1 ]]; then
	echo "mismatched sha! aborting"
	exit 1
fi

rm -rf build
mkdir -p build

tar -C build -xf download_cache/$ARCHIVE_NAME

pushd build/ngspice-35

# we must use homebrew's bison because macOS's bison is too old. build time only.
export PATH="$(brew --prefix bison)/bin:$PATH"

./configure --prefix=/build/install_root --without-readline --without-editline --without-fftw3 --with-ngshared --disable-dependency-tracking --disable-debug CFLAGS="-O2" CXXFLAGS="-O2"

make -j3 install DESTDIR=$PROJECT_DIR

popd

rm -rf product
mkdir -p product/ngspice.framework/Versions/A
pushd product/ngspice.framework/Versions/A
cp $PROJECT_DIR/build/install_root/lib/libngspice.0.dylib ngspice
install_name_tool -id '@rpath/ngspice.framework/Versions/A/ngspice' ngspice
mkdir Resources Headers Modules
cp $PROJECT_DIR/build/install_root/include/ngspice/sharedspice.h Headers/
cp $PROJECT_DIR/ngspice.h Headers/
cp $PROJECT_DIR/module.modulemap Modules/
# TODO: regenerate on the host machine
cp $PROJECT_DIR/Info.plist Resources/
cd ..
ln -s A Current
cd ..
ln -s Versions/Current/Resources Resources
ln -s Versions/Current/Headers Headers
ln -s Versions/Current/Modules Modules
ln -s Versions/Current/ngspice ngspice
cd ..
zip -yr ngspice.framework.zip ngspice.framework
popd

echo "Done!"

