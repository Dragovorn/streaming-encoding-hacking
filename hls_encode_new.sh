HLS_OPTIONS='-start_number 0 -hls_time 4 -hls_playlist_type vod'
INPUT='-i ~/workspace/public/isshoni/encoding/test_2.mkv'
FFMPEG_OPTIONS='${INPUT} -hide_banner -y'
SEGMENT_FILENAME='%03d.ts'

cd stream/

m -vfr video/source/*
rm -vfr audio/jp/*
rm -vfr subtitle/eng/*

echo "Generating video stream..."
ffmpeg ${FFMPEG_OPTIONS} -c:v copy -map 0:v:0 \
 ${HLS_OPTIONS} -hls_segment_filename video/source/${SEGMENT_FILENAME} \
 -f hls video/source/source.m3u8

echo "Generating audio stream..."
ffmpeg ${FFMPEG_OPTIONS} -c:a aac -map 0:a:0 \
 ${HLS_OPTIONS} -hls_segment_filename audio/jp/${SEGMENT_FILENAME} \
 -f hls audio/jp/jp.m3u8

echo "Generating english subtitles..."
ffmpeg ${FFMPEG_OPTIONS} -c:v copy -c:s webvtt -map 0:v:0 -map 0:s:0 \
 ${HLS_OPTIONS} -hls_segment_filename subtitle/eng/${SEGMENT_FILENAME} \
 -f hls subtitle/eng/eng.m3u8

echo "Cleaning up english subtitles..."
cd subtitle/eng/
rm -vfr *.ts
rm -vfr eng.m3u8
mv eng_vtt.m3u8 eng.m3u8

for f in *.vtt; do
    mv "$f" "${f#*eng}"
done

sed -e s/eng//g -i eng.m3u8

echo "Done."


#ffmpeg -i test_2.mkv -hide_banner -y -c:v copy -c:a aac -c:s webvtt -start_number 0 \
# -hls_time 4 -hls_playlist_type vod -hls_segment_filename stream/video/source/ts-%v-%03d.ts \
# -map v:0 -map a:0 -map s:0 -var_stream_map "v:0,a:0,s:0" \
# -master_pl_name stream2.m3u8 \
# -f hls stream/video/source/ts-%v.m3u8