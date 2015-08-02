#!/usr/bin/env bash

bundle

make keychain
KEYCHAIN="${HOME}/.calabash/calabash-codesign/ios/Calabash.keychain"
IDENTITY=`xcrun security find-identity -v -p codesigning ${KEYCHAIN} | awk 'match($0, /\"iPhone Developer: .+\"/) { print substr($0, RSTART, RLENGTH)}' | tr -d '\n'`

WORKSPACE="WordPress.xcworkspace"
SCHEME="WordPress"
TARGET_NAME="WordPress"
CONFIG=Calabash

CAL_BUILD_DIR="${PWD}/build"

rm -rf "${CAL_BUILD_DIR}"
mkdir -p "${CAL_BUILD_DIR}"

PRODUCT_DIR=./Calabash-app
rm -rf ${PRODUCT_DIR}
mkdir -p ${PRODUCT_DIR}

set +o errexit

xcrun xcodebuild \
  CODE_SIGN_IDENTITY="${IDENTITY}" \
  OTHER_CODE_SIGN_FLAGS="--keychain ${KEYCHAIN}" \
  -SYMROOT="${CAL_BUILD_DIR}" \
  -derivedDataPath "${CAL_BUILD_DIR}" \
  -workspace "${WORKSPACE}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIG}" \
  ARCHS="i386 x86_64" \
  VALID_ARCHS="i386 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  -sdk iphonesimulator \
  clean build | xcpretty -c

RETVAL=${PIPESTATUS[0]}

set -o errexit

if [ $RETVAL != 0 ]; then
  echo "FAIL:  could not build"
  exit $RETVAL
else
  echo "INFO: successfully built"
fi

APP_BUNDLE_PATH="${CAL_BUILD_DIR}/Build/Products/${CONFIG}-iphonesimulator/${TARGET_NAME}.app"
mv "${APP_BUNDLE_PATH}" "${PRODUCT_DIR}"
echo "INFO: Created ${PRODUCT_DIR}/${TARGET_NAME}.app"

DYSM_PATH="${CAL_BUILD_DIR}/Build/Products/${CONFIG}-iphonesimulator/${TARGET_NAME}.app.dSYM"
mv "${DYSM_PATH}" "${PRODUCT_DIR}"
echo "INFO: Created ${PRODUCT_DIR}/${TARGET_NAME}.app.dSYM"
