<script setup lang="ts">
/*
  Registrar una compra (POST /compras → sp_RegistrarCompra). Encabezado y líneas viajan juntos
  y el SP los guarda en una sola transacción. La compra queda PENDIENTE: el stock sube al recibirla.
*/
definePageMeta({ titulo: 'Nueva compra', permiso: 'COMPRA_REGISTRAR' })

type Repuesto = { idRepuesto: number; codigo: string; nombre: string; precioCompraRef: number; estado: string }
type Linea = { clave: number; idRepuesto: number | undefined; cantidad: number; costoUnitario: number }
type Opcion = { label: string; value: number }

const api = useApi()
const toast = useToast()

const proveedores = ref<Opcion[]>([])
const bodegas = ref<Opcion[]>([])
const repuestos = ref<Repuesto[]>([])

onMounted(async () => {
  try {
    const [p, b, r] = await Promise.all([
      api<{ idProveedor: number; nombre: string; estado: string }[]>('/proveedores'),
      api<{ idBodega: number; nombre: string; estado: string }[]>('/bodegas'),
      api<Repuesto[]>('/repuestos'),
    ])
    // Solo lo activo: el SP rechaza proveedores o bodegas inactivos
    proveedores.value = p.filter((x) => x.estado === 'ACTIVO').map((x) => ({ label: x.nombre, value: x.idProveedor }))
    bodegas.value = b.filter((x) => x.estado === 'ACTIVA').map((x) => ({ label: x.nombre, value: x.idBodega }))
    repuestos.value = r.filter((x) => x.estado === 'ACTIVO')
  } catch {
    /* useApi mostró el aviso; el formulario queda sin opciones */
  }
})

const compra = reactive({
  idProveedor: undefined as number | undefined,
  idBodegaDestino: undefined as number | undefined,
  numeroDocumento: '',
  observaciones: '',
})

let siguienteClave = 1
const nuevaLinea = (): Linea => ({ clave: siguienteClave++, idRepuesto: undefined, cantidad: 1, costoUnitario: 0 })
const lineas = ref<Linea[]>([nuevaLinea()])

const agregarLinea = () => lineas.value.push(nuevaLinea())
const quitarLinea = (clave: number) => {
  lineas.value = lineas.value.filter((l) => l.clave !== clave)
}

// En cada línea solo se ofrecen los repuestos que no están en otra (la API rechaza repetidos)
function opcionesPara(l: Linea): Opcion[] {
  const usados = new Set(lineas.value.filter((x) => x.clave !== l.clave).map((x) => x.idRepuesto))
  return repuestos.value
    .filter((r) => !usados.has(r.idRepuesto))
    .map((r) => ({ label: `${r.codigo} · ${r.nombre}`, value: r.idRepuesto }))
}

// Al elegir el repuesto se propone su costo de referencia; el usuario puede cambiarlo
function elegirRepuesto(l: Linea, id: number | undefined) {
  l.idRepuesto = id
  const r = repuestos.value.find((x) => x.idRepuesto === id)
  if (r) l.costoUnitario = r.precioCompraRef
}

const subtotal = (l: Linea) => (l.cantidad || 0) * (l.costoUnitario || 0)
const total = computed(() => lineas.value.reduce((s, l) => s + subtotal(l), 0))

// Las mismas reglas que valida la API, para avisar antes de enviar
const problema = computed(() => {
  if (!compra.idProveedor) return 'Elige el proveedor.'
  if (!compra.idBodegaDestino) return 'Elige la bodega destino.'
  if (!compra.numeroDocumento.trim()) return 'Escribe el número de documento (factura del proveedor).'
  if (compra.numeroDocumento.trim().length > 30) return 'El número de documento admite 30 caracteres.'
  if (compra.observaciones.length > 300) return 'Las observaciones admiten 300 caracteres.'
  if (lineas.value.length === 0) return 'Agrega al menos una línea.'
  if (lineas.value.some((l) => !l.idRepuesto)) return 'Cada línea necesita un repuesto.'
  if (lineas.value.some((l) => !(l.cantidad > 0))) return 'Cada cantidad debe ser mayor que cero.'
  if (lineas.value.some((l) => l.costoUnitario == null || l.costoUnitario < 0)) return 'El costo no puede ser negativo.'
  return ''
})

const intentado = ref(false)
const guardando = ref(false)

async function guardar() {
  intentado.value = true
  if (problema.value) return
  guardando.value = true
  try {
    const r = await api<{ idCompra: number }>('/compras', {
      method: 'POST',
      body: {
        idProveedor: compra.idProveedor,
        idBodegaDestino: compra.idBodegaDestino,
        numeroDocumento: compra.numeroDocumento.trim(),
        observaciones: compra.observaciones.trim() || null,
        lineas: lineas.value.map((l) => ({
          idRepuesto: l.idRepuesto,
          cantidad: l.cantidad,
          costoUnitario: l.costoUnitario,
        })),
      },
    })
    toast.add({
      title: 'Compra registrada',
      description: `Compra #${r.idCompra} por ${quetzales(total.value)}. Queda pendiente hasta recibirla en bodega.`,
      color: 'success',
    })
    await navigateTo({ path: '/compras', query: { estado: 'PENDIENTE' } })
  } catch {
    /* lo escrito se conserva; useApi mostró el mensaje del SP */
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <form class="mx-auto max-w-5xl space-y-6" novalidate @submit.prevent="guardar">
    <UButton to="/compras" color="neutral" variant="link" icon="i-lucide-arrow-left" class="px-0">Volver a compras</UButton>

    <section class="rounded-lg border border-bruma-200 bg-white p-5">
      <h2 class="font-semibold">Datos de la compra</h2>
      <div class="mt-4 grid gap-4 sm:grid-cols-3">
        <UFormField label="Proveedor" required>
          <USelect v-model="compra.idProveedor" :items="proveedores" placeholder="Elige uno" class="w-full" />
        </UFormField>
        <UFormField label="Bodega destino" required>
          <USelect v-model="compra.idBodegaDestino" :items="bodegas" placeholder="Elige una" class="w-full" />
        </UFormField>
        <UFormField label="Número de documento" required hint="Factura del proveedor">
          <UInput v-model="compra.numeroDocumento" maxlength="30" class="w-full" />
        </UFormField>
        <UFormField label="Observaciones" class="sm:col-span-3">
          <UTextarea v-model="compra.observaciones" :rows="2" maxlength="300" class="w-full" />
        </UFormField>
      </div>
    </section>

    <section class="rounded-lg border border-bruma-200 bg-white p-5">
      <div class="flex items-center justify-between gap-3">
        <h2 class="font-semibold">Repuestos</h2>
        <UButton color="neutral" variant="outline" icon="i-lucide-plus" size="sm" @click="agregarLinea">Agregar línea</UButton>
      </div>

      <ul class="mt-4 space-y-3">
        <li
          v-for="(l, i) in lineas"
          :key="l.clave"
          class="grid gap-3 border-b border-bruma-100 pb-3 last:border-0 last:pb-0 sm:grid-cols-[minmax(0,1fr)_7rem_9rem_8rem_2.5rem] sm:items-end"
        >
          <UFormField :label="`Repuesto ${i + 1}`">
            <USelectMenu
              :model-value="l.idRepuesto"
              :items="opcionesPara(l)"
              value-key="value"
              placeholder="Buscar repuesto"
              :search-input="{ placeholder: 'Código o nombre' }"
              class="w-full"
              @update:model-value="(v: number | undefined) => elegirRepuesto(l, v)"
            />
          </UFormField>
          <UFormField label="Cantidad">
            <UInputNumber v-model="l.cantidad" :min="1" class="w-full" />
          </UFormField>
          <UFormField label="Costo unitario">
            <UInputNumber
              v-model="l.costoUnitario"
              :min="0"
              :step="0.01"
              :format-options="{ minimumFractionDigits: 2, maximumFractionDigits: 2 }"
              class="w-full"
            />
          </UFormField>
          <div class="sm:text-right">
            <p class="text-xs text-bruma-500 sm:hidden">Subtotal</p>
            <p class="cifras py-1.5 font-medium">{{ quetzales(subtotal(l)) }}</p>
          </div>
          <UButton
            color="neutral"
            variant="ghost"
            icon="i-lucide-trash-2"
            :disabled="lineas.length === 1"
            :aria-label="`Quitar línea ${i + 1}`"
            @click="quitarLinea(l.clave)"
          />
        </li>
      </ul>

      <div class="mt-4 flex items-baseline justify-end gap-3 border-t border-bruma-200 pt-4">
        <span class="text-bruma-600">Total</span>
        <span class="cifras text-2xl font-semibold">{{ quetzales(total) }}</span>
      </div>
    </section>

    <div class="flex flex-col items-end gap-3">
      <div aria-live="polite" class="w-full">
        <UAlert v-if="intentado && problema" color="error" variant="subtle" icon="i-lucide-circle-alert" :description="problema" />
      </div>
      <UButton type="submit" color="secondary" size="lg" :loading="guardando">Registrar compra</UButton>
    </div>
  </form>
</template>
