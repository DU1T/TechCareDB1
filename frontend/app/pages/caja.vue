<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'

/*
  Caja: facturas EMITIDAS con saldo (GET /facturas?conSaldo=true, que sale de vw_FacturasSaldo).
  El saldo no se guarda en ninguna tabla: la vista lo calcula con fn_SaldoFactura (R13).
  Al pagar se vuelve a pedir la lista, así el saldo mostrado siempre es el de la base.
*/
definePageMeta({ titulo: 'Caja', permiso: 'PAGO_REGISTRAR' })

type FacturaSaldo = {
  idFactura: number
  numeroFactura: string
  fechaEmision: string
  numeroOrden: string
  cliente: string
  nitFacturacion: string
  total: number
  totalPagado: number
  saldo: number
  estadoPago: string
}

const api = useApi()

const texto = ref('')
const facturas = ref<FacturaSaldo[]>([])
const cargando = ref(true)

async function cargar() {
  cargando.value = true
  try {
    facturas.value = await api<FacturaSaldo[]>('/facturas', { query: { conSaldo: true } })
  } catch {
    facturas.value = []
  } finally {
    cargando.value = false
  }
}
onMounted(cargar)

const visibles = computed(() => {
  const t = texto.value.trim().toLowerCase()
  if (!t) return facturas.value
  return facturas.value.filter((f) =>
    [f.numeroFactura, f.numeroOrden, f.cliente, f.nitFacturacion].some((v) => v?.toLowerCase().includes(t)),
  )
})
const porCobrar = computed(() => visibles.value.reduce((s, f) => s + aCentavos(f.saldo), 0) / 100)

const derecha = { class: { th: 'text-right', td: 'text-right' } }
const columnas: TableColumn<FacturaSaldo>[] = [
  { accessorKey: 'numeroFactura', header: 'Factura' },
  { accessorKey: 'cliente', header: 'Cliente' },
  { accessorKey: 'total', header: 'Total', meta: derecha },
  { accessorKey: 'totalPagado', header: 'Pagado', meta: derecha },
  { accessorKey: 'saldo', header: 'Saldo', meta: derecha },
  { accessorKey: 'estadoPago', header: 'Estado' },
  { id: 'acciones', header: '', meta: derecha },
]

const pago = reactive({ abierto: false, factura: null as FacturaSaldo | null })
function pedirPago(f: FacturaSaldo) {
  Object.assign(pago, { abierto: true, factura: f })
}
</script>

<template>
  <div class="mx-auto max-w-7xl space-y-5">
    <div class="flex flex-wrap items-end gap-3">
      <UFormField label="Buscar" class="w-full sm:w-72">
        <UInput v-model="texto" icon="i-lucide-search" placeholder="Factura, orden, cliente o NIT" class="w-full" />
      </UFormField>
      <p v-if="!cargando" class="text-sm text-bruma-600 sm:ml-auto">
        {{ visibles.length }} {{ visibles.length === 1 ? 'factura' : 'facturas' }} con saldo ·
        por cobrar <strong class="text-highlighted">{{ quetzales(porCobrar) }}</strong>
      </p>
    </div>

    <div class="overflow-hidden rounded-lg border border-bruma-200 bg-white">
      <UTable :data="visibles" :columns="columnas" :loading="cargando" empty="No hay facturas con saldo pendiente." sticky class="max-h-[70dvh]">
        <template #numeroFactura-cell="{ row }">
          <span class="block font-medium text-highlighted">{{ row.original.numeroFactura }}</span>
          <span class="block text-xs text-bruma-500">{{ row.original.numeroOrden }} · {{ fecha(row.original.fechaEmision) }}</span>
        </template>
        <template #cliente-cell="{ row }">
          <span class="block">{{ row.original.cliente }}</span>
          <span class="block text-xs text-bruma-500">NIT {{ row.original.nitFacturacion }}</span>
        </template>
        <template #total-cell="{ row }">{{ quetzales(row.original.total) }}</template>
        <template #totalPagado-cell="{ row }">{{ quetzales(row.original.totalPagado) }}</template>
        <template #saldo-cell="{ row }"><strong>{{ quetzales(row.original.saldo) }}</strong></template>
        <template #estadoPago-cell="{ row }">
          <UBadge :color="ESTADO_PAGO[row.original.estadoPago]?.color ?? 'neutral'" variant="subtle">
            {{ ESTADO_PAGO[row.original.estadoPago]?.texto ?? row.original.estadoPago }}
          </UBadge>
        </template>
        <template #acciones-cell="{ row }">
          <UButton size="xs" color="secondary" icon="i-lucide-banknote" @click="pedirPago(row.original)">Cobrar</UButton>
        </template>
      </UTable>
    </div>

    <FormPago v-model:open="pago.abierto" :factura="pago.factura" @pagado="cargar" />
  </div>
</template>
