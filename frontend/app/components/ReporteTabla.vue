<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'
import type { ColumnaReporte, Formato } from '~/utils/reportes'

/*
  Tabla genérica de un resultado de reporte. Recibe las columnas de app/utils/reportes.ts
  y las filas tal como llegan de la API; aquí solo se da formato (no se calcula nada).
*/
const props = defineProps<{
  titulo?: string
  columnas: ColumnaReporte[]
  filas: Record<string, any>[]
  cargando?: boolean
}>()

const UBadge = resolveComponent('UBadge')

// Colores de los estados que aparecen en los reportes; lo que no esté aquí sale en gris
const COLOR_ESTADO: Record<string, 'success' | 'warning' | 'error' | 'info' | 'neutral'> = {
  ...Object.fromEntries(Object.entries(ESTADO_STOCK).map(([k, v]) => [k, v.color])),
  ...Object.fromEntries(Object.entries(ESTADO_COMPRA).map(([k, v]) => [k, v.color])),
  ENTREGADO: 'success', LISTO: 'success', FINALIZADA: 'success', ENTRADA: 'success',
  REPARACION: 'info', EN_PROCESO: 'info', DIAGNOSTICO: 'info',
  ESPERANDO_AUTORIZACION: 'warning', ALTA: 'warning',
  URGENTE: 'error', SALIDA: 'error',
}
const TEXTO_ESTADO: Record<string, string> = {
  ...Object.fromEntries(Object.entries(ESTADO_STOCK).map(([k, v]) => [k, v.texto])),
  ...Object.fromEntries(Object.entries(ESTADO_COMPRA).map(([k, v]) => [k, v.texto])),
}
// 'ESPERANDO_AUTORIZACION' -> 'Esperando autorizacion'
const legible = (codigo: string) => TEXTO_ESTADO[codigo] ?? (codigo[0] + codigo.slice(1).toLowerCase()).replaceAll('_', ' ')

const decimal = new Intl.NumberFormat('es-GT', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const NUMERICOS: Formato[] = ['numero', 'decimal', 'moneda']

function texto(valor: unknown, formato: Formato = 'texto'): string {
  if (valor == null || valor === '') return '—'
  switch (formato) {
    case 'numero': return numero(Number(valor))
    case 'decimal': return decimal.format(Number(valor))
    case 'moneda': return quetzales(Number(valor))
    case 'fecha': return fecha(String(valor))
    case 'fechaHora': return fechaYHora(String(valor))
    default: return String(valor)
  }
}

const columnasTabla = computed<TableColumn<Record<string, any>>[]>(() =>
  props.columnas.map((c) => ({
    id: c.clave,
    header: c.etiqueta,
    accessorFn: (fila) => (c.valor ? c.valor(fila) : fila[c.clave]),
    meta: NUMERICOS.includes(c.formato ?? 'texto') ? { class: { th: 'text-right', td: 'text-right cifras' } } : undefined,
    cell: ({ getValue }) => {
      const v = getValue()
      if (c.formato === 'estado' && v) {
        const codigo = String(v)
        return h(UBadge, { color: COLOR_ESTADO[codigo] ?? 'neutral', variant: 'subtle' }, () => legible(codigo))
      }
      return texto(v, c.formato)
    },
  })),
)
</script>

<template>
  <section class="space-y-2">
    <div v-if="titulo" class="flex items-baseline justify-between gap-3">
      <h3 class="font-semibold">{{ titulo }}</h3>
    </div>
    <div class="overflow-hidden rounded-lg border border-bruma-200 bg-white">
      <UTable
        :data="filas"
        :columns="columnasTabla"
        :loading="cargando"
        empty="El reporte no trae filas con esos filtros."
        sticky
        class="max-h-[65dvh]"
      />
    </div>
    <p v-if="!cargando" class="text-sm text-bruma-600" aria-live="polite">
      {{ numero(filas.length) }} {{ filas.length === 1 ? 'fila' : 'filas' }}
    </p>
  </section>
</template>
