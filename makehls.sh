#!/bin/bash

HLS_OPTIONS='-start_number 0 -hls_time 4 -hls_playlist_type vod'
FFMPEG_OPTIONS='-hide_banner -y'
SEGMENT_FILENAME='%03d.ts'
PASSTHROUGH='-c:v copy'

# This is a debug function, place this where you want to enforce a wait
wait() {
	echo "Press any key to continue"
	while [ true ] ; do
		read -t 3 -n 1
		if [ $? = 0 ] ; then
			break
		fi
	done
}

printusage() {
	echo "Usage: makehls.sh <input.mkv> <outfile.m3u8> <outdir>"
}

# This is used to quickly check if the previous line ended with an error,
# it then propogates that error up and terminates the script.
checkerror() {
	local STATUS=$?

	if [ $STATUS -ne 0 ]; then
		echo "Program errored, aborting."
		exit 1
	fi
}

#Example usage: writemedia AUDIO audio eng English YES NO
writemedia() {
	local TYPE=$1
	local GROUPNAME=$2
	local SHORTNAME=$3
	local LONGNAME=$4
	local DEFAULT=$5
	local FORCED=$6

	echo "#EXT-X-MEDIA:TYPE=${TYPE},GROUP-ID=\"${GROUPNAME}\",LANGUAGE=\"${SHORTNAME}\",NAME=\"${LONGNAME}\",AUTOSELECT=${DEFAULT},DEFAULT=${DEFAULT},FORCED=${FORCED},URI=\"${RELATIVEOUTDIR}/${TYPE,,}/${SHORTNAME}/${SHORTNAME}.m3u8\"" >> ${OUTFILE}
}

#Example uasge: writestream source 5605600 '1920x1080' audio subtitles
writestream() {
	local VIDEO=$1
	local BANDWIDTH=$2
	local RESOLUTION=$3
	local AUDIO=$4
	local SUBTITLES=$5

	echo "#EXT-X-STREAM-INF:BANDWIDTH=${BANDWIDTH},RESOLUTION=${RESOLUTION},AUDIO=\"${AUDIO}\",SUBTITLES=\"${SUBTITLES}\"" >> ${OUTFILE}
	echo "${RELATIVEOUTDIR}/video/${VIDEO}/${VIDEO}.m3u8" >> ${OUTFILE}
}

# Example usage: makevideo 0:v:0 source 5605600 '1920x1080' 'audio' 'subtitles' '-preset ultrafast' test.mkv
makevideo() {
	local MAP=$1
	local SHORTNAME=$2
	local BANDWIDTH=$3
	local RESOLUTION=$4
	local AUDIO=$5
	local SUBTITLES=$6
	local ARGUMENTS=$7
	local VIDEO='placeholder'

	if [ $# -eq 8 ]; then
		VIDEO=$8
	else
		VIDEO=${INPUT}
	fi

	local MAPPEDRESOLUTION=`echo "${RESOLUTION}" | sed -r s/x+/:/g`

	mkdir -p video/${SHORTNAME}

	echo "Generating ${SHORTNAME} video stream..."
	ffmpeg -i ${VIDEO} ${FFMPEG_OPTIONS} ${ARGUMENTS} -b:v ${BANDWIDTH} -maxrate ${BANDWIDTH} -bufsize $((BANDWIDTH/4)) \
	 -vf scale=${MAPPEDRESOLUTION} -map ${MAP} ${HLS_OPTIONS} -hls_segment_filename video/${SHORTNAME}/${SEGMENT_FILENAME} \
 	 -f hls video/${SHORTNAME}/${SHORTNAME}.m3u8

 	checkerror

 	echo "Writing to master playlist..."

 	writestream ${SHORTNAME} ${BANDWIDTH} ${RESOLUTION} ${AUDIO} ${SUBTITLES}

 	echo "Done."
}

# Example usage: makesubs 0:s:0 subtitles eng English YES
makesubs() {
	local MAP=$1
	local GROUPNAME=$2
	local SHORTNAME=$3
	local LONGNAME=$4
	local DEFAULT=$5
	local VIDEO='placeholder'

	if [ $# -eq 6 ]; then
		VIDEO=$6
	else
		VIDEO=${INPUT}
	fi

	mkdir -p subtitles/${SHORTNAME}

	# Create Subtitle Stream, since ffmpeg can't create subtitle only runs,
	# also create a video stream
	echo "Generating ${LONGNAME} subtitles..."
	ffmpeg -i ${INPUT} ${FFMPEG_OPTIONS} ${PASSTHROUGH} -c:s webvtt -map 0:v:0 -map ${MAP} \
 	 ${HLS_OPTIONS} -hls_segment_filename subtitles/${SHORTNAME}/${SEGMENT_FILENAME} \
 	 -f hls subtitles/${SHORTNAME}/${SHORTNAME}.m3u8

	checkerror
	echo "Done."

	# Clean up the extra video stream that was created by ffmpeg when making sub streams
	echo "Cleaning up ${LONGNAME} subtitles..."
	cd subtitles/${SHORTNAME}/
	echo "Removing video-related files"
	rm -vfr *.ts
	rm -vfr ${SHORTNAME}.m3u8
	# Take care to ensure we have our original file names present.
	echo "Overwrite to expected subtitle playlist"
	mv ${SHORTNAME}_vtt.m3u8 ${SHORTNAME}.m3u8

	# Rename all vtt files to their original intended names
	echo "Rename part files for consistency"
	for f in *.vtt; do
    	mv "$f" "${f#*${SHORTNAME}}"
	done

	# Rename all occurances within the playlist file too
	echo "Repair playlist file"
	sed -e s/${SHORTNAME}//g -i ${SHORTNAME}.m3u8

	echo "Writing to master playlist..."
	writemedia SUBTITLES ${GROUPNAME} ${SHORTNAME} ${LONGNAME} ${DEFAULT} YES

	echo "Done."

	cd ../../
}

# Example usage: makeaudio 0:a:0 audio eng English YES
makeaudio() {
	local MAP=$1
	local GROUPNAME=$2
	local SHORTNAME=$3
	local LONGNAME=$4
	local DEFAULT=$5
	local VIDEO='placeholder'

	if [ $# -eq 6 ]; then
		VIDEO=$6
	else
		VIDEO=${INPUT}
	fi

	mkdir -p audio/${SHORTNAME}

	# Create Audio Stream
	echo "Generating ${LONGNAME} audio stream..."
	ffmpeg -i ${INPUT} ${FFMPEG_OPTIONS} -c:a aac -map ${MAP} \
 	 ${HLS_OPTIONS} -hls_segment_filename audio/jp/${SEGMENT_FILENAME} \
 	 -f hls audio/jp/jp.m3u8

 	checkerror

 	echo "Writing to master playlist..."

 	writemedia AUDIO ${GROUPNAME} ${SHORTNAME} ${LONGNAME} ${DEFAULT} NO

 	echo "Done."
}

if [ $# -ne 3 ]; then
	printusage
	exit 1
fi

INPUT=$1
OUTFILE=$2
OUTDIR=$3
RELATIVEOUTDIR=${OUTDIR}

rm -fr ${OUTFILE}

touch ${OUTFILE}

OUTFILE=`realpath ${OUTFILE}`

mkdir -p ${OUTDIR}

OUTDIR=`realpath ${OUTDIR}`

echo "#EXTM3U" >> ${OUTFILE}
echo "Write #EXTM3U to ${OUTFILE}"

# If new dir setup dir-structure
mkdir -p ${OUTDIR}/video/
mkdir -p ${OUTDIR}/audio/
mkdir -p ${OUTDIR}/subtitles/

INPUT=`realpath ${INPUT}`

cd ${OUTDIR}/

# Clean up old attempts
rm -vfr video/*
rm -vfr audio/*
rm -vfr subtitles/*

makeaudio 0:a:0 audio jp Japanese YES

makesubs 0:s:0 subtitles eng English YES
makesubs 0:s:2 subtitles spa Spanish NO
makesubs 0:s:5 subtitles ara Arabic NO

makevideo 0:v:0 source 5605600 '1920x1080' 'audio' 'subtitles' '-c:v libx264 -preset ultrafast'

echo "Done writing stream."