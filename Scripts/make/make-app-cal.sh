#!/usr/bin/env bash

bundle

FIRST_ARG="${1}"

if [ "${FIRST_ARG}" = "calabash" ]; then
  TARGET_NAME="RiseUp-cal"
else
  TARGET_NAME="RiseUp"
fi

XC_PROJECT="RiseUp.xcodeproj"
XC_SCHEME="${TARGET_NAME}"
CAL_BUILD_CONFIG="Debug"

CAL_BUILD_DIR="${PWD}/build/simulator"
rm -rf "${CAL_BUILD_DIR}"
mkdir -p "${CAL_BUILD_DIR}"

set +o errexit

xcrun xcodebuild \
  -SYMROOT="${CAL_BUILD_DIR}" \
  -derivedDataPath "${CAL_BUILD_DIR}" \
  ARCHS="i386 x86_64" \
  VALID_ARCHS="i386 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  -project "${XC_PROJECT}" \
  -scheme "${TARGET_NAME}" \
  -sdk iphonesimulator \
  -configuration "${CAL_BUILD_CONFIG}" \
  clean build | xcpretty -c

RETVAL=${PIPESTATUS[0]}

set -o errexit

if [ $RETVAL != 0 ]; then
  echo "FAIL:  could not build"
  exit $RETVAL
else
  echo "INFO: successfully built"
fi

rm -rf "${PWD}/${TARGET_NAME}.app"

APP_BUNDLE_PATH="${CAL_BUILD_DIR}/Build/Products/${CAL_BUILD_CONFIG}-iphonesimulator/${TARGET_NAME}.app"
cp -r "${APP_BUNDLE_PATH}" "${PWD}"

echo "INFO: Created ${TARGET_NAME}.app"

echo "INFO: Cleaning stale targets"
bundle exec run-loop simctl install --app "${PWD}/${TARGET_NAME}.app" --debug

