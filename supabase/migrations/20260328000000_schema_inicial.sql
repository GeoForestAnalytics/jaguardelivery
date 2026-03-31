-- ============================================================
-- Jaguar Delivery — Schema Inicial
-- ============================================================

-- Extensões
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------
-- TABELA: usuarios
-- Perfil público vinculado ao auth.users do Supabase
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.usuarios (
  id                   UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  nome                 TEXT        NOT NULL,
  email                TEXT        NOT NULL,
  telefone             TEXT,
  cpf_cnpj             TEXT        UNIQUE,
  tipo                 TEXT        NOT NULL DEFAULT 'CLIENTE'
                         CHECK (tipo IN ('CLIENTE', 'MOTOBOY', 'COMERCIO', 'ADMIN')),
  foto_url             TEXT,
  -- Campos exclusivos do motoboy
  moto_modelo          TEXT,
  moto_placa           TEXT,
  validade_assinatura  TIMESTAMPTZ,
  -- Campos exclusivos do comércio
  nome_fantasia        TEXT,
  endereco_comercio    TEXT,
  lat_comercio         FLOAT8,
  lng_comercio         FLOAT8,
  data_cadastro        TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- TABELA: corridas
-- Corridas e entregas solicitadas pelo app (passageiro/cliente)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.corridas (
  id                   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  id_solicitante       UUID        REFERENCES public.usuarios(id) ON DELETE SET NULL,
  nome_solicitante     TEXT,
  telefone_solicitante TEXT,
  id_motoboy           UUID        REFERENCES public.usuarios(id) ON DELETE SET NULL,
  lat_origem           FLOAT8      NOT NULL,
  long_origem          FLOAT8      NOT NULL,
  endereco_origem      TEXT,
  lat_destino          FLOAT8,
  long_destino         FLOAT8,
  endereco_destino     TEXT,
  valor                NUMERIC(10,2),
  distancia_km         FLOAT8,
  pagamento            TEXT        DEFAULT 'Pix',
  tipo_servico         TEXT        DEFAULT 'PASSAGEIRO',
  item_entrega         TEXT,
  observacao           TEXT,
  status               TEXT        NOT NULL DEFAULT 'PENDENTE'
                         CHECK (status IN ('PENDENTE','ACEITO','A_CAMINHO_COLETA','EM_VIAGEM','FINALIZADO','CANCELADO')),
  lat_motoboy          FLOAT8,
  long_motoboy         FLOAT8,
  criado_em            TIMESTAMPTZ DEFAULT NOW(),
  data_aceite          TIMESTAMPTZ,
  data_finalizacao     TIMESTAMPTZ
);

-- ------------------------------------------------------------
-- TABELA: pedidos
-- Entregas comerciais criadas pelo merchant_web
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pedidos (
  id                   UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  comercio_id          UUID        REFERENCES public.usuarios(id) ON DELETE SET NULL,
  motoboy_id           UUID        REFERENCES public.usuarios(id) ON DELETE SET NULL,
  cliente_nome         TEXT,
  cliente_tel          TEXT,
  endereco_destino     TEXT,
  lat_destino          FLOAT8,
  long_destino         FLOAT8,
  valor_total          NUMERIC(10,2),
  descricao            TEXT,
  status               TEXT        NOT NULL DEFAULT 'PENDENTE',
  criado_em            TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- ROW LEVEL SECURITY
-- ------------------------------------------------------------
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.corridas  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos   ENABLE ROW LEVEL SECURITY;

-- usuarios: todos autenticados podem ler (necessário para drawer / painel CEO)
CREATE POLICY "autenticados podem ler usuarios"
  ON public.usuarios FOR SELECT
  USING (auth.role() = 'authenticated');

-- usuarios: cada user gerencia apenas seu próprio perfil
CREATE POLICY "usuario gerencia proprio perfil insert"
  ON public.usuarios FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "usuario gerencia proprio perfil update"
  ON public.usuarios FOR UPDATE
  USING (auth.uid() = id);

-- corridas: todos autenticados podem ler, inserir e atualizar
CREATE POLICY "autenticados podem ler corridas"
  ON public.corridas FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "autenticados podem inserir corridas"
  ON public.corridas FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "autenticados podem atualizar corridas"
  ON public.corridas FOR UPDATE
  USING (auth.role() = 'authenticated');

-- solicitante pode deletar apenas seu próprio pedido pendente
CREATE POLICY "solicitante pode cancelar corrida"
  ON public.corridas FOR DELETE
  USING (auth.uid() = id_solicitante);

-- pedidos: todos autenticados podem ler e atualizar
CREATE POLICY "autenticados podem ler pedidos"
  ON public.pedidos FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "autenticados podem atualizar pedidos"
  ON public.pedidos FOR UPDATE
  USING (auth.role() = 'authenticated');

-- ------------------------------------------------------------
-- FUNÇÃO: aceitar_corrida (aceite atômico — evita corrida dupla)
-- Retorna TRUE se aceitou, FALSE se já foi pega
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.aceitar_corrida(
  p_corrida_id UUID,
  p_motoboy_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_status TEXT;
BEGIN
  SELECT status INTO v_status
    FROM public.corridas
   WHERE id = p_corrida_id
     FOR UPDATE;

  IF v_status = 'PENDENTE' THEN
    UPDATE public.corridas
       SET status     = 'ACEITO',
           id_motoboy = p_motoboy_id,
           data_aceite = NOW()
     WHERE id = p_corrida_id;
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$;

-- ------------------------------------------------------------
-- REALTIME — habilitar tabelas para transmissão ao vivo
-- ------------------------------------------------------------
ALTER PUBLICATION supabase_realtime ADD TABLE public.corridas;
ALTER PUBLICATION supabase_realtime ADD TABLE public.pedidos;
ALTER PUBLICATION supabase_realtime ADD TABLE public.usuarios;
