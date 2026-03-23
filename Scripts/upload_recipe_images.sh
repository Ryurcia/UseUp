#!/bin/bash
# ============================================================
# Upload recipe images to Supabase Storage and generate SQL
# to update each recipe's image_path.
#
# Usage:
#   SERVICE_ROLE_KEY=ey... ./Scripts/upload_recipe_images.sh
#
# Or:
#   ./Scripts/upload_recipe_images.sh eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzeWNpcmV3Ymp5a3hud2F1YWlqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3Mjg5ODg3NSwiZXhwIjoyMDg4NDc0ODc1fQ.aIaI3Yr1pBwp-Yz_m9tDNH3qqj-WB8hijzidIT5K_2o
# ============================================================

set -euo pipefail

SERVICE_ROLE_KEY="${1:-${SERVICE_ROLE_KEY:-}}"

if [ -z "$SERVICE_ROLE_KEY" ]; then
  echo "Error: SERVICE_ROLE_KEY is required."
  echo "Usage: SERVICE_ROLE_KEY=ey... $0"
  echo "   or: $0 <service_role_key>"
  exit 1
fi

SUPABASE_URL="https://usycirewbjykxnwauaij.supabase.co"
USEUP_UUID="00000000-0000-0000-0000-000000555570"
BUCKET="recipe-images"
IMAGE_DIR="$(dirname "$0")/../Assets/RecipeImages"

# Map: recipe_uuid -> image_filename
declare -a RECIPES=(
  "a0000001-0000-4000-8000-000000000001:honey_garlic_salmon.jpg"
  "a0000001-0000-4000-8000-000000000002:carne_asada_tacos.jpg"
  "a0000001-0000-4000-8000-000000000003:wild_mushroom_risotto.jpg"
  "a0000001-0000-4000-8000-000000000004:teriyaki_chicken_donburi.jpg"
  "a0000001-0000-4000-8000-000000000005:butter_chicken.jpg"
  "a0000001-0000-4000-8000-000000000006:green_curry.jpg"
  "a0000001-0000-4000-8000-000000000007:kimchi_jjigae.jpg"
  "a0000001-0000-4000-8000-000000000008:mapo_tofu.jpg"
  "a0000001-0000-4000-8000-000000000009:ratatouille.jpg"
  "a0000001-0000-4000-8000-000000000010:chicken_souvlaki.jpg"
  "a0000001-0000-4000-8000-000000000011:sinigang_na_baboy.jpg"
  "a0000001-0000-4000-8000-000000000012:shakshuka.jpg"
  "a0000001-0000-4000-8000-000000000013:chicken_shawarma_bowl.jpg"
  "a0000001-0000-4000-8000-000000000014:pho_bo.jpg"
  "a0000001-0000-4000-8000-000000000015:crispy_carnitas.jpg"
  "a0000001-0000-4000-8000-000000000016:pasta_alla_norma.jpg"
  "a0000001-0000-4000-8000-000000000017:chana_masala.jpg"
  "a0000001-0000-4000-8000-000000000018:gyudon.jpg"
  "a0000001-0000-4000-8000-000000000019:pad_kra_pao.jpg"
  "a0000001-0000-4000-8000-000000000020:coq_au_vin.jpg"
)

echo "Uploading recipe images to Supabase Storage..."
echo "================================================"

SQL_UPDATES=""
FAILED=0

for entry in "${RECIPES[@]}"; do
  RECIPE_UUID="${entry%%:*}"
  FILENAME="${entry##*:}"
  FILEPATH="${IMAGE_DIR}/${FILENAME}"
  STORAGE_PATH="${USEUP_UUID}/${FILENAME}"

  if [ ! -f "$FILEPATH" ]; then
    echo "SKIP: $FILENAME (file not found)"
    FAILED=$((FAILED + 1))
    continue
  fi

  echo -n "Uploading $FILENAME... "

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST \
    "${SUPABASE_URL}/storage/v1/object/${BUCKET}/${STORAGE_PATH}" \
    -H "Authorization: Bearer ${SERVICE_ROLE_KEY}" \
    -H "Content-Type: image/jpeg" \
    --data-binary "@${FILEPATH}")

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "OK (${HTTP_CODE})"
    SQL_UPDATES="${SQL_UPDATES}UPDATE recipes SET image_path = '${STORAGE_PATH}' WHERE id = '${RECIPE_UUID}';\n"
  elif [ "$HTTP_CODE" = "409" ]; then
    echo "ALREADY EXISTS (409) — skipping"
    SQL_UPDATES="${SQL_UPDATES}UPDATE recipes SET image_path = '${STORAGE_PATH}' WHERE id = '${RECIPE_UUID}';\n"
  else
    echo "FAILED (${HTTP_CODE})"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "================================================"
echo "Done! ${FAILED} failures."
echo ""
echo "Run the following SQL in Supabase SQL Editor to set image_path on each recipe:"
echo ""
echo -e "$SQL_UPDATES"
