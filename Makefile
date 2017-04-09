export LC_ALL = C

.PHONY: all
all: gitconfig

gitconfig: src devel/mk-gitconfig
	sort -c src
	devel/mk-gitconfig < $(<) > $(@).tmp
	mv $(@).tmp $(@)

# vim:ts=4 sts=4 sw=4 noet
