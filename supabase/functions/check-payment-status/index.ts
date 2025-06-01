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

    const paymentRes = await fetch(`${supabaseUrl}/rest/v1/split_payments?id=eq.${split_payment_id}`, {
      headers,
    });
    const paymentData = await paymentRes.json();
    const payment = paymentData[0];

    if (!payment) {
      return new Response(JSON.stringify({ error: "Split payment not found" }), { status: 404 });
    }

    const links = await stripe.paymentLinks.list({ limit: 100 });

    const found = links.data.find((link: any) =>
      link.metadata?.split_payment_id === split_payment_id
    );

    if (!found) {
      return new Response(JSON.stringify({ error: "Stripe link not found" }), { status: 404 });
    }

    if (found.active && found.completed) {
      await fetch(`${supabaseUrl}/rest/v1/split_payments?id=eq.${split_payment_id}`, {
        method: "PATCH",
        headers: {
          ...headers,
          "Content-Type": "application/json",
          Prefer: "return=representation",
        },
        body: JSON.stringify({ is_paid: true }),
      });

      return new Response(JSON.stringify({ success: true, paid: true }), { status: 200 });
    }

    return new Response(JSON.stringify({ success: true, paid: false }), { status: 200 });
  } catch (e) {
    const errorMessage = e instanceof Error ? e.message : "Unknown error";
    return new Response(JSON.stringify({ error: errorMessage }), { status: 500 });
  }
});
