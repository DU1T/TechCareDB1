<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'
import type { Cliente } from '~/components/FormCliente.vue'
import type { Equipo } from '~/components/FormEquipo.vue'

/* Detalle de un cliente: sus datos, sus equipos y el acceso a abrir una orden con uno de ellos. */
definePageMeta({ titulo: 'Cliente', permiso: 'CLIENTE_GESTIONAR' })

const api = useApi()
const auth = useAuthStore()
const route = useRoute()
const id = Number(route.params.id)

const cliente = ref<Cliente | null>(null)
const equipos = ref<Equipo[]>([])
const cargando = ref(true)
const esqueleto = useEsqueleto(cargando)
const fallo = ref(false)
const tablaEquipos = ref<HTMLElement | null>(null)
useReacomodo(tablaEquipos, () => equipos.value) // al guardar un equipo, la tabla se acomoda en vez de saltar
const modalCliente = ref(false)
const modalEquipo = ref(false)
const equipoEditando = ref<Equipo | null>(null)

async function cargar() {
  cargando.value = true
  fallo.value = false
  try {
    const [c, e] = await Promise.all([api<Cliente>(`/clientes/${id}`), api<Equipo[]>(`/clientes/${id}/equipos`)])
    cliente.value = c
    equipos.value = e
  } catch {
    fallo.value = true
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)

function nuevoEquipo() { equipoEditando.value = null; modalEquipo.value = true }
function editarEquipo(e: Equipo) { equipoEditando.value = e; modalEquipo.value = true }

const ESTADO_EQUIPO: Record<string, { texto: string; color: 'success' | 'neutral' | 'error' }> = {
  ACTIVO: { texto: 'Activo', color: 'success' },
  INACTIVO: { texto: 'Inactivo', color: 'neutral' },
  BAJA: { texto: 'Baja', color: 'error' },
}
const columnas: TableColumn<Equipo>[] = [
  { id: 'equipo', header: 'Equipo' },
  { accessorKey: 'numeroSerie', header: 'Serie' },
  { accessorKey: 'estado', header: 'Estado' },
  { id: 'acciones', header: '', meta: { class: { th: 'text-right', td: 'text-right' } } },
]
</script>

<template>
  <div class="mx-auto max-w-5xl space-y-5">
    <UButton to="/clientes" color="neutral" variant="ghost" icon="i-lucide-arrow-left" size="sm">Clientes</UButton>

    <div v-if="fallo" class="rounded-lg border border-bruma-200 bg-white p-6 text-center text-bruma-600">
      No se pudo cargar el cliente.
      <UButton color="neutral" variant="outline" icon="i-lucide-refresh-cw" class="ml-2" @click="cargar">Reintentar</UButton>
    </div>

    <!-- Cargando: la misma forma de la ficha y de la tabla de equipos (solo si tarda más de un instante) -->
    <div v-else-if="!cliente" class="space-y-5 transition-opacity duration-300" :class="esqueleto ? 'opacity-100' : 'opacity-0'" aria-busy="true">
      <div class="rounded-lg border border-bruma-200 bg-white p-5">
        <USkeleton class="h-6 w-56" />
        <USkeleton class="mt-2 h-4 w-40" />
        <div class="mt-5 grid gap-3 sm:grid-cols-3">
          <USkeleton v-for="i in 3" :key="i" class="h-10" />
        </div>
      </div>
      <div class="overflow-hidden rounded-lg border border-bruma-200 bg-white"><TablaEsqueleto :visible="esqueleto" :filas="3" :columnas="3" /></div>
    </div>

    <template v-else-if="cliente">
      <section class="entra rounded-lg border border-bruma-200 bg-white p-5" style="--i: 0">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h2 class="text-lg font-semibold text-highlighted">{{ cliente.nombre }}</h2>
            <p class="text-sm text-bruma-500">{{ cliente.tipoCliente === 'EMPRESA' ? 'Empresa' : 'Individual' }} · NIT {{ cliente.nit }}</p>
          </div>
          <div class="flex items-center gap-2">
            <UBadge :color="cliente.estado === 'ACTIVO' ? 'success' : 'neutral'" variant="subtle">{{ cliente.estado === 'ACTIVO' ? 'Activo' : 'Inactivo' }}</UBadge>
            <UButton size="sm" color="neutral" variant="outline" icon="i-lucide-pencil" @click="modalCliente = true">Editar</UButton>
          </div>
        </div>
        <dl class="mt-4 grid gap-3 text-sm sm:grid-cols-3">
          <div><dt class="text-bruma-500">Teléfono</dt><dd>{{ cliente.telefono ?? '—' }}</dd></div>
          <div><dt class="text-bruma-500">Correo</dt><dd>{{ cliente.email ?? '—' }}</dd></div>
          <div><dt class="text-bruma-500">Dirección</dt><dd>{{ cliente.direccion ?? '—' }}</dd></div>
        </dl>
      </section>

      <section class="entra space-y-3" style="--i: 1">
        <div class="flex items-center justify-between">
          <h3 class="font-semibold text-highlighted">Equipos</h3>
          <UButton color="secondary" icon="i-lucide-plus" @click="nuevoEquipo">Nuevo equipo</UButton>
        </div>
        <div ref="tablaEquipos" class="overflow-hidden rounded-lg border border-bruma-200 bg-white">
          <UTable :data="equipos" :columns="columnas" :loading="cargando" empty="Este cliente aún no tiene equipos registrados.">
            <template #equipo-cell="{ row }">
              <span class="block font-medium text-highlighted">{{ row.original.tipoEquipo }} · {{ row.original.marca }} {{ row.original.modelo }}</span>
              <span v-if="row.original.descripcion" class="block text-xs text-bruma-500">{{ row.original.descripcion }}</span>
            </template>
            <template #estado-cell="{ row }">
              <UBadge :color="ESTADO_EQUIPO[row.original.estado]?.color ?? 'neutral'" variant="subtle">{{ ESTADO_EQUIPO[row.original.estado]?.texto ?? row.original.estado }}</UBadge>
            </template>
            <template #acciones-cell="{ row }">
              <div class="flex justify-end gap-2">
                <UButton
                  v-if="auth.puede('ORDEN_CREAR') && row.original.estado === 'ACTIVO'"
                  size="xs" color="secondary" variant="outline" icon="i-lucide-clipboard-plus"
                  :to="`/ordenes/nueva?cliente=${id}&equipo=${row.original.idEquipo}`"
                >Abrir orden</UButton>
                <UButton size="xs" color="neutral" variant="ghost" icon="i-lucide-pencil" aria-label="Editar equipo" @click="editarEquipo(row.original)" />
              </div>
            </template>
          </UTable>
        </div>
      </section>

      <FormCliente v-model:open="modalCliente" :cliente="cliente" @guardado="cargar" />
      <FormEquipo v-model:open="modalEquipo" :id-cliente="id" :equipo="equipoEditando" @guardado="cargar" />
    </template>
  </div>
</template>
