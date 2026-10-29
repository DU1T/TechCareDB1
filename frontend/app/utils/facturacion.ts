// Textos y colores de facturación. Viven en su propio archivo (no en formato.ts) para no chocar con C.

// estadoPago de vw_FacturasSaldo
export const ESTADO_PAGO: Record<string, { texto: string; color: 'success' | 'warning' | 'error' | 'neutral' }> = {
  PAGADA: { texto: 'Pagada', color: 'success' },
  PARCIAL: { texto: 'Pago parcial', color: 'warning' },
  PENDIENTE: { texto: 'Sin pagos', color: 'error' },
  ANULADA: { texto: 'Anulada', color: 'neutral' },
}

// Estado de cada pago (Pago.estado)
export const ESTADO_REGISTRO_PAGO: Record<string, { texto: string; color: 'success' | 'neutral' }> = {
  APLICADO: { texto: 'Aplicado', color: 'success' },
  ANULADO: { texto: 'Anulado', color: 'neutral' },
}

// Cantidades de dinero: dos decimales exactos (evita 0.1 + 0.2). Se compara en centavos.
export const aCentavos = (n: number) => Math.round(n * 100)
