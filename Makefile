export LC_ALL = C

.PHONY: all
all: gitconfig

gitconfig: src devel/mk-gitconfig
	sort -c src
	devel/mk-gitconfig < $(<) > $(@).tmp
	mv $(@).tmp $(@)

.PHONY: test
test: gitconfig
	prove -v :: $(only)

.PHONY: test-online
test-online: gitconfig
	HTTPS_EVERYGIT_ONLINE_TESTS=1 prove -v :: $(only)

# vim:ts=4 sts=4 sw=4 noet
