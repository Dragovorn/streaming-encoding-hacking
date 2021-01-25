#!/bin/bash

HLS_OPTIONS='-start_number 0 -hls_time 4 -hls_playlist_type vod'
FFMPEG_OPTIONS='-hide_banner -y'
SEGMENT_FILENAME='%03d.ts'
PASSTHROUGH='-c:v copy'

# This is a debug function, place this where you want to enforce a wait
wait() {
	echo "makehls: press any key to continue"
	while [ true ] ; do
		read -t 3 -n 1
		if [ $? = 0 ] ; then
			break
		fi
	done
}

printusage() {
	echo "makehls: makehls.sh <blueprint.sh>"
}

# This is used to quickly check if the previous line ended with an error,
# it then propogates that error up and terminates the script.
checkerror() {
	local STATUS=$?

	if [ $STATUS -ne 0 ]; then
		echo "makehls: program errored, aborting."
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
	local AUDIOSTR=''
	local SUBTITLESTR=''

	if [ ! -z "${AUDIO}" ]; then
		AUDIOSTR="AUDIO=\"${AUDIO}\""

		if [ ! -z "${SUBTITLES}" ]; then
			AUDIOSTR+=','
		fi
	fi

	if [ ! -z "${SUBTITLES}" ]; then
		SUBTITLESTR="SUBTITLES=\"${SUBTITLES}\""
	fi

	echo "#EXT-X-STREAM-INF:BANDWIDTH=${BANDWIDTH},RESOLUTION=${RESOLUTION},${AUDIOSTR}${SUBTITLESTR}" >> ${OUTFILE}
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
	local DIR=${OUTDIR}/video/${SHORTNAME}

	local RESCALE="-vf scale=${MAPPEDRESOLUTION}"
	if [ "${ARGUMENTS}" = "-c:v copy" ]; then
		echo "RESCALE SET"
		RESCALE=""
	fi

	if [ ! -d "${DIR}" ]; then
		mkdir -p ${DIR}

		echo "makevideo: generating ${SHORTNAME} video stream..."

		ffmpeg -i ${VIDEO} ${FFMPEG_OPTIONS} ${ARGUMENTS} -b:v ${BANDWIDTH} -maxrate ${BANDWIDTH} -bufsize $((BANDWIDTH/4)) \
	 	 ${RESCALE} -map ${MAP} ${HLS_OPTIONS} -hls_segment_filename ${DIR}/${SEGMENT_FILENAME} \
 	 	 -f hls ${DIR}/${SHORTNAME}.m3u8

 		checkerror
	else
		echo "makevideo: video stream already exists, skipping encoding..."
	fi

 	echo "makevideo: writing to master playlist..."

 	writestream ${SHORTNAME} ${BANDWIDTH} ${RESOLUTION} ${AUDIO} ${SUBTITLES}

 	echo "makevideo: done"
}

# Example usage: makesubs 0:s:0 subtitles eng English YES
makesubs() {
	local MAP=$1
	local GROUPNAME=$2
	local SHORTNAME=$3
	local LONGNAME=$4
	local DEFAULT=$5
	local VIDEO='placeholder'
	local DIR=${OUTDIR}/subtitles/${SHORTNAME}

	if [ $# -eq 6 ]; then
		VIDEO=$6
	else
		VIDEO=${INPUT}
	fi

	mkdir -p ${DIR}

	# Create Subtitle Stream, since ffmpeg can't create subtitle only runs,
	# also create a video stream
	echo "makesubs: generating ${LONGNAME} subtitles..."
	ffmpeg -i ${INPUT} ${FFMPEG_OPTIONS} ${PASSTHROUGH} -c:s webvtt -map 0:v:0 -map ${MAP} \
 	 ${HLS_OPTIONS} -hls_segment_filename ${DIR}/${SEGMENT_FILENAME} \
 	 -f hls ${DIR}/${SHORTNAME}.m3u8

	checkerror

	# Clean up the extra video stream that was created by ffmpeg when making sub streams
	echo "makesubs: cleaning up ${LONGNAME} subtitles..."
	echo "makesubs: removing video-related files"
	rm -vfr ${DIR}/*.ts
	rm -vfr ${DIR}/${SHORTNAME}.m3u8
	# Take care to ensure we have our original file names present.
	echo "makesubs: overwrite to expected subtitle playlist"
	mv ${DIR}/${SHORTNAME}_vtt.m3u8 ${DIR}/${SHORTNAME}.m3u8

	# Rename all vtt files to their original intended names
	echo "makesubs: rename part files for consistency"
	for f in ${DIR}/*.vtt; do
    	BASE=`basename $f`
    	mv "$f" "${DIR}/${BASE#${SHORTNAME}}"
	done

	# Rename all occurances within the playlist file too
	echo "makesubs: repair playlist file"
	sed -e s/${SHORTNAME}//g -i ${DIR}/${SHORTNAME}.m3u8

	echo "makesubs: writing to master playlist..."
	writemedia SUBTITLES ${GROUPNAME} ${SHORTNAME} ${LONGNAME} ${DEFAULT} YES

	echo "make subs: done"
}

# Example usage: makeaudio 0:a:0 audio eng English YES
makeaudio() {
	local MAP=$1
	local GROUPNAME=$2
	local SHORTNAME=$3
	local LONGNAME=$4
	local DEFAULT=$5
	local VIDEO='placeholder'
	local DIR=${OUTDIR}/audio/${SHORTNAME}

	if [ $# -eq 6 ]; then
		VIDEO=$6
	else
		VIDEO=${INPUT}
	fi

	mkdir -p ${DIR}

	# Create Audio Stream
	echo "makeaudio: generating ${LONGNAME} audio stream..."
	ffmpeg -i ${INPUT} ${FFMPEG_OPTIONS} -c:a aac -map ${MAP} \
 	 ${HLS_OPTIONS} -hls_segment_filename ${DIR}/${SEGMENT_FILENAME} \
 	 -f hls ${DIR}/${SHORTNAME}.m3u8

 	checkerror

 	echo "makeaudio: writing to master playlist..."

 	writemedia AUDIO ${GROUPNAME} ${SHORTNAME} ${LONGNAME} ${DEFAULT} NO

 	echo "makeaudio: done"
}

# Example usage: burnin 0:v:0 0:s:0 burned_in
burnin() {
	local VIDEOMAP=$1
	local SUBMAP=$2
	local NAME=$3
	local DIR=${OUTDIR}/work/

	ffmpeg -i ${INPUT} ${FFMPEG_OPTIONS} -filter_complex "[${VIDEOMAP}][${SUBMAP}]overlay=eof_action=pass[v]" \
	 -map "[v]" ${DIR}/${NAME}.mkv

	echo "${DIR}/${NAME}.mkv"
}

setout() {
	if [ $# -ne 1 ]; then
		echo "setout: one argument is required for this function: outname"
		exit 1
	fi

	OUTDIR=$1
	RELATIVEOUTDIR=${OUTDIR}
	OUTDIR=`realpath ${OUTDIR}`
	OUTFILE=${OUTDIR}
	OUTFILE+='.m3u8'

	echo "setout: removing previous outfile..."
	rm -vfr ${OUTFILE}

	touch ${OUTFILE}

	echo "setout: creating outdir: ${OUTDIR}..."
	mkdir -p ${OUTDIR}

	echo "setout: appending hls metadata tags..."
	echo "#EXTM3U" >> ${OUTFILE}

	echo "setout: formatting outdir..."
	mkdir -p ${OUTDIR}/video/
	mkdir -p ${OUTDIR}/audio/
	mkdir -p ${OUTDIR}/subtitles/
	mkdir -p ${OUTDIR}/work/

	echo "setout: cleaning outdir..."
	rm -vfr ${OUTDIR}/video/*
	rm -vfr ${OUTDIR}/audio/*
	rm -vfr ${OUTDIR}/subtitles/*
	rm -vfr ${OUTDIR}/work/*
}

setin() {
	if [ $# -ne 1 ]; then
		echo "setin: one argument is required for this function: infile"
		exit 1
	fi

	INPUT=`realpath $1`

	echo "setin: input set to: ${INPUT}"
}

if [ $# -eq 0 ]; then
	printusage
	exit 1
fi

echo "makehls: processing $# blueprint file..."

BLUEPRINTS=$@

for BLUEPRINT in ${BLUEPRINTS}
do
	echo "makehls: executing blueprint: ${BLUEPRINT}"
	source ${BLUEPRINT}
done

echo "makehls: done executing"