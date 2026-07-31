import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)

async function sendTelegramMessage(chatId: number | string, text: string) {
  await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text, parse_mode: 'Markdown' })
  })
}

Deno.serve(async (req) => {
  try {
    const { message } = await req.json()
    if (!message || !message.text) return new Response('OK')

    const chatId = message.chat.id
    const text = message.text.trim()
    const textLower = text.toLowerCase()

    // Saludo de bienvenida simple, separado del flujo de vinculación.
    if (textLower === '/start' || textLower === 'hola') {
      await sendTelegramMessage(
        chatId,
        `¡Hola! 👋 Soy el bot de *Abarrotes Doña Mary*.\n\nPuedo ayudarte con:\n\n🔗 Vincular tu cuenta para tus compras — escribe /vincular\n🔍 Consultar precio y existencia de un producto — escribe el nombre o el código de barras (ej. "café" o "7501059224827")`
      )
      return new Response('OK')
    }

    // Vinculación con código PERMANENTE: se genera una sola vez por
    // cliente y se reutiliza en cada compra futura, en vez de rotar
    // cada 15 minutos.
    if (textLower === '/vincular') {
      const { data: existing } = await supabase
        .from('telegram_customers')
        .select('short_code')
        .eq('chat_id', chatId.toString())
        .maybeSingle()

      let shortCode = existing?.short_code

      if (!shortCode) {
        // Genera un código nuevo, verificando que no esté ya asignado a otro cliente.
        let isUnique = false
        while (!isUnique) {
          shortCode = Math.floor(1000 + Math.random() * 9000).toString()
          const { data: taken } = await supabase
            .from('telegram_customers')
            .select('chat_id')
            .eq('short_code', shortCode)
            .maybeSingle()
          isUnique = !taken
        }

        const { error: upsertError } = await supabase.from('telegram_customers').upsert({
          chat_id: chatId.toString(),
          username: message.from.username || null,
          short_code: shortCode
        })

        if (upsertError) {
          console.error('Error guardando telegram_customers:', upsertError)
          await sendTelegramMessage(chatId, '❌ Hubo un error generando tu código. Intenta de nuevo en un momento.')
          return new Response('OK')
        }
      }

      await sendTelegramMessage(
        chatId,
        `¡Hola! Tu código permanente para OmniNexus POS es: 🔑 ${shortCode}\n\nDíctaselo al cajero cada vez que compres. No cambia — ¡guárdalo!`
      )
      return new Response('OK')
    }

    // Búsqueda de producto: por código de barras exacto (6+ dígitos) o por nombre.
    const isBarcode = /^\d{6,}$/.test(text)

    const query = supabase.from('products').select('name, price, stock, is_weighted, unit')
    const { data: products } = isBarcode
      ? await query.eq('code', text).limit(3)
      : await query.ilike('name', `%${text}%`).limit(3)

    let responseText = `No encontré ningún producto que coincida con "${text}". Intenta con otro nombre o su código de barras.\n\nSi buscabas vincular tu cuenta, escribe /vincular.`
    if (products && products.length > 0) {
      responseText = `🔍 Resultados para "${text}":\n\n` +
        products.map(p => {
          const unidad = p.is_weighted ? (p.unit || 'kg') : 'pza'
          const precioLinea = p.is_weighted ? `💰 Precio: $${p.price} / ${unidad}` : `💰 Precio: $${p.price}`
          return `📦 ${p.name}\n${precioLinea}\n📊 Stock: ${p.stock} ${unidad}`
        }).join('\n\n')
    }

    await sendTelegramMessage(chatId, responseText)
    return new Response('OK')
  } catch (error) {
    console.error('Error en telegram-webhook:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})