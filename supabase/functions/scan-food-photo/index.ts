import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  ESCALATION_CONFIDENCE_THRESHOLD,
  LITE_MODEL,
  RESPONSE_SCHEMA,
  STANDARD_MODEL,
  SYSTEM_PROMPT,
} from './prompt.ts'

// Proxies food-photo identification to Gemini so the API key never ships in the app binary. The
// client uploads a compressed JPEG (base64); this function runs the two-tier scan (cheap lite
// model, escalating to the standard model on an empty / low-confidence / errored lite result),
// records one `photo_scan_events` telemetry row, and returns { items: ScannedFoodItem[] }.

const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta'

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))

interface ScannedFoodItem {
  name: string
  category: string
  estimated_quantity: string
  is_packaged: boolean
  suggest_barcode_scan: boolean
  likely_frozen: boolean
  suggested_storage: string
  confidence: number
  estimated_shelf_life_days: number
}

interface RequestBody {
  image?: string
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

// MARK: - Gemini

function callGeminiOnce(geminiKey: string, model: string, imageBase64: string): Promise<Response> {
  return fetch(`${GEMINI_BASE}/models/${model}:generateContent?key=${geminiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
      contents: [
        {
          role: 'user',
          parts: [{ inlineData: { mimeType: 'image/jpeg', data: imageBase64 } }],
        },
      ],
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: RESPONSE_SCHEMA,
        temperature: 0.4,
        thinkingConfig: { thinkingBudget: 0 },
      },
    }),
  })
}

// Retries on a 503 (model overloaded) up to 3 attempts total, exponential backoff. Any other
// status / transport error propagates immediately.
async function scanWithModel(
  geminiKey: string,
  model: string,
  imageBase64: string,
): Promise<ScannedFoodItem[]> {
  let res: Response | null = null
  for (let attempt = 0; attempt < 3; attempt++) {
    res = await callGeminiOnce(geminiKey, model, imageBase64)
    if (res.status !== 503) break
    if (attempt < 2) await sleep(Math.pow(2, attempt) * 1000)
  }

  if (!res!.ok) {
    throw new GeminiError(502, 'gemini_error', `${res!.status}: ${(await res!.text()).slice(0, 500)}`)
  }

  const parsed = await res!.json()
  const usage = parsed.usageMetadata ?? {}
  console.log(
    `[scan-food-photo] model=${model} prompt=${usage.promptTokenCount ?? '?'} output=${
      usage.candidatesTokenCount ?? '?'
    } total=${usage.totalTokenCount ?? '?'}`,
  )

  const parts: Array<{ text?: string; thought?: boolean }> =
    parsed.candidates?.[0]?.content?.parts ?? []
  const textPart = [...parts].reverse().find((p) => p.thought == null && typeof p.text === 'string')
  if (!textPart?.text) {
    throw new GeminiError(502, 'empty_response', 'no text part in response')
  }

  let items: unknown
  try {
    items = JSON.parse(textPart.text)
  } catch {
    throw new GeminiError(502, 'parse_error', textPart.text.slice(0, 500))
  }
  if (!Array.isArray(items)) {
    throw new GeminiError(502, 'parse_error', 'response is not an array')
  }
  return items as ScannedFoodItem[]
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

  const image = typeof raw.image === 'string' ? raw.image : ''
  if (image.length === 0) {
    return jsonResponse({ error: 'no_image' }, 400)
  }

  // Tier 1: lite model.
  let liteItems: ScannedFoodItem[] = []
  let liteError = false
  try {
    liteItems = await scanWithModel(geminiKey, LITE_MODEL, image)
  } catch (e) {
    liteError = true
    console.warn('[scan-food-photo] lite tier failed, escalating', e)
  }

  const confidences = liteItems.map((i) => i.confidence).filter((c) => typeof c === 'number')
  const liteItemCount = liteError ? null : liteItems.length
  const liteMinConfidence = confidences.length ? Math.min(...confidences) : null
  const liteAvgConfidence = confidences.length
    ? confidences.reduce((a, b) => a + b, 0) / confidences.length
    : null

  const confident = !liteError &&
    liteItems.length > 0 &&
    liteItems.every((i) => i.confidence >= ESCALATION_CONFIDENCE_THRESHOLD)

  let resolvedTier: 'lite' | 'standard'
  let escalated: boolean
  let escalationReason: string | null
  let finalItems: ScannedFoodItem[]

  if (confident) {
    resolvedTier = 'lite'
    escalated = false
    escalationReason = null
    finalItems = liteItems
  } else {
    resolvedTier = 'standard'
    escalated = true
    escalationReason = liteError ? 'error' : liteItems.length === 0 ? 'empty' : 'low_confidence'
    try {
      finalItems = await scanWithModel(geminiKey, STANDARD_MODEL, image)
    } catch (e) {
      if (e instanceof GeminiError) {
        return jsonResponse({ error: e.code, detail: e.detail }, e.status)
      }
      console.error('[scan-food-photo] standard tier failed', e)
      return jsonResponse({ error: 'internal_error' }, 500)
    }
  }

  // Best-effort telemetry — never fails the response. Service-role insert, so an explicit
  // user_id is required (the RLS `auth.uid()` default doesn't apply).
  try {
    await admin.from('photo_scan_events').insert({
      user_id: userId,
      resolved_tier: resolvedTier,
      lite_item_count: liteItemCount,
      lite_min_confidence: liteMinConfidence,
      lite_avg_confidence: liteAvgConfidence,
      escalated,
      escalation_reason: escalationReason,
      final_item_count: finalItems.length,
    })
  } catch (e) {
    console.error('[scan-food-photo] telemetry insert failed', e)
  }

  return jsonResponse({ items: finalItems }, 200)
})
