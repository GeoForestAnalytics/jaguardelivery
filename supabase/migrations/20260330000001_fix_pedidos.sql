-- Fix: adiciona colunas faltantes na tabela pedidos

ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS data_finalizacao TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS lat_origem       DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS long_origem      DOUBLE PRECISION;
