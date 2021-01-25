setin aot.mkv
setout aot
makeaudio 0:a:0 audio jp Japanese YES
makesubs 0:s:0 subtitles eng English YES
makesubs 0:s:2 subtitles spa Spanish NO
makesubs 0:s:5 subtitles ara Arabic NO
makevideo 0:v:0 source 5605600 '1920x1080' 'audio' 'subtitles' '-c:v libx264 -preset ultrafast'