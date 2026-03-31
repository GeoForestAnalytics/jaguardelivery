-- Tracking do motoboy em pedidos comerciais + cálculo de frete
ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS lat_motoboy   DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS long_motoboy  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS valor_produto DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS valor_frete   DOUBLE PRECISION;

-- Cidade/estado para filtro regional
ALTER TABLE public.usuarios
  ADD COLUMN IF NOT EXISTS cidade TEXT,
  ADD COLUMN IF NOT EXISTS estado TEXT;
