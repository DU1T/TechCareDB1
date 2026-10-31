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

// Color de relleno de cada estado en gráficos (línea del taller, línea de tiempo): un solo verde que se
// oscurece mientras la orden avanza; amarillo en la única etapa que depende del cliente; gris si se canceló
export const COLOR_ESTADO_ORDEN: Record<string, string> = {
  RECIBIDO: 'bg-placa-200',
  DIAGNOSTICO: 'bg-placa-300',
  ESPERANDO_AUTORIZACION: 'bg-acento-400',
  REPARACION: 'bg-placa-500',
  LISTO: 'bg-placa-700',
  ENTREGADO: 'bg-placa-900',
  CANCELADO: 'bg-bruma-400',
}

// El número de orden es 'OS-' + el id con 6 dígitos: "OS-000012", "os-12" o "12" son la orden 12.
export function idDeOrden(texto: string): number {
  const digitos = texto.match(/\d+/)?.[0]
  const n = digitos ? Number(digitos) : 0
  return Number.isSafeInteger(n) && n > 0 ? n : 0
}
