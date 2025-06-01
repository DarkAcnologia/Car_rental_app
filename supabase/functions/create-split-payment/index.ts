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

    // Получаем информацию о платеже
    const splitRes = await fetch(
      `${supabaseUrl}/rest/v1/split_payments?id=eq.${split_payment_id}`,
      { headers }
    );
    const splitData = await splitRes.json();
    const payment = splitData[0];

    if (!payment) {
      return new Response(JSON.stringify({ error: "Split payment not found" }), { status: 404 });
    }

    // 1. Создаем продукт
    const product = await stripe.products.create({
      name: `Оплата от ${payment.contributor_name}`,
    });

    // 2. Создаем цену
    const price = await stripe.prices.create({
      unit_amount: Math.round(payment.amount * 100),
      currency: "rub",
      product: product.id,
    });

    // 3. Создаем ссылку оплаты
    const link = await stripe.paymentLinks.create({
      line_items: [
        {
          price: price.id,
          quantity: 1,
        },
      ],
      metadata: {
        split_payment_id,
        booking_id: payment.booking_id,
        contributor: payment.contributor_name,
      },
    });

    return new Response(JSON.stringify({ url: link.url }), { status: 200 });

  } catch (e) {
    return new Response(
      JSON.stringify({ error: e instanceof Error ? e.message : String(e) }),
      { status: 500 }
    );
  }
});
