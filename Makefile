.PHONY: build run test clean release

# Build the .app bundle into build/
build:
	./build.sh

# Build and launch the app
run: build
	open "build/OpenCode Credit.app"

# Compile and run the unit tests for the core logic
test:
	./scripts/run-tests.sh

# Remove all build artifacts
clean:
	rm -rf build dist

# Build a distributable zip (used by the release workflow)
release:
	./scripts/package.sh
