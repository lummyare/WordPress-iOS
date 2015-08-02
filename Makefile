all:
	$(MAKE) ipa-cal
	$(MAKE) app-cal

clean:
	rm -rf build
	rm -rf Calabash-ipa
	rm -rf Calabash-app

# Builds an ipa with Calabash linked.
# Not working - codesigning the extention fails.
ipa-cal:
	rm -rf Calabash-ipa
	Scripts/make/make-ipa-cal.sh

# Builds an app with Calabash linked.
app-cal:
	rm -rf Calabash-app
	Scripts/make/make-app-cal.sh

# Makes a code signing keychain for Calabash targets.
keychain:
	Scripts/make/make-keychain.sh
