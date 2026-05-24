AWK ?= awk
PYTHON ?= python3

LIB = src/lib
MAIN = src/main
# Engine = every lib (functions only) + the single main, cat'd last.
# Codex drops src/lib/*.awk + src/main/awkuid.awk; the build picks them up.
AWKUID_SRCS = $(sort $(wildcard $(LIB)/*.awk)) $(MAIN)/awkuid.awk

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN { FS = ":.*## " } /^[A-Za-z0-9_.-]+:.*## / { printf "%-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: test
test: build lint golden ## Run lint and the enforced golden cases.

.PHONY: golden
golden: build ## Enforce the golden-liquid core list (test/golden/golden-core.txt).
	$(PYTHON) test/golden/run-golden.py --awk "$(AWK)" --core test/golden/golden-core.txt

.PHONY: progress
progress: build ## Report pass rate across the whole golden-liquid corpus.
	$(PYTHON) test/golden/run-golden.py --awk "$(AWK)"

.PHONY: build
build: build/awkuid ## Build the single-file awkuid from src/.

build/awkuid: $(AWKUID_SRCS)
	@mkdir -p build
	@echo '#!/usr/bin/awk -f' > $@.tmp
	@cat $(AWKUID_SRCS) >> $@.tmp
	@chmod +x $@.tmp
	@mv $@.tmp $@

.PHONY: lint
lint: ## POSIX-lint the engine sources (skips until they exist).
	@if [ -f $(MAIN)/awkuid.awk ] && command -v gawk >/dev/null 2>&1; then \
		gawk --posix --lint -v liquid_template_dir="" $(addprefix -f ,$(AWKUID_SRCS)) /dev/null </dev/null >/dev/null; \
	else \
		echo "skip lint: engine sources not present yet"; \
	fi

.PHONY: clean
clean: ## Remove build artifacts.
	rm -rf build
