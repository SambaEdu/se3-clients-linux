#!/bin/sh

script_dir=$(cd $(dirname "$0"); pwd)
pkg_name="se3-clients-linux"

cd "$script_dir" || {
    echo "Error, impossible to change directory to $script_dir."
    echo "End of the script."
    exit 1
}

# Remove old *.deb files.
rm -rf "$script_dir/"*.deb

cp -ra "$script_dir/../src" "$script_dir/$pkg_name"
dpkg --build "$script_dir/$pkg_name" .

# Cleaning.
rm -r "$script_dir/$pkg_name"

