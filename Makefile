GOPKG_BASE := github.com/raravena80/gotestsshagent
GOPKGS := $(shell go list ./... | grep -v /vendor/)
GOPKG_COVERS := $(shell go list ./... | grep -v '^$(GOPKG_BASE)/vendor/' | grep -v '^$(GOPKG_BASE)$$' | sed "s|^$(GOPKG_BASE)/|cover/|" | sed 's/$$/.cover/')
COVER_MODE := atomic
FIRST_GOPATH=$(shell go env GOPATH | cut -d: -f1)
GOFILES = $(shell find . -name '*.go' -not -path './vendor/*')
# Define in your CI system as an env var
COVERALLS_TOKEN ?= undefined

VERSION := $(shell cat VERSION)
VERSION_DESCRIBE := $(shell git describe --tags --always)
GITCOMMIT := $(shell git rev-parse --short HEAD)
GITUNTRACKEDCHANGES := $(shell git status --porcelain --untracked-files=no)
ifneq ($(GITUNTRACKEDCHANGES),)
        GITCOMMIT := $(GITCOMMIT)-dirty
endif
CTIMEVAR=-X $(GOPKG_BASE)/cmd.Version=$(VERSION) -X $(GOPKG_BASE)/cmd.Gitcommit=$(GITCOMMIT)
GO_LDFLAGS=-ldflags "-w $(CTIMEVAR)"
GO_LDFLAGS_STATIC=-ldflags "-w $(CTIMEVAR) -extldflags -static"

default: build

cover/%.cover: %
	mkdir -p $(dir $@)
	go test -v -race -coverprofile=$@ -covermode=$(COVER_MODE) ./$<

sshserverstart:
	echo 'Start SSH Test Server'
	gotestsshd & > /dev/null 2>&1

sshserverstop:
	echo 'Stop SSH Test Server'
	pkill -9 gotestsshd

cover/all: $(GOPKG_COVERS)
	echo mode: $(COVER_MODE) > $@
	for f in $(GOPKG_COVERS); do test -f $$f && sed 1d $$f >> $@ || true; done

goveralls: cover/all
	$(FIRST_GOPATH)/bin/goveralls -coverprofile=cover/all -service=circle-ci \
		-repotoken $(COVERALLS_TOKEN) || echo "not sending to coveralls"

circle: goveralls

workdir:
	mkdir -p workdir

build: workdir/gotestsshagent

build-native: $(GOFILES)
	go build $(GO_LDFLAGS) -o workdir/gotestsshagent .

build-static: $(GOFILES)
	go build $(GO_LDFLAGS_STATIC) -o workdir/gotestsshagent .

workdir/gotestsshagent: $(GOFILES)
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build $(GO_LDFLAGS) -o workdir/gotestsshagent.linux.amd64 .

test: test-all

test-all:
	@go test -v $(GOPKGS)

clean:
	rm -rf cover workdir

.PHONY: default test goveralls circle build
