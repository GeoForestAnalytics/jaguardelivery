-- ============================================================
-- Tabela de estado de conversas WhatsApp (chatbot N8N)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.whatsapp_conversas (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  telefone      TEXT        NOT NULL,
  instancia     TEXT        NOT NULL,
  comercio_id   UUID        REFERENCES public.usuarios(id) ON DELETE CASCADE,
  etapa         TEXT        NOT NULL DEFAULT 'INICIO',
  nome          TEXT,
  endereco      TEXT,
  pedido        TEXT,
  pagamento     TEXT,
  atualizado_em TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(telefone, instancia)
);

ALTER TABLE public.whatsapp_conversas ENABLE ROW LEVEL SECURITY;

-- Service role (N8N usa a service_role key) tem acesso total
CREATE POLICY "service role acesso total conversas"
  ON public.whatsapp_conversas
  USING (true)
  WITH CHECK (true);

-- Função para resetar conversas antigas (> 2h sem atividade)
CREATE OR REPLACE FUNCTION public.limpar_conversas_antigas()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  DELETE FROM public.whatsapp_conversas
  WHERE atualizado_em < NOW() - INTERVAL '2 hours'
    AND etapa = 'FINALIZADO';
END;
$$;
