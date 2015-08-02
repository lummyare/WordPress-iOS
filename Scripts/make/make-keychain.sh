#!/usr/bin/env bash

KEYCHAIN_REPO="${HOME}/.calabash/calabash-codesign"
KEYCHAIN_CREATE="${KEYCHAIN_REPO}/ios/create-keychain.sh"
IMPORT_PROFILES="${KEYCHAIN_REPO}/ios/import-profiles.sh"
CURRENT_DIR=${PWD}

if [ ! -d "${KEYCHAIN_REPO}" ]; then
  echo "INFO: Keychain repo does not exist."
  echo "INFO: Cloning from github."
  mkdir -p "${HOME}/.riseup"
  cd "${HOME}/.riseup"
  git clone git@github.com:calabash/calabash-codesign.git
else
  echo "INFO: Keychain repo exists."
  echo "INFO: Checking for a clean repo."

  cd "${KEYCHAIN_REPO}"
  if [[ `git status --porcelain` ]]; then
    echo "FAIL: Code signing repo has uncommitted changes."
    echo "FAIL: Commit or rollback any changes and try again."
    exit 1
  else
    echo "INFO: Code sign repo is clean."
  fi

  echo "INFO: Pulling the latest changes code signing changes."
  cd "${KEYCHAIN_REPO}"
  git checkout master
  git pull
fi

cd "${PWD}"

${KEYCHAIN_CREATE}
${IMPORT_PROFILES}
