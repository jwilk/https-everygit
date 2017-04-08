.PHONY: all

all: gitconfig

gitconfig: src tools/mk-gitconfig
	tools/mk-gitconfig < $(<) > $(@).tmp
	mv $(@).tmp $(@)

# vim:ts=4 sts=4 sw=4 noet
