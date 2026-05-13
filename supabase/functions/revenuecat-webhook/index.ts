import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const PREMIUM_EVENTS = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'UNCANCELLATION',
  'PRODUCT_CHANGE',
])

const FREE_EVENTS = new Set([
  'EXPIRATION',
  'CANCELLATION',
])

const ENTITLEMENT_ID = 'UseUp Pro'

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  const authHeader = req.headers.get('Authorization')
  const webhookSecret = Deno.env.get('REVENUECAT_WEBHOOK_SECRET')
  if (!webhookSecret || authHeader !== webhookSecret) {
    return new Response('Unauthorized', { status: 401 })
  }

  let payload: any
  try {
    payload = await req.json()
  } catch {
    return new Response('Invalid JSON', { status: 400 })
  }

  const event = payload?.event
  if (!event) {
    return new Response('Missing event', { status: 400 })
  }

  const eventType: string = event.type
  const appUserId: string = event.app_user_id
  const entitlementIds: string[] = event.entitlement_ids ?? []

  let subscriptionType: string | null = null

  if (PREMIUM_EVENTS.has(eventType) && entitlementIds.includes(ENTITLEMENT_ID)) {
    subscriptionType = 'premium'
  } else if (FREE_EVENTS.has(eventType)) {
    subscriptionType = 'free'
  }

  if (subscriptionType === null) {
    return new Response(
      JSON.stringify({ received: true, action: 'ignored', eventType }),
      { headers: { 'Content-Type': 'application/json' } },
    )
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  )

  const { error } = await supabase
    .from('profiles')
    .update({ subscription_type: subscriptionType })
    .eq('id', appUserId)

  if (error) {
    console.error('Failed to update subscription_type:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 500 })
  }

  return new Response(
    JSON.stringify({ received: true, action: 'updated', subscriptionType }),
    { headers: { 'Content-Type': 'application/json' } },
  )
})
