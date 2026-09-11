// Run: deno test supabase/functions/scan-food-photo/
import { assert, assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import {
  ESCALATION_CONFIDENCE_THRESHOLD,
  RESPONSE_SCHEMA,
  SYSTEM_PROMPT,
} from './prompt.ts'

const FIELDS = [
  'name',
  'category',
  'estimated_quantity',
  'is_packaged',
  'suggest_barcode_scan',
  'likely_frozen',
  'suggested_storage',
  'confidence',
  'estimated_shelf_life_days',
]

Deno.test('system prompt documents all 9 output fields', () => {
  for (const field of FIELDS) {
    assert(SYSTEM_PROMPT.includes(field), `system prompt missing "${field}"`)
  }
})

Deno.test('system prompt keys banana shelf life to visible ripeness', () => {
  assert(SYSTEM_PROMPT.includes('ripeness'), 'prompt missing "ripeness"')
  assert(SYSTEM_PROMPT.includes('Bananas'), 'prompt missing banana ripeness guidance')
})

Deno.test('response schema is an array of objects requiring all 9 fields', () => {
  assertEquals(RESPONSE_SCHEMA.type, 'ARRAY')
  assertEquals(RESPONSE_SCHEMA.items.type, 'OBJECT')
  assertEquals([...RESPONSE_SCHEMA.items.required].sort(), [...FIELDS].sort())
})

Deno.test('category and storage enums match the client model', () => {
  assertEquals(RESPONSE_SCHEMA.items.properties.category.enum, [
    'produce', 'dairy', 'meat', 'seafood', 'frozen', 'pantry', 'bakery', 'beverage', 'condiment', 'other',
  ])
  assertEquals(RESPONSE_SCHEMA.items.properties.suggested_storage.enum, ['fridge', 'pantry', 'freezer'])
})

Deno.test('escalation threshold matches the former client value', () => {
  assertEquals(ESCALATION_CONFIDENCE_THRESHOLD, 0.75)
})
