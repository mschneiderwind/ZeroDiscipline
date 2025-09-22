.PHONY: build run clean test

# Build the Swift app
build:
	swift build -c release

# Run the app in debug mode
run:
	swift run

# Run the app in release mode
run-release:
	swift run -c release

# Clean build artifacts
clean:
	swift package clean

# Run tests
test:
	swift test

# Build and install in /usr/local/bin (requires sudo)
install: build
	sudo cp .build/release/ZeroDisciplineSwift /usr/local/bin/zero-discipline-swift

# Create a simple app bundle (for development)
app-bundle: build
	mkdir -p ZeroDiscipline.app/Contents/MacOS
	mkdir -p ZeroDiscipline.app/Contents/Resources
	cp .build/release/ZeroDisciplineSwift ZeroDiscipline.app/Contents/MacOS/
	cp Sources/ZeroDisciplineSwift/Info.plist ZeroDiscipline.app/Contents/
	
# Open the app bundle
open-app: app-bundle
	open ZeroDiscipline.app

# Build for distribution (optimized)
release: clean
	swift build -c release --arch arm64 --arch x86_64

help:
	@echo "Available targets:"
	@echo "  build       - Build the project"
	@echo "  run         - Run the project in debug mode" 
	@echo "  run-release - Run the project in release mode"
	@echo "  clean       - Clean build artifacts"
	@echo "  test        - Run tests"
	@echo "  install     - Install to /usr/local/bin (requires sudo)"
	@echo "  app-bundle  - Create a basic .app bundle"
	@echo "  open-app    - Create and open the .app bundle"
	@echo "  release     - Build optimized universal binary"