#!/bin/bash
# -*- coding: utf-8 -*-

# gets the package name and version from the plugin file
plugin_json=$(cat plugin.json)
name_re='\"name\": \"(\w*)\"'
[[ "$plugin_json" =~ $name_re ]]
name=${BASH_REMATCH[1]}
version_re='\"version\": \"([0-9]\.[0-9]\.[0-9])\"'
[[ "$plugin_json" =~ $version_re ]]
version=${BASH_REMATCH[1]}
echo "[INFO] Automating release of $name@$version"

# builds the release bundle
echo "[INFO] Building release bundle"
npm install
npm run build-cdn

# installs the GitHub CLI tool
gh_version="2.14.7"
echo "[INFO] Installing GitHubCLI@$gh_version"
curl -LGO "https://github.com/cli/cli/releases/download/v${gh_version}/gh_${gh_version}_linux_amd64.tar.gz" -o gh_${gh_version}_linux_amd64.tar.gz
tar xf gh_${gh_version}_linux_amd64.tar.gz

# logs in using the GitHub CLI tool and sets git credentials
echo "[INFO] Logging in GitHub CLI tool and setting Git credentials"
echo $GH_TOKEN | gh_${gh_version}_linux_amd64/bin/gh auth login --with-token
git config --global user.email "ripe-bot@platforme.com"
git config --global user.name "ripe-bot"

# clones RIPE Static
echo "[INFO] Cloning RIPE Static"
git clone https://ripe-bot:$GH_TOKEN@github.com/ripe-tech/ripe-static
cd ripe-static

# creates the release branch, deleting an already existing
# branch with the same name (hence this name should be specific)
branch="ripe-bot/${name}-${version}"
echo "[INFO] Creating release branch '$branch'"
if git rev-parse --quiet --verify $branch /dev/null; then
    echo "[INFO] Branch '$branch' already exists. Deleting it and creating a new one."
    git branch -D $branch
    git push origin --delete $branch
fi
git checkout -b $branch

# copies the expected release contents to the target
# destination in RIPE Static
echo "[INFO] Copying release contents to RIPE Static"
mkdir -p ripe/ripe_commons/plugins/$name/$version
cp -r ../dist/assets ripe/ripe_commons/plugins/$name/$version
cp ../dist/bundle.js ripe/ripe_commons/plugins/$name/$version
cp ../plugin.json ripe/ripe_commons/plugins/$name/$version
rm -rf ripe/ripe_commons/plugins/$name/latest
cp -r ../dist/assets ripe/ripe_commons/plugins/$name/latest
cp ../dist/bundle.js ripe/ripe_commons/plugins/$name/latest
cp ../plugin.json ripe/ripe_commons/plugins/$name/latest

# pushes the release files to the created branch
echo "[INFO] Pushing changes to '$branch'"
git add .
git commit -m "version: $name@$version"
git push -u origin $branch

# creates the release pull request
title="version: $name@$version"
body="version: $name@$version"
assignee="ripe-bot"
echo "[INFO] Creating pull request '$title' for branch '$branch' authored by $assignee"
../gh_${gh_version}_linux_amd64/bin/gh pr create --assignee $assignee --title "$title" --body "$body" --label "no-changelog" --label "release 🎉"
