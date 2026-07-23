import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

const supabase = createClient(SUPABASE_URL!, SUPABASE_SERVICE_ROLE_KEY!)

Deno.serve(async (req) => {
  try {
    const { message } = await req.json()
    if (!message || !message.text) return new Response('OK')

    const chatId = message.chat.id
    const text = message.text.trim()
    const textLower = text.toLowerCase()

    // CORREGIDO: se agrega '/vincular' (y variantes con mayúsculas/espacios)
    // como disparador del código. Antes solo escuchaba '/start' y 'hola',
    // así que '/vincular' caía directo a la búsqueda de productos de abajo.
    if (
      textLower === '/start' ||
      textLower === '/vincular' ||
      textLower === 'hola'
    ) {
      const shortCode = Math.floor(1000 + Math.random() * 9000).toString() // Genera código de 4 dígitos
      const expiresAt = new Date(Date.now() + 15 * 60 * 1000).toISOString() // Expira en 15 minutos

      const { error: upsertError } = await supabase.from('telegram_customers').upsert({
        chat_id: chatId.toString(),
        username: message.from.username || null,
        short_code: shortCode,
        expires_at: expiresAt
      })

      if (upsertError) {
        console.error('Error guardando telegram_customers:', upsertError)
        await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            chat_id: chatId,
            text: '❌ Hubo un error generando tu código. Intenta de nuevo en un momento.'
          })
        })
        return new Response('OK')
      }

      await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          text: `¡Hola! Tu código de vinculación para OmniNexus POS es: 🔑 ${shortCode}\n\nDíctaselo al cajero al momento de pagar tu compra. Vence en 15 minutos.`
        })
      })
      return new Response('OK')
    }

    // A partir de aquí, cualquier otro texto se trata como búsqueda de producto
    // (sin cambios respecto a lo que ya tenías y funciona bien).
    const { data: products } = await supabase
      .from('products')
      .select('name, price')
      .ilike('name', `%${text}%`)
      .limit(3)

    let responseText = `No encontré ningún producto que coincida con "${text}". Intenta con otro nombre.\n\nSi buscabas vincular tu cuenta, escribe /vincular.`
    if (products && products.length > 0) {
      responseText = `🔍 Resultados para "${text}":\n\n` + 
        products.map(p => `📦 ${p.name}\n💰 Precio: $${p.price}`).join('\n\n')
    }

    await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: chatId, text: responseText })
    })

    return new Response('OK')
  } catch (error) {
    console.error('Error en telegram-webhook:', error)
    return new Response(JSON.stringify({ error: error.message }), { status: 400 })
  }
})