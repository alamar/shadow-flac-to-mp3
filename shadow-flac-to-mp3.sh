#!/bin/bash

INS=`mktemp -t 'shadow-flac-to-mp3XXXX'`

exec 5>$INS
exec 2>/dev/null

echo -n "Scanning dirs."

find "$1" -name \*.flac -print0 | while read -d $'\0' IF; do
  OF=`echo "$IF" | sed s/\.flac$/.mp3/g | sed s,"$1","$2",g`
  if [ ! \( -f "$OF" -a "$IF" -ot "$OF" \) ]; then
    mkdir -p "${OF%/*}"
    (echo -n "$IF" && echo -ne '\t' && echo -n "$OF" && echo -ne '\0000') >&5
  fi
  echo -n .
done

echo
exec 5>&-

SCRIPT=`mktemp -t 'shadow-flac-to-mp3-fileXXXX.sh'`

cat << 'FOO' > "$SCRIPT"
#!/bin/bash

if [ ! -f "$1" ]; then
  echo "No input, something bad happens"
  exit 1
fi

echo "$1" "->" "$2"
rm -f "$2.part"

CHANNELS=`metaflac "$1" --show-channels`
ARTIST=`metaflac "$1" --show-tag=ARTIST | sed 's/[^=]*=//g'`
TITLE=`metaflac "$1" --show-tag=TITLE | sed 's/[^=]*=//g'`
ALBUM=`metaflac "$1" --show-tag=ALBUM | sed 's/[^=]*=//g'`
TRACKNUMBER=`metaflac "$1" --show-tag=TRACKNUMBER | sed 's/[^=]*=//g; s/\/.*//g'`
DATE=`metaflac "$1" --show-tag=DATE | sed 's/[^=]*=//g'; s/[ -].*//g`
COMMENT=`metaflac "$1" --show-tag=DESCRIPTION | sed 's/[^=]*=//g' | tr $'\n' ';' | sed 's/;*$//g'`

QUALITY="-m j --cbr -b 320"
if [ "$CHANNELS" -eq 1 ]; then
    QUALITY="-m m --cbr -b 192"
fi

DATEARGS=
if [ "$DATE" -gt 0 ]; then
    DATEARGS="--recording-date=$DATE -Y $DATE"
fi

(flac -c -d "$1" | lame -h $QUALITY  - "$2.part" && \
eyeD3 --encoding=utf8 -t "$TITLE" -n "${TRACKNUMBER:-0}" -a "$ARTIST" -A "$ALBUM" $DATEARGS -c "$COMMENT" "$2.part" >&2 && \
mv -f "$2.part" "$2") || rm -f "$2.part"

if [ -f "$2" -a "$1" -ot "$2" ]; then
  exit 0
fi

echo "Failed to transcode file"
exit 1
FOO

chmod +x "$SCRIPT"

parallel -0 -C $'\t' -j 3 -a "$INS" "$SCRIPT" {1} {2}

rm -f "$SCRIPT" "$INS"

echo -n "Copying over covers."
find "$1" -name \*.jpg -o -name \*.jpeg -o -name \*.png -o -name \*.gif -print0 | while read -d $'\0' IF; do
  OF=`echo "$IF" | sed s,"$1","$2",g`
  if [ ! \( -f "$OF" -a "$IF" -ot "$OF" \) ]; then
    cp "$IF" "$OF"
    echo -n .
  fi
done

echo
echo "Done!"

