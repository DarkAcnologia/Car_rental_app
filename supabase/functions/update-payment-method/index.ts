// supabase/functions/update-payment-method/index.ts

import Stripe from "https://esm.sh/stripe@13.1.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2022-11-15",
});

Deno.serve(async (req: Request): Promise<Response> => {
  const badRequest = (msg: string) =>
    new Response(JSON.stringify({ error: msg }), { status: 400 });

  const serverError = (msg: string) =>
    new Response(JSON.stringify({ error: msg }), { status: 500 });

  try {
    const textBody = await req.text();
    const { user_id, stripe_payment_method_id } = JSON.parse(textBody);

    if (!user_id || !stripe_payment_method_id) {
      return badRequest("Missing user_id or stripe_payment_method_id");
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const headers = {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
      "Content-Type": "application/json",
    };

    // ❌ Снимаем is_primary со всех предыдущих карт
    await fetch(`${supabaseUrl}/rest/v1/payment_methods?user_id=eq.${user_id}`, {
      method: "PATCH",
      headers,
      body: JSON.stringify({ is_primary: false }),
    });

    // ✅ UPSERT карты как основной (избегаем дубликатов)
    const upsertRes = await fetch(`${supabaseUrl}/rest/v1/payment_methods`, {
      method: "POST",
      headers: {
        ...headers,
        Prefer: "resolution=merge-duplicates",
      },
      body: JSON.stringify({
        user_id,
        stripe_payment_method_id,
        is_primary: true,
      }),
    });

    const resultText = await upsertRes.text();

    if (!upsertRes.ok) {
      return new Response(JSON.stringify({ error: resultText }), {
        status: upsertRes.status,
      });
    }

    let parsedResult: unknown;
    try {
      parsedResult = JSON.parse(resultText || '{}');
    } catch (_) {
      parsedResult = {};
    }

    return new Response(
      JSON.stringify({ success: true, data: parsedResult }),
      { status: 200 }
    );

  } catch (e) {
    return serverError(e instanceof Error ? e.message : String(e));
  }
});
