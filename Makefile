IMAGE?=docker/volumes-backup-extension
TAG?=latest
BUILDER=buildx-multi-arch
REACT_APP_MUI_LICENSE_KEY?=UNKNOWN_KEY

export BUGSNAG_API_KEY?=
export BUGSNAG_RELEASE_STAGE?=local

INFO_COLOR = \033[0;36m
NO_COLOR   = \033[m

build-extension: ## Build service image to be deployed as a desktop extension
	docker buildx build \
		--secret id=BUGSNAG_API_KEY \
		--secret id=REACT_APP_MUI_LICENSE_KEY \
		--build-arg BUGSNAG_RELEASE_STAGE=$(BUGSNAG_RELEASE_STAGE) \
		--build-arg BUGSNAG_APP_VERSION=$(TAG) \
		--load \
		--tag=$(IMAGE):$(TAG) \
		.

install-extension: build-extension ## Install the extension
	docker extension install $(IMAGE):$(TAG)

update-extension: build-extension ## Update the extension
	docker extension update $(IMAGE):$(TAG) -f

dev-up:
	docker extension dev ui-source $(IMAGE):$(TAG) http://localhost:3000
	docker extension dev debug $(IMAGE):$(TAG)

dev-reset:
	docker extension dev reset $(IMAGE):$(TAG)

prepare-buildx: ## Create buildx builder for multi-arch build, if not exists
	docker buildx inspect $(BUILDER) || docker buildx create --name=$(BUILDER) --driver=docker-container --driver-opt=network=host

push-extension: prepare-buildx ## Build & Upload extension image to hub. Do not push if tag already exists: make push-extension tag=0.1
	docker pull $(IMAGE):$(TAG) && echo "Failure: Tag already exists" || docker buildx build --secret id=BUGSNAG_API_KEY --secret id=REACT_APP_MUI_LICENSE_KEY --build-arg BUGSNAG_RELEASE_STAGE=$(BUGSNAG_RELEASE_STAGE) --build-arg BUGSNAG_APP_VERSION=$(TAG) --push --builder=$(BUILDER) --platform=linux/amd64,linux/arm64 --build-arg TAG=$(TAG) --tag=$(IMAGE):$(TAG) .

run-benchmark: ## Run the Go benchmarks
	cd vm \
	&& go install golang.org/x/perf/cmd/benchstat@latest \
	&& rm -rf benchmark.txt \
	&& go test -timeout 30m -run="-" -bench=".*" -count=1 ./... | tee benchmark.txt \
    && benchstat benchmark.txt

help: ## Show this help
	@echo Please specify a build target. The choices are:
	@grep -E '^[0-9a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "$(INFO_COLOR)%-30s$(NO_COLOR) %s\n", $$1, $$2}'

.PHONY: help
