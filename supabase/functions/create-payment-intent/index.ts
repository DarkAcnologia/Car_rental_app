import Stripe from "https://esm.sh/stripe@13.1.0?target=deno";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!, {
  apiVersion: "2022-11-15",
});

Deno.serve(async (req) => {
  try {
    const { user_id, booking_id } = await req.json();
    if (!user_id || !booking_id) {
      return new Response(JSON.stringify({ error: "Missing user_id or booking_id" }), { status: 400 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const headers = {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
      "Content-Type": "application/json",
    };

    // 1. Получаем бронирование
    const bookingRes = await fetch(`${supabaseUrl}/rest/v1/bookings?id=eq.${booking_id}`, { headers });
    const bookingData = await bookingRes.json();
    const data = bookingData[0];

    if (!data || data.status !== "finished") {
      return new Response(JSON.stringify({ error: "Invalid or unpaid booking" }), { status: 400 });
    }

    const amountRub = Number(data.total_price);
    if (amountRub < 50) {
      return new Response(JSON.stringify({
        error: `Минимальная сумма для оплаты Stripe — 50₽. Сейчас: ${amountRub.toFixed(2)}₽`,
      }), { status: 400 });
    }

    // 2. Получаем карту и профиль
    const [cardRes, profileRes] = await Promise.all([
      fetch(`${supabaseUrl}/rest/v1/payment_methods?user_id=eq.${user_id}&is_primary=eq.true`, { headers }),
      fetch(`${supabaseUrl}/rest/v1/profiles?id=eq.${user_id}`, { headers }),
    ]);

    const card = (await cardRes.json())[0];
    const profile = (await profileRes.json())[0];

    if (!card || !profile?.stripe_customer_id) {
      return new Response(JSON.stringify({ error: "No primary card or stripe_customer_id found" }), { status: 400 });
    }

    // 3. Создаём платеж
    const intent = await stripe.paymentIntents.create({
      amount: Math.round(amountRub * 100),
      currency: "rub",
      customer: profile.stripe_customer_id,
      payment_method: card.stripe_payment_method_id,
      confirm: true,
      off_session: true,
      metadata: {
        booking_id,
        user_id,
      },
    });

    // 4. Обновляем статус оплаты в Supabase
    const paymentStatus = intent.status === "succeeded" ? "success" : "failed";
    const updateRes = await fetch(`${supabaseUrl}/rest/v1/bookings?id=eq.${booking_id}`, {
      method: "PATCH",
      headers,
      body: JSON.stringify({ payment_status: paymentStatus }),
    });

    const updateText = await updateRes.text();
    if (!updateRes.ok) {
      return new Response(JSON.stringify({
        error: `Failed to update booking status. Status ${updateRes.status}, Response: ${updateText}`,
      }), { status: 500 });
    }

    return new Response(JSON.stringify({
      success: true,
      payment_status: paymentStatus,
      stripe_status: intent.status,
    }), { status: 200 });

  } catch (e) {
    return new Response(JSON.stringify({
      error: e instanceof Error ? e.message : String(e),
    }), { status: 500 });
  }
});
