import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

console.log('Function starting up...')

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { pin } = await req.json()
    if (!pin) {
      throw new Error('PIN is required in the request body.')
    }

    const projectUrl = Deno.env.get('PROJECT_URL')
    const serviceKey = Deno.env.get('SERVICE_KEY')

    if (!projectUrl || !serviceKey) {
      throw new Error('Server is missing required configuration (PROJECT_URL or SERVICE_KEY).')
    }

    const supabaseAdmin = createClient(projectUrl, serviceKey)

    // Step 1: Find the farmer by their login PIN
    const { data: farmer, error: farmerError } = await supabaseAdmin
      .from('farmers')
      .select('phone_number')
      .eq('login_pin', pin)
      .single()

    if (farmerError) {
      console.error('Farmer lookup error:', farmerError.message)
      throw new Error('Invalid PIN provided.')
    }

    const userIdentifier = `${farmer.phone_number}@cropsync.local`

    // Step 2: Generate a magic link for the user.
    const { data, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
        type: 'magiclink',
        email: userIdentifier,
    });

    if (linkError) {
      console.error('Generate link error:', linkError.message)
      throw new Error('Could not generate a user session.')
    }

    // Step 3: Return the successful data object to the client.
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Caught an error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
