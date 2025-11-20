#!/bin/bash

# H.265 Hardware-Accelerated Video Transcoder
# Transcodes video files to H.265 using NVIDIA NVENC or Intel QSV hardware acceleration

# Show help message
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    cat << EOF
H.265 Hardware-Accelerated Video Transcoder
============================================

Transcodes video files to H.265 (HEVC) using hardware acceleration (NVIDIA NVENC or Intel QSV),
while preserving subtitles and audio tracks.

Usage:
  $0 [INPUT_DIR] [OUTPUT_DIR]
  $0 -h|--help

Arguments:
  INPUT_DIR   Directory containing video files (default: current directory)
  OUTPUT_DIR  Directory for transcoded files (default: ./transcoded)

Options:
  -h, --help  Show this help message

Configuration (edit script to change):
  HW_ACCEL         Hardware encoder: auto, nvenc, qsv (default: auto)
  PRESET           Encoding preset (default: medium)
                   NVENC: slow, medium, fast, hp, hq, bd, ll, llhq, llhp, lossless
                   QSV: veryslow, slower, slow, medium, fast, faster, veryfast
  CRF              Quality level: 0-51, lower is better quality (default: 23)
  SUBTITLE_LANGS   Comma-separated language codes to keep (default: all)
                   Examples: "eng", "eng,spa", "eng,fre,ger"
                   Leave empty to keep all subtitles

Supported Formats:
  Video: mp4, mkv, avi, mov, flv, wmv, webm, m4v, mpg, mpeg
  Subtitles: SRT, ASS, SSA, WebVTT (bitmap subtitles may be skipped)

Requirements:
  - ffmpeg with NVENC and/or QSV support
  - ffprobe
  - NVIDIA GPU (for NVENC) or Intel CPU with Quick Sync (for QSV)

Examples:
  $0                          # Transcode current directory (auto-detect encoder)
  $0 /path/to/videos          # Transcode specific directory
  $0 ./videos ./output        # Specify input and output directories

Output:
  Files are saved as: [original_name]_h265.mp4

EOF
    exit 0
fi

# Configuration
INPUT_DIR="${1:-.}"  # First argument or current directory
OUTPUT_DIR="${2:-./transcoded}"  # Second argument or ./transcoded
HW_ACCEL="auto"  # Options: auto, nvenc, qsv
PRESET="medium"  # Encoding preset (depends on encoder)
CRF="23"  # Quality: 0-51, lower is better quality (23 is default)
SUBTITLE_LANGS=""  # Comma-separated language codes (e.g., "eng,spa") or empty for all

# Supported video extensions
VIDEO_EXTENSIONS=("mp4" "mkv" "avi" "mov" "flv" "wmv" "webm" "m4v" "mpg" "mpeg")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo -e "${RED}Error: ffmpeg is not installed${NC}"
    exit 1
fi

# Check if ffprobe is installed
if ! command -v ffprobe &> /dev/null; then
    echo -e "${RED}Error: ffprobe is not installed${NC}"
    exit 1
fi

# Detect and configure hardware encoder
ENCODER=""
HWACCEL_DEVICE=""
ENCODER_NAME=""

if [[ "$HW_ACCEL" == "auto" ]]; then
    # Try NVENC first, then QSV
    if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_nvenc"; then
        ENCODER="hevc_nvenc"
        HWACCEL_DEVICE="cuda"
        ENCODER_NAME="NVENC"
        echo -e "${GREEN}Detected: NVIDIA NVENC${NC}"
    elif ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_qsv"; then
        ENCODER="hevc_qsv"
        HWACCEL_DEVICE="qsv"
        ENCODER_NAME="QSV"
        echo -e "${GREEN}Detected: Intel QSV${NC}"
    else
        echo -e "${RED}Error: No hardware encoder available (NVENC or QSV)${NC}"
        echo "Make sure you have:"
        echo "  - NVIDIA GPU with NVENC support, OR"
        echo "  - Intel CPU with Quick Sync Video support"
        echo "  - ffmpeg compiled with hardware encoder support"
        exit 1
    fi
elif [[ "$HW_ACCEL" == "nvenc" ]]; then
    if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_nvenc"; then
        echo -e "${RED}Error: NVENC (hevc_nvenc) encoder not available${NC}"
        echo "Make sure you have:"
        echo "  1. NVIDIA GPU with NVENC support"
        echo "  2. Proper NVIDIA drivers installed"
        echo "  3. ffmpeg compiled with NVENC support"
        exit 1
    fi
    ENCODER="hevc_nvenc"
    HWACCEL_DEVICE="cuda"
    ENCODER_NAME="NVENC"
elif [[ "$HW_ACCEL" == "qsv" ]]; then
    if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "hevc_qsv"; then
        echo -e "${RED}Error: QSV (hevc_qsv) encoder not available${NC}"
        echo "Make sure you have:"
        echo "  1. Intel CPU with Quick Sync Video support"
        echo "  2. ffmpeg compiled with QSV support"
        echo "  3. Proper Intel graphics drivers"
        exit 1
    fi
    ENCODER="hevc_qsv"
    HWACCEL_DEVICE="qsv"
    ENCODER_NAME="QSV"
else
    echo -e "${RED}Error: Invalid HW_ACCEL setting: $HW_ACCEL${NC}"
    echo "Valid options: auto, nvenc, qsv"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Trap to cleanup on script interruption
trap 'echo -e "\n${YELLOW}Script interrupted. Cleaning up temporary files...${NC}"; find "$OUTPUT_DIR" -name ".*_temp.mp4" -delete 2>/dev/null; find "$OUTPUT_DIR" -type d -name ".subtitles_*" -exec rm -rf {} + 2>/dev/null; exit 130' INT TERM

echo -e "${GREEN}H.265 Hardware-Accelerated Transcoder${NC}"
echo "Encoder: $ENCODER_NAME"
echo "Input directory: $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "Preset: $PRESET"
echo "CRF: $CRF"
if [ -n "$SUBTITLE_LANGS" ]; then
    echo "Subtitle languages: $SUBTITLE_LANGS"
else
    echo "Subtitle languages: all"
fi
echo "----------------------------------------"

# Counter for statistics
total_files=0
successful=0
failed=0
total_original_size=0
total_transcoded_size=0

# Function to transcode a single file
transcode_file() {
    local input_file="$1"
    local filename=$(basename "$input_file")
    local name="${filename%.*}"
    local ext="${filename##*.}"
    local unique_id="${name}_${ext}_$$"
    local output_file="$OUTPUT_DIR/${name}_h265.mp4"
    local temp_video="$OUTPUT_DIR/.${unique_id}_temp.mp4"
    local temp_dir="$OUTPUT_DIR/.subtitles_${unique_id}"
    
    # Skip if output file already exists
    if [ -f "$output_file" ]; then
        echo -e "${YELLOW}Skipping: $filename (already transcoded)${NC}"
        echo "----------------------------------------"
        return 0
    fi
    
    echo -e "${YELLOW}Processing: $filename${NC}"
    
    # Create temporary directory for subtitles
    mkdir -p "$temp_dir"
    
    # Step 1: Extract all subtitle streams
    echo "  Extracting subtitles..."
    local subtitle_count=$(ffprobe -v error -select_streams s -show_entries stream=index -of csv=p=0 "$input_file" 2>/dev/null | wc -l)
    
    local subtitle_files=()
    local subtitle_map_args=()
    local subtitle_metadata_args=()
    
    if [ "$subtitle_count" -gt 0 ]; then
        local stream_index=0
        local extracted_count=0
        while IFS= read -r stream_info; do
            local codec=$(echo "$stream_info" | cut -d'|' -f1)
            local title=$(echo "$stream_info" | cut -d'|' -f2)
            local language=$(echo "$stream_info" | cut -d'|' -f3)
            
            # Determine subtitle format based on codec
            local sub_ext="srt"
            local is_bitmap=false
            case "$codec" in
                ass|ssa)
                    sub_ext="ass"
                    ;;
                subrip|srt)
                    sub_ext="srt"
                    ;;
                webvtt)
                    sub_ext="vtt"
                    ;;
                dvd_subtitle|dvdsub)
                    sub_ext="sub"
                    is_bitmap=true
                    ;;
                hdmv_pgs_subtitle|pgssub)
                    sub_ext="sup"
                    is_bitmap=true
                    ;;
                *)
                    sub_ext="srt"  # Default fallback
                    ;;
            esac
            
            # Check if this subtitle language should be kept
            local keep_subtitle=true
            if [ -n "$SUBTITLE_LANGS" ]; then
                keep_subtitle=false
                IFS=',' read -ra LANG_ARRAY <<< "$SUBTITLE_LANGS"
                for lang_filter in "${LANG_ARRAY[@]}"; do
                    lang_filter=$(echo "$lang_filter" | xargs)  # Trim whitespace
                    if [[ "$language" == "$lang_filter" ]]; then
                        keep_subtitle=true
                        break
                    fi
                done
                
                if [ "$keep_subtitle" = false ]; then
                    echo -e "  ${YELLOW}Skipping subtitle stream ${stream_index} (language: ${language:-unknown})${NC}"
                    ((stream_index++))
                    continue
                fi
            fi
            
            # Warn about bitmap subtitles
            if [ "$is_bitmap" = true ]; then
                echo -e "  ${YELLOW}Warning: Bitmap subtitle detected (${codec}) - may not be compatible with MP4/mov_text${NC}"
            fi
            
            local subtitle_file="$temp_dir/subtitle_${stream_index}.${sub_ext}"
            
            # Extract subtitle stream
            if ffmpeg -i "$input_file" -map 0:s:${stream_index} "$subtitle_file" -hide_banner -loglevel error 2>/dev/null; then
                subtitle_files+=("$subtitle_file")
                subtitle_map_args+=("-i" "$subtitle_file")
                
                # Preserve metadata with correct output index
                [ -n "$language" ] && subtitle_metadata_args+=("-metadata:s:s:${extracted_count}" "language=${language}")
                [ -n "$title" ] && subtitle_metadata_args+=("-metadata:s:s:${extracted_count}" "title=${title}")
                
                ((extracted_count++))
            else
                echo -e "  ${RED}Warning: Failed to extract subtitle stream ${stream_index} (${codec})${NC}"
            fi
            
            ((stream_index++))
        done < <(ffprobe -v error -select_streams s -show_entries stream=codec_name:stream_tags=title,language -of csv=p=0 "$input_file" 2>/dev/null)
        
        if [ ${#subtitle_files[@]} -gt 0 ]; then
            echo "  Found ${#subtitle_files[@]} subtitle stream(s)"
        else
            echo -e "  ${YELLOW}Warning: No subtitles could be extracted${NC}"
        fi
    fi
    
    # Step 2: Transcode video to temporary file
    echo "  Transcoding video..."
    
    # Build ffmpeg command based on encoder
    if [[ "$ENCODER" == "hevc_nvenc" ]]; then
        if ! ffmpeg -hwaccel "$HWACCEL_DEVICE" -i "$input_file" \
            -c:v "$ENCODER" -preset "$PRESET" -rc vbr -cq "$CRF" -b:v 0 \
            -c:a copy \
            -map 0:v -map 0:a? \
            "$temp_video" \
            -hide_banner -loglevel error -stats; then
            
            echo -e "${RED}✗ Failed: $filename (transcoding)${NC}"
            rm -rf "$temp_dir"
            [ -f "$temp_video" ] && rm "$temp_video"
            ((failed++))
            echo "----------------------------------------"
            return 1
        fi
    elif [[ "$ENCODER" == "hevc_qsv" ]]; then
        if ! ffmpeg -hwaccel "$HWACCEL_DEVICE" -i "$input_file" \
            -c:v "$ENCODER" -preset "$PRESET" -global_quality "$CRF" \
            -c:a copy \
            -map 0:v -map 0:a? \
            "$temp_video" \
            -hide_banner -loglevel error -stats; then
            
            echo -e "${RED}✗ Failed: $filename (transcoding)${NC}"
            rm -rf "$temp_dir"
            [ -f "$temp_video" ] && rm "$temp_video"
            ((failed++))
            echo "----------------------------------------"
            return 1
        fi
    fi
    
    # Step 3: Add subtitles back to the transcoded file
    if [ ${#subtitle_files[@]} -gt 0 ]; then
        echo "  Adding subtitles to transcoded file..."
        
        # Build the subtitle mapping arguments
        local map_args=("-i" "$temp_video")
        map_args+=("${subtitle_map_args[@]}")
        map_args+=("-map" "0:v" "-map" "0:a?")
        
        # Map all subtitle files
        for i in "${!subtitle_files[@]}"; do
            map_args+=("-map" "$((i+1)):0")
        done
        
        # Add codec and metadata arguments
        map_args+=("-c:v" "copy" "-c:a" "copy" "-c:s" "mov_text")
        map_args+=("${subtitle_metadata_args[@]}")
        map_args+=("-movflags" "+faststart")
        
        if ffmpeg "${map_args[@]}" "$output_file" -hide_banner -loglevel error -stats; then
            # Validate output file
            if [ ! -f "$output_file" ] || [ ! -s "$output_file" ]; then
                echo -e "${RED}✗ Failed: $filename (output file invalid)${NC}"
                rm -rf "$temp_dir"
                [ -f "$temp_video" ] && rm "$temp_video"
                [ -f "$output_file" ] && rm "$output_file"
                ((failed++))
                echo "----------------------------------------"
                return 1
            fi
            
            # Calculate file sizes
            local original_size=$(stat -c%s "$input_file" 2>/dev/null || stat -f%z "$input_file" 2>/dev/null || echo 0)
            local transcoded_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo 0)
            total_original_size=$((total_original_size + original_size))
            total_transcoded_size=$((total_transcoded_size + transcoded_size))
            
            local size_percent=0
            if [ $original_size -gt 0 ]; then
                size_percent=$((100 * transcoded_size / original_size))
            fi
            
            echo -e "${GREEN}✓ Success: $filename (with ${#subtitle_files[@]} subtitle(s))${NC}"
            echo "  Size: $(numfmt --to=iec-i --suffix=B $original_size 2>/dev/null || echo "${original_size} bytes") → $(numfmt --to=iec-i --suffix=B $transcoded_size 2>/dev/null || echo "${transcoded_size} bytes") (${size_percent}%)"
            ((successful++))
        else
            echo -e "${RED}✗ Failed: $filename (adding subtitles)${NC}"
            # If adding subtitles fails, keep the transcoded video without subtitles
            if [ -f "$temp_video" ]; then
                mv "$temp_video" "$output_file"
                echo -e "${YELLOW}  Saved without subtitles${NC}"
                
                # Calculate file sizes
                local original_size=$(stat -c%s "$input_file" 2>/dev/null || stat -f%z "$input_file" 2>/dev/null || echo 0)
                local transcoded_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo 0)
                total_original_size=$((total_original_size + original_size))
                total_transcoded_size=$((total_transcoded_size + transcoded_size))
                
                local size_percent=0
                if [ $original_size -gt 0 ]; then
                    size_percent=$((100 * transcoded_size / original_size))
                fi
                echo "  Size: $(numfmt --to=iec-i --suffix=B $original_size 2>/dev/null || echo "${original_size} bytes") → $(numfmt --to=iec-i --suffix=B $transcoded_size 2>/dev/null || echo "${transcoded_size} bytes") (${size_percent}%)"
                ((successful++))
            else
                echo -e "${RED}  Temp file missing, marking as failed${NC}"
                ((failed++))
            fi
        fi
    else
        # No subtitles, just rename the temp file
        mv "$temp_video" "$output_file"
        
        # Validate output file
        if [ ! -f "$output_file" ] || [ ! -s "$output_file" ]; then
            echo -e "${RED}✗ Failed: $filename (output file invalid)${NC}"
            rm -rf "$temp_dir"
            [ -f "$output_file" ] && rm "$output_file"
            ((failed++))
            echo "----------------------------------------"
            return 1
        fi
        
        # Calculate file sizes
        local original_size=$(stat -c%s "$input_file" 2>/dev/null || stat -f%z "$input_file" 2>/dev/null || echo 0)
        local transcoded_size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo 0)
        total_original_size=$((total_original_size + original_size))
        total_transcoded_size=$((total_transcoded_size + transcoded_size))
        
        local size_percent=0
        if [ $original_size -gt 0 ]; then
            size_percent=$((100 * transcoded_size / original_size))
        fi
        
        echo -e "${GREEN}✓ Success: $filename (no subtitles)${NC}"
        echo "  Size: $(numfmt --to=iec-i --suffix=B $original_size 2>/dev/null || echo "${original_size} bytes") → $(numfmt --to=iec-i --suffix=B $transcoded_size 2>/dev/null || echo "${transcoded_size} bytes") (${size_percent}%)"
        ((successful++))
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    [ -f "$temp_video" ] && rm "$temp_video"
    
    echo "----------------------------------------"
}

# Find all video files first
echo "Searching for video files in: $INPUT_DIR"
declare -a video_files
for ext in "${VIDEO_EXTENSIONS[@]}"; do
    while IFS= read -r -d '' file; do
        video_files+=("$file")
        echo "Found: $(basename "$file")"
    done < <(find "$INPUT_DIR" -maxdepth 1 -type f -iname "*.${ext}" -print0)
done

echo "Total files found: ${#video_files[@]}"
echo ""

# Process all video files
for file in "${video_files[@]}"; do
    ((total_files++))
    transcode_file "$file"
done

echo "Processing complete. Total files processed: $total_files"

# Check if any files were found
if [ $total_files -eq 0 ]; then
    echo -e "${YELLOW}No video files found in: $INPUT_DIR${NC}"
    echo "Supported extensions: ${VIDEO_EXTENSIONS[*]}"
fi

# Print summary
echo -e "${GREEN}Transcoding Complete!${NC}"
echo "Total files processed: $total_files"
echo -e "${GREEN}Successful: $successful${NC}"
if [ $failed -gt 0 ]; then
    echo -e "${RED}Failed: $failed${NC}"
fi

# Print size comparison
if [ $total_original_size -gt 0 ]; then
    total_saved=$((total_original_size - total_transcoded_size))
    total_percent=$((100 * total_transcoded_size / total_original_size))
    echo "----------------------------------------"
    echo "Storage Summary:"
    echo "  Original total:   $(numfmt --to=iec-i --suffix=B $total_original_size 2>/dev/null || echo "${total_original_size} bytes")"
    echo "  Transcoded total: $(numfmt --to=iec-i --suffix=B $total_transcoded_size 2>/dev/null || echo "${total_transcoded_size} bytes")"
    if [ $total_saved -gt 0 ]; then
        echo -e "  ${GREEN}Space saved:      $(numfmt --to=iec-i --suffix=B $total_saved 2>/dev/null || echo "${total_saved} bytes") ($(( 100 - total_percent ))% reduction)${NC}"
    else
        echo -e "  ${YELLOW}Size increased:   $(numfmt --to=iec-i --suffix=B ${total_saved#-} 2>/dev/null || echo "${total_saved#-} bytes")${NC}"
    fi
fi