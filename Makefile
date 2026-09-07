.PHONY: build test run-mock run-detector run-tap clean

build:
	swift build

test:
	swift test

run-mock:
	SOUNDBAR_ENGINE=mock swift run Soundbar

run-detector:
	SOUNDBAR_ENGINE=detector swift run Soundbar

run-tap:
	SOUNDBAR_ENGINE=tap swift run Soundbar

clean:
	rm -rf .build
