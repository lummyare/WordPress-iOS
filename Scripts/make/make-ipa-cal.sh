#!/usr/bin/env bash

bundle

make keychain

KEYCHAIN="${HOME}/.calabash/calabash-codesign/ios/Calabash.keychain"

#xcrun security \
#  find-identity \
#  -v -p codesigning \
#  "${PWD}/Calabash.keychain" | \
#  awk 'match($0, /\"iPhone Developer: .+\"/) { print substr($0, RSTART, RLENGTH)}' \
#  | tr -d '\n'



CODE_SIGN_IDENTITY=`xcrun security find-identity -v -p codesigning ${KEYCHAIN} | awk 'match($0, /\"iPhone Developer: .+\"/) { print substr($0, RSTART, RLENGTH)}' | tr -d '\n'`

WORKSPACE="WordPress.xcworkspace"
SCHEME="WordPress"
TARGET_NAME="WordPress"

CAL_DISTRO_DIR="${PWD}/build"
ARCHIVE_BUNDLE="${CAL_DISTRO_DIR}/WordPress.xcarchive"
APP_BUNDLE_PATH="${ARCHIVE_BUNDLE}/Products/Applications/WordPress.app"
IPA_PATH="${CAL_DISTRO_DIR}/${TARGET_NAME}.ipa"
DSYM_PATH="${ARCHIVE_BUNDLE}/dSYMs/${TARGET_NAME}.app.dSYM"
CONFIG=Debug

rm -rf "${CAL_DISTRO_DIR}"
mkdir -p "${CAL_DISTRO_DIR}"

set +o errexit

xcrun xcodebuild archive \
  CODE_SIGN_IDENTITY="${RISEUP_SIGNING_IDENTITY}" \
  OTHER_CODE_SIGN_FLAGS="--keychain ${KEYCHAIN}" \
  -SYMROOT="${CAL_DISTRO_DIR}" \
  -derivedDataPath "${CAL_DISTRO_DIR}" \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIG}" \
  ARCHS="arm64 armv7 armv7s" \
  VALID_ARCHS="arm64 armv7 armv7s" \
  ONLY_ACTIVE_ARCH=NO \
  -archivePath "${ARCHIVE_BUNDLE}" \
  -sdk iphoneos | xcpretty -c

RETVAL=${PIPESTATUS[0]}

set -o errexit

if [ $RETVAL != 0 ]; then
  echo "FAIL:  archive failed"
  exit $RETVAL
fi

set +o errexit

echo "INFO: Packaging the .ipa"

TMP_DIR=./tmp/packaging
PAYLOAD_DIR="${TMP_DIR}/Payload"

rm -rf ${TMP_DIR}
mkdir -p "${PAYLOAD_DIR}"

cp -Rp "${APP_BUNDLE_PATH}" "${PAYLOAD_DIR}/${TARGET_NAME}.app"
CURRENT_DIR="${PWD}"

cd "${TMP_DIR}"

xcrun zip \
  --symlinks \
  --recurse-paths \
  --quiet \
  ${IPA_PATH} \
  Payload

cd "${CURRENT_DIR}"

PRODUCT_DIR=./ipa-cal

mkdir -p ${PRODUCT_PATH}

cp "${IPA_PATH}" "${PRODUCT_PATH}"
echo "INFO: Created ${PRODUCT_PATH}/${TARGET_NAME}.ipa"

mv "${DSYM_PATH}" "${PRODUCT_PATH}"
echo "INFO: Created ${PWD}/${TARGET_NAME}.app.dSYM"
