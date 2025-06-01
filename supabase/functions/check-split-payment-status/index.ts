// supabase/functions/check-split-payment-status/index.ts
import Stripe from "https://esm.sh/stripe@13.1.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2022-11-15",
});

Deno.serve(async (req) => {
  try {
    const { split_payment_id } = await req.json();
    if (!split_payment_id) {
      return new Response(
        JSON.stringify({ error: "Missing split_payment_id" }),
        { status: 400 }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const headers = {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
    };

    // 1. Найдём PaymentIntent по метаданным
    const paymentIntents = await stripe.paymentIntents.search({
      query: `metadata["split_payment_id"]:"${split_payment_id}"`,
    });

    const intent = paymentIntents.data.find(
      (i: Stripe.PaymentIntent) => i.status === "succeeded"
    );

    if (!intent) {
      return new Response(JSON.stringify({ paid: false }), { status: 200 });
    }

    // 2. Обновим split_payments
    await fetch(`${supabaseUrl}/rest/v1/split_payments?id=eq.${split_payment_id}`, {
      method: "PATCH",
      headers: {
        ...headers,
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify({ is_paid: true }),
    });

    // 3. Получаем booking_id из записи split_payment
    const splitRes = await fetch(`${supabaseUrl}/rest/v1/split_payments?id=eq.${split_payment_id}`, {
      headers,
    });
    const splitJson = await splitRes.json();
    const bookingId = splitJson[0]?.booking_id;

    // 4. Если все оплатили — обновляем bookings.payment_status = 'paid'
    if (bookingId) {
      const unpaidRes = await fetch(
        `${supabaseUrl}/rest/v1/split_payments?booking_id=eq.${bookingId}&is_paid=eq.false`,
        { headers }
      );
      const unpaid = await unpaidRes.json();

      if (unpaid.length === 0) {
        await fetch(`${supabaseUrl}/rest/v1/bookings?id=eq.${bookingId}`, {
          method: "PATCH",
          headers: {
            ...headers,
            "Content-Type": "application/json",
            Prefer: "return=representation",
          },
          body: JSON.stringify({ payment_status: 'paid' }),
        });
      }
    }

    return new Response(JSON.stringify({ paid: true }), { status: 200 });
  } catch (e) {
    const errorMessage = e instanceof Error ? e.message : "Unknown error";
    return new Response(JSON.stringify({ error: errorMessage }), { status: 500 });
  }
});
