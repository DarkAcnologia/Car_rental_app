// supabase/functions/create-stripe-customer/index.ts
import Stripe from "https://esm.sh/stripe@13.1.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2022-11-15",
});

Deno.serve(async (req) => {
  try {
    const { user_id, email } = await req.json();
    if (!user_id || !email) {
      return new Response(JSON.stringify({ error: "Missing user_id or email" }), { status: 400 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const headers = {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
      "Content-Type": "application/json",
    };

    const profileRes = await fetch(`${supabaseUrl}/rest/v1/profiles?id=eq.${user_id}`, {
      headers,
    });

    const profile = await profileRes.json();
    const existingId = profile[0]?.stripe_customer_id;

    if (existingId) {
      return new Response(JSON.stringify({ stripe_customer_id: existingId }), { status: 200 });
    }

    const customer = await stripe.customers.create({ email });

    await fetch(`${supabaseUrl}/rest/v1/profiles?id=eq.${user_id}`, {
      method: "PATCH",
      headers,
      body: JSON.stringify({ stripe_customer_id: customer.id }),
    });

    return new Response(JSON.stringify({ stripe_customer_id: customer.id }), { status: 200 });
  } catch (e) {
  return new Response(JSON.stringify({ error: e instanceof Error ? e.message : String(e) }), {
    status: 500,
  });
}
});
