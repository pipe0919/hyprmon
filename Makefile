.PHONY: build test install uninstall clean run

build:
	./build.sh

test:
	swift test

run: build
	open ./build/Hyprmon.app

install: build
	rm -rf /Applications/Hyprmon.app
	cp -R ./build/Hyprmon.app /Applications/
	@echo "Installed to /Applications/Hyprmon.app"
	@echo "Run 'hyprmon --install-agent' to start at login (or open the app manually)."

uninstall:
	rm -rf /Applications/Hyprmon.app
	./build/Hyprmon.app/Contents/MacOS/hyprmon --uninstall-agent 2>/dev/null || true
	@echo "Removed /Applications/Hyprmon.app"

clean:
	rm -rf .build build
