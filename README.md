# H.265 Hardware-Accelerated Video Transcoder

A robust Bash script that transcodes video files to H.265 (HEVC) using hardware acceleration (NVIDIA NVENC or Intel QSV), with support for selective subtitle language filtering and audio track preservation.

## Features

- 🚀 **Hardware Acceleration** - Auto-detects and uses NVIDIA NVENC or Intel QSV for fast encoding
- 🎬 **Subtitle Preservation** - Extracts and re-adds subtitle streams with language filtering
- 🌍 **Language Filtering** - Keep only specific subtitle languages (e.g., English, Spanish)
- 🔊 **Audio Preservation** - Copies all audio tracks without re-encoding
- 📊 **Size Tracking** - Shows file size reduction per file and total
- 🎨 **Colored Output** - Easy-to-read progress with color-coded messages
- 🛡️ **Robust Error Handling** - Validates output and handles failures gracefully
- 🧹 **Auto Cleanup** - Removes temporary files, even on interruption (Ctrl+C)
- 📦 **Batch Processing** - Processes entire directories automatically
- 🔄 **Auto-Detection** - Automatically selects best available hardware encoder

## Requirements

### Hardware (at least one)
- **NVIDIA GPU** with NVENC support (GTX 600 series or newer), OR
- **Intel CPU** with Quick Sync Video (2nd gen Core or newer)
- Appropriate drivers installed

### Software
- `ffmpeg` compiled with NVENC and/or QSV support
- `ffprobe` (usually included with ffmpeg)
- Bash shell (Linux, macOS, WSL, Git Bash)

### Check Hardware Encoder Support
```bash
# Check for NVENC support
ffmpeg -hide_banner -encoders | grep hevc_nvenc

# Check for QSV support
ffmpeg -hide_banner -encoders | grep hevc_qsv
```

If you see either encoder, you're good to go! The script will auto-detect the best available option.

## Installation

1. **Clone or download the script:**
   ```bash
   git clone <your-repo-url>
   cd transcode_h265
   ```

2. **Make it executable:**
   ```bash
   chmod +x transcode_h265.sh
   ```

3. **Verify dependencies:**
   ```bash
   ./transcode_h265.sh -h
   ```

## Usage

### Basic Usage
```bash
# Transcode all videos in current directory
./transcode_h265.sh

# Transcode specific directory
./transcode_h265.sh /path/to/videos

# Specify input and output directories
./transcode_h265.sh /path/to/videos /path/to/output
```

### Help
```bash
./transcode_h265.sh -h
```

## Configuration

Edit the script to customize encoding settings:

```bash
HW_ACCEL="auto"       # Hardware encoder: auto, nvenc, qsv
PRESET="medium"       # Encoding speed/quality tradeoff
CRF="23"              # Quality level (lower = better quality)
SUBTITLE_LANGS=""     # Subtitle languages to keep (empty = all)
```

### HW_ACCEL Options
- `auto` - Auto-detect best available encoder (default)
- `nvenc` - Force NVIDIA NVENC
- `qsv` - Force Intel Quick Sync Video

### PRESET Options

**For NVENC:**
- `slow` - Best quality, slowest encoding
- `medium` - Balanced (default)
- `fast` - Faster encoding, slightly lower quality
- `hp` - High performance
- `hq` - High quality
- `bd` - Blu-ray disc
- `ll` - Low latency
- `llhq` - Low latency high quality
- `llhp` - Low latency high performance
- `lossless` - Lossless encoding

**For QSV:**
- `veryslow` - Best quality
- `slower` - Better quality
- `slow` - Good quality
- `medium` - Balanced (default)
- `fast` - Faster encoding
- `faster` - Very fast
- `veryfast` - Fastest encoding

### Subtitle Language Filtering

Set `SUBTITLE_LANGS` to keep only specific languages:

```bash
# Keep only English subtitles
SUBTITLE_LANGS="eng"

# Keep English and Spanish
SUBTITLE_LANGS="eng,spa"

# Keep English, French, and German
SUBTITLE_LANGS="eng,fre,ger"

# Keep all subtitles (default)
SUBTITLE_LANGS=""
```

**Common Language Codes:**
- `eng` - English
- `spa` - Spanish
- `fre` - French
- `ger` - German
- `ita` - Italian
- `por` - Portuguese
- `rus` - Russian
- `jpn` - Japanese
- `chi` - Chinese
- `kor` - Korean

### CRF (Quality) Guide
- `18-22` - Very high quality (large files)
- `23` - Default, good balance (recommended)
- `24-28` - Good quality, smaller files
- `28+` - Lower quality, very small files

## Supported Formats

### Video Containers
MP4, MKV, AVI, MOV, FLV, WMV, WebM, M4V, MPG, MPEG

### Subtitle Formats
- **Text-based** (fully supported): SRT, ASS, SSA, WebVTT
- **Bitmap** (may be skipped): PGS, DVD subtitles

### Audio
All audio codecs are preserved (copied without re-encoding)

## Output

- Files are saved as: `[original_name]_h265.mp4`
- Original files are **not modified**
- Output directory is created automatically

## Example Output

```
Detected: NVIDIA NVENC
H.265 Hardware-Accelerated Transcoder
Encoder: NVENC
Input directory: ./videos
Output directory: ./transcoded
Preset: medium
CRF: 23
Subtitle languages: eng,spa
----------------------------------------
Processing: movie.mkv
  Extracting subtitles...
  Skipping subtitle stream 2 (language: fre)
  Found 2 subtitle stream(s)
  Transcoding video...
  Adding subtitles to transcoded file...
✓ Success: movie.mkv (with 2 subtitle(s))
  Size: 4.2 GiB → 1.8 GiB (42%)
----------------------------------------
Transcoding Complete!
Total files processed: 1
Successful: 1
----------------------------------------
Storage Summary:
  Original total:   4.2 GiB
  Transcoded total: 1.8 GiB
  Space saved:      2.4 GiB (58% reduction)
```

## How It Works

1. **Extract Subtitles** - All subtitle streams are extracted to temporary files
2. **Transcode Video** - Video is transcoded to H.265 using NVENC, audio is copied
3. **Merge Subtitles** - Subtitles are added back to the transcoded file
4. **Validate & Cleanup** - Output is validated, temporary files are removed

## Error Handling

The script handles various error scenarios:

- **Missing dependencies** - Checks for ffmpeg, ffprobe, and NVENC
- **Transcoding failures** - Marks file as failed, continues with next file
- **Subtitle extraction failures** - Shows warning, continues without subtitles
- **Invalid output** - Validates file exists and is not empty
- **Interruption** - Cleans up temporary files on Ctrl+C

## Troubleshooting

### "No hardware encoder available (NVENC or QSV)"
- Ensure you have either:
  - NVIDIA GPU with NVENC support, OR
  - Intel CPU with Quick Sync Video support
- Update your drivers (NVIDIA or Intel)
- Verify ffmpeg is compiled with hardware support:
  ```bash
  ffmpeg -encoders | grep hevc_nvenc  # For NVENC
  ffmpeg -encoders | grep hevc_qsv    # For QSV
  ```

### "NVENC encoder not available" (when forcing NVENC)
- Ensure you have an NVIDIA GPU with NVENC support
- Update your NVIDIA drivers
- Verify ffmpeg is compiled with NVENC: `ffmpeg -encoders | grep nvenc`

### "QSV encoder not available" (when forcing QSV)
- Ensure you have an Intel CPU with Quick Sync Video
- Update your Intel graphics drivers
- Verify ffmpeg is compiled with QSV: `ffmpeg -encoders | grep qsv`
- On Linux, ensure `/dev/dri/renderD128` is accessible

### "ffmpeg is not installed"
Install ffmpeg with NVENC support:
- **Ubuntu/Debian**: `sudo apt install ffmpeg`
- **macOS**: `brew install ffmpeg`
- **Windows**: Download from [ffmpeg.org](https://ffmpeg.org/download.html)

### Subtitles not appearing
- Check if subtitles are bitmap format (PGS, DVD) - these may not be compatible
- Verify the player supports MP4 subtitle format (mov_text)
- Some players require manual subtitle track selection
- If using `SUBTITLE_LANGS`, ensure the language codes match exactly
- Check subtitle language codes with: `ffprobe -i video.mkv`

### Files are larger after transcoding
- Try lowering the CRF value (e.g., 20-22 for higher quality)
- Some videos may already be well-compressed
- H.265 typically saves 30-50% compared to H.264

## Performance Tips

- **NVENC** - Uses dedicated hardware, minimal impact on GPU gaming/rendering
- **QSV** - Uses integrated GPU, very efficient on Intel systems
- **CPU Usage** - Very low with hardware encoding
- **Parallel Processing** - Run multiple instances for different directories
- **SSD Storage** - Use SSD for temp files for faster I/O
- **Encoder Selection** - NVENC typically faster, QSV more power-efficient

## Limitations

- Only processes files in the specified directory (not subdirectories)
- Always outputs to MP4 container
- Bitmap subtitles (PGS, DVD) may not be compatible with MP4
- Requires either NVIDIA GPU or Intel CPU with Quick Sync (no AMD support)
- Subtitle language filtering requires proper language tags in source files

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is open source and available under the MIT License.

## Acknowledgments

- Built with [ffmpeg](https://ffmpeg.org/)
- Uses NVIDIA NVENC hardware acceleration
- Inspired by the need for efficient video library management

## Author

Created for efficient video transcoding with subtitle preservation.

---

**Note:** Always test with a sample file before processing your entire video library!
