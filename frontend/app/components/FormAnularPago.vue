<script setup lang="ts">
/*
  Anular un pago (POST /pagos/{id}/anulacion -> sp_AnularPago). R14: el pago NO se borra; queda ANULADO
  con su motivo y el saldo de la factura vuelve a subir. El procedimiento rechaza anular si la orden ya se entregó.
*/
type PagoAnular = { idPago: number; monto: number; metodoPago: string }

const props = defineProps<{ pago: PagoAnular | null }>()
const abierto = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ hecho: [] }>()

const api = useApi()
const toast = useToast()
const motivo = ref('')
const guardando = ref(false)
const intento = ref(false)

watch(abierto, (v) => {
  if (!v) return
  motivo.value = ''
  intento.value = false
})

const error = computed(() => {
  const m = motivo.value.trim()
  if (m.length < 5) return 'Explica el motivo (al menos 5 caracteres).'
  if (m.length > 250) return 'Máximo 250 caracteres.'
  return ''
})

async function anular() {
  intento.value = true
  if (!props.pago || error.value) return
  guardando.value = true
  try {
    const r = await api<{ idPago: number; saldoActual: number }>(`/pagos/${props.pago.idPago}/anulacion`, {
      method: 'POST',
      body: { motivo: motivo.value.trim() },
    })
    toast.add({ title: 'Pago anulado', description: `El saldo de la factura ahora es ${quetzales(r.saldoActual)}.`, color: 'success' })
    abierto.value = false
    emit('hecho')
  } catch {
    /* useApi mostró el mensaje (por ejemplo, si la orden ya fue entregada) */
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <UModal v-model:open="abierto" title="Anular pago">
    <template #body>
      <form v-if="pago" class="space-y-4" novalidate @submit.prevent="anular">
        <p class="text-sm text-bruma-600">
          Pago de <strong class="text-highlighted">{{ quetzales(pago.monto) }}</strong> ({{ pago.metodoPago }}). No se borra:
          queda registrado como anulado y el saldo de la factura vuelve a subir.
        </p>
        <UFormField label="Motivo de la anulación" required :error="intento ? error : undefined">
          <UTextarea v-model="motivo" :rows="3" class="w-full" />
        </UFormField>
        <button type="submit" class="hidden" tabindex="-1" aria-hidden="true" />
      </form>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="error" icon="i-lucide-undo-2" :loading="guardando" @click="anular">Anular pago</UButton>
      </div>
    </template>
  </UModal>
</template>
