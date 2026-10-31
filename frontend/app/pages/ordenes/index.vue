<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'

/*
  Órdenes activas (GET /ordenes, que sale de vw_OrdenesActivas: no incluye las ya entregadas o canceladas).
  Para ver la trazabilidad de CUALQUIER orden, también las entregadas, se escribe su número arriba.
*/
definePageMeta({ titulo: 'Órdenes', permiso: 'REPORTE_VER' })

type Orden = {
  idOrden: number
  numeroOrden: string
  fechaIngreso: string
  prioridad: string
  estado: string
  cliente: string
  tipoEquipo: string
  marca: string
  modelo: string
  tecnicoAsignado: string | null
  diasAbierta: number
}

const api = useApi()
const route = useRoute()
const estados = [
  { label: 'Todos los estados activos', value: 'TODOS' },
  ...Object.entries(ESTADO_ORDEN)
    .filter(([codigo]) => !['ENTREGADO', 'CANCELADO'].includes(codigo))
    .map(([value, e]) => ({ label: e.texto, value })),
]
// Desde el Inicio se llega con ?estado=LISTO (por ejemplo): solo vale si es un estado activo conocido
const estadoInicial = String(route.query.estado ?? '')
const filtro = reactive({
  estado: estados.some((e) => e.value === estadoInicial) ? estadoInicial : 'TODOS',
  texto: '',
})

const ordenes = ref<Orden[]>([])
const cargando = ref(true)
const fallo = ref(false)

async function cargar() {
  cargando.value = true
  fallo.value = false
  try {
    ordenes.value = await api<Orden[]>('/ordenes', { query: { estado: filtro.estado === 'TODOS' ? undefined : filtro.estado } })
  } catch {
    ordenes.value = []
    fallo.value = true
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)
watch(() => filtro.estado, cargar)

const visibles = computed(() => {
  const t = filtro.texto.trim().toLowerCase()
  if (!t) return ordenes.value
  return ordenes.value.filter((o) =>
    [o.numeroOrden, o.cliente, o.tipoEquipo, o.marca, o.modelo, o.tecnicoAsignado].some((v) => v?.toLowerCase().includes(t)),
  )
})

// Al filtrar o buscar, las filas se deslizan a su lugar nuevo y las que entran aparecen (composables/useReacomodo.ts)
const tabla = ref<HTMLElement | null>(null)
useReacomodo(tabla, () => visibles.value)

// ---- Ir a la trazabilidad de una orden por su número
const numeroBuscado = ref('')
const errorNumero = ref('')
function irATrazabilidad() {
  const id = idDeOrden(numeroBuscado.value)
  if (!id) {
    errorNumero.value = 'Escribe el número de la orden, por ejemplo OS-000012 o 12.'
    return
  }
  errorNumero.value = ''
  navigateTo(`/ordenes/${id}/trazabilidad`)
}

const derecha = { class: { th: 'text-right', td: 'text-right' } }
const columnas: TableColumn<Orden>[] = [
  { accessorKey: 'numeroOrden', header: 'Orden' },
  { accessorKey: 'cliente', header: 'Cliente' },
  { id: 'equipo', header: 'Equipo' },
  { accessorKey: 'estado', header: 'Estado' },
  { accessorKey: 'diasAbierta', header: 'Días', meta: derecha },
  { accessorKey: 'tecnicoAsignado', header: 'Técnico' },
  { id: 'acciones', header: '', meta: derecha },
]
</script>

<template>
  <div class="mx-auto max-w-7xl space-y-5">
    <form class="flex flex-wrap items-end gap-3 rounded-lg border border-bruma-200 bg-white p-4" novalidate @submit.prevent="irATrazabilidad">
      <UFormField label="Trazabilidad de una orden" :error="errorNumero || undefined" class="w-full sm:w-80" hint="También las ya entregadas">
        <UInput v-model="numeroBuscado" placeholder="OS-000012 o 12" maxlength="12" class="w-full" />
      </UFormField>
      <UButton type="submit" color="secondary" icon="i-lucide-route">Ver trazabilidad</UButton>
    </form>

    <div class="flex flex-wrap items-end gap-3">
      <UFormField label="Estado" class="w-full sm:w-60">
        <USelect v-model="filtro.estado" :items="estados" class="w-full" />
      </UFormField>
      <UFormField label="Buscar" class="w-full sm:w-72">
        <UInput v-model="filtro.texto" icon="i-lucide-search" placeholder="Orden, cliente, equipo o técnico" :maxlength="LIMITE.busqueda" class="w-full" />
      </UFormField>
    </div>

    <div ref="tabla" class="overflow-hidden rounded-lg border border-bruma-200 bg-white">
      <UTable
        :data="visibles"
        :columns="columnas"
        :loading="cargando"
        :empty="fallo ? 'No se pudo cargar la lista de órdenes. Intenta de nuevo.' : 'No hay órdenes activas con esos filtros.'"
        sticky
        class="max-h-[70dvh]"
      >
        <template #numeroOrden-cell="{ row }">
          <span class="block font-medium text-highlighted">{{ row.original.numeroOrden }}</span>
          <span class="block text-xs text-bruma-500">{{ fecha(row.original.fechaIngreso) }}</span>
        </template>
        <template #equipo-cell="{ row }">
          {{ [row.original.tipoEquipo, row.original.marca, row.original.modelo].filter(Boolean).join(' · ') }}
        </template>
        <template #estado-cell="{ row }">
          <UBadge :color="ESTADO_ORDEN[row.original.estado]?.color ?? 'neutral'" variant="subtle">
            {{ ESTADO_ORDEN[row.original.estado]?.texto ?? row.original.estado }}
          </UBadge>
        </template>
        <template #tecnicoAsignado-cell="{ row }">{{ row.original.tecnicoAsignado ?? 'Sin asignar' }}</template>
        <template #acciones-cell="{ row }">
          <UButton :to="`/ordenes/${row.original.idOrden}/trazabilidad`" size="xs" color="neutral" variant="outline" icon="i-lucide-route">
            Trazabilidad
          </UButton>
        </template>
      </UTable>
    </div>
    <div v-if="fallo && !cargando" class="flex justify-center">
      <UButton color="neutral" variant="outline" icon="i-lucide-refresh-cw" @click="cargar">Reintentar</UButton>
    </div>
  </div>
</template>
