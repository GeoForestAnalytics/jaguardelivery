-- ============================================================
-- Jaguar Delivery — Melhorias v2
-- OneSignal, Avaliações, RLS completo
-- ============================================================

-- ── Novos campos em usuarios ──────────────────────────────────────────────────
ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS onesignal_player_id TEXT,
  ADD COLUMN IF NOT EXISTS avaliacao_media      FLOAT8  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_avaliacoes     INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS auth_id              UUID;   -- alias útil para merchant_web

-- Preenche auth_id com o próprio id (são iguais no esquema atual)
UPDATE public.usuarios SET auth_id = id WHERE auth_id IS NULL;

-- ── Novos campos em corridas ──────────────────────────────────────────────────
ALTER TABLE public.corridas
  ADD COLUMN IF NOT EXISTS avaliacao_nota_motoboy        INTEGER CHECK (avaliacao_nota_motoboy BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS avaliacao_comentario_motoboy  TEXT,
  ADD COLUMN IF NOT EXISTS avaliacao_nota_cliente        INTEGER CHECK (avaliacao_nota_cliente BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS avaliacao_comentario_cliente  TEXT;

-- ── Novos campos em pedidos ───────────────────────────────────────────────────
ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS forma_pagamento TEXT DEFAULT 'DINHEIRO';

-- ── RLS completo — Corridas ───────────────────────────────────────────────────
-- Remove políticas amplas existentes e substitui por regras granulares

DO $$ BEGIN
  DROP POLICY IF EXISTS "autenticados podem ler corridas"     ON public.corridas;
  DROP POLICY IF EXISTS "autenticados podem inserir corridas" ON public.corridas;
  DROP POLICY IF EXISTS "autenticados podem atualizar corridas" ON public.corridas;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

-- SELECT: solicitante vê suas corridas; motoboy vê as suas + as pendentes
CREATE POLICY "corridas_select"
  ON public.corridas FOR SELECT
  USING (
    auth.uid() = id_solicitante
    OR auth.uid() = id_motoboy
    OR status = 'PENDENTE'
  );

-- INSERT: qualquer autenticado pode criar
CREATE POLICY "corridas_insert"
  ON public.corridas FOR INSERT
  WITH CHECK (auth.uid() = id_solicitante);

-- UPDATE: solicitante atualiza a própria (cancelar); motoboy atualiza as suas
CREATE POLICY "corridas_update"
  ON public.corridas FOR UPDATE
  USING (
    auth.uid() = id_solicitante
    OR auth.uid() = id_motoboy
    OR (id_motoboy IS NULL AND status = 'PENDENTE')  -- aceite atômico
  );

-- ── RLS completo — Pedidos ────────────────────────────────────────────────────
DO $$ BEGIN
  DROP POLICY IF EXISTS "autenticados podem ler pedidos"      ON public.pedidos;
  DROP POLICY IF EXISTS "autenticados podem atualizar pedidos" ON public.pedidos;
  DROP POLICY IF EXISTS "comercio pode cancelar pedido pendente" ON public.pedidos;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

-- SELECT: comerciante vê os seus pedidos; motoboy vê pendentes/aceitos pelos dele
CREATE POLICY "pedidos_select"
  ON public.pedidos FOR SELECT
  USING (
    auth.uid() = comercio_id
    OR auth.uid() = motoboy_id
    OR status IN ('PENDENTE')
  );

-- UPDATE: comerciante atualiza os seus; motoboy atualiza o que aceitou
CREATE POLICY "pedidos_update"
  ON public.pedidos FOR UPDATE
  USING (
    auth.uid() = comercio_id
    OR auth.uid() = motoboy_id
    OR (motoboy_id IS NULL AND status = 'PENDENTE')
  );

-- DELETE: apenas o comerciante dono pode excluir
CREATE POLICY "pedidos_delete"
  ON public.pedidos FOR DELETE
  USING (auth.uid() = comercio_id);

-- ── RLS — Usuarios ────────────────────────────────────────────────────────────
-- Mantém SELECT aberto (necessário para ver perfil do motoboy, etc.)
-- Restringe UPDATE ao próprio usuário (já existe, mas garante)
DO $$ BEGIN
  DROP POLICY IF EXISTS "usuario gerencia proprio perfil update" ON public.usuarios;
EXCEPTION WHEN undefined_object THEN NULL;
END $$;

CREATE POLICY "usuarios_update"
  ON public.usuarios FOR UPDATE
  USING (auth.uid() = id);

-- ── Índices de performance ────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_corridas_status          ON public.corridas (status);
CREATE INDEX IF NOT EXISTS idx_corridas_id_motoboy      ON public.corridas (id_motoboy);
CREATE INDEX IF NOT EXISTS idx_corridas_id_solicitante  ON public.corridas (id_solicitante);
CREATE INDEX IF NOT EXISTS idx_pedidos_comercio_id      ON public.pedidos (comercio_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_status           ON public.pedidos (status);
CREATE INDEX IF NOT EXISTS idx_usuarios_tipo            ON public.usuarios (tipo);
