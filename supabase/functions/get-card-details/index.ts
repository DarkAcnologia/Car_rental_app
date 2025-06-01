Deno.serve(async (req: Request): Promise<Response> => {
  try {
    const { payment_method_id } = await req.json();

    if (!payment_method_id) {
      return new Response(JSON.stringify({ error: "Missing payment_method_id" }), { status: 400 });
    }

    const stripeSecretKey = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecretKey) {
      return new Response(JSON.stringify({ error: "Missing STRIPE_SECRET_KEY env" }), { status: 500 });
    }

    const res = await fetch(`https://api.stripe.com/v1/payment_methods/${payment_method_id}`, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${stripeSecretKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
    });

    const data = await res.json();

    if (!data.card) {
      return new Response(JSON.stringify({ error: "No card data", stripe_response: data }), { status: 404 });
    }

    // Вернуть только нужные данные
    return new Response(
      JSON.stringify({
        brand: data.card.brand,
        last4: data.card.last4
      }),
      { status: 200 }
    );
  } catch (e) {
    return new Response(
      JSON.stringify({
        error: `Server error: ${e instanceof Error ? e.message : String(e)}`,
      }),
      { status: 500 },
    );
  }
});
