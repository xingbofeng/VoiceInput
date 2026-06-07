APP_NAME := VoiceInputApp
BUILD_DIR := .build
BUNDLE_DIR := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR := /Applications/$(APP_NAME).app
PLIST := Sources/VoiceInputApp/Resources/Info.plist
ICON := Resources/AppIcon.icns
CODE_SIGN_IDENTITY ?= -
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$(PLIST)")
DMG_NAME := VoiceInput-$(VERSION)-macOS
DMG_FILE := dist/$(DMG_NAME).dmg

ARCH_FLAGS := --arch arm64 --arch x86_64
SWIFT_BUILD_FLAGS := -c release $(ARCH_FLAGS) -Xswiftc -Osize -Xswiftc -warnings-as-errors

.PHONY: all build run install dmg release clean debug

all: build

build:
	@echo "🔨 Building $(APP_NAME)..."
	swift build $(SWIFT_BUILD_FLAGS)
	@echo "📦 Creating app bundle..."
	@rm -rf "$(BUNDLE_DIR)"
	@mkdir -p "$(BUNDLE_DIR)/Contents/MacOS"
	@mkdir -p "$(BUNDLE_DIR)/Contents/Resources"
	@BIN_DIR="$$(swift build -c release $(ARCH_FLAGS) --show-bin-path)"; \
		cp "$$BIN_DIR/$(APP_NAME)" "$(BUNDLE_DIR)/Contents/MacOS/"
	@lipo "$(BUNDLE_DIR)/Contents/MacOS/$(APP_NAME)" -verify_arch arm64 x86_64
	@cp "$(PLIST)" "$(BUNDLE_DIR)/Contents/"
	@cp "$(ICON)" "$(BUNDLE_DIR)/Contents/Resources/"
	@plutil -lint "$(BUNDLE_DIR)/Contents/Info.plist"
	@codesign --force --sign "$(CODE_SIGN_IDENTITY)" "$(BUNDLE_DIR)"
	@codesign --verify --deep --strict "$(BUNDLE_DIR)"
	@echo "✅ Build complete: $(BUNDLE_DIR)"

run: build
	@echo "🚀 Launching $(APP_NAME)..."
	@pkill -x "$(APP_NAME)" 2>/dev/null || true
	@sleep 0.3
	open "$(BUNDLE_DIR)"

install: build
	@echo "📥 Installing to $(INSTALL_DIR)..."
	@pkill -x "$(APP_NAME)" 2>/dev/null || true
	@sleep 0.3
	@rm -rf "$(INSTALL_DIR)"
	@ditto "$(BUNDLE_DIR)" "$(INSTALL_DIR)"
	@codesign --verify --deep --strict "$(INSTALL_DIR)"
	@echo "✅ Installed: $(INSTALL_DIR)"

dmg: build
	@echo "💿 Creating DMG installer..."
	@mkdir -p dist
	@rm -rf dist/staging
	@mkdir -p dist/staging
	@cp -R "$(BUNDLE_DIR)" dist/staging/
	@ln -s /Applications dist/staging/
	@rm -f "$(DMG_FILE)"
	@hdiutil create -volname "$(DMG_NAME)" \
		-srcfolder dist/staging \
		-ov -format UDZO \
		-imagekey zlib-level=9 \
		"$(DMG_FILE)" > /dev/null
	@rm -rf dist/staging
	@shasum -a 256 "$(DMG_FILE)" > "$(DMG_FILE).sha256"
	@echo "✅ DMG created: $(DMG_FILE)"

release: dmg
	@echo "📦 Release package: $(DMG_FILE)"
	@echo "📄 Checksum:   $(DMG_FILE).sha256"

clean:
	@echo "🧹 Cleaning..."
	@rm -rf "$(BUNDLE_DIR)" dist/staging
	swift package clean
	@echo "✅ Clean complete"

debug:
	swift build -c debug -Xswiftc -warnings-as-errors
