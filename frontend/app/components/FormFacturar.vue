<script setup lang="ts">
/*
  Facturar una orden LISTO (POST /ordenes/{id}/factura -> sp_FacturarOrden).
  El total NO se calcula aquí: lo arma el procedimiento con mano de obra y repuestos a precio histórico (R09).
  Los datos de facturación son opcionales; si se dejan vacíos, la factura usa los del cliente.
*/
type OrdenFactura = { idOrden: number; numeroOrden: string; cliente: string; nitCliente: string }

const props = defineProps<{ orden: OrdenFactura | null }>()
const abierto = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ hecho: [] }>()

const api = useApi()
const toast = useToast()
const form = reactive({ nit: '', nombre: '', direccion: '' })
const guardando = ref(false)
const intento = ref(false) // el formato del NIT se avisa al intentar emitir, no mientras se escribe

watch(abierto, (v) => {
  if (!v) return
  Object.assign(form, { nit: '', nombre: '', direccion: '' })
  intento.value = false
})

const errores = computed(() => ({
  nit: form.nit.length > 15 ? 'Máximo 15 caracteres.' : form.nit.trim() && !nitValido(form.nit) ? MENSAJE.nit : '',
  nombre: form.nombre.length > 150 ? 'Máximo 150 caracteres.' : '',
  direccion: form.direccion.length > 250 ? 'Máximo 250 caracteres.' : '',
}))
const hayError = computed(() => Object.values(errores.value).some(Boolean))

async function emitir() {
  intento.value = true
  if (!props.orden || hayError.value) return
  guardando.value = true
  try {
    const r = await api<{ idFactura: number; serie: string; numero: number; total: number }>(`/ordenes/${props.orden.idOrden}/factura`, {
      method: 'POST',
      body: {
        nitFacturacion: form.nit.trim() || undefined,
        nombreFacturacion: form.nombre.trim() || undefined,
        direccionFacturacion: form.direccion.trim() || undefined,
      },
    })
    toast.add({
      title: 'Factura emitida',
      description: `${r.serie}-${String(r.numero).padStart(6, '0')} por ${quetzales(r.total)}.`,
      color: 'success',
    })
    abierto.value = false
    emit('hecho')
  } catch {
    /* useApi mostró el mensaje del procedimiento (por ejemplo, si la orden ya tiene factura) */
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <UModal v-model:open="abierto" title="Emitir factura">
    <template #body>
      <form v-if="orden" class="space-y-4" novalidate @submit.prevent="emitir">
        <p class="text-sm text-bruma-600">
          Se facturará <strong class="text-highlighted">{{ orden.numeroOrden }}</strong> con la mano de obra y los repuestos
          registrados. Cada orden tiene una sola factura.
        </p>
        <UFormField label="NIT de facturación" :error="(intento || form.nit.length > 15) && errores.nit ? errores.nit : undefined" hint="Opcional">
          <UInput v-model="form.nit" :placeholder="orden.nitCliente" maxlength="15" class="w-full" />
        </UFormField>
        <UFormField label="Nombre de facturación" :error="errores.nombre || undefined" hint="Opcional">
          <UInput v-model="form.nombre" :placeholder="orden.cliente" maxlength="150" class="w-full" />
        </UFormField>
        <UFormField label="Dirección" :error="errores.direccion || undefined" hint="Opcional">
          <UInput v-model="form.direccion" placeholder="La del cliente" maxlength="250" class="w-full" />
        </UFormField>
        <button type="submit" class="hidden" tabindex="-1" aria-hidden="true" />
      </form>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="secondary" icon="i-lucide-receipt" :loading="guardando" :disabled="hayError" @click="emitir">Emitir factura</UButton>
      </div>
    </template>
  </UModal>
</template>
