export LC_ALL = C

.PHONY: all
all: gitconfig

gitconfig: src tools/mk-gitconfig
	sort -c src
	tools/mk-gitconfig < $(<) > $(@).tmp
	mv $(@).tmp $(@)

# vim:ts=4 sts=4 sw=4 noet
