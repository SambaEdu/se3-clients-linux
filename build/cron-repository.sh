#!/bin/sh

exec >"$HOME/cron-repository.log" 2>&1
date # To have the date in the log.
set -x
git_dir="$HOME/se3-clients-linux"
reprepro_dir="$HOME/repository"
codename='se3-clients-linux'

cd "$git_dir" || {

    echo "\`$git_dir\` directory does not exist. End of the script."
    exit 1
}

# Update the git repository.
timeout --kill-after=10s 10s git pull || {

    echo "Impossible to update the git repository. End of the script."
    exit 1

}

# Get the list of the remote branches.
branches=$(git branch --no-color -r --no-abbrev | awk '{print $1}' \
    | grep '^origin' | cut -d'/' -f2 | grep -v '^HEAD$')

# Just to have spaces instead of \n.
# branches == "branch1 branch2 branch3..."
branches=$(echo $branches)


test -e "$reprepro_dir/conf/distributions" || {

    echo "The file \`$reprepro_dir/conf/distributions\` does not exist. End of the script."
    exit 1

}

# Update the configuration of reprepro.
cat >"$reprepro_dir/conf/distributions" <<EOF
Origin: Francois Lafont
Label: Francois Lafont
Suite: stable
Codename: $codename
Version: all
Architectures: i386 amd64
Components: $branches
Description: Repository to test se3-clients-linux directly form git
EOF

sleep 1

# Remove packages and components from branches which does not exist anymore.
reprepro --delete --verbose --basedir "$reprepro_dir" clearvanished


for branch in $branches
do
    git checkout "$branch" || {

        echo "Impossible to toggle onto $branch branch. End of the script."
        exit 1

    }

    timeout --kill-after=10s 10s git pull || {

        echo "Impossible to update the git repository. End of the script."
        exit 1

    }

    # The last commit id (just the last 10 characters).
    commit_id=$(git log --format="%H" -n 1 | sed -r 's/^(.{10}).*$/\1/')

    if reprepro --verbose --basedir "$reprepro_dir" list "$codename" \
        | grep -E "${codename}\|${branch}\|" | grep "~${commit_id}$"
    then
        echo "The commit-id==${commit_id} version is already packaged in the branch ${branch}."
    else
        echo "The commit-id==${commit_id} version is not yet packaged in the branch ${branch}."
        # Build the new version of the package.
        "$git_dir/build/build.sh"
        # Add the package in reprepro.
        reprepro --verbose --basedir "$reprepro_dir" --component="${branch}" includedeb "$codename" "$git_dir/build/se3-clients-linux"*".deb"
    fi

done


