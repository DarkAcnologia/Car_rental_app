// supabase/functions/initiate-split-payment/index.ts
import Stripe from "https://esm.sh/stripe@13.1.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2022-11-15",
});

Deno.serve(async (req) => {
  try {
    const { booking_id, contributors } = await req.json();

    if (!booking_id || !contributors || !Array.isArray(contributors)) {
      return new Response(
        JSON.stringify({ error: "Missing booking_id or contributors" }),
        { status: 400 },
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const headers = {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
    };

    const results = [];

    for (const contributor of contributors) {
      const { name, amount } = contributor;

      const insertRes = await fetch(`${supabaseUrl}/rest/v1/split_payments`, {
        method: "POST",
        headers: {
          ...headers,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          booking_id,
          contributor_name: name,
          amount,
        }),
      });

      const insertData = await insertRes.json();
      const splitPaymentId = insertData[0]?.id;

      if (!splitPaymentId) continue;

      const link = await stripe.paymentLinks.create({
        line_items: [
          {
            price_data: {
              currency: "rub",
              product_data: { name: `Оплата ${name}` },
              unit_amount: Math.round(amount * 100),
            },
            quantity: 1,
          },
        ],
        metadata: {
          split_payment_id: splitPaymentId,
          booking_id,
          contributor: name,
        },
      });

      results.push({ name, amount, link: link.url });
    }

    return new Response(JSON.stringify({ success: true, results }), {
      status: 200,
    });
  } catch (e) {
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : String(e) }),
      { status: 500 },
    );
  }
});
