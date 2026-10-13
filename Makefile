all: seafevents.tar.gz

seafevents.tar.gz:
	git archive --prefix=seafevents/ -o $@ HEAD

clean:
	rm -f seafevents.tar.gz

BASE_REGISTRY ?= docker.io
REGISTRY ?=
IMAGE_METADATA ?= $(shell git rev-parse --path-format=absolute --git-common-dir)/seafile-image.json
IMAGE_LOCK := $(shell git rev-parse --path-format=absolute --git-common-dir)/seafile-image.lock

.PHONY: test-indexing image-build image-publish
test-indexing:
	aventure-compute run --lane seafevents-image --weight 4 --resource "$(IMAGE_LOCK)" -- ./docker/build.sh test "$(REGISTRY)" "$(BASE_REGISTRY)" "$(IMAGE_METADATA)"

image-build:
	aventure-compute run --lane seafevents-image --weight 4 --resource "$(IMAGE_LOCK)" -- ./docker/build.sh build "$(REGISTRY)" "$(BASE_REGISTRY)" "$(IMAGE_METADATA)"

image-publish:
	nexus-docker-login
	aventure-compute run --lane seafevents-image --weight 4 --resource "$(IMAGE_LOCK)" -- ./docker/build.sh publish "$(REGISTRY)" "$(BASE_REGISTRY)" "$(IMAGE_METADATA)"
