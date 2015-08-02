#!/usr/bin/env ruby
require 'fileutils'

system('make', 'keychain')

KEYCHAIN="#{ENV['HOME']}/.calabash/calabash-codesign/ios/Calabash.keychain"
IDENTITY=`xcrun security find-identity -v -p codesigning #{KEYCHAIN} | awk 'match($0, /\"iPhone Developer: .+\"/) { print substr($0, RSTART, RLENGTH)}' | tr -d '\n'`
DEFAULT_KEYCHAIN=`xcrun security default-keychain`.strip

begin
  `xcrun security default-keychain -s #{KEYCHAIN}`
  system('Scripts/make/xcodebuild-ipa.sh', KEYCHAIN, IDENTITY)
ensure
  `xcrun security default-keychain -s #{DEFAULT_KEYCHAIN}`
end

puts DEFAULT_KEYCHAIN
