# Determine this Makefile's path - ensure this is before any 'include' directives
THIS_FILE := $(lastword $(MAKEFILE_LIST))

# Set shell to bash to avoid surprises
SHELL := /bin/bash

# Set environment to example-gcp if not specified
ENV ?= example-gcp

# Set tenants definition path
TENANTS := "tenants"

# Set environments definition path
ENVIRONMENTS := "environments"

# Set release buildtime, revision, and version
SOURCE_DATE_EPOCH ?= $(shell git log -1 --pretty=%ct)
RELEASE_BUILDTIME ?= $(shell date -Iseconds)
RELEASE_REVISION ?= $(shell git describe --match=NeVeRmAtCh --always --abbrev=400 --dirty)
RELEASE_VERSION ?= undefined

# Helm requires the version to be SemVer, so if it's not, prefix 0.0.0- to it
RELEASE_VERSION := $(shell echo $(RELEASE_VERSION) | sed -E -e '/^[0-9]+\.[0-9]+\.[0-9]+.*$$/! s/^/0.0.0-/')

# Also expose as tofu variables
TF_RELEASE_VARS := -var release_buildtime="$(RELEASE_BUILDTIME)" -var release_revision="$(RELEASE_REVISION)" -var release_version="$(RELEASE_VERSION)"

# Set features path prefix for the selected environment
FEATURES_PREFIX := environments/$(ENV)/.feature-

# Used in tofu apply/destroy, useful for setting defaults
TERRAFORM_ARGS ?=

# use local yq, otherwise fallback to running it via docker
YQ := $$(which yq || echo docker run --rm -i -v "$${PWD}":/tenants -w /tenants mikefarah/yq) -r

# use local helm, otherwise fallback to running it via docker TODO: docker version broken by deterministic repackager
HELM := $$(which helm || echo docker run --rm -i -v "$${PWD}":/environments -w /environments -v ~/.config/helm:/root/.config/helm alpine/helm)

# use local hadolint, otherwise fallback to running it via docker
HADOLINT := $$(which hadolint || echo docker run --rm -i hadolint/hadolint hadolint)

# use local golangci-lint, otherwise fallback to running it via docker
GOLANGCI_LINT := $$(which golangci-lint || echo docker run --rm -i -v "$${PWD}":/functional-tests -w /functional-tests -v "$${HOME}/.cache/golangci-lint":/root/.cache/golangci-lint golangci/golangci-lint golangci-lint)

# if tac doesn't exist, try using tail -r
TAC := $$(which tac || echo tail -r)



.PHONY: default
default: help

.PHONY: help
help: Makefile
	@echo "Usage: "
	@sed -n 's/^##[ -]/   /p' Makefile
	@echo ""

.PHONY: help-all
help-all: Makefile
	@echo "Usage: "
	@sed -n 's/^##[# -]/   /p' Makefile
	@echo ""


.PHONY: clean
clean: clean-features

.PHONY: clean-features
clean-features:
	@rm -rf "$(FEATURES_PREFIX)"*



## make all					Bootstrap and run IaC
.PHONY: all
all: lint features-init bootstrap features-apply features-test



## make bootstrap				Bootstrap IaC
.PHONY: bootstrap
bootstrap:
	@echo "--- Bootstrap"
	@$(MAKE) --no-print-directory -f $(THIS_FILE) features-prepare feature=connected-kubernetes
	@terragrunt apply --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" $(TF_RELEASE_VARS) \
		--target="module.bootstrap" \
		--target="module.connected-kubernetes.module.gke.data.google_compute_zones.available" \
		--target="module.connected-kubernetes.module.gke.random_shuffle.available_zones" \
		$(TERRAFORM_ARGS)
	@echo ""



##-
# Linting
#

###make lint					Run lint tools
.PHONY: lint
lint: tg-hclfmt-check tf-fmt-check helm-lint dockerfiles-lint environments-validate tenants-validate functional-tests-lint

###make tg-hclfmt-check				Run terragrunt hclfmt --terragrunt-check
.PHONY: tg-hclfmt-check
tg-hclfmt-check:
	@echo "--- Terragrunt hclfmt --terragrunt-check"
	@terragrunt hclfmt --terragrunt-check || bash -c "echo \"Run 'make tg-hclfmt' to fix\" && exit 1"

###make tg-hclfmt				Run terragrunt hclfmt
.PHONY: tg-hclfmt
tg-hclfmt:
	@echo "--- Terragrunt hclfmt"
	@terragrunt hclfmt

###make tf-fmt-check				Run tofu fmt --check
.PHONY: tf-fmt-check
tf-fmt-check:
	@echo "--- Tofu fmt -check"
	@tofu fmt -check -recursive || bash -c "echo \"Run 'make tf-fmt' to fix\" && exit 1"
	@for FILE in $$(find . -type f -name '*.tf-*') ; do \
		ln -s "$${FILE}" "$$$$.tf" ; \
		tofu fmt --check "$$$$.tf" >/dev/null ; \
		if [ "$$?" != "0" ] ; then \
			rm -f "$$$$.tf" ; \
			echo "$${FILE/\.\//}" ; \
			echo "Run 'make tf-fmt' to fix" ; \
			exit 1 ; \
		else \
			rm -f "$$$$.tf" ; \
		fi ; \
	done

###make tf-fmt					Run tofu fmt
.PHONY: tf-fmt
tf-fmt:
	@echo "--- Tofu fmt"
	@tofu fmt -recursive
	@for FILE in $$(find . -type f -name '*.tf-*') ; do \
		ln -s "$${FILE}" "$$$$.tf" ; \
		tofu fmt --check "$$$$.tf" >/dev/null ; \
		if [ "$$?" != "0" ] ; then \
			echo "$${FILE/\.\//}" ; \
			tofu fmt "$$$$.tf" >/dev/null ; \
		fi ; \
		rm -f "$$$$.tf" ; \
	done

###make dockerfiles-lint			Lint Dockerfiles
.PHONY: dockerfiles-lint
dockerfiles-lint:
	@echo "--- Dockerfiles lint"
	@$(HADOLINT) - < Dockerfile;

## make tenants-validate			Tenant schema validation
.PHONY: tenants-validate
tenants-validate:
	@echo "--- Tenants list validation"
	@if [ -n "$(TENANTS)" ] ; then \
		cd $(TENANTS) && $(MAKE) --no-print-directory tenants-validate ; \
	else \
		echo "TENANTS not defined, nothing to validate" ; \
	fi

## make environments-validate			Environment schema validation
.PHONY: environments-validate
environments-validate:
	@echo "--- Environments list validation"
	@if [ -n "$(ENVIRONMENTS)" ] ; then \
		cd $(ENVIRONMENTS) && $(MAKE) --no-print-directory environments-validate ; \
	else \
		echo "ENVIRONMENTS not defined, nothing to validate" ; \
	fi

###make functional-tests-lint			Functional tests golang lint validation
.PHONY: functional-tests-lint
functional-tests-lint:
	@echo "--- Functional tests golang lint"
	@cd functional-tests && $(GOLANGCI_LINT) run --timeout 5m ./

###make functional-tests-upgrade		Run go get -t -u && go mod tidy
.PHONY: functional-tests-upgrade
functional-tests-upgrade:
	@echo "--- Functional tests update go deps"
	@cd functional-tests && go get -t -u && go mod tidy && go test -c -o /dev/null



##-
# Terragrunt features
#


FUNC_FEATURES_LIST := \
	for feature in $$($(YQ) '.features' -o t environments/$(ENV)/config.yaml) ; do \
			echo "$${feature}" ; \
	done

FUNC_FEATURE_ENABLED := \
	echo "$$($(FUNC_FEATURES_LIST))" | grep -q "^$(feature)$$"

FUNC_RUN_FUNCTIONAL_TESTS := $$($(YQ) '.tests.functional' -o t environments/$(ENV)/config.yaml)

# returns aws, azure, or gcp
FUNC_VENDOR := \
	$$($(YQ) '.platform.vendor' -o t environments/$(ENV)/config.yaml)

# returns s3, azurerm, or gcs
FUNC_VENDOR_BACKEND := \
	$$($(YQ) '.platform.vendor' -o t environments/$(ENV)/config.yaml | sed -e "s/aws/s3/" -e "s/azure/azurerm/" -e "s/gcp/gcs/")



## make features-list				List features
.PHONY: features-list
features-list:
	@$(FUNC_FEATURES_LIST)



.PHONY: features-rsync
features-rsync:
	@if [ -z $(feature) ] ; then \
		for feature in $$($(FUNC_FEATURES_LIST)) ; do \
			$(MAKE) --no-print-directory -f $(THIS_FILE) features-rsync feature=$${feature} || exit 1 ; \
		done ; \
	elif ! $$($(FUNC_FEATURE_ENABLED)) ; then \
		echo "* Feature $(feature) not enabled for environment $(ENV), skipping" ; \
	else \
		if ! [ -d "features/$${feature}" ] ; then echo "ERROR: features/$${feature} doesn't exist" ; exit 1 ; fi ; \
		rsync -rt --copy-dirlinks --delete --exclude ".terraform" "features/$${feature}/" "$(FEATURES_PREFIX)$${feature}" || exit 1 ; \
	fi

.PHONY: features-vendor
features-vendor:
	@if [ -z $(feature) ] ; then \
		for feature in $$($(FUNC_FEATURES_LIST)) ; do \
			$(MAKE) --no-print-directory -f $(THIS_FILE) features-vendor feature=$${feature} || exit 1 ; \
		done ; \
	elif ! $$($(FUNC_FEATURE_ENABLED)) ; then \
		echo "* Feature $(feature) not enabled for environment $(ENV), skipping" ; \
	else \
		if ! [ -d "features/$${feature}" ] ; then echo "ERROR: features/$${feature} doesn't exist" ; exit 1 ; fi ; \
		BACKEND=$(FUNC_VENDOR_BACKEND) ; \
		sed -i.bak -e "s/backend \".*\"/backend \"$${BACKEND}\"/" "$(FEATURES_PREFIX)$${feature}/backend.tf" || exit 1 ; \
		if [ -f "$(FEATURES_PREFIX)$${feature}/vendor.tf-$(FUNC_VENDOR)" ] ; then \
			ln -s "vendor.tf-$(FUNC_VENDOR)" "$(FEATURES_PREFIX)$${feature}/vendor.tf" || exit 1 ; \
		fi ; \
		ln -s "terragrunt-$(FUNC_VENDOR).hcl" "$(FEATURES_PREFIX)$${feature}/terragrunt.hcl" || exit 1 ; \
	fi

.PHONY: features-prepare
features-prepare: features-rsync features-vendor



###make features-init-upgrade			Run terragrunt init -upgrade
.PHONY: features-init-upgrade
features-init-upgrade:
	@if [ -z $(feature) ] ; then \
		for feature in $$($(FUNC_FEATURES_LIST)) ; do \
			$(MAKE) --no-print-directory -f $(THIS_FILE) features-init-upgrade feature=$${feature} || exit 1 ; \
		done ; \
	elif ! $$($(FUNC_FEATURE_ENABLED)) ; then \
		echo "* Feature $(feature) not enabled for environment $(ENV), skipping" ; \
	else \
		echo "--- Terragrunt init -upgrade ($(feature))" && \
		$(MAKE) --no-print-directory -f $(THIS_FILE) features-prepare feature=$${feature} || exit 1 ; \
		terragrunt init -upgrade --terragrunt-working-dir="$(FEATURES_PREFIX)$(feature)" --terragrunt-non-interactive -lock=false || exit 1 ; \
		echo "" && \
		terragrunt providers lock --platform=darwin_amd64 --platform=darwin_arm64 --platform=linux_amd64 --platform=linux_arm64 --platform=windows_amd64 --terragrunt-working-dir="$(FEATURES_PREFIX)$(feature)" || exit 1 ; \
		cp "$(FEATURES_PREFIX)$(feature)/.terraform.lock.hcl" "features/$(feature)/.terraform.lock.hcl" || exit 1 ; \
		echo "" ; \
	fi



###make features-init				Run terragrunt init
.PHONY: features-init
features-init:
	@if [ -z $(feature) ] ; then \
		for feature in $$($(FUNC_FEATURES_LIST)) ; do \
			$(MAKE) --no-print-directory -f $(THIS_FILE) features-init feature=$${feature} || exit 1 ; \
		done ; \
	elif ! $$($(FUNC_FEATURE_ENABLED)) ; then \
		echo "* Feature $(feature) not enabled for environment $(ENV), skipping" ; \
	else \
		echo "--- Terragrunt init ($(feature))" && \
		$(MAKE) --no-print-directory -f $(THIS_FILE) features-prepare feature=$${feature} || exit 1 ; \
		terragrunt init --terragrunt-working-dir="$(FEATURES_PREFIX)$(feature)" --terragrunt-non-interactive -lock=false || exit 1 ; \
		echo "" ; \
	fi



###make features-validate			Run terragrunt validate
.PHONY: features-validate
features-validate:
	@if [ -z $(feature) ] ; then \
		for feature in $$($(FUNC_FEATURES_LIST)) ; do \
			$(MAKE) --no-print-directory -f $(THIS_FILE) features-validate feature=$${feature} || exit 1 ; \
		done ; \
	elif ! $$($(FUNC_FEATURE_ENABLED)) ; then \
		echo "* Feature $(feature) not enabled for environment $(ENV), skipping" ; \
	else \
		echo "--- Terragrunt validate ($(feature))" && \
		$(MAKE) --no-print-directory -f $(THIS_FILE) features-prepare feature=$${feature} || exit 1 ; \
		terragrunt validate --terragrunt-working-dir="$(FEATURES_PREFIX)$(feature)" || exit 1 ; \
	fi



## make features-plan				Run terragrunt plan
.PHONY: features-plan
features-plan:
	@if [ -z $(feature) ] ; then \
		for feature in $$($(FUNC_FEATURES_LIST)) ; do \
			$(MAKE) --no-print-directory -f $(THIS_FILE) features-plan feature=$${feature} || exit 1 ; \
		done ; \
	elif ! $$($(FUNC_FEATURE_ENABLED)) ; then \
		echo "* Feature $(feature) not enabled for environment $(ENV), skipping" ; \
	else \
		echo "--- Terragrunt plan ($(feature))" && \
		$(MAKE) --no-print-directory -f $(THIS_FILE) features-prepare feature=$${feature} || exit 1 ; \
		if [ -e "$(FEATURES_PREFIX)$(feature)/charts" ] ; then \
			$(MAKE) --no-print-directory -f $(THIS_FILE) helm-package feature=$${feature} || exit 1 ; \
		fi && \
		if [[ ! -f "$(FEATURES_PREFIX)$(feature)/.skip-kubeconfig" ]] ; then \
			$(MAKE) --no-print-directory -f $(THIS_FILE) cluster-api-access || exit 1 ; \
		fi ; \
		terragrunt plan --terragrunt-working-dir="$(FEATURES_PREFIX)$(feature)" $(TF_RELEASE_VARS) -lock=false -out="plan-$(feature).zip" || exit 1 ; \
		echo "" ; \
	fi



## make features-apply				Run terragrunt apply
.PHONY: features-apply
features-apply:
	@if [ -z $(feature) ] ; then \
		for feature in $$($(FUNC_FEATURES_LIST)) ; do \
			$(MAKE) --no-print-directory -f $(THIS_FILE) features-apply feature=$${feature} || exit 1 ; \
		done ; \
	elif ! $$($(FUNC_FEATURE_ENABLED)) ; then \
		echo "* Feature $(feature) not enabled for environment $(ENV), skipping" ; \
	else \
		echo "--- Terragrunt apply ($(feature))" && \
		$(MAKE) --no-print-directory -f $(THIS_FILE) features-prepare feature=$${feature} || exit 1 ; \
		if [ -e "$(FEATURES_PREFIX)$(feature)/charts" ] ; then \
			$(MAKE) --no-print-directory -f $(THIS_FILE) helm-push feature=$${feature} || exit 1 ; \
		fi && \
		if [[ ! -f "$(FEATURES_PREFIX)$(feature)/.skip-kubeconfig" ]] ; then \
			$(MAKE) --no-print-directory -f $(THIS_FILE) cluster-api-access || exit 1 ; \
		fi ; \
		terragrunt apply --terragrunt-working-dir="$(FEATURES_PREFIX)$(feature)" $(TF_RELEASE_VARS) $(TERRAFORM_ARGS) || exit 1 ; \
		if [ "$${feature}" == "connected-kubernetes" ] ; then \
			$(MAKE) --no-print-directory -f $(THIS_FILE) cluster-prewarm || exit 1 ; \
		fi ; \
		echo "" ; \
	fi



## make features-destroy			Run terragrunt destroy
.PHONY: features-destroy
features-destroy:
	@if [ -z $(feature) ] ; then \
		for feature in $$($(FUNC_FEATURES_LIST) | $(TAC)) ; do \
			$(MAKE) --no-print-directory -f $(THIS_FILE) features-destroy feature=$${feature} || exit 1 ; \
		done ; \
	elif ! $$($(FUNC_FEATURE_ENABLED)) ; then \
		echo "* Feature $(feature) not enabled for environment $(ENV), skipping" ; \
	else \
		echo "--- Terragrunt destroy ($(feature))" && \
		$(MAKE) --no-print-directory -f $(THIS_FILE) features-prepare feature=$${feature} || exit 1 ; \
		if [[ ! -f "$(FEATURES_PREFIX)$(feature)/.skip-kubeconfig" ]] ; then \
			$(MAKE) --no-print-directory -f $(THIS_FILE) cluster-api-access || exit 1 ; \
		fi ; \
		if [[ -f "$(FEATURES_PREFIX)$${feature}/.skip-feature-destroy" ]] ; then \
			echo "* Skipping due to .skip-feature-destroy file" ; \
			echo "" ; \
		else \
			terragrunt destroy --terragrunt-working-dir="$(FEATURES_PREFIX)$(feature)" $(TF_RELEASE_VARS) $(TERRAFORM_ARGS) || exit 1 ; \
		fi ; \
		if [[ -f "$(FEATURES_PREFIX)$(feature)/post-destroy-script.sh" ]] ; then \
			./$(FEATURES_PREFIX)$(feature)/post-destroy-script.sh "${PWD}/environments/$(ENV)/config.yaml" || exit 1 ; \
		fi ; \
		echo "" ; \
	fi

## make features-test				Run tests
.PHONY: features-test
features-test:
	@if [ "$(FUNC_RUN_FUNCTIONAL_TESTS)" != "true" ] ; then \
		echo "Skipping functional tests"; \
	elif [ -z $(feature) ] ; then \
		for feature in $$($(FUNC_FEATURES_LIST)) ; do \
			$(MAKE) --no-print-directory -f $(THIS_FILE) features-test feature=$${feature} || exit 1 ; \
		done ; \
	elif ! $$($(FUNC_FEATURE_ENABLED)) ; then \
		echo "* Feature $(feature) not enabled for environment $(ENV), skipping" ; \
	else \
		echo "--- Test ($(feature))" && \
		$(MAKE) --no-print-directory -f $(THIS_FILE) features-prepare feature=$${feature} || exit 1 ; \
		if [[ ! -f "$(FEATURES_PREFIX)$(feature)/.skip-kubeconfig" ]] ; then \
			$(MAKE) --no-print-directory -f $(THIS_FILE) cluster-api-access || exit 1 ; \
		fi ; \
		export KUBE_CONTEXT=$$(terragrunt output -raw kubeconfig_context --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes") && \
		export INTERNAL_OCI_REGISTRY=$$(terragrunt output -raw internal_oci_registry --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes") && \
		export ENVIRONMENT_CONFIG_FILE="${PWD}/environments/$(ENV)/config.yaml" && \
		cd functional-tests && \
		if [ -f /.dockerenv ] ; then \
			ENVIRONMENT_CONFIG_FILE=$${ENVIRONMENT_CONFIG_FILE} KUBE_CONTEXT=$${KUBE_CONTEXT} INTERNAL_OCI_REGISTRY=$${INTERNAL_OCI_REGISTRY} RELEASE_VERSION=$(RELEASE_VERSION) RELEASE_REVISION=$(RELEASE_REVISION) ./test -test.v --godog.tags="$(feature) && ~@disabled" || exit 1; \
		else \
			ENVIRONMENT_CONFIG_FILE=$${ENVIRONMENT_CONFIG_FILE} KUBE_CONTEXT=$${KUBE_CONTEXT} INTERNAL_OCI_REGISTRY=$${INTERNAL_OCI_REGISTRY} RELEASE_VERSION=$(RELEASE_VERSION) RELEASE_REVISION=$(RELEASE_REVISION) go test -v --godog.tags="$(feature) && ~@disabled" || exit 1; \
		fi ; \
		echo "" ; \
	fi

###make helm-lint				Helm lint charts
.PHONY: helm-lint
helm-lint:
	@echo "--- Helm lint"
	@echo "DISABLED!" || find -L features/*/charts/ -name "Chart.yaml" | xargs -n1 sh -c ' \
		CHARTFILE="$$1" ; \
		CHART=$$(basename $$(dirname "$$CHARTFILE")) ; \
		echo "* helm lint $${CHART}" ; \
		$(HELM) lint --quiet "$$( dirname $$CHARTFILE )" ; ' 'make: helm-lint'

###make helm-registry-login			Helm registry login to internal OCI registry
.PHONY: helm-registry-login
helm-registry-login:
	@echo "--- Helm registry login"
	@$(MAKE) --no-print-directory -f $(THIS_FILE) features-prepare feature=connected-kubernetes
	@export INTERNAL_OCI_REGISTRY=$$(terragrunt output -raw internal_oci_registry --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes") && \
	test -n "$${INTERNAL_OCI_REGISTRY}" && \
	echo "* helm registry login to '$${INTERNAL_OCI_REGISTRY%%/*}'" && \
	mkdir -p ~/.config/helm/registry && \
	gcloud auth print-access-token | $(HELM) registry login -u oauth2accesstoken --password-stdin "https://$${INTERNAL_OCI_REGISTRY%%/*}" && \
	echo ""

###make helm-package				Helm package charts
.PHONY: helm-package
helm-package: helm-package-do

.PHONY: helm-package-do
helm-package-do: TAR = $$(which gtar || which tar)
helm-package-do:
	@$(TAR) --version | grep -q "(GNU tar)" || bash -c "echo 'GNU tar is required (run \"brew install gnu-tar\" to install on macOS)' ; exit 1"
	@if [ -z "$(feature)" ] ; then \
		for feature in $$($(FUNC_FEATURES_LIST)) ; do \
			$(MAKE) --no-print-directory -f $(THIS_FILE) helm-package-do feature=$${feature} || exit 1 ; \
		done ; \
	elif [ -n "$(feature)" ] && [ -z "$(chart)" ] ; then \
		if [ -d $(FEATURES_PREFIX)$(feature)/charts ] ; then \
			for chart in $$(find -L $(FEATURES_PREFIX)$(feature)/charts -name "Chart.yaml" | xargs -n1 dirname $1) ; do \
				$(MAKE) --no-print-directory -f $(THIS_FILE) helm-package-do feature=$(feature) chart=$$(basename $${chart}) || exit 1 ; \
			done ; \
		fi ; \
	elif [ -n "$(feature)" ] && [ -n "$(chart)" ] ; then \
		echo "--- Helm package ($(feature)/$(chart))" ; \
		TMPDIR=/tmp/helm-deterministic-repackaging.$$$$ && \
		mkdir -p "$${TMPDIR}" && \
		$(HELM) package "$(FEATURES_PREFIX)$(feature)/charts/$(chart)" --version "$(RELEASE_VERSION)" --destination "$$TMPDIR" && \
		PACKAGE_FILENAME=$(chart)-$(RELEASE_VERSION).tgz && \
		LC_ALL=C $(TAR) xzm -C "$${TMPDIR}/" -f $${TMPDIR}/$$PACKAGE_FILENAME && \
		$(TAR) c -C "$${TMPDIR}/" \
			--sort=name --format=posix \
			--pax-option=exthdr.name=%d/PaxHeaders/%f \
			--pax-option=delete=atime,delete=ctime \
			--clamp-mtime --mtime="@$(SOURCE_DATE_EPOCH)" \
			--numeric-owner --owner=0 --group=0 \
			--mode=644 \
			-f - $$(cd "$$TMPDIR"; find "$(chart)" -type f | sort) | gzip --no-name --best >"$(FEATURES_PREFIX)$(feature)/charts/$$PACKAGE_FILENAME" || exit 1 ; \
		rm -rf $${TMPDIR} ; \
		echo "" ; \
	else \
		exit 1 ; \
	fi

###make helm-push				Helm push charts to internal OCI registry
.PHONY: helm-push
helm-push: helm-registry-login helm-package helm-push-do

.PHONY: helm-push-do
helm-push-do:
	@if [ -z "$(feature)" ] ; then \
		for feature in $$($(FUNC_FEATURES_LIST)) ; do \
			$(MAKE) --no-print-directory -f $(THIS_FILE) helm-push-do feature=$${feature} || exit 1 ; \
		done ; \
	elif [ -n "$(feature)" ] && [ -z "$(chart)" ] ; then \
		if [ -d $(FEATURES_PREFIX)$(feature)/charts ] ; then \
			for chart in $$(find -L $(FEATURES_PREFIX)$(feature)/charts -name "Chart.yaml" | xargs -n1 dirname $1) ; do \
				$(MAKE) --no-print-directory -f $(THIS_FILE) helm-push-do feature=$(feature) chart=$$(basename $${chart}) || exit 1 ; \
			done ; \
		fi ; \
	elif [ -n "$(feature)" ] && [ -n "$(chart)" ] ; then \
		echo "--- Helm push ($(feature)/$(chart))" ; \
		export INTERNAL_OCI_REGISTRY=$$(terragrunt output -raw internal_oci_registry --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes") && \
		$(HELM) push "$(FEATURES_PREFIX)$(feature)/charts/$(chart)-$(RELEASE_VERSION).tgz" "oci://$${INTERNAL_OCI_REGISTRY}" || exit 1 ; \
		echo "" ; \
	else \
		exit 1 ; \
	fi



##-
# Connectivity
#


## make cluster-api-access-commands		Print commands required for cluster API access
.PHONY: cluster-api-access-commands
cluster-api-access-commands: features-prepare
	@echo "#--- Kubeconf generate"
	@terragrunt output -raw kubeconfig_generate_command --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes"
	@echo ""
	@echo "#--- Set kubeconfig context"
	@echo kubectl config set-context $$(terragrunt output -raw kubeconfig_context --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes") --namespace=default
	@terragrunt output -raw kubeconfig_set_proxy_command --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes"
	@echo ""
	@if [ "$(FUNC_VENDOR)" == "aws" ] ; then \
		echo "#--- SSM Tunnel" ; \
		terragrunt output -raw ssm_tunnel_command --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" ; \
		echo ""; \
	elif [ "$(FUNC_VENDOR)" == "gcp" ] ; then \
		echo "#--- IAP Tunnel" ; \
		terragrunt output -raw iap_tunnel_command --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" ; \
		echo "" ; \
	else \
		echo "#--- Tunnel" ; \
		echo "Unsupported vendor $(FUNC_VENDOR)" ; \
		exit 1 ; \
	fi

###make cluster-api-access-test			Test access to the cluster API
.PHONY: cluster-api-access-test
cluster-api-access-test:
	@echo "--- Cluster API access test ($(ENV))"
	@$(MAKE) --no-print-directory -f $(THIS_FILE) features-prepare feature=connected-kubernetes
	@kubectl --context=$$(terragrunt output -raw kubeconfig_context --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes") cluster-info

###make cluster-api-access			Setup access to the cluster API
.PHONY: cluster-api-access
cluster-api-access:
# use kubectl cluster-info to check if cluster is accessible, if not set up access and check again
	@$(MAKE) --no-print-directory -f $(THIS_FILE) features-prepare feature=connected-kubernetes
	@if ! kubectl --context=$$(terragrunt output -raw kubeconfig_context --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes") cluster-info >/dev/null 2>&1 ; then \
		$(MAKE) --no-print-directory -f $(THIS_FILE) kubeconfig-generate tunnel-start || exit 1 ; \
		kubectl --context=$$(terragrunt output -raw kubeconfig_context --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes") cluster-info >/dev/null 2>&1 || exit 1 ; \
	fi

###make cluster-prewarm				Prewarm the cluster
.PHONY: cluster-prewarm
cluster-prewarm: cluster-api-access
	@echo "--- Prewarm connected-kubernetes"
	@modules/connected-kubernetes-prewarm/prewarm-pods
	@$(MAKE) --no-print-directory -f $(THIS_FILE) cluster-wait-ready
	@echo ""



###make cluster-wait-ready			Wait until the cluster is ready
.PHONY: cluster-wait-ready
cluster-wait-ready: features-prepare
	@if [ -z "$(CLUSTER_DESCRIBE_CMD)" ] ; then \
		CLUSTER_DESCRIBE_CMD="$$(terragrunt output -raw cluster_describe_command --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" | grep -e "^gcloud container clusters describe " -e "^aws eks describe-cluster " -e "^az aks show " || echo false)" ; \
	else \
		CLUSTER_DESCRIBE_CMD="$(CLUSTER_DESCRIBE_CMD)" ; \
	fi ; \
	if [ "$(FUNC_VENDOR)" == "aws" ] ; then \
		sh -c "$${CLUSTER_DESCRIBE_CMD} >/dev/null 2>&1" && \
		while true ; do \
			STATUS=$$(sh -c "$${CLUSTER_DESCRIBE_CMD} | $(YQ) '.cluster.status'") ; \
			if [ "$${STATUS}" = "ACTIVE" ] ; then \
				break ; \
			fi ; \
			echo "$$(date -Iseconds) Cluster not ready (status: $${STATUS}) - waiting 60 sec" ; \
			sleep 60 ; \
		done ; \
	elif [ "$(FUNC_VENDOR)" == "gcp" ] ; then \
		sh -c "$${CLUSTER_DESCRIBE_CMD} >/dev/null 2>&1" && \
		while true ; do \
			STATUS=$$(sh -c "$${CLUSTER_DESCRIBE_CMD} | $(YQ) '.status'") ; \
			if [ "$${STATUS}" = "RUNNING" ] ; then \
				break ; \
			fi ; \
			echo "$$(date -Iseconds) Cluster not ready (status: $${STATUS}) - waiting 60 sec" ; \
			sleep 60 ; \
		done ; \
	else \
		echo "cluster-wait-ready: Unsupported vendor $(FUNC_VENDOR), aborting" ; \
		exit 1 ; \
	fi



## make kubeconfig-generate			Generate a kubeconfig entry for the cluster
.PHONY: kubeconfig-generate
kubeconfig-generate: features-prepare
	@echo "--- Generate kubeconfig"
	@sh -c "$$(terragrunt output -raw kubeconfig_generate_command --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" | grep -e "^gcloud container clusters get-credentials" -e "^aws eks update-kubeconfig " || echo false)"
	@sh -c "$$(terragrunt output -raw kubeconfig_set_proxy_command --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" | grep "^kubectl config set" || echo false)"
	kubectl config set-context $$(terragrunt output -raw kubeconfig_context --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes") --namespace=default
	@echo ""



## make tunnel-start				Start tunnel to the cluster
.PHONY: tunnel-start
tunnel-start:
	@echo "Executing tunnel-start"
	@if [ "$(FUNC_VENDOR)" == "aws" ] ; then \
		$(MAKE) --no-print-directory -f $(THIS_FILE) tunnel-start-ssm || exit 1 ; \
	elif [ "$(FUNC_VENDOR)" == "gcp" ] ; then \
		if ! [ -f .ssh-tunnel ] ; then \
			$(MAKE) --no-print-directory -f $(THIS_FILE) tunnel-start-iap || exit 1 ; \
		else \
			$(MAKE) --no-print-directory -f $(THIS_FILE) tunnel-start-ssh || exit 1 ; \
		fi ; \
	else \
		echo "Tunnel: Unsupported vendor $(FUNC_VENDOR), aborting" ; \
		exit 1 ; \
	fi

## make tunnel-stop				Stop tunnel to the cluster
.PHONY: tunnel-stop
tunnel-stop:
	@if [ "$(FUNC_VENDOR)" == "aws" ] ; then \
		$(MAKE) --no-print-directory -f $(THIS_FILE) tunnel-stop-ssm || exit 1 ; \
	elif [ "$(FUNC_VENDOR)" == "gcp" ] ; then \
		if ! [ -f .ssh-tunnel ] ; then \
			$(MAKE) --no-print-directory -f $(THIS_FILE) tunnel-stop-iap || exit 1 ; \
		else \
			$(MAKE) --no-print-directory -f $(THIS_FILE) tunnel-stop-ssh || exit 1 ; \
		fi ; \
	else \
		echo "Tunnel: Unsupported vendor $(FUNC_VENDOR), aborting" ; \
		exit 1 ; \
	fi



###make tunnel-start-ssm			Start SSM tunnel to the cluster
.PHONY: tunnel-start-ssm
tunnel-start-ssm: features-prepare
	@echo "--- Start tunnel (SSM)"
	@export SSM_TUNNEL_COMMAND="$$(terragrunt output -raw ssm_tunnel_command --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" | grep "^aws ssm start-session" || echo false)" && \
	export BASTION_INSTANCE_ID="$$(terragrunt output -raw bastion_instance_id --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" || echo false)" && \
	if pgrep -f "(start-session|StartSession) .*$${BASTION_INSTANCE_ID}" >/dev/null ; then \
		echo "SSM tunnel already running" ; \
	else \
		sh -c "$${SSM_TUNNEL_COMMAND} &" ; sleep 5 ; \
	fi
	@echo ""

###make tunnel-stop-ssm				Stop SSM tunnel to the cluster
.PHONY: tunnel-stop-ssm
tunnel-stop-ssm: features-prepare
	@echo "--- Stop tunnel (SSM)"
	@export BASTION_INSTANCE_ID="$$(terragrunt output -raw bastion_instance_id --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" || echo false)" && \
	if pkill -f "(start-session|StartSession) .*$${BASTION_INSTANCE_ID}" ; then \
		echo "SSM tunnel stopped" ; \
	else \
		echo "SSM tunnel not running" ; \
	fi
	@echo ""



###make tunnel-start-iap			Start IAP tunnel to the cluster
.PHONY: tunnel-start-iap
tunnel-start-iap: features-prepare
	@echo "--- Start tunnel (IAP)"
	@export IAP_TUNNEL_COMMAND="$$(terragrunt output -raw iap_tunnel_command --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" | grep "^gcloud compute start-iap-tunnel" || echo false)" && \
	export PROJECT_ID="$$(terragrunt output -raw project_id --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" || echo false)" && \
	if pgrep -f "start-iap-tunnel .* $${PROJECT_ID}" >/dev/null ; then \
		echo "IAP tunnel already running" ; \
	else \
		CLOUDSDK_PYTHON_SITEPACKAGES=1 \
		sh -c "while true ; do sh -c \"$${IAP_TUNNEL_COMMAND}\" ; sleep 1 ; done &" ; sleep 5 ; \
	fi
	@echo ""

###make tunnel-stop-iap				Stop IAP tunnel to the cluster
.PHONY: tunnel-stop-iap
tunnel-stop-iap: features-prepare
	@echo "--- Stop tunnel (IAP)"
	@export PROJECT_ID="$$(terragrunt output -raw project_id --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" || echo false)" && \
	if pkill -f "start-iap-tunnel .* $${PROJECT_ID}" ; then \
		echo "IAP tunnel stopped" ; \
	else \
		echo "IAP tunnel not running" ; \
	fi
	@echo ""

###make tunnel-start-ssh			Start SSH tunnel to the cluster
.PHONY: tunnel-start-ssh
tunnel-start-ssh: features-prepare
	@echo "--- Start tunnel (SSH)"
	@if ! [ -S .ssh-tunnel-$${ENV} ] ; then \
		if ! [ -f ~/.ssh/google_compute_engine ] ; then ssh-keygen -b 3072 -f ~/.ssh/google_compute_engine -t rsa -q -N "" ; fi ; \
		CLOUDSDK_PYTHON_SITEPACKAGES=1 \
		sh -c "$$(terragrunt output -raw ssh_tunnel_command --terragrunt-working-dir="$(FEATURES_PREFIX)connected-kubernetes" | grep "^gcloud beta compute ssh" || echo false) -f -M -S .ssh-tunnel-$${ENV}" ; \
	fi ; \
	printf "SSH tunnel: " ; \
	ssh -S .ssh-tunnel-$${ENV} -O check tunnel
	@echo ""

###make tunnel-stop-ssh				Stop SSH tunnel to the cluster
.PHONY: tunnel-stop-ssh
tunnel-stop-ssh: features-prepare
	@echo "--- Stop tunnel (SSH)"
	@if [ -S .ssh-tunnel-$${ENV} ] ; then \
		printf "SSH tunnel: " ; \
		ssh -S .ssh-tunnel-$${ENV} -O exit tunnel ; \
		echo "" ; \
	else \
		echo "SSH tunnel not running" ; \
		echo "" ; \
	fi



##
# Misc
#

###make local-cli				Get a shell in the release artifact with additional mounting directory for local development
.PHONY: local-cli
local-cli:
	@docker run --rm -it \
	-e ENV=${ENV} \
	-v ~/.aws/:/root/.aws \
	-v ~/.azure/:/root/.azure \
	-v ~/.config/gcloud/:/root/.config/gcloud \
	-v ~/.kube/config:/root/.kube/config \
	-v "${PWD}/Makefile:/app/Makefile" \
	-v "${PWD}/environments/Makefile:/app/environments/Makefile" \
	-v "${PWD}/environments/schema.yaml:/app/environments/schema.yaml" \
	-v "${PWD}/environments/${ENV}/config.yaml:/app/environments/${ENV}/config.yaml" \
	-v "${PWD}/${TENANTS}/:/app/${TENANTS}/" \
	-v "${PWD}/features/:/app/features/" \
	-v "${PWD}/modules/:/app/modules/" \
	"$(DOCKER_RELEASE_TAG)" \
	bash



##
# Release
#

DOCKER_RELEASE_TAG := ghcr.io/coreeng/example-core-platform:0.0.0-undefined

###make release-build				Build release artifact
.PHONY: release-build
release-build:
	@docker build -t $(DOCKER_RELEASE_TAG) \
		--platform linux/amd64 \
		--build-arg SOURCE_DATE_EPOCH="$(SOURCE_DATE_EPOCH)" \
		--build-arg RELEASE_BUILDTIME="$(RELEASE_BUILDTIME)" \
		--build-arg RELEASE_REVISION="$(RELEASE_REVISION)" \
		--build-arg RELEASE_VERSION="0.0.0-undefined" \
		-f Dockerfile .

###make release-build-cli			Get a shell in the release artifact container for testing
release-build-cli: release-build
release-build-cli:
	@docker run --rm -it \
	-e ENV=${ENV} \
	-v ~/.aws/:/root/.aws \
	-v ~/.azure/:/root/.azure \
	-v ~/.config/gcloud/:/root/.config/gcloud \
	-v "${PWD}/environments/Makefile:/app/environments/Makefile" \
	-v "${PWD}/environments/schema.yaml:/app/environments/schema.yaml" \
	-v "${PWD}/environments/${ENV}/config.yaml:/app/environments/${ENV}/config.yaml" \
	-v "${PWD}/${TENANTS}/:/app/${TENANTS}/" \
	"$(DOCKER_RELEASE_TAG)" \
	bash
