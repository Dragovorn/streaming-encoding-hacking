#!/bin/bash

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

checkerror() {
	STATUS=$?

	if [ $STATUS -ne 0 ]; then
		echo "Program errored, aborting."
		exit 1
	fi
}

HLS_OPTIONS='-start_number 0 -hls_time 4 -hls_playlist_type vod'
INPUT='-i ../test_2.mkv'
FFMPEG_OPTIONS='-hide_banner -y'
SEGMENT_FILENAME='%03d.ts'

cd stream/

# Clean up old attempts
m -vfr video/source/*
rm -vfr audio/jp/*
rm -vfr subtitle/eng/*

# Create Video Stream
echo "Generating video stream..."
ffmpeg ${INPUT} ${FFMPEG_OPTIONS} -c:v 264 -map 0:v:0 \
 ${HLS_OPTIONS} -hls_segment_filename video/source/${SEGMENT_FILENAME} \
 -f hls video/source/source.m3u8

checkerror

# Create Audio Stream
echo "Generating audio stream..."
ffmpeg ${INPUT} ${FFMPEG_OPTIONS} -c:a aac -map 0:a:0 \
 ${HLS_OPTIONS} -hls_segment_filename audio/jp/${SEGMENT_FILENAME} \
 -f hls audio/jp/jp.m3u8

checkerror

# Create Subtitle Stream, since ffmpeg can't create subtitle only runs,
# also create a video stream
echo "Generating english subtitles..."
ffmpeg ${INPUT} ${FFMPEG_OPTIONS} -c:v copy -c:s webvtt -map 0:v:0 -map 0:s:0 \
 ${HLS_OPTIONS} -hls_segment_filename subtitle/eng/${SEGMENT_FILENAME} \
 -f hls subtitle/eng/eng.m3u8

checkerror

# Clean up the extra video stream that was created by ffmpeg when making sub streams
echo "Cleaning up english subtitles..."
cd subtitle/eng/
rm -vfr *.ts
rm -vfr eng.m3u8
# Take care to ensure we have our original file names present.
mv eng_vtt.m3u8 eng.m3u8

# Rename all vtt files to their original intended names
for f in *.vtt; do
    mv "$f" "${f#*eng}"
done

# Rename all occurances within the playlist file too
sed -e s/eng//g -i eng.m3u8

echo "Done."


#ffmpeg -i test_2.mkv -hide_banner -y -c:v copy -c:a aac -c:s webvtt -start_number 0 \
# -hls_time 4 -hls_playlist_type vod -hls_segment_filename stream/video/source/ts-%v-%03d.ts \
# -map v:0 -map a:0 -map s:0 -var_stream_map "v:0,a:0,s:0" \
# -master_pl_name stream2.m3u8 \
# -f hls stream/video/source/ts-%v.m3u8