// supabase/functions/get-payment-method-id/index.ts
Deno.serve(async (req: Request): Promise<Response> => {
  try {
    const text = await req.text();
    const { setup_intent_id } = JSON.parse(text);

    if (!setup_intent_id) {
      return new Response(JSON.stringify({ error: "Missing setup_intent_id" }), { status: 400 });
    }

    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) throw new Error("Missing STRIPE_SECRET_KEY");

    const intentRes = await fetch(`https://api.stripe.com/v1/setup_intents/${setup_intent_id}`, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${stripeSecretKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
    });

    const intent = await intentRes.json();

    if (!intent.payment_method) {
      return new Response(JSON.stringify({ error: "No payment_method found" }), { status: 404 });
    }

    return new Response(
      JSON.stringify({ stripe_payment_method_id: intent.payment_method }),
      { status: 200 }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({
        error: `Server error: ${e instanceof Error ? e.message : String(e)}`,
      }),
      { status: 500 }
    );
  }
});
