#!/bin/bash

pkggit="62e175ef9fae75335575964c845a302447c012c7"
appid="$1"
appdir="$HOME/.var/app/$appid"

if [ -z "$appid" ]; then
    echo "Please provide a Flatpak application ID"
    exit -1
fi

flatpak info $appid > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Invalid Flatpak application ID"
    exit -1
fi

ldpath="$(flatpak override --show $appid | grep LD_LIBRARY_PATH | sed 's/LD_LIBRARY_PATH=//g'):$(flatpak override --user --show $appid | grep LD_LIBRARY_PATH | sed 's/LD_LIBRARY_PATH=//g')"

echo "Preparing workspace..."
cwd="$(pwd)"
cd "$appdir"
rm -rf ./tmp
mkdir tmp && cd tmp
for patch in "$cwd/00"*.patch; do cp "$patch" . ; done
cwd="$(pwd)"

echo "Downloading ECM source..."
git clone "https://github.com/KDE/extra-cmake-modules.git"

echo "Installing ECM..."
cd extra-cmake-modules
mkdir install
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX="../install" && make install

echo "Downloading libdecor source"
cd "$cwd"
git clone --depth 1 "https://gitlab.gnome.org/jadahl/libdecor.git" --branch 0.1.0

echo "Building libdecor..."
cd libdecor
mkdir -p "$appdir/usr"
flatpak run --command=sh --devel $appid -c "meson build --buildtype release -Ddemo=false -Ddbus=disabled -Dprefix=\"$appdir/usr\""
flatpak run --command=sh --devel $appid -c "ninja -C build"
flatpak run --command=sh --devel $appid -c "meson install -C build"

echo "Downloading GLFW source..."
cd "$cwd"
wget -O glfw.tar.gz "https://github.com/glfw/glfw/archive/$pkggit.tar.gz"

echo "Uncompressing GLFW source..."
tar xf glfw.tar.gz
mv "glfw-$pkggit" "glfw"

echo "Patching GLFW source..."
cd glfw
for patch in "$cwd/00"*.patch; do patch -p1 < "$patch"; done

echo "Building GLFW..."
mkdir build && cd build
flatpak run --command=sh --devel $appid -c "ECM_DIR=\"$cwd/extra-cmake-modules/install/share/ECM\" PKG_CONFIG_PATH=\"$appdir/usr/lib/pkgconfig\" cmake .. -DCMAKE_INSTALL_PREFIX=\"$appdir/usr\" -DCMAKE_INSTALL_LIBDIR=lib -DBUILD_SHARED_LIBS=ON -DGLFW_BUILD_WAYLAND=ON -DGLFW_USE_LIBDECOR=ON && make install"
flatpak override --user --env=LD_LIBRARY_PATH="$appdir/usr/lib:$ldpath" $appid

echo "Done!"
cd $appdir
