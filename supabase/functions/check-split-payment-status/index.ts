// supabase/functions/check-split-payment-status/index.ts
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

    // Получаем split_payment по ID
    const splitRes = await fetch(
      `${supabaseUrl}/rest/v1/split_payments?id=eq.${split_payment_id}`,
      { headers }
    );
    const splitData = await splitRes.json();
    const payment = splitData[0];
    if (!payment) {
      return new Response(JSON.stringify({ paid: false }), { status: 404 });
    }

    const bookingId = payment.booking_id;

    // Получаем всех с unpaid
    const unpaidRes = await fetch(
      `${supabaseUrl}/rest/v1/split_payments?booking_id=eq.${bookingId}&is_paid=eq.false`,
      { headers }
    );
    const unpaid = await unpaidRes.json();

    if (unpaid.length === 0) {
      // Все оплатили — статус success
      await fetch(`${supabaseUrl}/rest/v1/bookings?id=eq.${bookingId}`, {
        method: "PATCH",
        headers: {
          ...headers,
          "Content-Type": "application/json",
          Prefer: "return=representation",
        },
        body: JSON.stringify({
          payment_status: "success",
          unpaid_amount: 0
        }),
      });
    } else {
      // Часть не оплатили — считаем сколько уже оплачено
      const paidRes = await fetch(
        `${supabaseUrl}/rest/v1/split_payments?booking_id=eq.${bookingId}&is_paid=eq.true`,
        { headers }
      );
      const paid = await paidRes.json();
      const paidAmount = paid.reduce((sum: number, item: any) => sum + (item.amount || 0), 0);

      // Получаем общую стоимость из booking
      const bookingRes = await fetch(
        `${supabaseUrl}/rest/v1/bookings?id=eq.${bookingId}&select=total_price`,
        { headers }
      );
      const bookingJson = await bookingRes.json();
      const totalPrice = bookingJson[0]?.total_price ?? 0;

      const unpaidAmount = totalPrice - paidAmount;

      // Обновляем booking
      await fetch(`${supabaseUrl}/rest/v1/bookings?id=eq.${bookingId}`, {
        method: "PATCH",
        headers: {
          ...headers,
          "Content-Type": "application/json",
          Prefer: "return=representation",
        },
        body: JSON.stringify({
          payment_status: "failed",
          unpaid_amount: unpaidAmount
        }),
      });
    }

    return new Response(JSON.stringify({ paid: payment.is_paid }), { status: 200 });
  } catch (e) {
    const errorMessage = e instanceof Error ? e.message : "Unknown error";
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500 }
    );
  }
});
