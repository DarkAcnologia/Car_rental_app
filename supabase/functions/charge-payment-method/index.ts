import Stripe from "https://esm.sh/stripe@13.1.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2022-11-15",
});

Deno.serve(async (req: Request): Promise<Response> => {
  try {
    const { user_id } = await req.json();

    if (!user_id) {
      return new Response(
        JSON.stringify({ error: "Missing user_id" }),
        {
          status: 400,
          headers: { "Content-Type": "application/json" },
        }
      );
    }

    // 🔍 Ищи существующего customer по user_id
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    const userRes = await fetch(`${supabaseUrl}/rest/v1/payment_methods?user_id=eq.${user_id}`, {
      headers: {
        apikey: supabaseKey!,
        Authorization: `Bearer ${supabaseKey}`,
      },
    });

    const userMethods = await userRes.json();
    let customer_id: string;

    if (userMethods.length > 0 && userMethods[0].stripe_customer_id) {
      customer_id = userMethods[0].stripe_customer_id;
    } else {
      // 🆕 создаём нового Stripe customer
      const customer = await stripe.customers.create({ metadata: { user_id } });
      customer_id = customer.id;

      // сохраняем в Supabase
      await fetch(`${supabaseUrl}/rest/v1/payment_methods`, {
        method: "POST",
        headers: {
          apikey: supabaseKey!,
          Authorization: `Bearer ${supabaseKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          user_id,
          stripe_customer_id: customer_id,
        }),
      });
    }

    // 🎯 создаём SetupIntent
    const setupIntent = await stripe.setupIntents.create({
      customer: customer_id,
    });

    return new Response(
      JSON.stringify({
        clientSecret: setupIntent.client_secret,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("SetupIntent error:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message || String(err) }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
