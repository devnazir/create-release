#!/bin/bash

show_menu() {
  echo -e "
    ==============================\n
    Welcome to the release manager! 🚀\n
    ==============================\n
    Please select an option:\n  
    1) Create a new release from the master branch
    2) Create a new release from the latest release
    3) Deploy a release (Coming soon)
    4) Exit
  "
  read -p "Enter your choice: " choice
}

install_gh() {
    echo "Installing gh..."

    # architecture
    local arch=$(uname -m)

    case "$OSTYPE" in
        darwin*)  os="macOS";;
        msys*)    os="windows";;
        *)        
            echo "Currently only support macOS and Windows"
            exit
            ;;
    esac

    case $arch in
        x86_64) arch="amd64";;
        aarch64|arm64) arch="arm64";;
        *)  
            echo "Unsupported architecture: $arch"
            exit
        ;;
    esac

    # download latest gh
    curl -s https://api.github.com/repos/cli/cli/releases/latest \
        | grep "browser_download_url.*gh_" \
        | cut -d: -f 2,3 \
        | tr -d \" | tr -d ' '  \
        | grep $os \
        | grep $arch \
        | xargs -I {} curl -O -L {}

    # unzip zip file
    unzip gh_*_$os_$arch.zip

    # move gh to /usr/local/bin
    mv gh_*_$os_$arch/bin/gh /usr/local/bin

    # remove downloaded files
    rm -rf gh_*_$os_$arch.zip gh_*_$os_$arch

    echo -e "\e[1;32mgh installed successfully\e[0m"
}

is_valid_version() {
    local version=$1
    local fixed_version_regex="^[0-9]+\.[0-9]+\.[0-9]+$";
    local incremental_version_regex="major|minor|patch";

    local regex="^($fixed_version_regex|$incremental_version_regex)$"

    if [[ $1 =~ $regex ]]; then
        return 0
    else
        return 1
    fi
}

create_release() {
    local version=$1
    local branch=$2

    if ! is_valid_version $version; then
        echo "Invalid version: $version, please provide a valid version (major|minor|patch|x.x.x)"
        exit 1
    fi

    # check if gh is installed
    if ! command -v gh &> /dev/null; then
        install_gh
    fi

    yarn config set version-git-message "Bump version to v%s"
    yarn version --new-version $version

    git push --follow-tags

    new_version=$(git describe --tags --abbrev=0)
    echo "Creating a new release $new_version from $branch branch..."
    gh release create $new_version --generate-notes --verify-tag --draft --target $branch
}

show_menu;

while ! [[ "$choice" =~ ^[1-4]+$ ]]; do
  echo "Invalid selection. Please try again."
  show_menu;
done



case $choice in
  # create a new release from the master branch
  1)
    read -p "Enter the new version: " version

    # if current branch is not master, checkout to master
    if [[ $(git branch --show-current) != "master" ]]; then
        echo "Switching to master branch..."
        git checkout master
    fi

    create_release $version "master"
    ;;
  # create a new release from the latest release
  2)
    read -p "Enter the new version: " version
    latest_version=$(git describe --tags --abbrev=0)

    # checkout to the latest release
    echo "Switching to the latest release..."
    git checkout $latest_version

    # create branch from the latest release
    read -p "Branch name for the new release: " branch_name
    git checkout -b $branch_name

    # ask wanna cherry-pick commits to the new release
    read -p "Do you want to cherry-pick commits to the new release? (y/n): " cherry_pick

    if [[ $cherry_pick == "y" ]]; then
        continue_cherry_pick="y"

        while [[ $continue_cherry_pick == "y" ]]; do
            read -p "Enter the merge commit hash: " commit_hash
            git cherry-pick -m 1 $commit_hash

            read -p "Do you want to cherry-pick more commits? (y/n): " continue_cherry_pick
        done

        git push -u origin $branch_name
        create_release $version $branch_name
    fi

    ;;
  3)
    echo "Coming soon..."
    ;;
  4)
    echo "Exiting..."
    exit 0
    ;;
esac
 
