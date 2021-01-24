#!/bin/bash

HLS_OPTIONS='-start_number 0 -hls_time 4 -hls_playlist_type vod'
INPUT='-i ../test_2.mkv'
FFMPEG_OPTIONS='-hide_banner -y'
SEGMENT_FILENAME='%03d.ts'
LIBX264='-c:v libx264 -preset ultrafast'
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

# This is used to quickly check if the previous line ended with an error,
# it then propogates that error up and terminates the script.
checkerror() {
	STATUS=$?

	if [ $STATUS -ne 0 ]; then
		echo "Program errored, aborting."
		exit 1
	fi
}

# Example usage: makesubs 0:s:0 eng English
makesubs() {
	SUBMAP=$1
	SHORTLANG=$2
	LONGLANG=$3

	mkdir -p subtitle/${SHORTLANG}

	# Create Subtitle Stream, since ffmpeg can't create subtitle only runs,
	# also create a video stream
	echo "Generating ${LONGLANG} subtitles..."
	ffmpeg ${INPUT} ${FFMPEG_OPTIONS} ${PASSTHROUGH} -c:s webvtt -map 0:v:0 -map ${SUBMAP} \
 	 ${HLS_OPTIONS} -hls_segment_filename subtitle/${SHORTLANG}/${SEGMENT_FILENAME} \
 	 -f hls subtitle/${SHORTLANG}/${SHORTLANG}.m3u8

	checkerror

	# Clean up the extra video stream that was created by ffmpeg when making sub streams
	echo "Cleaning up ${LONGLANG} subtitles..."
	cd subtitle/${SHORTLANG}/
	rm -vfr *.ts
	rm -vfr ${SHORTLANG}.m3u8
	# Take care to ensure we have our original file names present.
	mv ${SHORTLANG}_vtt.m3u8 ${SHORTLANG}.m3u8

	# Rename all vtt files to their original intended names
	for f in *.vtt; do
    	mv "$f" "${f#*${SHORTLANG}}"
	done

	# Rename all occurances within the playlist file too
	sed -e s/${SHORTLANG}//g -i ${SHORTLANG}.m3u8

	cd ../../
}

cd stream/

# Clean up old attempts
m -vfr video/source/*
rm -vfr audio/jp/*
rm -vfr subtitle/eng/*

# Create Video Stream
echo "Generating video stream..."
ffmpeg ${INPUT} ${FFMPEG_OPTIONS} ${LIBX264} -map 0:v:0 \
 ${HLS_OPTIONS} -hls_segment_filename video/source/${SEGMENT_FILENAME} \
 -f hls video/source/source.m3u8

checkerror

# Create Audio Stream
echo "Generating audio stream..."
ffmpeg ${INPUT} ${FFMPEG_OPTIONS} -c:a aac -map 0:a:0 \
 ${HLS_OPTIONS} -hls_segment_filename audio/jp/${SEGMENT_FILENAME} \
 -f hls audio/jp/jp.m3u8

checkerror

makesubs 0:s:0 eng English

echo "Done."

#ffmpeg -i test_2.mkv -hide_banner -y -c:v copy -c:a aac -c:s webvtt -start_number 0 \
# -hls_time 4 -hls_playlist_type vod -hls_segment_filename stream/video/source/ts-%v-%03d.ts \
# -map v:0 -map a:0 -map s:0 -var_stream_map "v:0,a:0,s:0" \
# -master_pl_name stream2.m3u8 \
# -f hls stream/video/source/ts-%v.m3u8