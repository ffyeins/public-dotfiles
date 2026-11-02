# Command Line

## Search files by name

```bash
find ~ -maxdepth 3 -type f -name 'XXXX' 2>/dev/null
find ~ -maxdepth 3 -type d -name 'XXXX' 2>/dev/null
```

## Fix missing cursor on terminal

When missing, dissapeared, hidden cursor, then run:

```bash
tput cnorm
```

## Interactive du with navigation

```bash
brew install ncdu

ncdu    # scan standing directory
ncdu ~  # scan home
ncdu /  # scan root
```

## Compress files

```bash
tar -czf filename.tar.gz *.txt
```

## `scp`: transfer files

```bash
scp *.mkv archserver:'/mnt/storage/jellyfin/media/shows/My Show Name/Season 1/'

scp -r 'E:\series\_pending\Steins Gate' archserver:/mnt/storage-4tb/data/media/movies/
```

## Sort contents ordered by date

```bash
ls -s modified -r | head -10
```

## MKV Subtitle Extraction

Note: Requires `mkvtoolnix` installed.

Use `ffprobe` to list tracks:

```bash
ffprobe -v quiet -select_streams s -show_entries stream=index:stream_tags=language,title -of compact 'filename.mkv'
```

To extract all subtitles from the `.mkv` files (first check track id and file extension):

```bash
for file in *.mkv; do
  mkvextract "$file" tracks 3:"${file%.mkv}.ass"
done
```
