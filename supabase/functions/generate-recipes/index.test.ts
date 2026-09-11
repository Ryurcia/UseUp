// Run: deno test supabase/functions/generate-recipes/
import { assertEquals, assertStringIncludes } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { buildUserPrompt, normalizeOptions, RECIPES_PER_GENERATION } from './prompt.ts'

const baseOptions = {
  dietType: 'Any',
  dietaryRestrictions: [] as string[],
  allergies: [] as string[],
  maxTimeMinutes: 30,
  targetCalories: null,
  cuisine: null,
  skillLevel: 1,
  priorityIngredients: [] as string[],
  diversifyIngredients: false,
  count: RECIPES_PER_GENERATION,
}

Deno.test('lists ingredients and the fixed recipe count', () => {
  const prompt = buildUserPrompt(['chicken', 'rice', 'broccoli'], baseOptions)
  assertStringIncludes(prompt, 'chicken, rice, broccoli')
  assertStringIncludes(prompt, 'Generate exactly 5 recipes')
  assertStringIncludes(prompt, 'at least 3 user-provided ingredients')
  assertStringIncludes(prompt, "at least 60% of the user's provided ingredients")
})

Deno.test('count defaults to RECIPES_PER_GENERATION and clamps out-of-range values', () => {
  assertEquals(normalizeOptions(undefined).count, RECIPES_PER_GENERATION)
  assertEquals(normalizeOptions({}).count, RECIPES_PER_GENERATION)
  assertEquals(normalizeOptions({ count: 1 }).count, 1)
  assertEquals(normalizeOptions({ count: 0 }).count, RECIPES_PER_GENERATION)
  assertEquals(normalizeOptions({ count: 99 }).count, RECIPES_PER_GENERATION)
})

Deno.test('count: 1 asks for a single recipe and clamps the min-ingredient rule', () => {
  const prompt = buildUserPrompt(['chicken', 'rice', 'broccoli'], { ...baseOptions, count: 1 })
  assertStringIncludes(prompt, 'Generate exactly 1 recipe in "recipes"')
  assertEquals(prompt.includes('Generate exactly 5 recipes'), false)

  const twoItems = buildUserPrompt(['chicken', 'rice'], { ...baseOptions, count: 1 })
  assertStringIncludes(twoItems, 'at least 2 user-provided ingredients')

  const oneItem = buildUserPrompt(['chicken'], { ...baseOptions, count: 1 })
  assertStringIncludes(oneItem, 'at least 1 user-provided ingredient.')
})

Deno.test('diversify mode swaps the coverage rules', () => {
  const prompt = buildUserPrompt(['a', 'b', 'c'], { ...baseOptions, diversifyIngredients: true })
  assertStringIncludes(prompt, 'at least 2 user-provided ingredients')
  assertStringIncludes(prompt, 'DIFFERENT SUBSET of the provided ingredients')
  assertEquals(prompt.includes("at least 60% of the user's provided ingredients"), false)
})

Deno.test('allergy block is present verbatim and safety-critical phrasing intact', () => {
  const prompt = buildUserPrompt(['peanut butter', 'bread'], {
    ...baseOptions,
    allergies: ['peanuts', 'tree nuts'],
  })
  assertStringIncludes(prompt, '⚠️ CRITICAL ALLERGY ALERT — THIS IS A HARD CONSTRAINT, NOT A PREFERENCE:')
  assertStringIncludes(prompt, 'The user is allergic to: peanuts, tree nuts')
  assertStringIncludes(prompt, 'treat it as life-or-death')
  assertStringIncludes(prompt, 'exclude common derivatives and hidden sources of the allergen')
})

Deno.test('each dietary restriction appears, sorted', () => {
  const prompt = buildUserPrompt(['tofu'], {
    ...baseOptions,
    dietaryRestrictions: ['Soy-Free', 'Dairy-Free', 'Gluten-Free'],
  })
  assertStringIncludes(prompt, 'Dietary restrictions: Dairy-Free, Gluten-Free, Soy-Free')
})

Deno.test('optional constraints render only when set', () => {
  const bare = buildUserPrompt(['egg'], baseOptions)
  assertEquals(bare.includes('Diet type:'), false)
  assertEquals(bare.includes('Required cuisine:'), false)
  assertEquals(bare.includes('Target calories'), false)

  const full = buildUserPrompt(['egg'], {
    ...baseOptions,
    dietType: 'Vegetarian',
    cuisine: 'Italian',
    targetCalories: 600,
    maxTimeMinutes: 20,
    priorityIngredients: ['milk'],
  })
  assertStringIncludes(full, 'Diet type: Vegetarian')
  assertStringIncludes(full, 'Required cuisine: Italian — every recipe MUST be an authentic Italian dish')
  assertStringIncludes(full, 'Target calories per serving: 600')
  assertStringIncludes(full, 'Max cooking time: 20 minutes')
  assertStringIncludes(full, 'Priority ingredients (expiring soon')
})

Deno.test('skill level maps to the right description', () => {
  assertStringIncludes(buildUserPrompt(['x'], { ...baseOptions, skillLevel: 1 }), 'Cooking skill level: beginner')
  assertStringIncludes(buildUserPrompt(['x'], { ...baseOptions, skillLevel: 2 }), 'Cooking skill level: intermediate')
  assertStringIncludes(buildUserPrompt(['x'], { ...baseOptions, skillLevel: 3 }), 'Cooking skill level: advanced')
})
