// Pure module — no network, no Deno.serve — so the unit tests can import it without starting the
// edge-function server. `index.ts` is the only other importer.
//
// Source of truth for the ingredient cost-estimation prompt + schema. The function resolves a
// base price via a cascade (confirmed personal history -> Open Prices for a barcode -> nothing)
// and always runs the result through this prompt: it either converts a known price to the logged
// quantity/unit, or estimates from scratch when there's no base price.

export const MODEL = 'gemini-2.5-flash'

// A confirmed personal price older than this is treated as no history and falls through the
// cascade. Mirrored in the Swift client only implicitly (the client never checks staleness —
// the function is authoritative). Flagged for tuning.
export const STALENESS_DAYS = 60

export const OPEN_PRICES_BASE = 'https://prices.openfoodfacts.org/api/v1'

export const SYSTEM_PROMPT =
  `You estimate the US grocery cost of a single pantry item a user just logged.

You are given: the ingredient name, the quantity and unit the user logged, an optional
unit_count (how many of that size they have), and OPTIONALLY a known reference price with its
own unit and where it came from (the user's own past confirmed price, or a crowdsourced price
for this exact product).

Rules:
- If a reference price is given, treat it as ground truth. Your job is unit conversion, not
  re-estimation: convert that price to the user's logged quantity and unit and return it. Only
  adjust the number if the reference is clearly a different pack size than what was logged
  (e.g. reference is "per case", user logged one can). Set conversion_applied to true whenever
  the reference unit differs from the logged unit.
- If no reference price is given, estimate from typical US supermarket prices — mid-range,
  store-brand-ish, national average, present day. Set conversion_applied to false.
- unit_price_usd is the price for ONE of the user's logged unit (e.g. per lb, per cup, per
  whole item).
- total_price_usd is the price for the full logged amount: quantity x unit_price, then x
  unit_count if unit_count > 1.
- confidence is 0 to 1. Use a high value only when you have a reference price or the item and
  unit are common and unambiguous. Lower it for vague names ("sauce"), ambiguous units, bulk
  bin items, or anything you are guessing at without a reference.
- Currency is USD. Round both prices to cents.
- If the item is not food, or cannot be sensibly priced, return null for both prices and
  confidence 0.

Return only the JSON object described by the schema.`

export const RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    unit_price_usd: { type: 'NUMBER', nullable: true },
    total_price_usd: { type: 'NUMBER', nullable: true },
    conversion_applied: { type: 'BOOLEAN' },
    confidence: { type: 'NUMBER' },
  },
  required: ['unit_price_usd', 'total_price_usd', 'conversion_applied', 'confidence'],
} as const

export interface KnownPrice {
  unitPrice: number
  unit: string
  source: 'personal' | 'openfoodfacts'
}

export interface CostPromptInput {
  ingredientName: string
  quantity: number
  unit: string
  unitCount: number
  knownPrice: KnownPrice | null
}

export function buildUserPrompt(input: CostPromptInput): string {
  const { ingredientName, quantity, unit, unitCount, knownPrice } = input

  const lines = [
    `Ingredient: ${ingredientName}`,
    `Logged quantity: ${quantity} ${unit}`,
    `Unit count: ${unitCount}`,
  ]

  if (knownPrice) {
    const label = knownPrice.source === 'personal'
      ? "the user's own previously confirmed price"
      : 'a crowdsourced price for this exact product'
    lines.push(
      `Reference price: $${knownPrice.unitPrice.toFixed(2)} per ${knownPrice.unit} (${label}). ` +
        `Convert this to the logged quantity and unit.`,
    )
  } else {
    lines.push('No reference price — estimate from scratch.')
  }

  return lines.join('\n')
}

// Open Prices `price_per` enum -> the unit vocabulary the app uses.
export function mapPricePer(pricePer: string | null | undefined): string {
  switch ((pricePer ?? '').toUpperCase()) {
    case 'KILOGRAM':
      return 'kg'
    case 'UNIT':
      return 'whole'
    default:
      return 'whole'
  }
}
