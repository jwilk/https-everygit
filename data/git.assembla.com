[rules]
git://git.assembla.com/ = https://git.assembla.com/

[tests]
git://git.assembla.com/gitmagic.git OFFLINE = https://git.assembla.com/gitmagic.git OFFLINE
http://git.assembla.com/gitmagic.git OFFLINE = https://git.assembla.com/gitmagic.git OFFLINE

# vim:ft=dosini
