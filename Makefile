online =

export LC_ALL = C

ifeq "$(XDG_CONFIG_HOME)" ""
export XDG_CONFIG_HOME = $(HOME)/.config
endif

.PHONY: all
all: gitconfig

gitconfig: data $(wildcard data/*) devel/mk-gitconfig
	devel/mk-gitconfig data/* > $(@).tmp
	mv $(@).tmp $(@)

.PHONY: install
install: gitconfig
	mkdir -m 700 -p "$$XDG_CONFIG_HOME/git"
	cp gitconfig "$$XDG_CONFIG_HOME/git/config-https-everygit"
	git config --get include.path | grep -q -w config-https-everygit \
	|| git config --global --add include.path "$$XDG_CONFIG_HOME/git/config-https-everygit"

.PHONY: test
test: gitconfig
	$(and $(online),HTTPS_EVERYGIT_ONLINE_TESTS=1) prove -v :: $(only)

.error = GNU make is required

# vim:ts=4 sts=4 sw=4 noet
