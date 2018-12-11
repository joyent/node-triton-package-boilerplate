#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2018, Joyent, Inc.
#


#
# Tools
#

TAP := ./node_modules/.bin/tap

#
# Files
#

JS_FILES := $(shell find lib -name '*.js')
ESLINT_FILES := $(JS_FILES)

# BOILERPLATE: We use (manual) copies of Makefile includes from joyent/eng.git.
ifeq ($(shell uname -s),SunOS)
	NODE_PREBUILT_VERSION =	v4.6.1
	NODE_PREBUILT_TAG =	zone
	NODE_PREBUILT_IMAGE =	18b094b0-eb01-11e5-80c1-175dac7ddf02
endif

include ./tools/mk/Makefile.defs
ifeq ($(shell uname -s),SunOS)
	include ./tools/mk/Makefile.node_prebuilt.defs
else
	NODE := node
	NPM := $(shell which npm)
	NPM_EXEC= $(NPM)
endif
include ./tools/mk/Makefile.node_modules.defs

#
# Variables
#

TEST_UNIT_JOBS ?= 4
BUILD = $(TOP)/build
CLEAN_FILES += $(BUILD)

#
# Targets
#
.PHONY: all
all: $(STAMP_NODE_MODULES)

$(TAP): $(STAMP_NODE_MODULES)

$(BUILD):
	mkdir $@

.PHONY: test-unit
test-unit: | $(TAP) $(STAMP_NODE_MODULES) $(BUILD)
	$(TAP) --jobs=$(TEST_UNIT_JOBS) --output-file=$(BUILD)/test.unit.tap test/unit/**/*.test.js

.PHONY: test-coverage-unit
test-coverage-unit: | $(TAP) $(STAMP_NODE_MODULES) $(BUILD)
	$(TAP) --jobs=$(TEST_UNIT_JOBS) --output-file=$(BUILD)/test.unit.tap --coverage \
	test/unit/**/*.test.js

check:: check-version

# Ensure CHANGES.md and package.json have the same version.
.PHONY: check-version
check-version:
	@echo version is: $(shell cat package.json | json version)
	[[ `cat package.json | json version` == `grep '^## ' CHANGES.md | head -2 | tail -1 | awk '{print $$2}'` ]]

# BOILERPLATE: Code lint and formatting via eslint and prettier. See TRITON-155.
.PHONY: fmt
fmt:: | $(ESLINT)
	$(ESLINT) --fix $(ESLINT_FILES)

.PHONY: cutarelease
cutarelease: check
	[[ -z `git status --short` ]]  # If this fails, the working dir is dirty.
	@which json 2>/dev/null 1>/dev/null && \
	    ver=$(shell json -f package.json version) && \
	    name=$(shell json -f package.json name) && \
	    publishedVer=$(shell npm view -j $(shell json -f package.json name)@$(shell json -f package.json version) version 2>/dev/null) && \
	    if [[ -n "$$publishedVer" ]]; then \
		echo "error: $$name@$$ver is already published to npm"; \
		exit 1; \
	    fi && \
	    echo "** Are you sure you want to tag and publish $$name@$$ver to npm?" && \
	    echo "** Enter to continue, Ctrl+C to abort." && \
	    read
	ver=$(shell cat package.json | json version) && \
	    date=$(shell date -u "+%Y-%m-%d") && \
	    git tag -a "$$ver" -m "version $$ver ($$date)" && \
	    git push --tags origin && \
	    npm publish

.PHONY: git-hooks
git-hooks:
	ln -sf ../../tools/pre-commit.sh .git/hooks/pre-commit

include ./tools/mk/Makefile.deps
ifeq ($(shell uname -s),SunOS)
	include ./tools/mk/Makefile.node_prebuilt.targ
endif
include ./tools/mk/Makefile.targ
include ./tools/mk/Makefile.node_modules.targ
