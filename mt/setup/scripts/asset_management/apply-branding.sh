#!/bin/bash

# Asset Management for Open WebUI Deployments
# Downloads logos from URL and applies to container without storing on host

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

check_dependencies() {
    local missing_deps=()

    # Check for curl
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    # Check for ImageMagick (convert command)
    if ! command -v convert &> /dev/null; then
        missing_deps+=("imagemagick")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing required dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo
        echo "Install with:"
        echo "  sudo apt-get update && sudo apt-get install -y ${missing_deps[*]}"
        return 1
    fi

    return 0
}

generate_logo_variants() {
    local source_file="$1"
    local temp_dir="$2"

    echo -e "${BLUE}Generating logo variants...${NC}"
    echo -e "${BLUE}Note: Using high-quality Lanczos resampling filter${NC}"
    echo

    # Generate favicon.png (32x32) - preserve aspect ratio with high-quality filter
    if convert "$source_file" -filter Lanczos -resize 32x32 -background none -gravity center -extent 32x32 "$temp_dir/favicon.png" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} favicon.png (32x32)"
    else
        echo -e "${RED}✗${NC} Failed to generate favicon.png"
        return 1
    fi

    # Generate favicon-96x96.png - preserve aspect ratio with high-quality filter
    if convert "$source_file" -filter Lanczos -resize 96x96 -background none -gravity center -extent 96x96 "$temp_dir/favicon-96x96.png" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} favicon-96x96.png (96x96)"
    else
        echo -e "${RED}✗${NC} Failed to generate favicon-96x96.png"
        return 1
    fi

    # Generate favicon-dark.png (use same as favicon for now) - preserve aspect ratio with high-quality filter
    if convert "$source_file" -filter Lanczos -resize 32x32 -background none -gravity center -extent 32x32 "$temp_dir/favicon-dark.png" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} favicon-dark.png (32x32)"
    else
        echo -e "${RED}✗${NC} Failed to generate favicon-dark.png"
        return 1
    fi

    # Generate logo.png - preserve aspect ratio with high-quality filter
    if convert "$source_file" -filter Lanczos -resize 512x512 -background none -gravity center -extent 512x512 "$temp_dir/logo.png" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} logo.png (512x512, high-quality)"
    else
        echo -e "${RED}✗${NC} Failed to generate logo.png"
        return 1
    fi

    # Generate apple-touch-icon.png (180x180) - preserve aspect ratio with high-quality filter
    if convert "$source_file" -filter Lanczos -resize 180x180 -background none -gravity center -extent 180x180 "$temp_dir/apple-touch-icon.png" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} apple-touch-icon.png (180x180)"
    else
        echo -e "${RED}✗${NC} Failed to generate apple-touch-icon.png"
        return 1
    fi

    # Generate web-app-manifest-192x192.png - preserve aspect ratio with high-quality filter
    if convert "$source_file" -filter Lanczos -resize 192x192 -background none -gravity center -extent 192x192 "$temp_dir/web-app-manifest-192x192.png" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} web-app-manifest-192x192.png (192x192)"
    else
        echo -e "${RED}✗${NC} Failed to generate web-app-manifest-192x192.png"
        return 1
    fi

    # Generate web-app-manifest-512x512.png - preserve aspect ratio with high-quality filter
    if convert "$source_file" -filter Lanczos -resize 512x512 -background none -gravity center -extent 512x512 "$temp_dir/web-app-manifest-512x512.png" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} web-app-manifest-512x512.png (512x512)"
    else
        echo -e "${RED}✗${NC} Failed to generate web-app-manifest-512x512.png"
        return 1
    fi

    # Generate splash.png (for loading screens) - preserve aspect ratio with high-quality filter
    if convert "$source_file" -filter Lanczos -resize 512x512 -background none -gravity center -extent 512x512 "$temp_dir/splash.png" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} splash.png (512x512, high-quality)"
    else
        echo -e "${RED}✗${NC} Failed to generate splash.png"
        return 1
    fi

    # Generate splash-dark.png (same as splash for now) - preserve aspect ratio with high-quality filter
    if convert "$source_file" -filter Lanczos -resize 512x512 -background none -gravity center -extent 512x512 "$temp_dir/splash-dark.png" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} splash-dark.png (512x512, high-quality)"
    else
        echo -e "${RED}✗${NC} Failed to generate splash-dark.png"
        return 1
    fi

    # Generate favicon.ico (16x16 and 32x32 multi-resolution ICO) - preserve aspect ratio
    if convert "$source_file" \
        \( -clone 0 -resize 16x16 -background none -gravity center -extent 16x16 \) \
        \( -clone 0 -resize 32x32 -background none -gravity center -extent 32x32 \) \
        -delete 0 "$temp_dir/favicon.ico" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} favicon.ico (16x16, 32x32)"
    else
        echo -e "${RED}✗${NC} Failed to generate favicon.ico"
        return 1
    fi

    # Generate favicon.svg (convert PNG to SVG outline)
    # Note: This creates a simple SVG embedding the PNG - not a true vector conversion
    if convert "$source_file" -resize 32x32 -background none -flatten "$temp_dir/favicon-temp.png" 2>/dev/null; then
        # Create simple SVG wrapper
        local img_data=$(base64 -w 0 "$temp_dir/favicon-temp.png" 2>/dev/null || base64 "$temp_dir/favicon-temp.png")
        cat > "$temp_dir/favicon.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="32" height="32" viewBox="0 0 32 32">
  <image width="32" height="32" xlink:href="data:image/png;base64,$img_data"/>
</svg>
EOF
        rm -f "$temp_dir/favicon-temp.png"
        echo -e "${GREEN}✓${NC} favicon.svg (SVG wrapper)"
    else
        echo -e "${RED}✗${NC} Failed to generate favicon.svg"
        return 1
    fi

    return 0
}

apply_branding_to_container() {
    local container_name="$1"
    local temp_dir="$2"

    echo
    echo -e "${BLUE}Applying branding to container: $container_name${NC}"
    echo

    # Check if container exists and is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo -e "${RED}❌ Container '$container_name' is not running${NC}"
        return 1
    fi

    local files_to_copy=(
        "favicon.png"
        "favicon-96x96.png"
        "favicon-dark.png"
        "favicon.ico"
        "favicon.svg"
        "logo.png"
        "apple-touch-icon.png"
        "web-app-manifest-192x192.png"
        "web-app-manifest-512x512.png"
        "splash.png"
        "splash-dark.png"
    )

    # Container paths to update
    local backend_static="/app/backend/open_webui/static"
    local build_dir="/app/build"
    local build_static="/app/build/static"

    local success_count=0
    local total_count=0

    # Copy to backend static directory
    echo -e "${YELLOW}Copying to backend static directory...${NC}"
    for file in "${files_to_copy[@]}"; do
        if [ -f "$temp_dir/$file" ]; then
            ((total_count++))
            if docker cp "$temp_dir/$file" "$container_name:$backend_static/$file" 2>/dev/null; then
                echo -e "${GREEN}✓${NC} $backend_static/$file"
                ((success_count++))
            else
                echo -e "${YELLOW}⚠${NC} Failed to copy $file to backend static (may not exist)"
            fi
        fi
    done

    # Copy to build directory
    echo
    echo -e "${YELLOW}Copying to build directory...${NC}"
    for file in favicon.png logo.png; do
        if [ -f "$temp_dir/$file" ]; then
            ((total_count++))
            if docker cp "$temp_dir/$file" "$container_name:$build_dir/$file" 2>/dev/null; then
                echo -e "${GREEN}✓${NC} $build_dir/$file"
                ((success_count++))
            else
                echo -e "${YELLOW}⚠${NC} Failed to copy $file to build (may not exist)"
            fi
        fi
    done

    # Copy to build/static directory
    echo
    echo -e "${YELLOW}Copying to build/static directory...${NC}"
    for file in "${files_to_copy[@]}"; do
        if [ -f "$temp_dir/$file" ]; then
            ((total_count++))
            if docker cp "$temp_dir/$file" "$container_name:$build_static/$file" 2>/dev/null; then
                echo -e "${GREEN}✓${NC} $build_static/$file"
                ((success_count++))
            else
                echo -e "${YELLOW}⚠${NC} Failed to copy $file to build/static (may not exist)"
            fi
        fi
    done

    # Copy favicon to swagger-ui directory
    echo
    echo -e "${YELLOW}Copying to swagger-ui directory...${NC}"
    if [ -f "$temp_dir/favicon.png" ]; then
        ((total_count++))
        if docker cp "$temp_dir/favicon.png" "$container_name:$backend_static/swagger-ui/favicon.png" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} $backend_static/swagger-ui/favicon.png"
            ((success_count++))
        else
            echo -e "${YELLOW}⚠${NC} Failed to copy to swagger-ui (may not exist)"
        fi
    fi

    echo
    echo -e "${GREEN}✅ Branding applied: $success_count/$total_count files copied${NC}"
    echo

    # Restart container to ensure all static assets are reloaded
    echo -e "${BLUE}Restarting container to reload static assets...${NC}"
    if docker restart "$container_name" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Container restarted successfully"
        echo
        echo -e "${BLUE}ℹ${NC}  Container is restarting (this takes ~10-15 seconds)"
        echo -e "${BLUE}ℹ${NC}  Hard refresh browser (Ctrl+Shift+R) after container is ready"
        echo -e "${BLUE}ℹ${NC}  Check status: docker ps | grep $container_name"
    else
        echo -e "${YELLOW}⚠${NC} Failed to restart container (manual restart recommended)"
        echo -e "${BLUE}ℹ${NC}  Restart manually: docker restart $container_name"
    fi
    echo

    return 0
}

download_and_apply_branding() {
    local container_name="$1"
    local logo_url="$2"

    # Check dependencies first
    if ! check_dependencies; then
        return 1
    fi

    # Create temporary directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf '$temp_dir'" EXIT

    echo
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         Asset Management               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo
    echo "Container: $container_name"
    echo "Logo URL: $logo_url"
    echo

    # Download logo
    echo -e "${BLUE}Downloading logo from URL...${NC}"
    local source_logo="$temp_dir/source_logo.png"

    if curl -fsSL "$logo_url" -o "$source_logo" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Logo downloaded successfully"

        # Verify it's a valid image
        if ! file "$source_logo" | grep -qE 'image|PNG|JPEG|JPG'; then
            echo -e "${RED}❌ Downloaded file is not a valid image${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Failed to download logo from URL${NC}"
        echo "Please verify:"
        echo "  1. URL is correct and accessible"
        echo "  2. Network connectivity is working"
        echo "  3. File is a valid image (PNG, JPG)"
        return 1
    fi

    echo

    # Generate all logo variants
    if ! generate_logo_variants "$source_logo" "$temp_dir"; then
        echo -e "${RED}❌ Failed to generate logo variants${NC}"
        return 1
    fi

    echo

    # Apply branding to container
    if ! apply_branding_to_container "$container_name" "$temp_dir"; then
        return 1
    fi

    # Cleanup happens automatically via trap
    return 0
}

# If script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ $# -ne 2 ]; then
        echo "Usage: $0 CONTAINER_NAME LOGO_URL"
        echo
        echo "Example:"
        echo "  $0 openwebui-acme https://example.com/logo.png"
        exit 1
    fi

    download_and_apply_branding "$1" "$2"
fi
