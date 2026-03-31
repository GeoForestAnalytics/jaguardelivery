import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

// Secrets configurados via: supabase secrets set ONESIGNAL_APP_ID=xxx ONESIGNAL_API_KEY=yyy
const ONESIGNAL_APP_ID  = Deno.env.get('ONESIGNAL_APP_ID')!
const ONESIGNAL_API_KEY = Deno.env.get('ONESIGNAL_API_KEY')!

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    const { player_ids, titulo, mensagem, dados } = await req.json()

    if (!player_ids || player_ids.length === 0) {
      return new Response(JSON.stringify({ error: 'Nenhum player_id fornecido' }), { status: 400 })
    }

    const payload = {
      app_id:             ONESIGNAL_APP_ID,
      include_player_ids: player_ids,
      headings:           { pt: titulo, en: titulo },
      contents:           { pt: mensagem, en: mensagem },
      data:               dados ?? {},
    }

    const res = await fetch('https://onesignal.com/api/v1/notifications', {
      method:  'POST',
      headers: {
        'Content-Type':  'application/json',
        'Authorization': `Basic ${ONESIGNAL_API_KEY}`,
      },
      body: JSON.stringify(payload),
    })

    const result = await res.json()
    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 })
  }
})
