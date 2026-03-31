'use client'
import { useState, useEffect, useRef, useCallback } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase'

// ─── Types ───────────────────────────────────────────────────────────────────
type Status = 'PENDENTE' | 'ACEITO' | 'A_CAMINHO' | 'ENTREGUE' | 'CANCELADO'

interface Pedido {
  id: string
  cliente_nome: string
  cliente_tel?: string
  endereco_destino: string
  descricao?: string
  forma_pagamento?: string
  valor_total: number
  status: Status
  criado_em: string
  lat_destino?: number
  long_destino?: number
  comercio_id?: string
  usuario_id?: string
}

interface Linha {
  cliente_nome: string
  cliente_tel: string
  endereco_destino: string
  descricao: string
  forma_pagamento: string
  valor_total: string
  lat_destino?: number
  long_destino?: number
  enderecoConfirmado?: boolean
}

interface ToastItem {
  id: number
  msg: string
  tipo: 'ok' | 'erro'
}

interface Sugestao {
  place_id: string
  description: string
}

// ─── Helpers ─────────────────────────────────────────────────────────────────
const STATUS_CONFIG: Record<Status, { label: string; cor: string }> = {
  PENDENTE:   { label: 'Pendente',    cor: 'bg-yellow-100 text-yellow-700 border-yellow-200' },
  ACEITO:     { label: 'Aceito',      cor: 'bg-blue-100 text-blue-700 border-blue-200' },
  A_CAMINHO:  { label: 'A Caminho',   cor: 'bg-purple-100 text-purple-700 border-purple-200' },
  ENTREGUE:   { label: 'Entregue',    cor: 'bg-green-100 text-green-700 border-green-200' },
  CANCELADO:  { label: 'Cancelado',   cor: 'bg-red-100 text-red-700 border-red-200' },
}

const LINHAS_POR_PAGINA = 20

function linhaVazia(): Linha {
  return { cliente_nome: '', cliente_tel: '', endereco_destino: '', descricao: '', forma_pagamento: 'DINHEIRO', valor_total: '' }
}

// ─── Component ───────────────────────────────────────────────────────────────
export default function DashboardPage() {
  const supabase = createClient()
  const router   = useRouter()

  // Auth
  const [nomeComercio, setNomeComercio] = useState('')
  const [comercioId,   setComercioId]   = useState<string | null>(null)
  const [authReady,    setAuthReady]    = useState(false)

  // Stats
  const [statTotal,     setStatTotal]     = useState(0)
  const [statPendente,  setStatPendente]  = useState(0)
  const [statAndamento, setStatAndamento] = useState(0)
  const [statEntregue,  setStatEntregue]  = useState(0)

  // Pedidos list
  const [pedidos,    setPedidos]    = useState<Pedido[]>([])
  const [filtroAba,  setFiltroAba]  = useState<Status | 'TODOS'>('TODOS')
  const [pagina,     setPagina]     = useState(0)
  const [temMais,    setTemMais]    = useState(false)
  const [carregando, setCarregando] = useState(false)

  // Cancel / Delete
  const [cancelandoId, setCancelandoId] = useState<string | null>(null)
  const [excluindoId,  setExcluindoId]  = useState<string | null>(null)

  // Toast
  const [toasts,    setToasts]    = useState<ToastItem[]>([])
  const toastIdRef = useRef(0)

  // Batch form modal
  const [modalAberto, setModalAberto] = useState(false)
  const [linhas,      setLinhas]      = useState<Linha[]>([linhaVazia()])
  const [enviando,    setEnviando]    = useState(false)

  // Google Places autocomplete
  const [sugestoes,       setSugestoes]       = useState<Sugestao[]>({} as any)
  const [sugestoesIdx,    setSugestoesIdx]    = useState<number | null>(null)
  const debounceRef = useRef<Record<number, ReturnType<typeof setTimeout>>>({})

  // ─── Auth init ─────────────────────────────────────────────────────────────
  useEffect(() => {
    const init = async () => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { router.push('/login'); return }

      const { data: perfil } = await supabase
        .from('usuarios')
        .select('nome_fantasia, id')
        .eq('id', user.id)
        .single()

      setNomeComercio(perfil?.nome_fantasia ?? 'Comerciante')
      setComercioId(perfil?.id ?? user.id)
      setAuthReady(true)
    }
    init()
  }, [])

  // ─── Load stats ────────────────────────────────────────────────────────────
  const carregarStats = useCallback(async (cid: string) => {
    const [t, p, a, e] = await Promise.all([
      supabase.from('pedidos').select('*', { count: 'exact', head: true }).eq('comercio_id', cid),
      supabase.from('pedidos').select('*', { count: 'exact', head: true }).eq('comercio_id', cid).eq('status', 'PENDENTE'),
      supabase.from('pedidos').select('*', { count: 'exact', head: true }).eq('comercio_id', cid).in('status', ['ACEITO', 'A_CAMINHO']),
      supabase.from('pedidos').select('*', { count: 'exact', head: true }).eq('comercio_id', cid).eq('status', 'ENTREGUE'),
    ])
    setStatTotal(t.count ?? 0)
    setStatPendente(p.count ?? 0)
    setStatAndamento(a.count ?? 0)
    setStatEntregue(e.count ?? 0)
  }, [])

  // ─── Load pedidos ──────────────────────────────────────────────────────────
  const carregarPedidos = useCallback(async (cid: string, aba: Status | 'TODOS', pg: number, acumular = false) => {
    setCarregando(true)
    let q = supabase
      .from('pedidos')
      .select('*')
      .eq('comercio_id', cid)
      .order('criado_em', { ascending: false })
      .range(pg * LINHAS_POR_PAGINA, (pg + 1) * LINHAS_POR_PAGINA)

    if (aba !== 'TODOS') q = q.eq('status', aba)

    const { data } = await q
    if (data) {
      setPedidos(prev => acumular ? [...prev, ...data] : data)
      setTemMais(data.length === LINHAS_POR_PAGINA + 1)
      if (data.length === LINHAS_POR_PAGINA + 1) data.pop()
    }
    setCarregando(false)
  }, [])

  // ─── Init after auth ───────────────────────────────────────────────────────
  useEffect(() => {
    if (!authReady || !comercioId) return

    carregarStats(comercioId)
    carregarPedidos(comercioId, filtroAba, 0)

    const channel = supabase
      .channel('pedidos-realtime')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'pedidos', filter: `comercio_id=eq.${comercioId}` }, () => {
        carregarStats(comercioId)
        carregarPedidos(comercioId, filtroAba, 0)
      })
      .subscribe()

    return () => { supabase.removeChannel(channel) }
  }, [authReady, comercioId])

  // ─── Filter change ─────────────────────────────────────────────────────────
  const mudarAba = (aba: Status | 'TODOS') => {
    setFiltroAba(aba)
    setPagina(0)
    if (comercioId) carregarPedidos(comercioId, aba, 0)
  }

  const carregarMais = () => {
    const novaP = pagina + 1
    setPagina(novaP)
    if (comercioId) carregarPedidos(comercioId, filtroAba, novaP, true)
  }

  // ─── Delete ────────────────────────────────────────────────────────────────
  const confirmarExclusao = async (id: string) => {
    const { error } = await supabase.from('pedidos').delete().eq('id', id)
    if (error) toast('Erro ao excluir pedido.', 'erro')
    else toast('Pedido excluído.', 'ok')
    setExcluindoId(null)
  }

  // ─── Cancel ────────────────────────────────────────────────────────────────
  const confirmarCancelamento = async (id: string) => {
    const { error } = await supabase
      .from('pedidos')
      .update({ status: 'CANCELADO' })
      .eq('id', id)
      .in('status', ['PENDENTE', 'ACEITO'])

    if (error) {
      toast('Erro ao cancelar pedido.', 'erro')
    } else {
      toast('Pedido cancelado.', 'ok')
    }
    setCancelandoId(null)
  }

  // ─── Toast ─────────────────────────────────────────────────────────────────
  const toast = (msg: string, tipo: 'ok' | 'erro' = 'ok') => {
    const id = ++toastIdRef.current
    setToasts(prev => [...prev, { id, msg, tipo }])
    setTimeout(() => setToasts(prev => prev.filter(t => t.id !== id)), 4000)
  }

  // ─── Logout ────────────────────────────────────────────────────────────────
  const sair = async () => {
    await supabase.auth.signOut()
    router.push('/login')
  }

  // ─── Batch form ────────────────────────────────────────────────────────────
  const abrirModal = () => {
    setLinhas([linhaVazia()])
    setSugestoes({} as any)
    setSugestoesIdx(null)
    setModalAberto(true)
  }

  const atualizarLinha = (i: number, campo: keyof Linha, valor: string) => {
    setLinhas(prev => prev.map((l, idx) => idx === i ? { ...l, [campo]: valor, enderecoConfirmado: campo === 'endereco_destino' ? false : l.enderecoConfirmado } : l))
  }

  const onEnderecoChange = (i: number, valor: string) => {
    atualizarLinha(i, 'endereco_destino', valor)
    clearTimeout(debounceRef.current[i])
    if (valor.length < 3) { setSugestoes(prev => ({ ...prev, [i]: [] })); return }
    debounceRef.current[i] = setTimeout(async () => {
      setSugestoesIdx(i)
      const res = await fetch(`/api/places?input=${encodeURIComponent(valor)}`)
      const json = await res.json()
      setSugestoes(prev => ({ ...prev, [i]: json.predictions ?? [] }))
    }, 400)
  }

  const selecionarSugestao = async (i: number, s: Sugestao) => {
    setSugestoes(prev => ({ ...prev, [i]: [] }))
    setSugestoesIdx(null)
    atualizarLinha(i, 'endereco_destino', s.description)

    const res  = await fetch(`/api/places?place_id=${s.place_id}`)
    const json = await res.json()
    const loc  = json.result?.geometry?.location
    if (loc) {
      setLinhas(prev => prev.map((l, idx) => idx === i
        ? { ...l, endereco_destino: s.description, lat_destino: loc.lat, long_destino: loc.lng, enderecoConfirmado: true }
        : l
      ))
    }
  }

  const validarLinhas = () => {
    for (const l of linhas) {
      if (!l.cliente_nome.trim())    { toast('Preencha o nome do cliente em todas as linhas.', 'erro'); return false }
      if (!l.endereco_destino.trim()) { toast('Preencha o endereço em todas as linhas.', 'erro'); return false }
    }
    return true
  }

  const enviarLote = async () => {
    if (!validarLinhas()) return
    setEnviando(true)
    try {
      const inserts = linhas.map(l => ({
        cliente_nome:      l.cliente_nome.trim(),
        cliente_tel:       l.cliente_tel.trim() || null,
        endereco_destino:  l.endereco_destino.trim(),
        descricao:         l.descricao.trim() || null,
        forma_pagamento:   l.forma_pagamento,
        valor_total:       parseFloat(l.valor_total) || 0,
        lat_destino:       l.lat_destino ?? null,
        long_destino:      l.long_destino ?? null,
        status:            'PENDENTE',
        comercio_id:       comercioId,
      }))

      const { error } = await supabase.from('pedidos').insert(inserts)
      if (error) throw error

      toast(`${linhas.length} entrega(s) solicitada(s) com sucesso!`, 'ok')
      setModalAberto(false)
    } catch (e: any) {
      toast('Erro ao enviar: ' + e.message, 'erro')
    } finally {
      setEnviando(false)
    }
  }

  // ─── Loading / auth guard ──────────────────────────────────────────────────
  if (!authReady) {
    return (
      <div className="min-h-screen bg-indigo-950 flex items-center justify-center">
        <div className="text-white text-center">
          <div className="text-5xl mb-4">🐆</div>
          <p className="text-indigo-300">Carregando...</p>
        </div>
      </div>
    )
  }

  const pedidosFiltrados = pedidos

  // ─── Render ────────────────────────────────────────────────────────────────
  return (
    <div className="min-h-screen bg-gray-50">

      {/* ── Toasts ── */}
      <div className="fixed top-4 right-4 z-50 space-y-2">
        {toasts.map(t => (
          <div key={t.id} className={`px-5 py-3 rounded-xl shadow-lg text-sm font-semibold text-white transition-all ${t.tipo === 'ok' ? 'bg-green-600' : 'bg-red-600'}`}>
            {t.tipo === 'ok' ? '✓' : '✕'} {t.msg}
          </div>
        ))}
      </div>

      {/* ── Header ── */}
      <header className="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between sticky top-0 z-30 shadow-sm">
        <div className="flex items-center gap-3">
          <span className="text-3xl">🐆</span>
          <div>
            <h1 className="font-black text-indigo-900 text-lg leading-none">Jaguar Delivery</h1>
            <p className="text-gray-500 text-xs">{nomeComercio}</p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={abrirModal}
            className="bg-indigo-600 text-white px-5 py-2 rounded-xl font-bold text-sm hover:bg-indigo-700 transition-all shadow"
          >
            + Nova Entrega
          </button>
          <button onClick={sair} className="text-gray-400 hover:text-gray-700 text-sm px-3 py-2 rounded-lg hover:bg-gray-100 transition">
            Sair
          </button>
        </div>
      </header>

      <main className="max-w-6xl mx-auto px-4 py-8">

        {/* ── Stats ── */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
          {[
            { label: 'Total Hoje',   valor: statTotal,     cor: 'text-indigo-700',  bg: 'bg-indigo-50',  icon: '📦' },
            { label: 'Pendentes',    valor: statPendente,  cor: 'text-yellow-700',  bg: 'bg-yellow-50',  icon: '⏳' },
            { label: 'Em Andamento', valor: statAndamento, cor: 'text-blue-700',    bg: 'bg-blue-50',    icon: '🏍️' },
            { label: 'Entregues',    valor: statEntregue,  cor: 'text-green-700',   bg: 'bg-green-50',   icon: '✅' },
          ].map(s => (
            <div key={s.label} className={`${s.bg} rounded-2xl p-5 border border-gray-100 shadow-sm`}>
              <div className="text-2xl mb-1">{s.icon}</div>
              <div className={`text-3xl font-black ${s.cor}`}>{s.valor}</div>
              <div className="text-gray-500 text-sm mt-1">{s.label}</div>
            </div>
          ))}
        </div>

        {/* ── Filter tabs ── */}
        <div className="flex gap-2 mb-4 flex-wrap">
          {(['TODOS', 'PENDENTE', 'ACEITO', 'A_CAMINHO', 'ENTREGUE', 'CANCELADO'] as const).map(aba => {
            const cfg = aba === 'TODOS' ? { label: 'Todos', cor: '' } : STATUS_CONFIG[aba]
            const ativo = filtroAba === aba
            return (
              <button
                key={aba}
                onClick={() => mudarAba(aba)}
                className={`px-4 py-2 rounded-xl text-sm font-semibold border transition-all ${ativo ? 'bg-indigo-600 text-white border-indigo-600 shadow' : 'bg-white text-gray-600 border-gray-200 hover:border-indigo-300'}`}
              >
                {aba === 'TODOS' ? 'Todos' : cfg.label}
              </button>
            )
          })}
        </div>

        {/* ── Table ── */}
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full text-left">
              <thead className="bg-gray-50 border-b border-gray-200">
                <tr className="text-xs font-semibold text-gray-500 uppercase tracking-wider">
                  <th className="px-5 py-4">Cliente</th>
                  <th className="px-5 py-4">Endereço</th>
                  <th className="px-5 py-4">Pagamento</th>
                  <th className="px-5 py-4">Valor</th>
                  <th className="px-5 py-4">Status</th>
                  <th className="px-5 py-4">Horário</th>
                  <th className="px-5 py-4">Ação</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {pedidosFiltrados.length === 0 && !carregando && (
                  <tr>
                    <td colSpan={7} className="text-center text-gray-400 py-16 text-sm">
                      Nenhuma entrega encontrada.
                    </td>
                  </tr>
                )}
                {pedidosFiltrados.map(p => {
                  const cfg = STATUS_CONFIG[p.status] ?? STATUS_CONFIG['PENDENTE']
                  const hora = new Date(p.criado_em).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' })
                  const cancelavel = p.status === 'PENDENTE' || p.status === 'ACEITO'
                  return (
                    <tr key={p.id} className="hover:bg-gray-50 transition-colors">
                      <td className="px-5 py-4">
                        <div className="font-semibold text-gray-800 text-sm">{p.cliente_nome || '—'}</div>
                        {p.cliente_tel && <div className="text-gray-400 text-xs">{p.cliente_tel}</div>}
                      </td>
                      <td className="px-5 py-4 max-w-xs">
                        <div className="text-gray-700 text-sm truncate">{p.endereco_destino}</div>
                        {p.descricao && <div className="text-gray-400 text-xs truncate">{p.descricao}</div>}
                      </td>
                      <td className="px-5 py-4 text-gray-600 text-sm">{p.forma_pagamento ?? 'DINHEIRO'}</td>
                      <td className="px-5 py-4 font-bold text-green-700 text-sm">
                        R$ {(p.valor_total ?? 0).toFixed(2)}
                      </td>
                      <td className="px-5 py-4">
                        <span className={`px-3 py-1 rounded-full text-xs font-bold border ${cfg.cor}`}>
                          {cfg.label}
                        </span>
                      </td>
                      <td className="px-5 py-4 text-gray-400 text-sm">{hora}</td>
                      <td className="px-5 py-4">
                        {excluindoId === p.id ? (
                          <div className="flex items-center gap-2">
                            <button onClick={() => confirmarExclusao(p.id)} className="text-xs bg-red-600 text-white px-3 py-1 rounded-lg font-bold hover:bg-red-700 transition">Confirmar</button>
                            <button onClick={() => setExcluindoId(null)} className="text-xs bg-gray-100 text-gray-600 px-3 py-1 rounded-lg font-bold hover:bg-gray-200 transition">Não</button>
                          </div>
                        ) : cancelandoId === p.id ? (
                          <div className="flex items-center gap-2">
                            <button onClick={() => confirmarCancelamento(p.id)} className="text-xs bg-red-600 text-white px-3 py-1 rounded-lg font-bold hover:bg-red-700 transition">Confirmar</button>
                            <button onClick={() => setCancelandoId(null)} className="text-xs bg-gray-100 text-gray-600 px-3 py-1 rounded-lg font-bold hover:bg-gray-200 transition">Não</button>
                          </div>
                        ) : p.status === 'CANCELADO' ? (
                          <button onClick={() => setExcluindoId(p.id)} className="text-xs text-gray-400 hover:text-red-600 font-semibold hover:underline transition">
                            Excluir
                          </button>
                        ) : cancelavel ? (
                          <button onClick={() => setCancelandoId(p.id)} className="text-xs text-red-500 hover:text-red-700 font-semibold hover:underline transition">
                            Cancelar
                          </button>
                        ) : (
                          <span className="text-gray-300 text-xs">—</span>
                        )}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>

          {temMais && (
            <div className="border-t border-gray-100 p-4 flex justify-center">
              <button onClick={carregarMais} disabled={carregando} className="text-indigo-600 font-semibold text-sm hover:underline disabled:text-gray-400">
                {carregando ? 'Carregando...' : 'Carregar mais'}
              </button>
            </div>
          )}
        </div>
      </main>

      {/* ── Modal: Nova Entrega ── */}
      {modalAberto && (
        <div className="fixed inset-0 z-50 bg-black/50 flex items-start justify-center pt-8 px-4 pb-8 overflow-y-auto">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-4xl">
            {/* Modal header */}
            <div className="flex items-center justify-between px-6 py-5 border-b border-gray-200">
              <h2 className="text-lg font-black text-gray-800">Solicitar Entregas 🏍️</h2>
              <button onClick={() => setModalAberto(false)} className="text-gray-400 hover:text-gray-700 text-xl leading-none">✕</button>
            </div>

            {/* Lines */}
            <div className="px-6 py-4 space-y-4 max-h-[60vh] overflow-y-auto">
              {linhas.map((linha, i) => (
                <div key={i} className="bg-gray-50 rounded-xl p-4 border border-gray-200">
                  <div className="flex items-center justify-between mb-3">
                    <span className="text-xs font-bold text-gray-500 uppercase">Entrega #{i + 1}</span>
                    {linhas.length > 1 && (
                      <button onClick={() => setLinhas(prev => prev.filter((_, idx) => idx !== i))} className="text-red-400 hover:text-red-600 text-sm">✕ Remover</button>
                    )}
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                    {/* Cliente */}
                    <input
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
                      placeholder="Nome do cliente *"
                      value={linha.cliente_nome}
                      onChange={e => atualizarLinha(i, 'cliente_nome', e.target.value)}
                    />
                    {/* Telefone */}
                    <input
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
                      placeholder="Telefone do cliente"
                      value={linha.cliente_tel}
                      onChange={e => atualizarLinha(i, 'cliente_tel', e.target.value)}
                    />
                    {/* Endereço com autocomplete */}
                    <div className="relative md:col-span-2">
                      <div className="flex gap-2 items-center">
                        <input
                          className={`flex-1 px-3 py-2 border rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 ${linha.enderecoConfirmado ? 'border-green-400 bg-green-50' : 'border-gray-300'}`}
                          placeholder="Endereço de entrega *"
                          value={linha.endereco_destino}
                          onChange={e => onEnderecoChange(i, e.target.value)}
                          autoComplete="off"
                        />
                        {linha.enderecoConfirmado && <span className="text-green-600 text-lg">✓</span>}
                      </div>
                      {sugestoesIdx === i && (sugestoes as any)[i]?.length > 0 && (
                        <ul className="absolute top-full left-0 right-0 bg-white border border-gray-200 rounded-xl shadow-xl z-50 mt-1 overflow-hidden">
                          {((sugestoes as any)[i] as Sugestao[]).map(s => (
                            <li
                              key={s.place_id}
                              className="px-4 py-3 text-sm text-gray-700 hover:bg-indigo-50 cursor-pointer border-b border-gray-100 last:border-0"
                              onClick={() => selecionarSugestao(i, s)}
                            >
                              📍 {s.description}
                            </li>
                          ))}
                        </ul>
                      )}
                    </div>
                    {/* Descrição */}
                    <input
                      className="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
                      placeholder="Descrição do pedido"
                      value={linha.descricao}
                      onChange={e => atualizarLinha(i, 'descricao', e.target.value)}
                    />
                    {/* Pagamento + Valor */}
                    <div className="flex gap-2">
                      <select
                        className="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400 bg-white"
                        value={linha.forma_pagamento}
                        onChange={e => atualizarLinha(i, 'forma_pagamento', e.target.value)}
                      >
                        <option value="DINHEIRO">Dinheiro</option>
                        <option value="PIX">PIX</option>
                        <option value="CARTAO">Cartão</option>
                        <option value="FIADO">Fiado</option>
                      </select>
                      <input
                        type="number"
                        min="0"
                        step="0.01"
                        className="w-28 px-3 py-2 border border-gray-300 rounded-lg text-sm font-bold text-green-700 focus:outline-none focus:ring-2 focus:ring-indigo-400"
                        placeholder="R$ taxa"
                        value={linha.valor_total}
                        onChange={e => atualizarLinha(i, 'valor_total', e.target.value)}
                      />
                    </div>
                  </div>
                </div>
              ))}
            </div>

            {/* Modal footer */}
            <div className="px-6 py-4 border-t border-gray-200 flex items-center justify-between gap-3">
              <button
                onClick={() => setLinhas(prev => [...prev, linhaVazia()])}
                className="text-indigo-600 font-semibold text-sm hover:underline"
              >
                + Adicionar entrega
              </button>
              <div className="flex gap-3">
                <button onClick={() => setModalAberto(false)} className="px-5 py-2 rounded-xl border border-gray-300 text-gray-600 text-sm font-semibold hover:bg-gray-50 transition">
                  Cancelar
                </button>
                <button
                  onClick={enviarLote}
                  disabled={enviando}
                  className="px-6 py-2 bg-indigo-600 text-white rounded-xl font-bold text-sm hover:bg-indigo-700 disabled:bg-gray-400 transition shadow"
                >
                  {enviando ? 'Enviando...' : `Solicitar ${linhas.length > 1 ? linhas.length + ' motos' : 'moto'} 🏍️`}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
