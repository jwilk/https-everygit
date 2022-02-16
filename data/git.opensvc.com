[rules]
http://git.opensvc.com/ = https://git.opensvc.com/

[tests]
http://git.opensvc.com/multipath-tools/.git OFFLINE = https://git.opensvc.com/multipath-tools/.git OFFLINE

# vim:ft=dosini
