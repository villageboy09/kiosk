import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  // This is needed for browser clients to call the function
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { pin } = await req.json()
    if (!pin) throw new Error('PIN is required.')

    const supabaseAdmin = createClient(
      Deno.env.get('PROJECT_URL') ?? '',
      Deno.env.get('SERVICE_KEY') ?? ''
    )

    // Step 1: Find the farmer by their login PIN
    const { data: farmer, error: farmerError } = await supabaseAdmin
      .from('farmers')
      .select('id, phone_number') // We now need the farmer's primary key 'id'
      .eq('login_pin', pin)
      .single()

    if (farmerError) {
      console.error('Farmer lookup error:', farmerError.message)
      throw new Error('Invalid PIN provided.')
    }

    const userIdentifier = `${farmer.phone_number}@cropsync.local`

    // Step 2: Find or create the corresponding user in Supabase Auth
    const { data: authData, error: linkError } = await supabaseAdmin.auth.admin.generateLink({
        type: 'magiclink',
        email: userIdentifier,
    });

    if (linkError) {
      console.error('Generate link error:', linkError.message)
      throw new Error('Could not generate a user session.')
    }

    // Step 3: NEW - Link the auth user to the farmer profile
    const userId = authData.user.id
    const farmerId = farmer.id

    // This update query creates the crucial link between the two tables.
    const { error: updateError } = await supabaseAdmin
      .from('farmers')
      .update({ user_id: userId })
      .eq('id', farmerId)

    if (updateError) {
      // Log the error but don't stop the login process.
      // The link can be established on a subsequent login.
      console.error('Failed to link farmer to auth user:', updateError.message)
    }

    // Step 4: Return the successful data object to the client.
    return new Response(JSON.stringify(authData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Caught an error in function:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
