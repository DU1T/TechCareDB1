// Textos y colores de los estados de una orden (OrdenServicio.estado)
export const ESTADO_ORDEN: Record<string, { texto: string; color: 'neutral' | 'info' | 'warning' | 'success' | 'error' }> = {
  RECIBIDO: { texto: 'Recibido', color: 'neutral' },
  DIAGNOSTICO: { texto: 'En diagnóstico', color: 'info' },
  ESPERANDO_AUTORIZACION: { texto: 'Esperando autorización', color: 'warning' },
  REPARACION: { texto: 'En reparación', color: 'info' },
  LISTO: { texto: 'Listo para entregar', color: 'success' },
  ENTREGADO: { texto: 'Entregado', color: 'success' },
  CANCELADO: { texto: 'Cancelado', color: 'neutral' },
}

// El número de orden es 'OS-' + el id con 6 dígitos: "OS-000012", "os-12" o "12" son la orden 12.
export function idDeOrden(texto: string): number {
  const digitos = texto.match(/\d+/)?.[0]
  const n = digitos ? Number(digitos) : 0
  return Number.isSafeInteger(n) && n > 0 ? n : 0
}
