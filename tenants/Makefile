# use bash for advanced variable substitutions
SHELL := /bin/bash

# use local yamale & yq if present, otherwise fallback to docker
YAMALE := $$(which yamale || echo docker run --rm -v "$${PWD}":/tenants -w /tenants quay.io/helmpack/chart-testing yamale)
YQ := $$(which yq || echo docker run --rm -v "$${PWD}":/tenants -w /tenants mikefarah/yq) -r

.PHONY: default
default: help

.PHONY: help
help: Makefile
	@echo "Usage: "
	@sed -n 's/^## /   /p' Makefile

## make tenants-validate			Validate tenants definition
.PHONY: tenants-validate
tenants-validate:
	@ERRVAL=0 ; \
	set -o pipefail ; \
	name_array=() ; \
	for TENANT_YAML in $$(find . -name '*.yaml' | grep -v "./schema.yaml" | sed -e "s@./@@" | sort) ; do \
		FILENAME=$$(basename $$TENANT_YAML) ; \
		DIRNAME=$$(dirname $$TENANT_YAML) ; \
		$(YAMALE) "$${TENANT_YAML}" | sed -e "s@$(PWD)/@@g" -e "/Validation /d" ; \
		ERRVAL=$$(($${ERRVAL} + $$?)) ; \
		NAME=$$($(YQ) .name "$${TENANT_YAML}") ; \
		if printf '%s\0' "$${name_array[@]}" | grep -Fxqz -- "$$NAME" ; then \
			printf "Error validating file '$${TENANT_YAML}'\n\tname: $${NAME} is a duplicate\n" ; \
			ERRVAL=1 ; \
		fi ; \
		name_array+=($$NAME) ; \
		if [ "$${NAME}" != "$${FILENAME/\.yaml}" ] ; then \
			printf "Error validating file '$${TENANT_YAML}'\n\tname: $${NAME} doesn't match filename\n" ; \
			ERRVAL=1 ; \
		fi ; \
		PARENT=$$($(YQ) .parent "$${TENANT_YAML}") ; \
		if [ "$${NAME}" == "$${PARENT}" ] ; then \
			printf "Error validating file '$${TENANT_YAML}'\n\tparent: must be set to root or a different tenant\n" ; \
			ERRVAL=1 ; \
		fi ; \
		if ! [ -f "$${DIRNAME}/$${PARENT}.yaml" ] && [ "$${PARENT}" != "root" ] ; then \
			printf "Error validating file '$${TENANT_YAML}'\n\tparent: $${PARENT} doesn't exist\n" ; \
			ERRVAL=1 ; \
		fi ; \
	done ; \
	if [ "$${ERRVAL}" != 0 ] ; then \
		echo "Tenant validation tests failed" ; \
	else \
		echo "Tenant validation tests passed" ; \
	fi ; \
	exit "$${ERRVAL}"
.PHONY: debug
debug:
	@echo yamale = $(YAMALE)
	@$(YAMALE) -V
	@echo yq = $(YQ)
	@$(YQ) -V
