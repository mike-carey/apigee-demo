#!/usr/bin/env make

SRC = src
BIN = bin

.PHONY: *

env: .envrc
	@hash direnv >/dev/null || (echo "[ERROR] Please install the direnv cli: \`brew install direnv\`" >&2 && exit 1)
	direnv allow

.envrc:
	cp .envrc.example .envrc

install:
	@hash npm >/dev/null || (echo "[ERROR] Please install the npm cli: \`brew install npm\`" >&2 && exit 1)
	npm install

mock:
	deploy-proxy $(SRC)/mock

oauth:
	deploy-shared-flow $(SRC)/oauth

#
