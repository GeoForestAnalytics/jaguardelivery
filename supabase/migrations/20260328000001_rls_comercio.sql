-- ============================================================
-- Fase 2 — Políticas RLS para o fluxo do Comércio
-- ============================================================

-- Permite que o comerciante autenticado crie seus próprios pedidos
CREATE POLICY "comercio pode inserir pedidos"
  ON public.pedidos FOR INSERT
  WITH CHECK (auth.uid() = comercio_id);

-- Permite cancelar pedido pendente que é seu
CREATE POLICY "comercio pode cancelar pedido pendente"
  ON public.pedidos FOR DELETE
  USING (auth.uid() = comercio_id AND status = 'PENDENTE');
