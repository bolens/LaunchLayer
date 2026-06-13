.PHONY: test lint check shellcheck check-hub-git

SHELL := /bin/bash
BATS ?= bats

test:
	$(BATS) test/integration/*.bats test/unit/*.bats
	cd hub && pnpm test

lint shellcheck:
	shellcheck -x -P lib --severity=warning launchlayer lib/*.sh lib/**/*.sh scripts/*.sh test/helpers.bash

check-hub-git:
	bash scripts/check-staged-hub-secrets.sh

check: shellcheck check-hub-git test
