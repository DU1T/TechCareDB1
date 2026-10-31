<script setup lang="ts">
/*
  Registrar un pago sobre una factura (POST /facturas/{id}/pagos -> sp_RegistrarPago).
  La pantalla solo evita errores evidentes (monto, referencia); la regla real (pago <= saldo, R12)
  la vuelve a validar el procedimiento, y si lo rechaza se muestra su mensaje.
*/
type FacturaPago = { idFactura: number; numeroFactura: string; cliente: string; saldo: number }
type Metodo = { idMetodoPago: number; nombre: string; requiereReferencia: boolean }

const props = defineProps<{ factura: FacturaPago | null }>()
const abierto = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ pagado: [saldoRestante: number] }>()

const api = useApi()
const toast = useToast()

const metodos = ref<Metodo[]>([])
const form = reactive({ idMetodoPago: undefined as number | undefined, monto: '' as string, referencia: '' })
const guardando = ref(false)
const intento = ref(false)

const metodo = computed(() => metodos.value.find((m) => m.idMetodoPago === form.idMetodoPago))
const montoNum = computed(() => Number(form.monto))
const errores = computed(() => {
  const e: Record<string, string> = {}
  if (!form.idMetodoPago) e.metodo = 'Elige el método de pago.'
  if (!form.monto || !(montoNum.value > 0)) e.monto = 'Escribe un monto mayor que cero.'
  else if (!dosDecimales(montoNum.value)) e.monto = MENSAJE.decimales
  else if (props.factura && aCentavos(montoNum.value) > aCentavos(props.factura.saldo))
    e.monto = `No puede superar el saldo (${quetzales(props.factura.saldo)}).`
  if (metodo.value?.requiereReferencia && !form.referencia.trim()) e.referencia = 'Este método requiere número de referencia.'
  else if (!referenciaValida(form.referencia)) e.referencia = MENSAJE.referencia
  return e
})

onMounted(async () => {
  try {
    metodos.value = await api<Metodo[]>('/metodos-pago')
  } catch {
    metodos.value = []
  }
})

// Cada vez que se abre: formulario limpio y el saldo completo sugerido (lo habitual es pagar todo)
watch(abierto, (v) => {
  if (!v || !props.factura) return
  intento.value = false
  Object.assign(form, { idMetodoPago: undefined, monto: props.factura.saldo.toFixed(2), referencia: '' })
})

async function guardar() {
  intento.value = true
  if (Object.keys(errores.value).length || !props.factura) return
  guardando.value = true
  try {
    const r = await api<{ idPago: number; saldoRestante: number }>(`/facturas/${props.factura.idFactura}/pagos`, {
      method: 'POST',
      body: {
        idMetodoPago: form.idMetodoPago,
        monto: Math.round(montoNum.value * 100) / 100,
        referencia: form.referencia.trim() || undefined,
      },
    })
    toast.add({
      title: 'Pago registrado',
      description: r.saldoRestante > 0
        ? `${props.factura.numeroFactura}: queda un saldo de ${quetzales(r.saldoRestante)}.`
        : `${props.factura.numeroFactura} quedó pagada por completo.`,
      color: 'success',
    })
    abierto.value = false
    emit('pagado', r.saldoRestante)
  } catch {
    /* useApi mostró el mensaje del procedimiento (por ejemplo, si otro cajero ya pagó) */
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <UModal v-model:open="abierto" title="Registrar pago">
    <template #body>
      <form v-if="factura" class="space-y-4" novalidate @submit.prevent="guardar">
        <p class="text-sm text-bruma-600">
          <strong class="text-highlighted">{{ factura.numeroFactura }}</strong> · {{ factura.cliente }}<br />
          Saldo pendiente: <strong class="text-highlighted">{{ quetzales(factura.saldo) }}</strong>
        </p>

        <UFormField label="Método de pago" required :error="intento ? errores.metodo : undefined">
          <USelect
            v-model="form.idMetodoPago"
            :items="metodos.map((m) => ({ label: m.nombre, value: m.idMetodoPago }))"
            placeholder="Selecciona"
            class="w-full"
          />
        </UFormField>

        <UFormField label="Monto (Q)" required :error="mostrar(intento, errores.monto, form.monto, /\.\d{3,}/)">
          <UInput v-model="form.monto" type="number" inputmode="decimal" step="0.01" min="0" class="w-full" />
        </UFormField>

        <UFormField
          v-if="metodo?.requiereReferencia"
          label="Número de referencia"
          required
          hint="Boleta, autorización o número de cheque"
          :error="mostrar(intento, errores.referencia, form.referencia, INVALIDO.referencia)"
        >
          <UInput v-model="form.referencia" maxlength="60" class="w-full" />
        </UFormField>

        <button type="submit" class="hidden" tabindex="-1" aria-hidden="true" />
      </form>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="secondary" icon="i-lucide-banknote" :loading="guardando" @click="guardar">Registrar pago</UButton>
      </div>
    </template>
  </UModal>
</template>
