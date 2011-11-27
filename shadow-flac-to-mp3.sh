#!/bin/bash

ME="$0"

if [ ! -f "$ME" ]; then
  echo "Cannot find me: $ME"
  exit 1;
fi

INS=`mktemp -t 'shadow-flac-to-mp3XXXX'`
OUTS=`mktemp -t 'shadow-flac-to-mp3XXXX'`

exec 5>$INS
exec 6>$OUTS
exec 2>/dev/null

echo -n "Scanning dirs."

find "$1" -name \*.flac -print0 | while read -d $'\0' IF; do
  OF=`echo "$IF" | sed s/\.flac$/.mp3/g | sed s,"$1","$2",g`
  if [ ! \( -f "$OF" -a "$IF" -ot "$OF" -a "$ME" -ot "$OF" \) ]; then
    mkdir -p "${OF%/*}"
    (echo -n "$IF" && echo -ne '\0000') >&5
    (echo -n "$OF" && echo -ne '\0000') >&6
  fi
  echo -n .
done

echo
exec 5>&-
exec 6>&-

SCRIPT=`mktemp -t 'shadow-flac-to-mp3-fileXXXX.sh'`

cat <<FOO > "$SCRIPT"
#!/bin/bash

if [ ! -f "\$1" ]; then
  echo "No input, something bad happens"
  exit 1
fi

echo "\$1" "->" "\$2"
rm -f "\$2.part"

ARTIST=\`metaflac "\$1" --show-tag=ARTIST | sed s/.*=//g\`
TITLE=\`metaflac "\$1" --show-tag=TITLE | sed s/.*=//g\`
ALBUM=\`metaflac "\$1" --show-tag=ALBUM | sed s/.*=//g\`
TRACKNUMBER=\`metaflac "\$1" --show-tag=TRACKNUMBER | sed s/.*=//g\`
DATE=\`metaflac "\$1" --show-tag=DATE | sed s/.*=//g\`

(flac -c -d "\$1" | lame -m j -q 2 --cbr -b 320 - "\$2.part" && \
eyeD3 --set-encoding=utf8 -t "\$TITLE" -n "\${TRACKNUMBER:-0}" -a "\$ARTIST" -A "\$ALBUM" -Y "\$DATE" "\$2.part" >&2 && \
mv -f "\$2.part" "\$2") || rm -f "\$2.part"

if [ -f "\$2" ]; then
  exit 0
fi

echo "Failed to transcode file"
exit 1
FOO

chmod +x "$SCRIPT"

parallel -0 -j 3 -a "$INS" -a "$OUTS" "$SCRIPT" {1} {2}

rm -f "$SCRIPT" "$INS" "$OUTS"

