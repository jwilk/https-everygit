[rules]
git://git.ghostscript.com/ = https://git.ghostscript.com/

[tests]
git://git.ghostscript.com/ghostpdl.git OFFLINE = https://git.ghostscript.com/ghostpdl.git OFFLINE
http://git.ghostscript.com/ghostpdl.git OFFLINE = https://git.ghostscript.com/ghostpdl.git OFFLINE

# vim:ft=dosini
