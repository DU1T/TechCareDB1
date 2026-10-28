<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'

/*
  Compras a proveedores (GET /compras). Una compra nace PENDIENTE y no mueve stock;
  al recibirla, sp_RecibirCompra suma cada línea a la bodega destino y la deja en el kárdex.
*/
definePageMeta({ titulo: 'Compras', permiso: 'COMPRA_REGISTRAR' })

type Compra = {
  idCompra: number
  numeroDocumento: string
  fechaCompra: string
  estado: string
  proveedor: string
  bodegaDestino: string
  registradaPor: string
  fechaRecepcion: string | null
  recibidaPor: string | null
  lineas: number
  total: number
}
type Opcion<T> = { label: string; value: T }

const api = useApi()
const auth = useAuthStore()
const route = useRoute()
const toast = useToast()
const puedeRecibir = computed(() => auth.puede('COMPRA_RECIBIR'))

const estadoInicial = String(route.query.estado ?? '')
const filtro = reactive({
  estado: estadoInicial in ESTADO_COMPRA ? estadoInicial : 'TODOS',
  idProveedor: 0,
})
const estados: Opcion<string>[] = [
  { label: 'Todos los estados', value: 'TODOS' },
  ...Object.entries(ESTADO_COMPRA).map(([value, e]) => ({ label: e.texto, value })),
]
const proveedores = ref<Opcion<number>[]>([{ label: 'Todos los proveedores', value: 0 }])

const compras = ref<Compra[]>([])
const cargando = ref(true)

async function cargar() {
  cargando.value = true
  try {
    compras.value = await api<Compra[]>('/compras', {
      query: {
        estado: filtro.estado === 'TODOS' ? undefined : filtro.estado,
        idProveedor: filtro.idProveedor || undefined,
      },
    })
  } catch {
    compras.value = []
  } finally {
    cargando.value = false
  }
}

onMounted(async () => {
  try {
    const p = await api<{ idProveedor: number; nombre: string }[]>('/proveedores')
    proveedores.value.push(...p.map((x) => ({ label: x.nombre, value: x.idProveedor })))
  } catch {
    /* sin catálogo el filtro queda en "Todos" */
  }
  await cargar()
})
watch(() => [filtro.estado, filtro.idProveedor], cargar)

const pendientes = computed(() => compras.value.filter((c) => c.estado === 'PENDIENTE').length)

const derecha = { class: { th: 'text-right', td: 'text-right' } }
const columnas: TableColumn<Compra>[] = [
  { accessorKey: 'numeroDocumento', header: 'Documento' },
  { accessorKey: 'proveedor', header: 'Proveedor' },
  { accessorKey: 'bodegaDestino', header: 'Bodega destino' },
  { accessorKey: 'lineas', header: 'Líneas', meta: derecha },
  { accessorKey: 'total', header: 'Total', meta: derecha },
  { accessorKey: 'estado', header: 'Estado' },
  { id: 'acciones', header: '', meta: derecha },
]

// ---- Recepción: se confirma antes, porque mueve el inventario y no se deshace desde aquí
const recepcion = reactive({ abierto: false, compra: null as Compra | null, guardando: false })

function pedirRecepcion(c: Compra) {
  Object.assign(recepcion, { abierto: true, compra: c })
}

async function recibir() {
  if (!recepcion.compra) return
  recepcion.guardando = true
  try {
    await api(`/compras/${recepcion.compra.idCompra}/recepcion`, { method: 'POST' })
    toast.add({
      title: 'Compra recibida',
      description: `${recepcion.compra.numeroDocumento}: el stock de ${recepcion.compra.bodegaDestino} ya se actualizó.`,
      color: 'success',
    })
    recepcion.abierto = false
    await cargar()
  } catch {
    /* useApi mostró el mensaje (por ejemplo, si otra persona ya la recibió) */
  } finally {
    recepcion.guardando = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-7xl space-y-5">
    <div class="flex flex-wrap items-end gap-3">
      <UFormField label="Estado" class="w-full sm:w-44">
        <USelect v-model="filtro.estado" :items="estados" class="w-full" />
      </UFormField>
      <UFormField label="Proveedor" class="w-full sm:w-60">
        <USelect v-model="filtro.idProveedor" :items="proveedores" class="w-full" />
      </UFormField>
      <UButton to="/compras/nueva" color="secondary" icon="i-lucide-plus" class="sm:ml-auto">Nueva compra</UButton>
    </div>

    <p v-if="!cargando && pendientes > 0" class="text-sm text-bruma-600">
      {{ pendientes }} {{ pendientes === 1 ? 'compra pendiente' : 'compras pendientes' }} de recibir en bodega.
    </p>

    <div class="overflow-hidden rounded-lg border border-bruma-200 bg-white">
      <UTable :data="compras" :columns="columnas" :loading="cargando" empty="No hay compras con esos filtros." sticky class="max-h-[70dvh]">
        <template #numeroDocumento-cell="{ row }">
          <span class="block font-medium text-highlighted">{{ row.original.numeroDocumento }}</span>
          <span class="block text-xs text-bruma-500">{{ fecha(row.original.fechaCompra) }} · {{ row.original.registradaPor }}</span>
        </template>
        <template #total-cell="{ row }">{{ quetzales(row.original.total) }}</template>
        <template #estado-cell="{ row }">
          <UBadge :color="ESTADO_COMPRA[row.original.estado]?.color ?? 'neutral'" variant="subtle">
            {{ ESTADO_COMPRA[row.original.estado]?.texto ?? row.original.estado }}
          </UBadge>
          <span v-if="row.original.recibidaPor" class="mt-0.5 block text-xs text-bruma-500">
            {{ fecha(row.original.fechaRecepcion) }} · {{ row.original.recibidaPor }}
          </span>
        </template>
        <template #acciones-cell="{ row }">
          <UButton
            v-if="puedeRecibir && row.original.estado === 'PENDIENTE'"
            size="xs"
            color="neutral"
            variant="outline"
            icon="i-lucide-package-check"
            @click="pedirRecepcion(row.original)"
          >
            Recibir
          </UButton>
        </template>
      </UTable>
    </div>

    <UModal v-model:open="recepcion.abierto" title="Recibir compra">
      <template #body>
        <p v-if="recepcion.compra" class="text-sm">
          Se sumarán las <strong>{{ recepcion.compra.lineas }}</strong> líneas de
          <strong>{{ recepcion.compra.numeroDocumento }}</strong> ({{ recepcion.compra.proveedor }},
          {{ quetzales(recepcion.compra.total) }}) a <strong>{{ recepcion.compra.bodegaDestino }}</strong>.
          Revisa que la mercadería llegó completa antes de confirmar.
        </p>
      </template>
      <template #footer="{ close }">
        <div class="flex w-full justify-end gap-2">
          <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
          <UButton color="secondary" icon="i-lucide-package-check" :loading="recepcion.guardando" @click="recibir">
            Confirmar recepción
          </UButton>
        </div>
      </template>
    </UModal>
  </div>
</template>
