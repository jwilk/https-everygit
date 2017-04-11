export LC_ALL = C

ifeq "$(XDG_CONFIG_HOME)" ""
export XDG_CONFIG_HOME = $(HOME)/.config
endif

.PHONY: all
all: gitconfig

gitconfig: src devel/mk-gitconfig
	sort -c src
	devel/mk-gitconfig < $(<) > $(@).tmp
	mv $(@).tmp $(@)

.PHONY: install
install: gitconfig
	mkdir -m 700 -p "$$XDG_CONFIG_HOME/git"
	cp gitconfig "$$XDG_CONFIG_HOME/git/config-https-everygit"
	git config --get include.path | grep -q -w config-https-everygit \
	|| git config --global --add include.path "$$XDG_CONFIG_HOME/git/config-https-everygit"

.PHONY: test
test: gitconfig
	prove -v :: $(only)

.PHONY: test-online
test-online: gitconfig
	HTTPS_EVERYGIT_ONLINE_TESTS=1 prove -v :: $(only)

# vim:ts=4 sts=4 sw=4 noet
