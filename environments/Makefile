# use bash for advanced variable substitutions
SHELL := /bin/bash

# use local yamale & yq if present, otherwise fallback to docker
YAMALE := $$(which yamale || echo docker run --rm -v "$${PWD}":/environments -w /environments quay.io/helmpack/chart-testing yamale)

YQ := $$(which yq || echo docker run --rm -v "$${PWD}":/environments -w /environments mikefarah/yq) -r

.PHONY: default
default: help

.PHONY: help
help: Makefile
	@echo "Usage: "
	@sed -n 's/^## /   /p' Makefile

## make environments-validate			Validate environment definitions
.PHONY: environments-validate
environments-validate:
	@ERRVAL=0 ; \
	set -o pipefail ; \
	name_array=() ; \
	for ENV_YAML in $$(find . -maxdepth 2 -iname 'config*.y*ml' | sed -e "s@./@@" | sort) ; do \
		FILENAME=$$(basename $$ENV_YAML) ; \
		DIRNAME=$$(dirname $$ENV_YAML) ; \
		$(YAMALE) "$${ENV_YAML}" | sed -e "s@$(PWD)/@@g" -e "/Validation /d" ; \
		ERRVAL=$$(($${ERRVAL} + $$?)) ; \
	done ; \
	if [ "$${ERRVAL}" != 0 ] ; then \
		echo "Environments validation tests failed" ; \
	else \
		echo "Environments validation tests passed" ; \
	fi ; \
	exit "$${ERRVAL}"

.PHONY: debug
debug:
	@echo yamale = $(YAMALE)
	@$(YAMALE) -V
	@echo yq = $(YQ)
	@$(YQ) -V
