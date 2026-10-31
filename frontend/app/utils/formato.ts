// Formatos de pantalla comunes. La API manda números y fechas ISO; aquí se vuelven texto legible.

const moneda = new Intl.NumberFormat('es-GT', { style: 'currency', currency: 'GTQ' })
const entero = new Intl.NumberFormat('es-GT')
const fechaCorta = new Intl.DateTimeFormat('es-GT', { dateStyle: 'medium' })
const fechaHora = new Intl.DateTimeFormat('es-GT', { dateStyle: 'medium', timeStyle: 'short' })

export const quetzales = (n: number | null | undefined) => (n == null ? '—' : moneda.format(n))
export const numero = (n: number | null | undefined) => (n == null ? '—' : entero.format(n))
export const fecha = (iso: string | null | undefined) => (iso ? fechaCorta.format(new Date(iso)) : '—')
export const fechaYHora = (iso: string | null | undefined) => (iso ? fechaHora.format(new Date(iso)) : '—')

// Tiempo entre dos momentos, en palabras cortas: "45 min", "2 h", "1 h 30 min", "3 días"
export function duracion(ms: number) {
  const min = Math.max(0, Math.round(ms / 60000))
  if (min < 60) return `${min} min`
  const h = Math.floor(min / 60)
  if (h < 48) return min % 60 ? `${h} h ${min % 60} min` : `${h} h`
  const d = Math.round(h / 24)
  return `${d} días`
}

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

// Día y hora cortos (sin año) para listas de actividad: "30 oct" y "2:00 p. m."
const fechaDia = new Intl.DateTimeFormat('es-GT', { day: 'numeric', month: 'short' })
const fechaHoraDelDia = new Intl.DateTimeFormat('es-GT', { hour: 'numeric', minute: '2-digit' })
export const diaCorto = (iso: string | null | undefined) => (iso ? fechaDia.format(new Date(iso)) : '—')
export const horaCorta = (iso: string | null | undefined) => (iso ? fechaHoraDelDia.format(new Date(iso)) : '')

// AAAA-MM-DD del día de hoy (hora local) desplazado n días, para los filtros de fecha de la API
export function diaISO(desplazamientoDias = 0) {
  const d = new Date()
  d.setDate(d.getDate() + desplazamientoDias)
  return d.toLocaleDateString('sv-SE')
}
