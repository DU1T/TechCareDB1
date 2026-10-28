<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'

/*
  Kárdex: cada entrada y salida de un repuesto con la existencia antes y después
  (reporte 9, GET /inventario/kardex). Desde /inventario se llega ya filtrado por bodega y repuesto.
*/
definePageMeta({ titulo: 'Kárdex', permiso: 'REPORTE_VER' })

type Movimiento = {
  fechaMovimiento: string
  bodega: string
  codigo: string
  repuesto: string
  tipo: 'ENTRADA' | 'SALIDA'
  origen: string
  documentoOrigen: string
  cantidad: number
  existenciaAnterior: number
  existenciaResultante: number
  usuario: string
}
type Opcion = { label: string; value: number }

const api = useApi()
const route = useRoute()

const aNumero = (v: unknown) => (Number.isInteger(Number(v)) && Number(v) > 0 ? Number(v) : 0)
const filtro = reactive({
  idBodega: aNumero(route.query.idBodega),
  idRepuesto: aNumero(route.query.idRepuesto),
  fechaInicio: '',
  fechaFin: '',
})
const bodegas = ref<Opcion[]>([{ label: 'Todas las bodegas', value: 0 }])
const repuestos = ref<Opcion[]>([{ label: 'Todos los repuestos', value: 0 }])

const movimientos = ref<Movimiento[]>([])
const cargando = ref(true)
const fechasInvertidas = computed(() => !!filtro.fechaInicio && !!filtro.fechaFin && filtro.fechaInicio > filtro.fechaFin)

async function cargar() {
  if (fechasInvertidas.value) return
  cargando.value = true
  try {
    movimientos.value = await api<Movimiento[]>('/inventario/kardex', {
      query: {
        idBodega: filtro.idBodega || undefined,
        idRepuesto: filtro.idRepuesto || undefined,
        fechaInicio: filtro.fechaInicio || undefined,
        fechaFin: filtro.fechaFin || undefined,
      },
    })
  } catch {
    movimientos.value = []
  } finally {
    cargando.value = false
  }
}

onMounted(async () => {
  try {
    const [b, r] = await Promise.all([
      api<{ idBodega: number; nombre: string }[]>('/bodegas'),
      api<{ idRepuesto: number; codigo: string; nombre: string }[]>('/repuestos'),
    ])
    bodegas.value.push(...b.map((x) => ({ label: x.nombre, value: x.idBodega })))
    repuestos.value.push(...r.map((x) => ({ label: `${x.codigo} · ${x.nombre}`, value: x.idRepuesto })))
  } catch {
    /* sin catálogos los filtros quedan en "Todos" */
  }
  await cargar()
})
watch(() => [filtro.idBodega, filtro.idRepuesto, filtro.fechaInicio, filtro.fechaFin], cargar)

function limpiar() {
  Object.assign(filtro, { idBodega: 0, idRepuesto: 0, fechaInicio: '', fechaFin: '' })
}

const totales = computed(() => ({
  entradas: movimientos.value.filter((m) => m.tipo === 'ENTRADA').reduce((s, m) => s + m.cantidad, 0),
  salidas: movimientos.value.filter((m) => m.tipo === 'SALIDA').reduce((s, m) => s + m.cantidad, 0),
}))

const ORIGEN: Record<string, string> = {
  COMPRA: 'Compra',
  REPARACION: 'Reparación',
  DEVOLUCION: 'Devolución',
  AJUSTE: 'Ajuste',
}

const derecha = { class: { th: 'text-right', td: 'text-right' } }
const columnas: TableColumn<Movimiento>[] = [
  { accessorKey: 'fechaMovimiento', header: 'Fecha' },
  { accessorKey: 'repuesto', header: 'Repuesto' },
  { accessorKey: 'bodega', header: 'Bodega' },
  { accessorKey: 'documentoOrigen', header: 'Origen' },
  { accessorKey: 'cantidad', header: 'Cantidad', meta: derecha },
  { accessorKey: 'existenciaAnterior', header: 'Antes', meta: derecha },
  { accessorKey: 'existenciaResultante', header: 'Después', meta: derecha },
  { accessorKey: 'usuario', header: 'Usuario' },
]
</script>

<template>
  <div class="mx-auto max-w-7xl space-y-5">
    <div class="flex flex-wrap items-end gap-3">
      <UFormField label="Bodega" class="w-full sm:w-52">
        <USelect v-model="filtro.idBodega" :items="bodegas" class="w-full" />
      </UFormField>
      <UFormField label="Repuesto" class="w-full sm:w-72">
        <USelectMenu
          v-model="filtro.idRepuesto"
          :items="repuestos"
          value-key="value"
          :search-input="{ placeholder: 'Buscar repuesto' }"
          class="w-full"
        />
      </UFormField>
      <UFormField label="Desde" class="w-full sm:w-40">
        <UInput v-model="filtro.fechaInicio" type="date" class="w-full" />
      </UFormField>
      <UFormField label="Hasta" class="w-full sm:w-40" :error="fechasInvertidas ? 'Es anterior a «Desde»' : undefined">
        <UInput v-model="filtro.fechaFin" type="date" class="w-full" />
      </UFormField>
      <UButton color="neutral" variant="ghost" @click="limpiar">Quitar filtros</UButton>
    </div>

    <p class="text-sm text-bruma-600" aria-live="polite">
      {{ numero(movimientos.length) }} movimientos ·
      <span class="text-green-700">+{{ numero(totales.entradas) }} entradas</span> ·
      <span class="text-red-700">−{{ numero(totales.salidas) }} salidas</span>
    </p>

    <div class="overflow-hidden rounded-lg border border-bruma-200 bg-white">
      <UTable :data="movimientos" :columns="columnas" :loading="cargando" empty="No hay movimientos con esos filtros." sticky class="max-h-[70dvh]">
        <template #fechaMovimiento-cell="{ row }">{{ fechaYHora(row.original.fechaMovimiento) }}</template>
        <template #repuesto-cell="{ row }">
          <span class="block font-medium text-highlighted">{{ row.original.repuesto }}</span>
          <span class="block text-xs text-bruma-500">{{ row.original.codigo }}</span>
        </template>
        <template #documentoOrigen-cell="{ row }">
          <span class="block">{{ row.original.documentoOrigen }}</span>
          <span class="block text-xs text-bruma-500">{{ ORIGEN[row.original.origen] ?? row.original.origen }}</span>
        </template>
        <template #cantidad-cell="{ row }">
          <span class="cifras font-medium" :class="row.original.tipo === 'ENTRADA' ? 'text-green-700' : 'text-red-700'">
            {{ row.original.tipo === 'ENTRADA' ? '+' : '−' }}{{ numero(row.original.cantidad) }}
          </span>
        </template>
      </UTable>
    </div>
  </div>
</template>
