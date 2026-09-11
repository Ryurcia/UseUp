import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  buildUserPrompt,
  KnownPrice,
  mapPricePer,
  MODEL,
  OPEN_PRICES_BASE,
  RESPONSE_SCHEMA,
  STALENESS_DAYS,
  SYSTEM_PROMPT,
} from './prompt.ts'

// Resolves the cost of one logged pantry item. Priority cascade, stop at the first hit:
//   1. the user's own confirmed price for this ingredient (ingredient_price_history), if fresh
//   2. Open Prices (prices.openfoodfacts.org) — only when a barcode is supplied; a miss is normal
//   3. a Gemini estimate — always available
// Whichever tier supplies a base price, the Gemini call still runs (it does the unit conversion).
// No quota: this never touches user_activity.

const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta'
const GEMINI_MODEL = `models/${MODEL}`
const OPEN_PRICES_MAX_AGE_MS = 365 * 86_400_000
const OPEN_PRICES_TIMEOUT_MS = 4_000

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

interface RequestBody {
  ingredientName?: string
  quantity?: number
  unit?: string
  unitCount?: number
  barcode?: string
}

interface CostResult {
  unit_price_usd: number | null
  total_price_usd: number | null
  conversion_applied: boolean
  confidence: number
}

class GeminiError extends Error {
  constructor(readonly status: number, readonly code: string, readonly detail: string) {
    super(code)
  }
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  })
}

// MARK: - Tier 1: confirmed personal history

async function personalBasePrice(
  admin: SupabaseClient,
  userId: string,
  ingredientKey: string,
): Promise<KnownPrice | null> {
  const { data } = await admin
    .from('ingredient_price_history')
    .select('unit_price, unit, last_updated')
    .eq('user_id', userId)
    .eq('ingredient_key', ingredientKey)
    .eq('source', 'personal')
    .maybeSingle()

  if (!data) return null
  const age = Date.now() - new Date(data.last_updated).getTime()
  if (age > STALENESS_DAYS * 86_400_000) return null

  return { unitPrice: Number(data.unit_price), unit: data.unit, source: 'personal' }
}

// MARK: - Tier 2: Open Prices (barcode only)

async function openPricesBasePrice(barcode: string): Promise<KnownPrice | null> {
  try {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), OPEN_PRICES_TIMEOUT_MS)
    const res = await fetch(
      `${OPEN_PRICES_BASE}/prices?product_code=${encodeURIComponent(barcode)}&order_by=-date&size=1`,
      { signal: controller.signal, headers: { Accept: 'application/json' } },
    )
    clearTimeout(timer)
    if (!res.ok) return null

    const json = await res.json()
    const row = json?.items?.[0]
    if (!row || typeof row.price !== 'number') return null
    if (row.currency && row.currency !== 'USD') return null
    if (row.date) {
      const age = Date.now() - new Date(row.date).getTime()
      if (age > OPEN_PRICES_MAX_AGE_MS) return null
    }

    return { unitPrice: row.price, unit: mapPricePer(row.price_per), source: 'openfoodfacts' }
  } catch {
    // Timeout, network error, sparse coverage — all normal. Fall through to the estimate.
    return null
  }
}

// MARK: - Tier 3: Gemini

// Retries on a 503 (model overloaded) up to 3 attempts total, exponential backoff. Any other
// status / transport error propagates immediately.
async function resolveWithModel(
  geminiKey: string,
  userPrompt: string,
): Promise<CostResult> {
  let res: Response | null = null
  for (let attempt = 0; attempt < 3; attempt++) {
    res = await fetch(`${GEMINI_BASE}/${GEMINI_MODEL}:generateContent?key=${geminiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
        contents: [{ role: 'user', parts: [{ text: userPrompt }] }],
        generationConfig: {
          responseMimeType: 'application/json',
          responseSchema: RESPONSE_SCHEMA,
          temperature: 0.2,
          thinkingConfig: { thinkingBudget: 0 },
        },
      }),
    })
    if (res.status !== 503) break
    if (attempt < 2) await sleep(Math.pow(2, attempt) * 1000)
  }

  if (!res!.ok) {
    throw new GeminiError(502, 'gemini_error', `${res!.status}: ${(await res!.text()).slice(0, 500)}`)
  }

  const parsed = await res!.json()
  const usage = parsed.usageMetadata ?? {}
  console.log(
    `[resolve-ingredient-cost] prompt=${usage.promptTokenCount ?? '?'} output=${
      usage.candidatesTokenCount ?? '?'
    } total=${usage.totalTokenCount ?? '?'}`,
  )

  const parts: Array<{ text?: string; thought?: boolean }> =
    parsed.candidates?.[0]?.content?.parts ?? []
  const textPart = [...parts].reverse().find((p) => p.thought == null && typeof p.text === 'string')
  if (!textPart?.text) {
    throw new GeminiError(502, 'empty_response', 'no text part in response')
  }

  try {
    return JSON.parse(textPart.text) as CostResult
  } catch {
    throw new GeminiError(502, 'parse_error', textPart.text.slice(0, 500))
  }
}

// MARK: - Handler

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return jsonResponse({ error: 'method_not_allowed' }, 405)
  }

  const jwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '')
  if (!jwt) {
    return jsonResponse({ error: 'unauthorized' }, 401)
  }

  const geminiKey = Deno.env.get('GEMINI_API_KEY')
  if (!geminiKey) {
    console.error('GEMINI_API_KEY is not set')
    return jsonResponse({ error: 'server_misconfigured' }, 500)
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  const { data: userData, error: userErr } = await admin.auth.getUser(jwt)
  if (userErr || !userData.user) {
    return jsonResponse({ error: 'unauthorized' }, 401)
  }
  const userId = userData.user.id

  let raw: RequestBody
  try {
    raw = await req.json()
  } catch {
    return jsonResponse({ error: 'invalid_json' }, 400)
  }

  const ingredientName = typeof raw.ingredientName === 'string' ? raw.ingredientName.trim() : ''
  const quantity = typeof raw.quantity === 'number' && raw.quantity > 0 ? raw.quantity : 1
  const unit = typeof raw.unit === 'string' && raw.unit.length > 0 ? raw.unit : 'whole'
  const unitCount = typeof raw.unitCount === 'number' && raw.unitCount >= 1
    ? Math.floor(raw.unitCount)
    : 1
  const barcode = typeof raw.barcode === 'string' && raw.barcode.length > 0 ? raw.barcode : null

  if (ingredientName.length === 0) {
    return jsonResponse({ error: 'missing_ingredient_name' }, 400)
  }

  const ingredientKey = ingredientName.toLowerCase()

  // Tier 1, then tier 2.
  let base = await personalBasePrice(admin, userId, ingredientKey)
  if (!base && barcode) {
    base = await openPricesBasePrice(barcode)
  }

  // Tier 3 — always runs (handles the unit conversion when a base price was found).
  let cost: CostResult
  try {
    cost = await resolveWithModel(
      geminiKey,
      buildUserPrompt({ ingredientName, quantity, unit, unitCount, knownPrice: base }),
    )
  } catch (e) {
    if (e instanceof GeminiError) {
      return jsonResponse({ error: e.code, detail: e.detail }, e.status)
    }
    console.error('[resolve-ingredient-cost] failed', e)
    return jsonResponse({ error: 'internal_error' }, 500)
  }

  return jsonResponse({
    unitPriceUsd: cost.unit_price_usd,
    totalPriceUsd: cost.total_price_usd,
    source: base?.source ?? 'estimate',
    conversionApplied: cost.conversion_applied === true,
    confidence: typeof cost.confidence === 'number' ? cost.confidence : 0,
  }, 200)
})
