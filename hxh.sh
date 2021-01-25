setout hxh
setin hxh.mkv
BURNIN=$(burnin 0:v:0 0:s:0 burned_in)
makeaudio 0:a:0 japanese jp Japanese YES
makeaudio 0:a:1 audio eng English YES
makevideo 0:v:0 source_burn_eng 5605600 '1920x1080' 'japanese' '' '-c:v libx264 -preset ultrafast' ${BURNIN}
makevideo 0:v:0 source_burn_eng 5605600 '1920x1080' 'english' '' '-c:v libx264 -preset ultrafast' ${BURNIN}
makevideo 0:v:0 source 5605600 '1920x1080' 'japanese' '' '-c:v libx264 -preset ultrafast'
makevideo 0:v:0 source 5605600 '1920x1080' 'english' '' '-c:v libx264 -preset ultrafast'