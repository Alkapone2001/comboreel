param(
  [switch]$SkipEpisodeEncoding
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$toolRoot = Join-Path $repositoryRoot '.content-tools'
$workspace = Join-Path $repositoryRoot '.content-workspace\sintel'
$sourcePath = Join-Path $workspace 'sintel-1024-surround.mp4'
$ffmpegZip = Join-Path $toolRoot 'ffmpeg-release-essentials.zip'
$ffmpegRoot = Join-Path $toolRoot 'ffmpeg'
$episodeRoot = Join-Path $workspace 'episodes'
$sourceUrl = 'https://peach.themazzone.com/durian/movies/sintel-1024-surround.mp4'
$ffmpegUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
$expectedHash = '1DC6F2CA9762DFCC7D1B1843129A3E4F351D1FE935DEA2241C7B359C11EBC1D8'

New-Item -ItemType Directory -Force -Path $toolRoot, $workspace, $episodeRoot | Out-Null

if (-not (Test-Path -LiteralPath $ffmpegZip)) {
  curl.exe -L --fail --retry 3 --output $ffmpegZip $ffmpegUrl
  if ($LASTEXITCODE -ne 0) { throw 'FFmpeg download failed.' }
}
if (-not (Test-Path -LiteralPath $ffmpegRoot)) {
  Expand-Archive -LiteralPath $ffmpegZip -DestinationPath $ffmpegRoot
}
$ffmpeg = Get-ChildItem -LiteralPath $ffmpegRoot -Recurse -Filter 'ffmpeg.exe' |
  Select-Object -First 1
if ($null -eq $ffmpeg) { throw 'Portable FFmpeg was not found after extraction.' }

if (-not (Test-Path -LiteralPath $sourcePath)) {
  curl.exe -L --fail --retry 3 --output $sourcePath $sourceUrl
  if ($LASTEXITCODE -ne 0) { throw 'Sintel master download failed.' }
}
$actualHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) {
  throw "Sintel master checksum mismatch: $actualHash"
}

$subtitleSource = Join-Path $workspace 'sintel_en.srt'
if (-not (Test-Path -LiteralPath $subtitleSource)) {
  curl.exe -L --fail --retry 3 --output $subtitleSource `
    'https://durian.blender.org/wp-content/content/subtitles/sintel_en.srt'
  if ($LASTEXITCODE -ne 0) { throw 'Sintel subtitle download failed.' }
}
& $ffmpeg.FullName -y -hide_banner -loglevel error -i $subtitleSource `
  (Join-Path $repositoryRoot 'assets\subtitles\sintel_en.vtt')
if ($LASTEXITCODE -ne 0) { throw 'Subtitle conversion failed.' }

if ($SkipEpisodeEncoding) {
  Write-Output 'Verified source and subtitles; skipped episode encoding.'
  exit 0
}

$manifest = Get-Content -LiteralPath (Join-Path $repositoryRoot 'content\sintel.demo.json') |
  ConvertFrom-Json
$videoFilter = '[0:v]split=2[bg][fg];[bg]scale=720:1280:force_original_aspect_ratio=increase,crop=720:1280,gblur=sigma=28[blur];[fg]scale=720:-2[front];[blur][front]overlay=(W-w)/2:(H-h)/2,format=yuv420p[outv]'

foreach ($episode in $manifest.episodes) {
  $duration = [int]$episode.end_seconds - [int]$episode.start_seconds
  $output = Join-Path $episodeRoot ('sintel-episode-{0:D2}.mp4' -f [int]$episode.number)
  & $ffmpeg.FullName -y -hide_banner -loglevel warning `
    -ss ([int]$episode.start_seconds) -t $duration -i $sourcePath `
    -filter_complex $videoFilter -map '[outv]' -map '0:a:0' `
    -c:v libx264 -preset ultrafast -crf 25 -maxrate 1800k -bufsize 3600k `
    -c:a aac -b:a 128k -movflags '+faststart' $output
  if ($LASTEXITCODE -ne 0) { throw "Encoding failed for episode $($episode.number)." }
}

Get-ChildItem -LiteralPath $episodeRoot -Filter '*.mp4' |
  Select-Object Name, Length
