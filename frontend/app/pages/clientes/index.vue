<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'
import type { Cliente } from '~/components/FormCliente.vue'

/* Clientes: búsqueda por nombre o NIT (GET /clientes?buscar=) y alta/edición en un modal. */
definePageMeta({ titulo: 'Clientes', permiso: 'CLIENTE_GESTIONAR' })

const api = useApi()
const buscar = ref('')
const clientes = ref<Cliente[]>([])
const cargando = ref(true)
const esqueleto = useEsqueleto(cargando)
const fallo = ref(false)
const modal = ref(false)
const editando = ref<Cliente | null>(null)

// Al buscar, las filas se deslizan a su lugar y las que entran aparecen (composables/useReacomodo.ts)
const tabla = ref<HTMLElement | null>(null)
useReacomodo(tabla, () => clientes.value)

// Si dos búsquedas se cruzan (escribes "a" y luego "ab"), solo vale la última que se pidió
let pedido = 0
async function cargar() {
  const mio = ++pedido
  cargando.value = true
  fallo.value = false
  try {
    const r = await api<Cliente[]>('/clientes', { query: { buscar: buscar.value.trim() || undefined } })
    if (mio === pedido) clientes.value = r
  } catch {
    if (mio !== pedido) return
    clientes.value = []
    fallo.value = true
  } finally {
    if (mio === pedido) cargando.value = false
  }
}
onMounted(cargar)
let espera: ReturnType<typeof setTimeout> | undefined
watch(buscar, () => {
  clearTimeout(espera)
  espera = setTimeout(cargar, 300)
})
onBeforeUnmount(() => clearTimeout(espera))

function nuevo() { editando.value = null; modal.value = true }
function editar(c: Cliente) { editando.value = c; modal.value = true }

const columnas: TableColumn<Cliente>[] = [
  { accessorKey: 'nombre', header: 'Cliente' },
  { accessorKey: 'nit', header: 'NIT' },
  { id: 'contacto', header: 'Contacto' },
  { accessorKey: 'estado', header: 'Estado' },
  { id: 'acciones', header: '', meta: { class: { th: 'text-right', td: 'text-right' } } },
]
</script>

<template>
  <div class="mx-auto max-w-6xl space-y-5">
    <div class="entra flex flex-wrap items-end justify-between gap-3" style="--i: 0">
      <UFormField label="Buscar" class="w-full sm:w-80">
        <UInput v-model="buscar" icon="i-lucide-search" placeholder="Nombre o NIT" :maxlength="LIMITE.busqueda" class="w-full" />
      </UFormField>
      <UButton color="secondary" icon="i-lucide-plus" @click="nuevo">Nuevo cliente</UButton>
    </div>

    <div ref="tabla" class="entra overflow-hidden rounded-lg border border-bruma-200 bg-white" style="--i: 1">
      <UTable
        :data="clientes"
        :columns="columnas"
        :loading="cargando"
        :empty="fallo ? 'No se pudo cargar la lista de clientes. Intenta de nuevo.' : 'No hay clientes con esa búsqueda.'"
        sticky
        class="max-h-[70dvh]"
      >
        <template #loading><TablaEsqueleto :visible="esqueleto" :columnas="4" /></template>
        <template #nombre-cell="{ row }">
          <NuxtLink :to="`/clientes/${row.original.idCliente}`" class="block font-medium text-highlighted hover:underline">{{ row.original.nombre }}</NuxtLink>
          <span class="block text-xs text-bruma-500">{{ row.original.tipoCliente === 'EMPRESA' ? 'Empresa' : 'Individual' }}</span>
        </template>
        <template #contacto-cell="{ row }">
          <span class="block">{{ row.original.telefono ?? '—' }}</span>
          <span class="block text-xs text-bruma-500">{{ row.original.email ?? '' }}</span>
        </template>
        <template #estado-cell="{ row }">
          <UBadge :color="row.original.estado === 'ACTIVO' ? 'success' : 'neutral'" variant="subtle">{{ row.original.estado === 'ACTIVO' ? 'Activo' : 'Inactivo' }}</UBadge>
        </template>
        <template #acciones-cell="{ row }">
          <div class="flex justify-end gap-2">
            <UButton size="xs" color="neutral" variant="outline" icon="i-lucide-laptop" :to="`/clientes/${row.original.idCliente}`">Equipos</UButton>
            <UButton size="xs" color="neutral" variant="ghost" icon="i-lucide-pencil" aria-label="Editar cliente" @click="editar(row.original)" />
          </div>
        </template>
      </UTable>
    </div>
    <div v-if="fallo && !cargando" class="flex justify-center">
      <UButton color="neutral" variant="outline" icon="i-lucide-refresh-cw" @click="cargar">Reintentar</UButton>
    </div>

    <FormCliente v-model:open="modal" :cliente="editando" @guardado="cargar" />
  </div>
</template>
