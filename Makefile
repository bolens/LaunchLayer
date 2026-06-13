.PHONY: test lint check shellcheck check-hub-git tui-screenshots

SHELL := /bin/bash
BATS ?= bats

test:
	$(BATS) test/integration/*.bats test/unit/*.bats

test-hub:
	cd hub && pnpm test

test-all: test test-hub

lint shellcheck:
	shellcheck -x -P lib -a --severity=warning launchlayer test/helpers.bash scripts/*.sh

check-hub-git:
	bash scripts/check-staged-hub-secrets.sh

check: shellcheck check-hub-git test

tui-screenshots:
	bash scripts/tui-screenshots/regenerate.sh
