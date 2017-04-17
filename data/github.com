[rules]
git://github.com/ = https://github.com/

[tests]
git://github.com/github/hub.git = https://github.com/github/hub.git
http://github.com/github/hub.git = https://github.com/github/hub.git

# vim:ft=dosini
