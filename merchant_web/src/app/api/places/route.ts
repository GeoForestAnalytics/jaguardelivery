import { NextRequest, NextResponse } from 'next/server'

const KEY = process.env.GOOGLE_PLACES_KEY!

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const input   = searchParams.get('input')
  const placeId = searchParams.get('place_id')

  if (placeId) {
    const res = await fetch(
      `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=geometry&key=${KEY}&language=pt-BR`
    )
    return NextResponse.json(await res.json())
  }

  if (input) {
    const res = await fetch(
      `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(input)}&key=${KEY}&language=pt-BR&components=country:br&types=address`
    )
    return NextResponse.json(await res.json())
  }

  return NextResponse.json({ error: 'Parâmetro inválido' }, { status: 400 })
}
