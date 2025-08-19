#!/bin/bash

# Script to generate all iOS app icon sizes from a source image
# Usage: ./generate_icons.sh <source_image_path>

SOURCE_IMAGE="$1"

if [ -z "$SOURCE_IMAGE" ] || [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Usage: $0 <source_image_path>"
    echo "Please provide a valid image file (PNG format recommended, at least 1024x1024)"
    exit 1
fi

# Create output directory
OUTPUT_DIR="Assets.xcassets/AppIcon.appiconset"
mkdir -p "$OUTPUT_DIR"

echo "Generating app icons from: $SOURCE_IMAGE"

# iOS App Icon sizes and filenames
declare -A icon_sizes=(
    ["20"]="icon-20@2x.png"
    ["29"]="icon-29@2x.png"
    ["40"]="icon-40@2x.png"
    ["60"]="icon-60@2x.png"
    ["30"]="icon-20@3x.png"
    ["43.5"]="icon-29@3x.png"
    ["60"]="icon-40@3x.png"
    ["90"]="icon-60@3x.png"
    ["1024"]="icon-1024.png"
)

# Alternative approach with explicit sizes
sizes=(
    "40:icon-20@2x.png"
    "60:icon-20@3x.png"
    "58:icon-29@2x.png"
    "87:icon-29@3x.png"
    "80:icon-40@2x.png"
    "120:icon-40@3x.png"
    "120:icon-60@2x.png"
    "180:icon-60@3x.png"
    "1024:icon-1024.png"
)

for size_info in "${sizes[@]}"; do
    size="${size_info%:*}"
    filename="${size_info#*:}"
    echo "Creating ${filename} (${size}x${size})"
    
    sips -z "$size" "$size" "$SOURCE_IMAGE" --out "$OUTPUT_DIR/$filename" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✓ Created $filename"
    else
        echo "✗ Failed to create $filename"
    fi
done

echo ""
echo "Icon generation complete!"
echo "Generated icons are in: $OUTPUT_DIR"
echo ""
echo "Next steps:"
echo "1. Open the Xcode project"
echo "2. The icons should automatically appear in the app icon set"
echo "3. Build and run your app to see the new icon"
