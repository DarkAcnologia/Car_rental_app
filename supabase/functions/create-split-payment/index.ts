import Stripe from "https://esm.sh/stripe@13.1.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2022-11-15",
});

Deno.serve(async (req) => {
  try {
    const { split_payment_id } = await req.json();
    if (!split_payment_id) {
      return new Response(JSON.stringify({ error: "Missing split_payment_id" }), { status: 400 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const headers = {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
    };

    // Получаем split_payment по ID
    const splitRes = await fetch(
      `${supabaseUrl}/rest/v1/split_payments?id=eq.${split_payment_id}`,
      { headers }
    );
    const splitData = await splitRes.json();
    const payment = splitData[0];

    if (!payment) {
      return new Response(JSON.stringify({ error: "Split payment not found" }), { status: 404 });
    }

    // Создаём Checkout Session
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ["card"],
      mode: "payment",
      line_items: [
        {
          price_data: {
            currency: "rub",
            product_data: {
              name: `Оплата от ${payment.contributor_name}`,
            },
            unit_amount: Math.round(payment.amount * 100),
          },
          quantity: 1,
        },
      ],
      metadata: {
        split_payment_id,
        booking_id: payment.booking_id,
        contributor: payment.contributor_name,
      },
      success_url: "https://example.com/success", // заменишь на нужный
      cancel_url: "https://example.com/cancel",
    });

    return new Response(JSON.stringify({ url: session.url }), { status: 200 });
  } catch (e) {
    const errorMessage = e instanceof Error ? e.message : "Unknown error";
    return new Response(JSON.stringify({ error: errorMessage }), { status: 500 });
  }
});
