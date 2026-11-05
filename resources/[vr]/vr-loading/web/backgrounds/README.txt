Put background pictures (jpg/png/webp) and videos (webm/mp4) here and list them in ../config.js under backgrounds.
Videos: no sound track, 1080p or smaller, 10 to 30 seconds, looped. WebM (VP9) is the smallest. To make one with ffmpeg:
  ffmpeg -i input.mp4 -t 25 -vf "scale=1920:-2,fps=30" -c:v libvpx-vp9 -crf 35 -b:v 0 -an out.webm
