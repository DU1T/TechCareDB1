// Formatos de pantalla comunes. La API manda números y fechas ISO; aquí se vuelven texto legible.

const moneda = new Intl.NumberFormat('es-GT', { style: 'currency', currency: 'GTQ' })
const entero = new Intl.NumberFormat('es-GT')
const fechaCorta = new Intl.DateTimeFormat('es-GT', { dateStyle: 'medium' })
const fechaHora = new Intl.DateTimeFormat('es-GT', { dateStyle: 'medium', timeStyle: 'short' })

export const quetzales = (n: number | null | undefined) => (n == null ? '—' : moneda.format(n))
export const numero = (n: number | null | undefined) => (n == null ? '—' : entero.format(n))
export const fecha = (iso: string | null | undefined) => (iso ? fechaCorta.format(new Date(iso)) : '—')
export const fechaYHora = (iso: string | null | undefined) => (iso ? fechaHora.format(new Date(iso)) : '—')

// Estados de stock de vw_InventarioActual: texto y color del distintivo
export const ESTADO_STOCK: Record<string, { texto: string; color: 'success' | 'warning' | 'error' }> = {
  OK: { texto: 'Disponible', color: 'success' },
  BAJO_MINIMO: { texto: 'Bajo mínimo', color: 'warning' },
  SIN_STOCK: { texto: 'Sin stock', color: 'error' },
}

// Estados de una compra
export const ESTADO_COMPRA: Record<string, { texto: string; color: 'warning' | 'success' | 'neutral' }> = {
  PENDIENTE: { texto: 'Pendiente', color: 'warning' },
  RECIBIDA: { texto: 'Recibida', color: 'success' },
  ANULADA: { texto: 'Anulada', color: 'neutral' },
}
