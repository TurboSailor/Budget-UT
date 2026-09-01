# Budget for Ubuntu Touch.
#
# The click tree is assembled in build/pkg, then packed *on the phone* (macOS
# has no `click` tool) and installed from there. See scripts/build.sh, scripts/deploy.sh.

APP     := budget.turbosailor
ARCH    := arm64
VERSION := $(shell sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' click/manifest.json)

PKG   := build/pkg
CLICK := build/$(APP)_$(VERSION)_$(ARCH).click

GO         := go
GO_BUILD   := CGO_ENABLED=0 GOOS=linux GOARCH=$(ARCH) $(GO) build -trimpath -ldflags "-s -w"
CLICK_META := click/manifest.json click/budget.apparmor click/budget.desktop click/budget.png

.PHONY: all backend qml meta pkg click deploy logs host-test clean

all: click

backend:
	mkdir -p $(PKG)/bin
	cd backend && $(GO_BUILD) -o $(CURDIR)/$(PKG)/bin/budgetd ./cmd/budgetd
	cd backend && $(GO_BUILD) -o $(CURDIR)/$(PKG)/bin/budgetctl ./cmd/budgetctl

qml:
	rm -rf $(PKG)/qml
	mkdir -p $(PKG)
	cp -R qml $(PKG)/qml

data:
	mkdir -p $(PKG)/data
	cp tools/realm-export/budget-bundle.json $(PKG)/data/default-bundle.json

meta:
	mkdir -p $(PKG)
	cp $(CLICK_META) $(PKG)/
	cp click/run.sh $(PKG)/run.sh
	chmod +x $(PKG)/run.sh

pkg: backend qml meta data

click: pkg
	scripts/build.sh $(PKG) $(CLICK)

deploy: click
	scripts/deploy.sh $(CLICK)

logs:
	scripts/logs.sh

# Host-side smoke: build native, import the bundle, boot the API, probe endpoints.
host-test:
	scripts/host-test.sh

clean:
	rm -rf build
