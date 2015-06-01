#!/bin/sh

arg1="$1"

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

if [ "$arg1" = "update-version" ]
then
    # Update the version number.
    commit_id=$(git log --format="%H" -n 1 | sed -r 's/^(.{10}).*$/\1/')
    epoch=$(date '+%s')
    version="${epoch}~${commit_id}"
    sed -i -r "s/^Version:.*$/Version: ${version}/" "$script_dir/se3-clients-linux/DEBIAN/control"
fi

dpkg --build "$script_dir/$pkg_name" .

# Cleaning.
rm -r "$script_dir/$pkg_name"


