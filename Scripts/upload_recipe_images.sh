#!/bin/bash
# ============================================================
# UseUp — Seed Recipe Image Uploader
# Downloads a matching food photo for each seed recipe and
# uploads it to Supabase Storage (recipe-images bucket).
#
# Requirements: curl, python3
# Usage:        bash scripts/upload_recipe_images.sh
# ============================================================

set -euo pipefail

SUPABASE_URL="https://usycirewbjykxnwauaij.supabase.co"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeWNpcmV3Ymp5a3hud2F1YWlqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Mjg5ODg3NSwiZXhwIjoyMDg4NDc0ODc1fQ.aIaI3Yr1pBwp-Yz_m9tDNH3qqj-WB8hijzidIT5K_2o"
BUCKET="recipe-images"
TMP_DIR="/tmp/useup_seed_$$"

mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

# ── upload_image(uuid, mealdb_query, fallback_unsplash_photo_id) ──────────────
# 1. Searches TheMealDB (free, no key) for a matching food photo
# 2. Falls back to a curated Unsplash photo if not found
# 3. Uploads to Supabase Storage with upsert (safe to re-run)
upload_image() {
  local uuid="$1"
  local query="$2"
  local fallback_photo_id="$3"
  local dest="seeds/${uuid}.jpg"
  local tmp="${TMP_DIR}/${uuid}.jpg"

  printf "  %-42s" "${query}"

  # --- 1. TheMealDB lookup ---
  local encoded
  encoded=$(python3 -c \
    "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" \
    "$query" 2>/dev/null || echo "${query// /+}")

  local img_url=""
  img_url=$(curl -sf --max-time 10 \
    "https://www.themealdb.com/api/json/v1/1/search.php?s=${encoded}" \
    | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    meals = d.get('meals') or []
    print(meals[0]['strMealThumb'] if meals else '')
except Exception:
    print('')
" 2>/dev/null) || img_url=""

  local source="TheMealDB"
  if [ -z "$img_url" ]; then
    img_url="https://images.unsplash.com/${fallback_photo_id}?auto=format&fit=crop&w=800&q=80"
    source="Unsplash "
  fi

  # --- 2. Download ---
  if ! curl -sfL --max-time 20 "$img_url" -o "$tmp" 2>/dev/null; then
    printf "${RED}✗ download failed${NC}\n"
    return
  fi

  # Sanity-check file size (real image should be > 10KB)
  local size
  size=$(wc -c < "$tmp" 2>/dev/null || echo 0)
  if [ "$size" -lt 10000 ]; then
    printf "${YELLOW}✗ file too small (${size}B) — skipping${NC}\n"
    return
  fi

  # --- 3. Upload to Supabase Storage ---
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${SUPABASE_URL}/storage/v1/object/${BUCKET}/${dest}" \
    -H "Authorization: Bearer ${SERVICE_KEY}" \
    -H "Content-Type: image/jpeg" \
    -H "x-upsert: true" \
    --data-binary @"$tmp")

  if [ "$http_code" = "200" ]; then
    printf "${GREEN}✓ %-12s${NC}\n" "($source)"
  else
    printf "${RED}✗ HTTP ${http_code}${NC}\n"
  fi
}

echo ""
echo "UseUp — Uploading 20 recipe seed images"
echo "════════════════════════════════════════════════════════════"
echo ""

#  uuid                                    TheMealDB search term      Unsplash fallback photo-id
upload_image \
  "a0000001-0000-4000-8000-000000000021" "Spaghetti Carbonara"      "photo-1612874742237-6526221588e3"

upload_image \
  "a0000001-0000-4000-8000-000000000022" "Chicken Tikka Masala"     "photo-1565557623262-b51c2513a641"

upload_image \
  "a0000001-0000-4000-8000-000000000023" "Buddha Bowl"              "photo-1512621776951-a57141f2eefd"

upload_image \
  "a0000001-0000-4000-8000-000000000024" "Beef Bulgogi"             "photo-1590301157890-4810ed352733"

upload_image \
  "a0000001-0000-4000-8000-000000000025" "Egg Breakfast Bowl"       "photo-1484723091739-30990ff56fba"

upload_image \
  "a0000001-0000-4000-8000-000000000026" "Pad Thai"                 "photo-1559314809-0d155014e29e"

upload_image \
  "a0000001-0000-4000-8000-000000000027" "Moussaka"                 "photo-1600891964092-4316c288032e"

upload_image \
  "a0000001-0000-4000-8000-000000000028" "Falafel"                  "photo-1547592181-eb5abfed09c2"

upload_image \
  "a0000001-0000-4000-8000-000000000029" "Birria Tacos"             "photo-1604467794349-0b74285de7e7"

upload_image \
  "a0000001-0000-4000-8000-000000000030" "Tonkotsu Ramen"           "photo-1569050467447-ce54b3bbc37d"

upload_image \
  "a0000001-0000-4000-8000-000000000031" "French Onion Soup"        "photo-1547592166-23ac45744acd"

upload_image \
  "a0000001-0000-4000-8000-000000000032" "Salmon Poke Bowl"         "photo-1519708227418-c8fd9a32b7a2"

upload_image \
  "a0000001-0000-4000-8000-000000000033" "Miso Glazed Cod"          "photo-1551326844-4df70f2d7c82"

upload_image \
  "a0000001-0000-4000-8000-000000000034" "Char Siu Pork"            "photo-1563245372-f21724e3856d"

upload_image \
  "a0000001-0000-4000-8000-000000000035" "Palak Paneer"             "photo-1574653853027-5382a3d23a15"

upload_image \
  "a0000001-0000-4000-8000-000000000036" "Tom Yum Goong"            "photo-1569718212165-3a8278d5f624"

upload_image \
  "a0000001-0000-4000-8000-000000000037" "Beef Bourguignon"         "photo-1534939561126-855b8675edd7"

upload_image \
  "a0000001-0000-4000-8000-000000000038" "Dal Fry"                  "photo-1547592180-85f173990554"

upload_image \
  "a0000001-0000-4000-8000-000000000039" "Paella"                   "photo-1534080564583-6be75777b70a"

upload_image \
  "a0000001-0000-4000-8000-000000000040" "Acai Bowl"                "photo-1490323914169-4b82b5d34fc6"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "Done. Check Supabase Storage → recipe-images/seeds/"
echo ""
