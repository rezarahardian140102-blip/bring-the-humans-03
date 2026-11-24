#!/usr/bin/env bash
# build-ad.sh — render the bring-the-humans-03 TikTok ad (15 s, 1080x1920).
# Pass 1: the creative clip (magenta ground, mascot, on-screen text slides).
# Pass 2: the press-pack recipe — make.fun brand badge from frame 0, referral
# end card over the last 2.5 s, referral code 8sbbe4ms typed into its field.
# Run from the repository root: ./build-ad.sh
# Outputs: clip.mp4 (intermediate), ad.mp4 (the file to post on TikTok).
set -euo pipefail
cd "$(dirname "$0")"

FONT_TEXT=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf
FONT_CODE=assets/JetBrainsMono-Bold.ttf
BADGE=assets/makefun-badge-9x16.png
CARD=assets/makefun-card-9x16-transparent.webm
LOGO=assets/2-logo.png
CODE=8sbbe4ms

# --- Pass 1: creative clip, 15 s, 30 fps, silent ---------------------------
ffmpeg -y -v error \
  -f lavfi -i "color=c=0xc41c83:s=1080x1920:d=15:r=30" \
  -i "$LOGO" \
  -filter_complex_script clip.filter \
  -map '[vout]' -t 15 -c:v libx264 -pix_fmt yuv420p -crf 18 -r 30 clip.mp4

# --- Pass 2: press-pack badge + end card + code (llms.txt recipe) ----------
W=1080 H=1920 LEN=2.5 REST=1.433 CX=210 CY=1232 CW=5 CH=78 MID=1271 SIZE=62
HOLD=0
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 clip.mp4)
T=$(awk "BEGIN{print $D+$HOLD-$LEN}")
ffmpeg -y -v error -i clip.mp4 -c:v libvpx-vp9 -i "$CARD" -i "$BADGE" -filter_complex "
[0:v]scale=$W:$H:force_original_aspect_ratio=increase,crop=$W:$H,setsar=1,fps=60,tpad=stop_mode=clone:stop_duration=$HOLD[base];
[base][2:v]overlay=enable='lt(t,$T)',format=yuva420p,split[clip][soft];
[soft]gblur=sigma=28,eq=saturation=0.35,fade=t=in:st=$T:d=0.8:alpha=1[soft];
[clip][soft]overlay[bg];
[1:v]format=yuva420p,setpts=PTS-STARTPTS+$T/TB[card];
[bg][card]overlay=eof_action=pass,
drawbox=x=$CX-2:y=$CY-2:w=$CW+4:h=$CH+4:color=white:t=fill:enable='gte(t,$T+$REST)',
drawtext=fontfile=$FONT_CODE:text=$CODE:fontsize=$SIZE:fontcolor=0x191419:x=$CX:y=$MID-(ascent-descent)/2:enable='gte(t,$T+$REST)'[v]" \
  -map '[v]' -map '0:a?' -c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac -movflags +faststart ad.mp4

ffprobe -v error -show_entries stream=width,height,codec_name,duration,r_frame_rate \
  -show_entries format=size,duration -of default=noprint_wrappers=1 ad.mp4
ls -la ad.mp4 clip.mp4
