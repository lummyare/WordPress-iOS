#!/usr/bin/env bash

# Call this script only from the make-ipa-cal.rb script!

KEYCHAIN="${1}"
IDENTITY="${2}"

if [ -z "${KEYCHAIN}" ]; then
  echo "FAIL: Must be called from the make-ipa-cal.rb script"
  exit 1
fi

if [ -z "${IDENTITY}" ]; then
  echo "FAIL: Must be called from the make-ipa-cal.rb script"
  exit 1
fi

echo "INFO:  Signing with keychain $KEYCHAIN"
echo "INFO:  Signing with identity $IDENTITY"

PRODUCT_DIR=./Calabash-ipa
rm -rf ${PRODUCT_DIR}
mkdir -p ${PRODUCT_DIR}

WORKSPACE="WordPress.xcworkspace"
SCHEME="WordPress"
TARGET_NAME="WordPress"
CONFIG=Calabash

CAL_DISTRO_DIR="${PWD}/build"
ARCHIVE_BUNDLE="${CAL_DISTRO_DIR}/WordPress.xcarchive"
APP_BUNDLE_PATH="${ARCHIVE_BUNDLE}/Products/Applications/WordPress.app"
IPA_PATH="${CAL_DISTRO_DIR}/${TARGET_NAME}.ipa"
DSYM_PATH="${ARCHIVE_BUNDLE}/dSYMs/${TARGET_NAME}.app.dSYM"

rm -rf "${CAL_DISTRO_DIR}"
mkdir -p "${CAL_DISTRO_DIR}"

set +o errexit

# Fails because the app extension does not pick up the
# code siging details that are passed.
#
# See CALABASH_README.md for details.
xcrun xcodebuild archive \
  OTHER_CODE_SIGN_FLAGS="--keychain ${KEYCHAIN}" \
  CODE_SIGN_IDENTITY="${IDENTITY}" \
  -SYMROOT="${CAL_DISTRO_DIR}" \
  -derivedDataPath "${CAL_DISTRO_DIR}" \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIG}" \
  ARCHS="arm64 armv7 armv7s" \
  VALID_ARCHS="arm64 armv7 armv7s" \
  ONLY_ACTIVE_ARCH=NO \
  -archivePath "${ARCHIVE_BUNDLE}" \
  -sdk iphoneos

  #-sdk iphoneos | bundle exec xcpretty -c
#RETVAL=${PIPESTATUS[0]}
RETVAL=$?

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


cp "${IPA_PATH}" "${PRODUCT_PATH}"
echo "INFO: Created ${PRODUCT_PATH}/${TARGET_NAME}.ipa"

mv "${DSYM_PATH}" "${PRODUCT_PATH}"
echo "INFO: Created ${PWD}/${TARGET_NAME}.app.dSYM"
