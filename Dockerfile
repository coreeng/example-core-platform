FROM debian:12.5-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETPLATFORM

# Ensure TARGETPLATFORM is not empty
RUN if [ "${TARGETPLATFORM}" = "" ] ; then \
        echo "TARGETPLATFORM is empty, ensure you have docker-buildx installed, aborting build." ; \
        exit 1 ; \
    fi

# Ensure the FROM image platform matches the build target platform
RUN DETECTEDPLATFORM="$(uname -o | sed -e "s/GNU\/Linux/linux/")/$(uname -m | sed -e "s/aarch64/arm64/" -e "s/x86_64/amd64/")" ; \
	if [ "${TARGETPLATFORM}" != "${DETECTEDPLATFORM}" ] ; then \
		echo "TARGETPLATFORM is '${TARGETPLATFORM}' but FROM image is ${DETECTEDPLATFORM}, aborting build." ; \
		exit 1 ; \
	fi

WORKDIR /app

# Add backports
RUN echo 'deb http://deb.debian.org/debian bookworm-backports main' >/etc/apt/sources.list.d/backports.list

# Install dependencies
RUN --mount=type=cache,target=/var/cache/apt \
 apt-get update \
 && apt-get install --no-install-recommends -y \
	curl="7.88.*" \
	dnsutils="1:9.18.*" \
	docker.io="20.10.*" \
	file="1:5.44-*" \
	gcc="4:12.2.*" \
	git="1:2.39.*" \
	golang-1.22/bookworm-backports \
	jq="1.6-*" \
	libc6-dev="2.36-*" \
	libjq1="1.6-*" \
	lsb-release="12.0-*" \
	make="4.3-*" \
	openssh-client="1:9.2p*" \
	podman="4.3.*" \
	procps="2:4.0.*" \
	python3-pip="23.0.*" \
	python3-venv="3.11.*" \
	python3="3.11.*" \
	rsync="3.2.*" \
	unzip="6.0-*" \
	vim="2:9.0.*" \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && ln -s /usr/lib/go-1.22/bin/go /usr/bin/go

# Install gcloud CLI
ARG GCLOUD_CLI_VERSION=475.0.0
ENV PATH /opt/google-cloud-sdk/bin:$PATH
VOLUME ["/root/.config/gcloud"]
RUN curl -Lso google-cloud-cli.tgz "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_CLI_VERSION}-linux-$(uname -m | sed -e "s/aarch64/arm/").tar.gz" \
 && tar zxf google-cloud-cli.tgz --directory /opt/ \
 && rm google-cloud-cli.tgz \
 && gcloud config set core/disable_usage_reporting true \
 && gcloud config set component_manager/disable_update_check true \
 && gcloud config set metrics/environment github_docker_image \
 && gcloud components install beta gke-gcloud-auth-plugin --quiet \
 && $(gcloud info --format="value(basic.python_location)") -m pip install numpy \
 && gcloud --version

# Install aws CLI
ARG AWS_CLI_VERSION=2.15.46
RUN curl -Lso awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m | sed -e "s/arm64/aarch64/")-${AWS_CLI_VERSION}.zip" \
 && unzip -q awscliv2.zip \
 && ./aws/install -i /usr/local/aws-cli -b /usr/local/bin \
 && rm -rf aws awscliv2.zip \
 && aws --version

# Install aws ssm plugin
ARG AWS_SESSION_MANAGER_PLUGIN_VERSION=1.2.553.0
RUN curl -Lso session-manager-plugin.deb "https://s3.amazonaws.com/session-manager-downloads/plugin/${AWS_SESSION_MANAGER_PLUGIN_VERSION}/ubuntu_$(uname -m | sed -e "s/aarch64/arm64/" -e "s/x86_64/64bit/")/session-manager-plugin.deb" \
 && dpkg --install session-manager-plugin.deb \
 && rm session-manager-plugin.deb \
 && session-manager-plugin --version

# Install azure cli
ARG AZURECLI_VERSION=2.60.0
RUN curl -Ls https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/microsoft.gpg >/dev/null \
 && echo "deb [arch=$(uname -m | sed -e "s/aarch64/arm64/" -e "s/x86_64/amd64/")] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azure-cli.list \
 && apt-get update && apt-get install --no-install-recommends -y azure-cli="${AZURECLI_VERSION}-1~$(lsb_release -cs)" \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
 && az --version

# Install kubectl
ARG KUBECTL_VERSION=1.28.9
RUN curl -Lso kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/$(uname -m | sed -e "s/aarch64/arm64/" -e "s/x86_64/amd64/")/kubectl" \
 && install -o root -g root -m 0755 kubectl /usr/local/bin/ \
 && rm kubectl \
 && kubectl version --client=true

# Install kubectl-hns
ARG KUBECTL_HNS_VERSION=1.1.0
RUN curl -Lso kubectl-hns "https://github.com/kubernetes-sigs/hierarchical-namespaces/releases/download/v${KUBECTL_HNS_VERSION}/kubectl-hns_linux_$(uname -m | sed -e "s/aarch64/arm64/" -e "s/x86_64/amd64/")" \
 && install -o root -g root -m 0755 kubectl-hns /usr/local/bin/ \
 && rm kubectl-hns \
 && kubectl hns version

# Install helm
ARG HELM_VERSION=3.14.4
RUN curl -Lso helm.tgz "https://get.helm.sh/helm-v${HELM_VERSION}-linux-$(uname -m | sed -e "s/aarch64/arm64/" -e "s/x86_64/amd64/").tar.gz" \
 && tar zxf helm.tgz --strip-components=1 "linux-$(uname -m | sed -e "s/aarch64/arm64/" -e "s/x86_64/amd64/")/helm" \
 && install -o root -g root -m 0755 helm /usr/local/bin/ \
 && rm helm.tgz helm \
 && helm version --short

# Install opentofu
ARG OPENTOFU_VERSION=1.7.1
RUN curl -Lso opentofu.zip "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_$(uname -m | sed -e "s/aarch64/arm64/" -e "s/x86_64/amd64/").zip" \
 && unzip -q opentofu.zip \
 && install -o root -g root -m 0755 tofu /usr/local/bin/ \
 && rm opentofu.zip tofu \
 && tofu version

# Install terragrunt
ARG TERRAGRUNT_VERSION=0.58.3
RUN curl -Lso terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_$(uname -m | sed -e "s/aarch64/arm64/" -e "s/x86_64/amd64/")" \
 && install -o root -g root -m 0755 terragrunt /usr/local/bin/ \
 && rm terragrunt \
 && terragrunt -version

# Install hadolint
ARG HADOLINT_VERSION=2.12.0
RUN curl -Lso hadolint "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-$(uname -m | sed -e "s/aarch64/arm64/")" \
 && install -o root -g root -m 0755 hadolint /usr/local/bin \
 && rm -rf hadolint \
 && hadolint --version

# Install yq
ARG YQ_VERSION=4.43.1
RUN curl -Lso yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_$(uname -m | sed -e "s/aarch64/arm64/" -e "s/x86_64/amd64/")" \
 && install -o root -g root -m 0755 yq /usr/local/bin/ \
 && rm yq \
 && yq --version

# Install golangci-lint
ARG GOLANGCI_VERSION=1.58.1
RUN curl -Lso golangci-lint.deb "https://github.com/golangci/golangci-lint/releases/download/v${GOLANGCI_VERSION}/golangci-lint-${GOLANGCI_VERSION}-linux-$(uname -m | sed -e "s/aarch64/arm64/" -e "s/x86_64/amd64/").deb" \
 && dpkg --install golangci-lint.deb \
 && rm golangci-lint.deb \
 && golangci-lint --version

# Install yamale
ARG YAMALE_VERSION=5.2.1
RUN pip install --no-cache-dir --break-system-packages yamale==${YAMALE_VERSION}

# Install gcp-init and dependencies
COPY gcp-init/ /app/gcp-init

WORKDIR /app/gcp-init
# hadolint ignore=SC1091
RUN python3 -m venv .venv \
 && source .venv/bin/activate \
 && pip install --no-cache-dir -r requirements.txt
WORKDIR /app

# Copy features
COPY features/ ./features

# Pre-compile feature go tests and remove source code
COPY functional-tests/ ./functional-tests

WORKDIR /app/functional-tests
RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/root/go/pkg/mod \
	go test -c -o test
WORKDIR /app

# Copy remaining files
COPY doc/ ./doc
COPY modules/ ./modules

COPY pkg/ ./pkg
COPY cmd/ ./cmd

COPY tenant-resources/Makefile ./tenant-resources/

COPY Dockerfile .

COPY Makefile .

# Set release buildtime, version and revision
ARG SOURCE_DATE_EPOCH
ENV SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}

ARG RELEASE_BUILDTIME=undefined
ENV RELEASE_BUILDTIME=${RELEASE_BUILDTIME}

ARG RELEASE_VERSION=0.0.0-undefined
ENV RELEASE_VERSION=${RELEASE_VERSION}

ARG RELEASE_REVISION=undefined
ENV RELEASE_REVISION=${RELEASE_REVISION}
