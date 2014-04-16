PROJECT='TravisCITestFlight/TravisCITestFlight.xcodeproj'
SCHEME='TravisCITestFlight'
SDK='iphoneos'
CONFIGURATION='AdHoc'
CONFIGURATION_BUILD_DIR='./out'
TEST_SDK='iphonesimulator'
CONFIGURATION_DEBUG='Debug'
DESTINATION='platform=iOS Simulator,name=iPhone Retina (4-inch),OS=7.0'
CONFIGURATION_TEMP_DIR=$(CONFIGURATION_BUILD_DIR)/tmp
PROVISIONING_PROFILE='hogehoge.mobileprovision'
APP_NAME=$(PWD)/$(SCHEME)/out/$(SCHEME).app
IPA_NAME=$(PWD)/$(SCHEME)/out/$(SCHEME).ipa
DSYM=$(PWD)/$(SCHEME)/out/$(SCHEME).app.dSYM
DSYM_ZIP=$(PWD)/$(SCHEME)/out/$(SCHEME).dSYM.zip

# test - clean, build, XCTest を実行する
test:
	xcodebuild \
			-project $(PROJECT) \
			-scheme $(SCHEME) \
			-sdk $(TEST_SDK) \
			-configuration $(CONFIGURATION_DEBUG) \
			-destination $(DESTINATION) \
			clean build test

# build - AdHoc ビルドをおこなう
build: add-certificates
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIGURATION) \
		CODE_SIGN_IDENTITY=$(SIGN) CONFIGURATION_TEMP_DIR=$(CONFIGURATION_TEMP_DIR) CONFIGURATION_BUILD_DIR=$(CONFIGURATION_BUILD_DIR) \
		clean build

# archive - IPA ファイルを生成する
archive: build
	xcrun \
		-sdk $(SDK) \
		PackageApplication $(APP_NAME) \
		-o $(IPA_NAME) \
		-embed ~/Library/MobileDevice/Provisioning\ Profiles/$(PROVISIONING_PROFILE)

# zip-dsym - DSYM.zip ファイルを作成する
zip-dsym: build
	zip -r $(DSYM_ZIP) $(DSYM)

# testflight - IAP ファイルと DSYM ファイルを TestFlight へアップロードする
testflight: archive zip-dsym
	curl 'http://testflightapp.com/api/builds.json' \
		-F 'file=@$(IPA_NAME)' \
		-F 'dsym=@$(DSYM_ZIP)' \
		-F 'api_token=$(TF_APITOKEN)' \
		-F 'team_token=$(TF_TEAMTOKEN)' \
		-F 'notes=This build was uploaded via the upload API on the Travis CI' \
		-v

# add-certificates - KeyChain を作成する
add-certificates: decrypt-certificates
	security create-keychain -p travis ios-build.keychain
	security import ./scripts/certs/apple.cer -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign
	security import ./scripts/certs/dist.cer -k ~/Library/Keychains/ios-build.keychain -T /usr/bin/codesign
	security import ./scripts/certs/dist.p12 -k ~/Library/Keychains/ios-build.keychain -P $(ENCRYPTION_SECRET) -T /usr/bin/codesign
	mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles
	cp ./scripts/profile/$(PROVISIONING_PROFILE) ~/Library/MobileDevice/Provisioning\ Profiles/

# decrypt_certificates - 暗号化されたファイルを復号化する
decrypt-certificates:
	openssl aes-256-cbc -k "$(ENCRYPTION_SECRET)" -in scripts/profile/$(PROVISIONING_PROFILE).enc -d -a -out scripts/profile/$(PROVISIONING_PROFILE)
	openssl aes-256-cbc -k "$(ENCRYPTION_SECRET)" -in scripts/certs/dist.p12.enc -d -a -out scripts/certs/dist.p12
	openssl aes-256-cbc -k "$(ENCRYPTION_SECRET)" -in scripts/certs/dist.p12.enc -d -a -out scripts/certs/dist.p12

# remove-certificates - KeyChain を削除する
remove-certificates:
	security delete-keychain ios-build.keychain
	rm -f ~/Library/MobileDevice/Provisioning\ Profiles/$(PROVISIONING_PROFILE)