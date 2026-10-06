{ pkgs }:
pkgs.runCommand "mango-wallpapers" {
  nativeBuildInputs = [ pkgs.librsvg ];
} ''
  mkdir -p "$out"
  rsvg-convert -w 2560 -h 1440 ${./wallpaper.svg} -o "$out/mango-noctalia.png"
''
