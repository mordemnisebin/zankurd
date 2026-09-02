#!/bin/bash
set -e

TOUR_DIR="/Users/kocer/.gemini/antigravity-ide/brain/131aaef1-652e-4cfb-bd97-fc4a0a465fd9/tour"
mkdir -p "$TOUR_DIR"

DEVICE="CA57ACB3-4C9C-4CB6-AE25-7805B48A6F34"

echo "Starting tour test on device $DEVICE..."

flutter test integration_test/tour_all_screens_test.dart -d "$DEVICE" | while IFS= read -r line; do
  echo "$line"
  if [[ "$line" =~ CAPTURE_SCREENSHOT:\ (.*) ]]; then
    SCREEN_NAME="${BASH_REMATCH[1]}"
    # Remove carriage returns if any
    SCREEN_NAME=$(echo "$SCREEN_NAME" | tr -d '\r')
    echo "[Capture] Taking screenshot for $SCREEN_NAME..."
    xcrun simctl io "$DEVICE" screenshot "$TOUR_DIR/$SCREEN_NAME.png"
    echo "[Capture] Saved to $TOUR_DIR/$SCREEN_NAME.png"
  fi
done

echo "Tour complete! All screenshots captured."
