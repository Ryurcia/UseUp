import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  buildUserPrompt,
  GenerationOptions,
  normalizeOptions,
  SYSTEM_PROMPT,
} from './prompt.ts'

// Proxies recipe generation to Gemini so that (a) the API key never ships in the app binary,
// (b) the per-user generation quota is enforced server-side, and (c) the ~1.2K-token system
// prompt is served from one shared Gemini `cachedContents` resource instead of being re-billed
// on every call. The client sends { ingredientNames, options }; this function owns the system
// prompt and builds the per-request user prompt.

const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta'
const GEMINI_MODEL = 'models/gemini-2.5-flash'
const CACHE_TTL_SECONDS = 86_400 // 24h
const CACHE_REFRESH_BUFFER_MS = 30 * 60 * 1000 // refresh when <30 min from expiry
const DAILY_LIMIT = 5
// Snap Chef: after the first (quota-consuming) recipe, this many re-rolls are free and uncounted.
const FREE_REGENS = 2

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input))
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

const SYSTEM_PROMPT_HASH = (await sha256Hex(SYSTEM_PROMPT)).slice(0, 12)
const CACHE_ID = `${GEMINI_MODEL}:${SYSTEM_PROMPT_HASH}`

type GenerationIntent = 'standard' | 'snap_chef' | 'snap_chef_regenerate'

interface RequestBody {
  ingredientNames?: string[]
  options?: Partial<GenerationOptions>
  count?: number
  intent?: GenerationIntent
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

// MARK: - Quota

async function isUnderQuota(admin: SupabaseClient, userId: string): Promise<boolean> {
  // One limit for everyone: DAILY_LIMIT generations per UTC day. Logging pantry items requires a
  // subscription, so anyone who can reach generation is already a paying user — there is no
  // separate free tier. Server time is UTC; the client's "today" uses the device timezone.
  // Minor divergence at the midnight boundary is acceptable — the server count is authoritative.
  const since = new Date(new Date().setUTCHours(0, 0, 0, 0)).toISOString()

  const { count } = await admin
    .from('user_activity')
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('event_type', 'recipe_generated')
    .gte('created_at', since)

  return (count ?? 0) < DAILY_LIMIT
}

// MARK: - Gemini cache

async function createCache(admin: SupabaseClient, geminiKey: string): Promise<string | null> {
  try {
    const res = await fetch(`${GEMINI_BASE}/cachedContents?key=${geminiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: GEMINI_MODEL,
        systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
        ttl: `${CACHE_TTL_SECONDS}s`,
      }),
    })

    if (!res.ok) {
      // Most likely the system prompt is below Gemini's minimum cacheable token count. Fall back
      // to an inline system instruction (implicit caching still applies).
      console.error('cachedContents create failed', res.status, await res.text())
      return null
    }

    const json = await res.json()
    const cacheName: string = json.name
    const expiresAt: string =
      json.expireTime ?? new Date(Date.now() + CACHE_TTL_SECONDS * 1000).toISOString()

    await admin.from('ai_prompt_cache').upsert({
      id: CACHE_ID,
      cache_name: cacheName,
      model: GEMINI_MODEL,
      prompt_hash: SYSTEM_PROMPT_HASH,
      token_count: json.usageMetadata?.totalTokenCount ?? null,
      expires_at: expiresAt,
      updated_at: new Date().toISOString(),
    })

    console.log(`cachedContents created ${cacheName} (${json.usageMetadata?.totalTokenCount} tokens)`)
    return cacheName
  } catch (e) {
    console.error('cachedContents create threw', e)
    return null
  }
}

async function getCacheName(admin: SupabaseClient, geminiKey: string): Promise<string | null> {
  const { data: row } = await admin
    .from('ai_prompt_cache')
    .select('cache_name, expires_at')
    .eq('id', CACHE_ID)
    .maybeSingle()

  if (row && new Date(row.expires_at).getTime() - Date.now() > CACHE_REFRESH_BUFFER_MS) {
    return row.cache_name
  }
  return await createCache(admin, geminiKey)
}

// MARK: - Generate

function callGemini(
  geminiKey: string,
  userPrompt: string,
  cacheName: string | null,
): Promise<Response> {
  const body: Record<string, unknown> = {
    contents: [{ role: 'user', parts: [{ text: userPrompt }] }],
    generationConfig: {
      responseMimeType: 'application/json',
      temperature: 0.7,
      maxOutputTokens: 4000,
      thinkingConfig: { thinkingBudget: 0 },
    },
  }
  if (cacheName) {
    body.cachedContent = cacheName
  } else {
    body.systemInstruction = { parts: [{ text: SYSTEM_PROMPT }] }
  }

  return fetch(`${GEMINI_BASE}/${GEMINI_MODEL}:generateContent?key=${geminiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms))

async function runGeneration(
  admin: SupabaseClient,
  geminiKey: string,
  userPrompt: string,
  recipeCount: number,
): Promise<{ recipes: unknown[] }> {
  let cacheName = await getCacheName(admin, geminiKey)
  let recreatedCache = false
  let retriedTruncated = false

  for (let attempt = 0; attempt < 3; attempt++) {
    const res = await callGemini(geminiKey, userPrompt, cacheName)

    // Gemini overloaded — back off and retry (1s, 2s).
    if (res.status === 503) {
      if (attempt < 2) {
        await sleep(Math.pow(2, attempt) * 1000)
        continue
      }
      throw new GeminiError(502, 'gemini_error', await res.text())
    }

    // A stale cache reference (expired / deleted between our read and Gemini's use) surfaces as a
    // 400/403 mentioning the cache. Drop it, make a fresh one, and retry once.
    if ((res.status === 400 || res.status === 403) && cacheName && !recreatedCache) {
      const errText = await res.text()
      if (/cache/i.test(errText)) {
        console.warn('stale cachedContent, recreating', errText)
        recreatedCache = true
        await admin.from('ai_prompt_cache').delete().eq('id', CACHE_ID)
        cacheName = await createCache(admin, geminiKey)
        continue
      }
      throw new GeminiError(502, 'gemini_error', errText)
    }

    if (!res.ok) {
      throw new GeminiError(502, 'gemini_error', await res.text())
    }

    const parsed = await res.json()
    const usage = parsed.usageMetadata ?? {}
    console.log(
      `[generate-recipes] prompt=${usage.promptTokenCount ?? '?'} cached=${
        usage.cachedContentTokenCount ?? 0
      } output=${usage.candidatesTokenCount ?? '?'} total=${usage.totalTokenCount ?? '?'}`,
    )

    const finishReason = parsed.candidates?.[0]?.finishReason
    if (finishReason === 'MAX_TOKENS') {
      if (!retriedTruncated) {
        retriedTruncated = true
        console.warn('response truncated (MAX_TOKENS), retrying once')
        continue
      }
      throw new GeminiError(502, 'truncated', 'response cut off twice')
    }

    const parts: Array<{ text?: string; thought?: boolean }> =
      parsed.candidates?.[0]?.content?.parts ?? []
    const textPart = [...parts].reverse().find((p) => p.thought == null && typeof p.text === 'string')
    if (!textPart?.text) {
      throw new GeminiError(502, 'empty_response', 'no text part in response')
    }

    let payload: { recipes?: unknown[] }
    try {
      payload = JSON.parse(textPart.text)
    } catch {
      throw new GeminiError(502, 'parse_error', textPart.text.slice(0, 500))
    }

    const recipes = (payload.recipes ?? []).slice(0, recipeCount)
    if (recipes.length === 0) {
      throw new GeminiError(502, 'empty_response', 'no recipes in response')
    }
    return { recipes }
  }

  throw new GeminiError(502, 'gemini_error', 'exhausted retry attempts')
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

  const ingredientNames = (raw.ingredientNames ?? [])
    .map((s) => s.trim().toLowerCase())
    .filter((s) => s.length > 0)
  if (ingredientNames.length === 0) {
    return jsonResponse({ error: 'no_ingredients' }, 400)
  }
  const options = normalizeOptions({ ...raw.options, count: raw.count })
  const intent: GenerationIntent = raw.intent ?? 'standard'

  // Snap Chef gives 2 free re-rolls per generated recipe. A free re-roll skips both the daily
  // quota check and the `recipe_generated` log; once the 2 are spent, a re-roll behaves like a
  // normal generation (counts against the daily 5).
  let countsAgainstDailyLimit = true
  let freeRegensRemaining: number | null = null

  if (intent === 'snap_chef_regenerate') {
    const { data: lastGen } = await admin
      .from('user_activity')
      .select('created_at')
      .eq('user_id', userId)
      .eq('event_type', 'recipe_generated')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()
    const since = lastGen?.created_at ?? new Date(0).toISOString()
    const { count: freeUsed } = await admin
      .from('user_activity')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('event_type', 'snap_chef_regenerate')
      .gt('created_at', since)
    if ((freeUsed ?? 0) < FREE_REGENS) {
      countsAgainstDailyLimit = false
      freeRegensRemaining = FREE_REGENS - (freeUsed ?? 0) - 1
    }
  }

  if (countsAgainstDailyLimit && !(await isUnderQuota(admin, userId))) {
    return jsonResponse({ error: 'limit_exhausted' }, 429)
  }

  const userPrompt = buildUserPrompt(ingredientNames, options)

  let result: { recipes: unknown[] }
  try {
    result = await runGeneration(admin, geminiKey, userPrompt, options.count)
  } catch (e) {
    if (e instanceof GeminiError) {
      return jsonResponse({ error: e.code, detail: e.detail }, e.status)
    }
    console.error('generation failed', e)
    return jsonResponse({ error: 'internal_error' }, 500)
  }

  // Authoritative usage record — replaces the client's optimistic `activityStore.logEvent`.
  const eventType = countsAgainstDailyLimit ? 'recipe_generated' : 'snap_chef_regenerate'
  const { error: logErr } = await admin
    .from('user_activity')
    .insert({ user_id: userId, event_type: eventType })
  if (logErr) {
    console.error(`failed to log ${eventType}`, logErr)
  }

  // Any `recipe_generated` row resets the free re-roll window (the count is "since the last one").
  if (countsAgainstDailyLimit) {
    freeRegensRemaining = FREE_REGENS
  }

  return jsonResponse(
    { ...result, freeRegensRemaining, countedAgainstDailyLimit: countsAgainstDailyLimit },
    200,
  )
})
