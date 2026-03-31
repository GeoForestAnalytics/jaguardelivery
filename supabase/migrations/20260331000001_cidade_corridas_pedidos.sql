-- Adiciona cidade e estado nas tabelas corridas e pedidos
-- para permitir filtragem por região do motoboy

ALTER TABLE public.corridas
  ADD COLUMN IF NOT EXISTS cidade TEXT,
  ADD COLUMN IF NOT EXISTS estado TEXT;

ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS cidade TEXT,
  ADD COLUMN IF NOT EXISTS estado TEXT;
