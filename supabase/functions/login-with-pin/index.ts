import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'

Deno.serve(async (req) => {
  // This is needed for browser clients to call the function
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { pin } = await req.json()

    // Create a Supabase client with the service_role key to bypass RLS
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Find the farmer by their login PIN
    const { data: farmer, error: farmerError } = await supabaseAdmin
      .from('farmers')
      .select('id, phone_number') // Select the phone_number to use as an identifier
      .eq('login_pin', pin)
      .single()

    if (farmerError) {
      throw new Error('Invalid PIN or database error')
    }

    // This is a placeholder for a real user identifier.
    // In a production system, you would likely have a user_id on the farmers table
    // that links to the auth.users table. Here, we'll use the phone number
    // as a unique identifier to find or create the auth user.
    const userIdentifier = `${farmer.phone_number}@cropsync.local`

    // 2. Find or create the corresponding user in Supabase Auth
    let { data: user, error: userError } = await supabaseAdmin.auth.admin.getUserByEmail(userIdentifier)

    if (userError) {
      // If user doesn't exist, create them
      const { data: newUser, error: createUserError } = await supabaseAdmin.auth.admin.createUser({
        email: userIdentifier,
        // It's good practice to set a secure, random password on the server
        password: crypto.randomUUID(), 
        email_confirm: true, // Auto-confirm the email since we trust this flow
      })

      if (createUserError) throw createUserError
      user = newUser.user
    }
    
    // 3. Create a session for the user
    const { data: sessionData, error: sessionError } = await supabaseAdmin.auth.signInWithPassword({
        email: userIdentifier,
        // We need a password to sign in, but since we are the admin, we don't use the PIN.
        // This uses the password we set during user creation.
        // A more advanced flow might use passwordless sign-in.
        password: user.password, // This is a simplification; a real app would handle this differently
    });

    if (sessionError) throw sessionError;

    // Return the session data (including the JWT) to the client
    return new Response(JSON.stringify(sessionData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
