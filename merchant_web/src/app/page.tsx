'use client'
import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase'

export default function MultiPedidosPage() {
  const supabase = createClient()
  const [loading, setLoading] = useState(false)
  const [pedidosAtivos, setPedidosAtivos] = useState<any[]>([]) // Para o dashboard
  const [pedidos, setPedidos] = useState([
    { cliente_nome: '', endereco_destino: '', valor_total: '' }
  ])

  // --- BUSCAR PEDIDOS EXISTENTES E OUVIR REALTIME ---
  useEffect(() => {
    buscarPedidosAtivos()

    // Ouve o Supabase: se qualquer pedido mudar, atualiza a lista na tela
    const channel = supabase
      .channel('schema-db-changes')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'pedidos' }, () => {
        buscarPedidosAtivos()
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [])

  const buscarPedidosAtivos = async () => {
    const { data } = await supabase
      .from('pedidos')
      .select('*')
      .order('criado_em', { ascending: false })
      .limit(10)
    if (data) setPedidosAtivos(data)
  }

  // --- LÓGICA DO FORMULÁRIO ---
  const adicionarLinha = () => {
    setPedidos([...pedidos, { cliente_nome: '', endereco_destino: '', valor_total: '' }])
  }

  const removerLinha = (index: number) => {
    if (pedidos.length > 1) setPedidos(pedidos.filter((_, i) => i !== index))
  }

  const handleChange = (index: number, field: string, value: string) => {
    const novosPedidos = [...pedidos]
    novosPedidos[index] = { ...novosPedidos[index], [field]: value }
    setPedidos(novosPedidos)
  }

  // --- INTELIGÊNCIA DE LOCALIZAÇÃO (MAPA) ---
  const buscarCoordenadas = async (endereco: string) => {
    try {
      const response = await fetch(
        `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(endereco)}&limit=1`
      )
      const data = await response.json()
      if (data && data.length > 0) {
        return { lat: parseFloat(data[0].lat), lon: parseFloat(data[0].lon) }
      }
    } catch (err) {
      console.error("Erro na geocodificação:", err)
    }
    return { lat: 0, lon: 0 }
  }

  // --- ENVIAR PARA O SUPABASE ---
  const enviarPedidos = async () => {
    setLoading(true)
    try {
      const userRes = await supabase.auth.getUser()
      const userId = userRes.data.user?.id

      const pedidosComCoordenadas = await Promise.all(
        pedidos.map(async (p) => {
          const coords = await buscarCoordenadas(p.endereco_destino)
          return {
            cliente_nome: p.cliente_nome,
            endereco_destino: p.endereco_destino,
            valor_total: parseFloat(p.valor_total) || 0,
            lat_destino: coords.lat,
            long_destino: coords.lon,
            status: 'PENDENTE',
            usuario_id: userId // Vincula ao lojista logado
          }
        })
      )

      const { error } = await supabase.from('pedidos').insert(pedidosComCoordenadas)

      if (error) throw error

      alert('🚀 ' + pedidos.length + ' pedidos enviados com sucesso!')
      setPedidos([{ cliente_nome: '', endereco_destino: '', valor_total: '' }])
    } catch (error: any) {
      alert('Erro ao enviar: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  return (
    <main className="min-h-screen bg-gray-100 p-4 md:p-8">
      <div className="max-w-5xl mx-auto">
        <header className="mb-10 text-center md:text-left">
          <h1 className="text-4xl font-black text-indigo-900">Jaguar Delivery 🐆</h1>
          <p className="text-gray-600">Painel do Comerciante - Lançamento e Acompanhamento</p>
        </header>

        {/* FORMULÁRIO DE LANÇAMENTO */}
        <div className="bg-white shadow-xl rounded-2xl p-6 mb-8 border border-gray-200">
          <div className="flex justify-between items-center mb-6">
            <h2 className="text-xl font-bold text-gray-800">Novo Lote de Entregas</h2>
            <button onClick={adicionarLinha} className="text-indigo-600 font-bold hover:underline">
              + Adicionar Linha
            </button>
          </div>

          <div className="space-y-3">
            {pedidos.map((pedido, index) => (
              <div key={index} className="grid grid-cols-1 md:grid-cols-12 gap-3 bg-gray-50 p-3 rounded-xl border">
                <div className="md:col-span-3">
                  <input className="w-full p-2 rounded border" value={pedido.cliente_nome} onChange={(e) => handleChange(index, 'cliente_nome', e.target.value)} placeholder="Cliente" />
                </div>
                <div className="md:col-span-6">
                  <input className="w-full p-2 rounded border" value={pedido.endereco_destino} onChange={(e) => handleChange(index, 'endereco_destino', e.target.value)} placeholder="Endereço (Rua, Número, Bairro)" />
                </div>
                <div className="md:col-span-2">
                  <input type="number" className="w-full p-2 rounded border font-bold text-green-700" value={pedido.valor_total} onChange={(e) => handleChange(index, 'valor_total', e.target.value)} placeholder="R$ Taxa" />
                </div>
                <div className="md:col-span-1 flex justify-center">
                  <button onClick={() => removerLinha(index)} className="text-red-500 text-xl">✕</button>
                </div>
              </div>
            ))}
          </div>

          <div className="mt-8 flex justify-center md:justify-end">
            <button 
              onClick={enviarPedidos} 
              disabled={loading}
              className="bg-indigo-600 text-white px-10 py-4 rounded-xl font-bold shadow-lg hover:bg-indigo-700 disabled:bg-gray-400 transition-all"
            >
              {loading ? 'BUSCANDO LOCALIZAÇÕES...' : 'SOLICITAR MOTOS AGORA 🏍️'}
            </button>
          </div>
        </div>

        {/* DASHBOARD DE ACOMPANHAMENTO REALTIME */}
        <div className="bg-white shadow-xl rounded-2xl p-6 border border-gray-200">
          <h2 className="text-xl font-bold text-gray-800 mb-6">Últimas Solicitações (Tempo Real)</h2>
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead>
                <tr className="text-gray-400 text-sm uppercase">
                  <th className="pb-4">Cliente</th>
                  <th className="pb-4">Endereço</th>
                  <th className="pb-4">Status</th>
                  <th className="pb-4">Valor</th>
                </tr>
              </thead>
              <tbody className="divide-y">
                {pedidosAtivos.map((p) => (
                  <tr key={p.id} className="text-sm">
                    <td className="py-4 font-semibold">{p.cliente_nome}</td>
                    <td className="py-4 text-gray-600">{p.endereco_destino}</td>
                    <td className="py-4">
                      <span className={`px-3 py-1 rounded-full text-xs font-bold ${
                        p.status === 'PENDENTE' ? 'bg-yellow-100 text-yellow-700' : 
                        p.status === 'ACEITO' ? 'bg-blue-100 text-blue-700' : 'bg-green-100 text-green-700'
                      }`}>
                        {p.status}
                      </span>
                    </td>
                    <td className="py-4 font-bold text-green-700">R$ {p.valor_total.toFixed(2)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </main>
  )
}