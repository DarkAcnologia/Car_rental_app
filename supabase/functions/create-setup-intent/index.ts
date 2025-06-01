Deno.serve(async (req: Request): Promise<Response> => {
  try {
    const textBody = await req.text();
    const { user_id } = JSON.parse(textBody);

    if (!user_id) {
      return new Response(JSON.stringify({ error: "Missing user_id" }), { status: 400 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");

    // 🔄 Теперь получаем stripe_customer_id из таблицы profiles
    const res = await fetch(`${supabaseUrl}/rest/v1/profiles?id=eq.${user_id}`, {
      headers: {
        apikey: supabaseKey!,
        Authorization: `Bearer ${supabaseKey}`,
      },
    });

    const profile = await res.json();
    if (!profile.length || !profile[0].stripe_customer_id) {
      return new Response(JSON.stringify({ error: "Customer not found in profiles" }), { status: 404 });
    }

    const customer_id = profile[0].stripe_customer_id;

    const intentRes = await fetch("https://api.stripe.com/v1/setup_intents", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${stripeSecretKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        customer: customer_id,
        "payment_method_types[]": "card",
      }),
    });

    const setupIntent = await intentRes.json();

    return new Response(
      JSON.stringify({
        clientSecret: setupIntent.client_secret,
        setupIntentId: setupIntent.id,
      }),
      { status: 200 },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : String(e) }), {
      status: 500,
    });
  }
});
