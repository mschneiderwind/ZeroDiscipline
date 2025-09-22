.PHONY: run clean test dmg version

# Run in debug mode
run:
	swift run

# Clean build artifacts
clean:
	swift package clean
	@rm -rf dist/

# Show next version (CalVer)
version:
	@today=$$(date +"%Y.%m.%d"); \
	existing=$$(git tag -l "$$today*" | wc -l | tr -d ' '); \
	if [ $$existing -eq 0 ]; then \
		echo "Next version: $$today"; \
	else \
		echo "Next version: $$today.$$existing"; \
	fi

# Run tests
test:
	swift test

# Create DMG for distribution
dmg:
	@echo "Building project..."
	@swift build -c release
	@echo "Creating app bundle..."
	@rm -rf dist/ZeroDiscipline.app
	@mkdir -p dist/ZeroDiscipline.app/Contents/MacOS
	@mkdir -p dist/ZeroDiscipline.app/Contents/Resources
	@cp .build/release/ZeroDiscipline dist/ZeroDiscipline.app/Contents/MacOS/
	@cp Sources/Info.plist dist/ZeroDiscipline.app/Contents/
	@chmod +x dist/ZeroDiscipline.app/Contents/MacOS/ZeroDiscipline
	@echo "Creating DMG..."
	@rm -rf dist/dmg-staging
	@mkdir -p dist/dmg-staging
	@cp -R dist/ZeroDiscipline.app dist/dmg-staging/
	@cp README.md dist/dmg-staging/
	@ln -s /Applications dist/dmg-staging/Applications
	@rm -f dist/ZeroDiscipline.dmg
	@hdiutil create -volname "Zero Discipline" \
		-srcfolder dist/dmg-staging \
		-ov -format UDZO \
		-imagekey zlib-level=9 \
		dist/ZeroDiscipline.dmg
	@echo "✅ DMG created at dist/ZeroDiscipline.dmg"

# Create GitHub release with DMG (CalVer: YYYY.MM.DD)
release: dmg
	@echo "Creating GitHub release with Calendar Versioning..."
	@today=$$(date +"%Y.%m.%d"); \
		existing=$$(git tag -l "$$today*" | wc -l | tr -d ' '); \
		if [ $$existing -eq 0 ]; then \
			version="$$today"; \
		else \
			version="$$today.$$existing"; \
		fi; \
		echo "Version will be: $$version"; \
		read -p "Enter release notes: " notes; \
		git tag $$version; \
		git push --tags; \
		gh release create $$version dist/ZeroDiscipline.dmg --title "$$version" --notes "$$notes"

help:
	@echo "Available commands:"
	@echo "  run        - Run in debug mode"
	@echo "  test       - Run tests"
	@echo "  clean      - Clean all artifacts"
	@echo "  version    - Show next CalVer version (YYYY.MM.DD)"
	@echo "  dmg        - Create DMG for distribution"
	@echo "  release    - Create GitHub release with CalVer"
