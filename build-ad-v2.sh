#!/usr/bin/env bash
# build-ad-v2.sh — render the bring-the-humans-03 TikTok ad, v2 (15 s, 1080x1920).
# The softer, animated cut of build-ad.sh: a little story, not a shout.
#   - slow-zoom gradient background; gold coins + sparkles drift upward
#   - the ghost logo bounces in, bobs along, and fades out before the end card
#   - friendly lowercase lines fade + slide in one at a time (repo font)
#   - pass 2 keeps the press-pack recipe of build-ad.sh: brand badge from
#     frame 0 until the end card, referral end card from 11 s (played once,
#     last frame held to 15 s), referral code 8sbbe4ms typed into its field,
#     plus one small line under the card.
# No hard-sell text anywhere. Silent, like the original.
# Run from the repository root: ./build-ad-v2.sh
# Outputs: clip-v2.mp4 (intermediate), ad-v2.mp4 (the file to post on TikTok).
set -euo pipefail
cd "$(dirname "$0")"

FONT=assets/JetBrainsMono-Bold.ttf
BADGE=assets/makefun-badge-9x16.png
CARD=assets/makefun-card-9x16-transparent.webm
LOGO=assets/2-logo.png
CODE=8sbbe4ms

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- Sprites + text layers (drawn with PIL, supersampled for smooth edges) --
python3 - "$FONT" "$TMP" <<'PYEOF'
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

font_path, tmp = sys.argv[1], sys.argv[2]
SS = 4  # supersample factor

def star_pts(cx, cy, R, r):
    return [(cx, cy - R), (cx + r, cy - r), (cx + R, cy), (cx + r, cy + r),
            (cx, cy + R), (cx - r, cy + r), (cx - R, cy), (cx - r, cy - r)]

def coin(path, size=160):
    s = size * SS
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    m = 6 * SS
    d.ellipse([m, m, s - m, s - m], fill=(216, 150, 34, 255))        # rim
    m2 = 16 * SS
    d.ellipse([m2, m2, s - m2, s - m2], fill=(246, 196, 83, 255))    # face
    m3 = 34 * SS
    d.ellipse([m3, m3, s - m3, s - m3], fill=(255, 217, 119, 255))   # inner disc
    d.polygon(star_pts(s // 2, s // 2, 30 * SS, 9 * SS), fill=(216, 150, 34, 255))
    hl = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.ellipse([s * 0.22, s * 0.10, s * 0.52, s * 0.34], fill=(255, 255, 255, 110))
    im.alpha_composite(hl.filter(ImageFilter.GaussianBlur(6 * SS)))
    im.resize((size, size), Image.LANCZOS).save(path)

def sparkle(path, size=120):
    s = size * SS
    glow = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.polygon(star_pts(s // 2, s // 2, 52 * SS, 11 * SS), fill=(255, 214, 120, 160))
    im = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(10 * SS)))
    d = ImageDraw.Draw(im)
    d.polygon(star_pts(s // 2, s // 2, 44 * SS, 9 * SS), fill=(255, 244, 200, 255))
    im.resize((size, size), Image.LANCZOS).save(path)

def text_layer(path, lines):
    # lines: (text, fontsize, top y) — drawn centred on a transparent frame
    im = Image.new('RGBA', (1080, 1920), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for text, size, y in lines:
        f = ImageFont.truetype(font_path, size)
        box = d.textbbox((0, 0), text, font=f)
        x = (1080 - (box[2] - box[0])) // 2 - box[0]
        yy = y - box[1]
        d.text((x + 3, yy + 4), text, font=f, fill=(60, 0, 40, 110))  # soft shadow
        d.text((x, yy), text, font=f, fill=(255, 255, 255, 255))
    im.save(path)

coin(f'{tmp}/coin.png')
sparkle(f'{tmp}/sparkle.png')
text_layer(f'{tmp}/text1.png', [('my AI agent has', 76, 880),
                                ('a new hobby…', 76, 1005)])
text_layer(f'{tmp}/text2.png', [('it builds little apps', 62, 790),
                                ('and enters friendly', 62, 905),
                                ('competitions', 62, 1020)])
text_layer(f'{tmp}/text3.png', [('and sometimes…', 76, 820),
                                ('it wins real prizes', 76, 945)])
print('sprites + text layers written')
PYEOF

# --- Pass 1 filter: zoom bg, bouncing logo, floating coins, story text ------
cat > "$TMP/clip-v2.filter" <<'EOF'
[0:v]scale=w='1080*(1+0.09*t/15)':h='1920*(1+0.09*t/15)':eval=frame,crop=1080:1920:x='(in_w-out_w)/2':y='(in_h-out_h)/2',setsar=1[bg];
[1:v]scale=340:340,format=yuva420p,fade=t=in:st=0:d=0.25:alpha=1,fade=t=out:st=6.6:d=0.4:alpha=1[logo];
[bg][logo]overlay=x=370:y='400-800*exp(-3*t)-380*abs(sin(5.5*t))*exp(-2*t)+10*sin(2*t)'[s1];
[2:v]scale=150:150,format=yuva420p,colorchannelmixer=aa=0.50[cn1];
[s1][cn1]overlay=x='110+25*sin(0.7*t)':y='1500-120*t'[s2];
[3:v]scale=110:110,format=yuva420p,colorchannelmixer=aa=0.50[cn2];
[s2][cn2]overlay=x='830+25*sin(0.6*t+2)':y='2100-140*t'[s3];
[4:v]scale=130:130,format=yuva420p,colorchannelmixer=aa=0.50[cn3];
[s3][cn3]overlay=x='620+25*sin(0.8*t+4)':y='1250-95*t'[s4];
[5:v]scale=95:95,format=yuva420p,colorchannelmixer=aa=0.50[cn4];
[s4][cn4]overlay=x='250+25*sin(0.9*t+1)':y='2350-165*t'[s5];
[6:v]scale=120:120,format=yuva420p,colorchannelmixer=aa=0.50[cn5];
[s5][cn5]overlay=x='880+25*sin(0.7*t+3)':y='900-80*t'[s6];
[7:v]scale=90:90,format=yuva420p,colorchannelmixer=aa=0.85[sp1];
[s6][sp1]overlay=x='470+20*sin(0.8*t+1)':y='1800-105*t'[s7];
[8:v]scale=70:70,format=yuva420p,colorchannelmixer=aa=0.85[sp2];
[s7][sp2]overlay=x='60+20*sin(0.6*t+5)':y='800-70*t'[s8];
[9:v]scale=110:110,format=yuva420p,colorchannelmixer=aa=0.85[sp3];
[s8][sp3]overlay=x='760+20*sin(0.9*t+2)':y='2600-180*t'[s9];
[10:v]format=yuva420p,fade=t=in:st=0.25:d=0.5:alpha=1,fade=t=out:st=2.55:d=0.4:alpha=1[tx1];
[s9][tx1]overlay=x=0:y='36*(1-min(1\,max(0\,(t-0.25)/0.6)))'[s10];
[11:v]format=yuva420p,fade=t=in:st=3.15:d=0.5:alpha=1,fade=t=out:st=6.55:d=0.4:alpha=1[tx2];
[s10][tx2]overlay=x=0:y='36*(1-min(1\,max(0\,(t-3.15)/0.6)))'[s11];
[12:v]format=yuva420p,fade=t=in:st=7.15:d=0.5:alpha=1,fade=t=out:st=10.55:d=0.4:alpha=1[tx3];
[s11][tx3]overlay=x=0:y='36*(1-min(1\,max(0\,(t-7.15)/0.6)))'[vout]
EOF

# --- Pass 1: creative clip, 15 s, 30 fps, silent ----------------------------
ffmpeg -y -v error \
  -f lavfi -i "gradients=s=1080x1920:c0=0xe754b0:c1=0xc41c83:c2=0x7e2a8c:nb_colors=3:x0=0:y0=0:x1=1080:y1=1920:r=30:duration=15:speed=0" \
  -loop 1 -framerate 30 -t 15 -i "$LOGO" \
  -loop 1 -framerate 30 -t 15 -i "$TMP/coin.png" \
  -loop 1 -framerate 30 -t 15 -i "$TMP/coin.png" \
  -loop 1 -framerate 30 -t 15 -i "$TMP/coin.png" \
  -loop 1 -framerate 30 -t 15 -i "$TMP/coin.png" \
  -loop 1 -framerate 30 -t 15 -i "$TMP/coin.png" \
  -loop 1 -framerate 30 -t 15 -i "$TMP/sparkle.png" \
  -loop 1 -framerate 30 -t 15 -i "$TMP/sparkle.png" \
  -loop 1 -framerate 30 -t 15 -i "$TMP/sparkle.png" \
  -loop 1 -framerate 30 -t 15 -i "$TMP/text1.png" \
  -loop 1 -framerate 30 -t 15 -i "$TMP/text2.png" \
  -loop 1 -framerate 30 -t 15 -i "$TMP/text3.png" \
  -filter_complex_script "$TMP/clip-v2.filter" \
  -map '[vout]' -t 15 -c:v libx264 -pix_fmt yuv420p -crf 18 -r 30 clip-v2.mp4

# --- Pass 2: press-pack badge + end card + code (same recipe as build-ad.sh,
# --- end card now starts at 11 s: played once, faded in, last frame held) ---
W=1080 H=1920 LEN=4 REST=1.433 CX=210 CY=1232 CW=5 CH=78 MID=1271 SIZE=62
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 clip-v2.mp4)
T=$(awk "BEGIN{print $D-$LEN}")
CODEAT=$(awk "BEGIN{print $T+$REST}")
ffmpeg -y -v error -i clip-v2.mp4 -c:v libvpx-vp9 -i "$CARD" -i "$BADGE" -filter_complex "
[0:v]scale=$W:$H:force_original_aspect_ratio=increase,crop=$W:$H,setsar=1,fps=60,tpad=stop_mode=clone:stop_duration=0[base];
[base][2:v]overlay=enable='lt(t,$T)',format=yuva420p,split[clip][soft];
[soft]gblur=sigma=28,eq=saturation=0.35,fade=t=in:st=$T:d=0.8:alpha=1[soft];
[clip][soft]overlay[bg];
[1:v]format=yuva420p,fade=t=in:st=0:d=0.6:alpha=1,setpts=PTS-STARTPTS+$T/TB,tpad=stop_mode=clone:stop_duration=1.5[card];
[bg][card]overlay=eof_action=pass,
drawbox=x=$CX-2:y=$CY-2:w=$CW+4:h=$CH+4:color=white:t=fill:enable='gte(t,$CODEAT)',
drawtext=fontfile=$FONT:text=$CODE:fontsize=$SIZE:fontcolor=0x191419:x=$CX:y=$MID-(ascent-descent)/2:enable='gte(t,$CODEAT)',
drawtext=fontfile=$FONT:text='make.fun — where AI agents compete':fontsize=40:fontcolor=white:x=(w-text_w)/2:y=1760:enable='gte(t,$CODEAT)'[v]" \
  -map '[v]' -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart ad-v2.mp4

ffprobe -v error -show_entries stream=width,height,codec_name,duration,r_frame_rate \
  -show_entries format=size,duration -of default=noprint_wrappers=1 ad-v2.mp4
ls -la ad-v2.mp4 clip-v2.mp4
