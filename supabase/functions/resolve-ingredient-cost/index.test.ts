// Run: deno test supabase/functions/resolve-ingredient-cost/
import { assert, assertEquals, assertStringIncludes } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { buildUserPrompt, mapPricePer, RESPONSE_SCHEMA, STALENESS_DAYS, SYSTEM_PROMPT } from './prompt.ts'

Deno.test('staleness window is 60 days', () => {
  assertEquals(STALENESS_DAYS, 60)
})

Deno.test('system prompt covers currency, conversion, and confidence', () => {
  assertStringIncludes(SYSTEM_PROMPT, 'USD')
  assertStringIncludes(SYSTEM_PROMPT, 'conversion_applied')
  assertStringIncludes(SYSTEM_PROMPT, 'confidence')
  assertStringIncludes(SYSTEM_PROMPT, 'reference price')
})

Deno.test('response schema matches the four keys the Swift client decodes', () => {
  assertEquals(
    [...RESPONSE_SCHEMA.required].sort(),
    ['confidence', 'conversion_applied', 'total_price_usd', 'unit_price_usd'],
  )
})

Deno.test('user prompt includes the reference line only when a known price is passed', () => {
  const withRef = buildUserPrompt({
    ingredientName: 'bananas',
    quantity: 5,
    unit: 'whole',
    unitCount: 1,
    knownPrice: { unitPrice: 0.29, unit: 'whole', source: 'personal' },
  })
  assertStringIncludes(withRef, 'Reference price: $0.29 per whole')
  assertStringIncludes(withRef, 'previously confirmed price')

  const withoutRef = buildUserPrompt({
    ingredientName: 'bananas',
    quantity: 5,
    unit: 'whole',
    unitCount: 1,
    knownPrice: null,
  })
  assertStringIncludes(withoutRef, 'No reference price')
  assertEquals(withoutRef.includes('Reference price:'), false)
})

Deno.test('user prompt labels a crowdsourced reference distinctly', () => {
  const prompt = buildUserPrompt({
    ingredientName: 'oat milk',
    quantity: 1,
    unit: 'L',
    unitCount: 2,
    knownPrice: { unitPrice: 3.5, unit: 'L', source: 'openfoodfacts' },
  })
  assertStringIncludes(prompt, 'crowdsourced price')
  assertStringIncludes(prompt, 'Unit count: 2')
})

Deno.test('mapPricePer normalizes the Open Prices enum', () => {
  assertEquals(mapPricePer('KILOGRAM'), 'kg')
  assertEquals(mapPricePer('UNIT'), 'whole')
  assertEquals(mapPricePer(null), 'whole')
  assertEquals(mapPricePer('anything-else'), 'whole')
  assert(typeof mapPricePer(undefined) === 'string')
})
