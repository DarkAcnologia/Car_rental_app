// supabase/functions/stripe-webhook/index.ts
import { serve } from "https://deno.land/std@0.192.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@13.1.0";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2022-11-15",
});

serve(async (req) => {
  try {
    const signature = req.headers.get("stripe-signature");
    const bodyText = await req.text();

    const endpointSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
    if (!endpointSecret || !signature) {
      return new Response("Missing webhook secret or signature", { status: 400 });
    }

    let event: Stripe.Event;

    try {
      event = await stripe.webhooks.constructEventAsync(bodyText, signature, endpointSecret);
    } catch (err) {
      return new Response(`Webhook Error: ${(err as Error).message}`, { status: 400 });
    }

    if (event.type === "checkout.session.completed") {
      const session = event.data.object as Stripe.Checkout.Session;
      const split_payment_id = session.metadata?.split_payment_id;

      if (!split_payment_id) {
        return new Response("No split_payment_id in metadata", { status: 400 });
      }

      const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
      const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

      await fetch(`${supabaseUrl}/rest/v1/split_payments?id=eq.${split_payment_id}`, {
        method: "PATCH",
        headers: {
          apikey: supabaseKey,
          Authorization: `Bearer ${supabaseKey}`,
          "Content-Type": "application/json",
          Prefer: "return=representation",
        },
        body: JSON.stringify({ is_paid: true }),
      });
    }

    return new Response(JSON.stringify({ received: true }), { status: 200 });
  } catch (e) {
    return new Response(`Unexpected error: ${(e as Error).message}`, { status: 500 });
  }
});
