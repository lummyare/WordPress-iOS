all:
	$(MAKE) ipa-cal
	$(MAKE) app-cal

clean:
	rm -rf build
	rm -rf cal-ipa
	rm -rf cal-app

# Builds an ipa with Calabash linked.
ipa-cal:
	rm -rf cal-ipa
	mkdir cal-ipa
	Scripts/make/make-ipa-cal.sh

# Builds an app with Calabash linked.
app-cal:
	rm -rf cal-app
	mkdir cal-app
	Scripts/make/make-app-cal.sh

# Makes a code signing keychain for Calabash targets
keychain:
	Scripts/make/make-keychain.sh
