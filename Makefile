APP_NAME := Detour
BUILD_DIR := .build/release
APP_BUNDLE := build/$(APP_NAME).app
BINARY := $(BUILD_DIR)/$(APP_NAME)

.PHONY: all build bundle install run clean

all: bundle

build:
	swift build -c release

bundle: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp $(BINARY) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Support/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	codesign --force --sign - $(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE)"

install: bundle
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(APP_BUNDLE) /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app — launch it once to get started."

run: bundle
	open $(APP_BUNDLE)

clean:
	rm -rf .build build
