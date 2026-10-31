<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'
import type { Usuario } from '~/components/FormUsuario.vue'

/*
  Mantenimiento de usuarios (§6.1): GET /usuarios, alta y edición con roles.
  No se borra: un usuario se desactiva con el estado INACTIVO, y la API no deja desactivar el propio.
*/
definePageMeta({ titulo: 'Usuarios', permiso: 'USUARIO_GESTIONAR' })

const api = useApi()
const usuarios = ref<Usuario[]>([])
const cargando = ref(true)
const fallo = ref(false)
const texto = ref('')
const modal = ref(false)
const editando = ref<Usuario | null>(null)

async function cargar() {
  cargando.value = true
  fallo.value = false
  try {
    usuarios.value = await api<Usuario[]>('/usuarios')
  } catch {
    usuarios.value = []
    fallo.value = true
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)

const visibles = computed(() => {
  const t = texto.value.trim().toLowerCase()
  if (!t) return usuarios.value
  return usuarios.value.filter((u) => [u.username, u.nombreCompleto, u.email, ...u.roles.map((r) => r.nombre)].some((v) => v?.toLowerCase().includes(t)))
})

function nuevo() { editando.value = null; modal.value = true }
function editar(u: Usuario) { editando.value = u; modal.value = true }

const columnas: TableColumn<Usuario>[] = [
  { accessorKey: 'username', header: 'Usuario' },
  { id: 'roles', header: 'Roles' },
  { id: 'contacto', header: 'Contacto' },
  { accessorKey: 'estado', header: 'Estado' },
  { id: 'acciones', header: '', meta: { class: { th: 'text-right', td: 'text-right' } } },
]
</script>

<template>
  <div class="mx-auto max-w-6xl space-y-5">
    <div class="flex flex-wrap items-end justify-between gap-3">
      <UFormField label="Buscar" class="w-full sm:w-80">
        <UInput v-model="texto" icon="i-lucide-search" placeholder="Usuario, nombre o rol" class="w-full" />
      </UFormField>
      <UButton color="secondary" icon="i-lucide-plus" @click="nuevo">Nuevo usuario</UButton>
    </div>

    <div class="overflow-hidden rounded-lg border border-bruma-200 bg-white">
      <UTable
        :data="visibles" :columns="columnas" :loading="cargando" sticky class="max-h-[70dvh]"
        :empty="fallo ? 'No se pudo cargar la lista de usuarios. Intenta de nuevo.' : 'No hay usuarios con esa búsqueda.'"
      >
        <template #username-cell="{ row }">
          <span class="block font-medium text-highlighted">{{ row.original.username }}</span>
          <span class="block text-xs text-bruma-500">{{ row.original.nombreCompleto }}</span>
        </template>
        <template #roles-cell="{ row }">
          <div class="flex flex-wrap gap-1">
            <UBadge v-for="r in row.original.roles" :key="r.idRol" color="neutral" variant="subtle">{{ r.nombre }}</UBadge>
          </div>
        </template>
        <template #contacto-cell="{ row }">
          <span class="block">{{ row.original.telefono ?? '—' }}</span>
          <span class="block text-xs text-bruma-500">{{ row.original.email ?? '' }}</span>
        </template>
        <template #estado-cell="{ row }">
          <UBadge :color="row.original.estado === 'ACTIVO' ? 'success' : 'neutral'" variant="subtle">{{ row.original.estado === 'ACTIVO' ? 'Activo' : 'Inactivo' }}</UBadge>
        </template>
        <template #acciones-cell="{ row }">
          <UButton size="xs" color="neutral" variant="ghost" icon="i-lucide-pencil" aria-label="Editar usuario" @click="editar(row.original)" />
        </template>
      </UTable>
    </div>
    <div v-if="fallo && !cargando" class="flex justify-center">
      <UButton color="neutral" variant="outline" icon="i-lucide-refresh-cw" @click="cargar">Reintentar</UButton>
    </div>

    <FormUsuario v-model:open="modal" :usuario="editando" @guardado="cargar" />
  </div>
</template>
