## Making Calabash Target

### Code signing

This app contains an extension.

We would like the build the .ipa from command line, but it is not
possible because `xcodebuild` does not use the code signing settings
passed from the command line.

The make `ipa-cal` rule and Scripts/make/make-ipa-cal.rb do not work.

I tried to make a new set of Info.plists and entitlements with
a new App ID and new Extension App ID - complete with profiles.  This
also did not work. :(

I also tried to change the default keychain - to force Xcode to read
the installed ~/.calabash/calabash-codesign/ios/Calabash.keychain.

```
# WARNING:  will unset and reset the default keychain.
$ Script/make/make-ipa-cal.rb # NOTE the .rb extension!
```

This also did not work.

### Linking calabash.framework

1. Created a new Configuration based on Debug
2. Copied calabash.framework to ./
3. Made the following changes to the Calabash config in Build Settings:

```
# Added calabash.framework to the Framework Search Paths
* $(PROJECT_DIR)/../calabash.framework

# Added linker flags
* -force_load $(PROJECT_DIR)/../calabash.framework/calabash
```

### Preparing

```
$ bundle
$ be pod update  # Only run if you have problems with pod install.
$ be pod install
```

### Making

The project is setup to use a Calabash configuration, rather than
a separate -cal target.

```
# Make an app and stage it to ./Calabash-app/WordPress.app
$ make app-cal
```

Making an ipa from the command line or Xcode is not possible.
