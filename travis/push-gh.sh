#!/bin/sh

setup_git() {
  git config --global user.email "git@github.com"
  git config --global user.name "Github Actions CI"
}

commit_website_files() {
  echo "Commiting files..."
  git add .
  git commit --message "Github Actions build"
}

upload_files() {
  echo "Uploading files..."
  git fetch
  git pull --rebase https://${GH_TOKEN}@github.com/elray1/Flusight-viz.git
  git push https://${GH_TOKEN}@github.com/elray1/Flusight-viz.git HEAD:main
  echo "pushed to github"
}

setup_git
commit_website_files
upload_files
