.PHONY: test lint check shellcheck

SHELL := /bin/bash
BATS ?= bats

test:
	$(BATS) test/integration/*.bats test/lib-units.bats

lint shellcheck:
	shellcheck -x launchlayer lib/*.sh lib/**/*.sh scripts/*.sh test/helpers.bash

check: shellcheck test
