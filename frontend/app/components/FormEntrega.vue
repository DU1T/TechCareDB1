<script setup lang="ts">
/*
  Entregar una orden LISTO (POST /ordenes/{id}/entrega -> sp_EntregarOrden).
  El procedimiento exige que la factura esté pagada por completo (R16); si no, se muestra su mensaje.
*/
type OrdenEntrega = { idOrden: number; numeroOrden: string; cliente: string }

const props = defineProps<{ orden: OrdenEntrega | null }>()
const abierto = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ hecho: [] }>()

const api = useApi()
const toast = useToast()
const form = reactive({ nombre: '', documento: '', observaciones: '' })
const guardando = ref(false)
const intento = ref(false)

watch(abierto, (v) => {
  if (!v || !props.orden) return
  intento.value = false
  Object.assign(form, { nombre: props.orden.cliente, documento: '', observaciones: '' })
})

const errores = computed(() => ({
  nombre: !form.nombre.trim() ? 'Escribe quién recibe el equipo.' : form.nombre.length > 120 ? 'Máximo 120 caracteres.' : '',
  documento: form.documento.length > 20 ? 'Máximo 20 caracteres.' : !dpiValido(form.documento) ? MENSAJE.dpi : '',
  observaciones: form.observaciones.length > 300 ? 'Máximo 300 caracteres.' : '',
}))
const hayError = computed(() => Object.values(errores.value).some(Boolean))

async function entregar() {
  intento.value = true
  if (!props.orden || hayError.value) return
  guardando.value = true
  try {
    const r = await api<{ idEntrega: number; numeroOrden: string; estado: string }>(`/ordenes/${props.orden.idOrden}/entrega`, {
      method: 'POST',
      body: {
        nombreRecibe: form.nombre.trim(),
        documentoRecibe: form.documento.trim() || undefined,
        observaciones: form.observaciones.trim() || undefined,
      },
    })
    toast.add({ title: 'Equipo entregado', description: `${r.numeroOrden} quedó cerrada.`, color: 'success' })
    abierto.value = false
    emit('hecho')
  } catch {
    /* useApi mostró el mensaje (por ejemplo, si todavía hay saldo pendiente) */
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <UModal v-model:open="abierto" title="Entregar equipo">
    <template #body>
      <form v-if="orden" class="space-y-4" novalidate @submit.prevent="entregar">
        <p class="text-sm text-bruma-600">
          Al entregar, <strong class="text-highlighted">{{ orden.numeroOrden }}</strong> queda cerrada y ya no se puede modificar.
        </p>
        <UFormField label="Quién recibe" required :error="intento ? errores.nombre : undefined">
          <UInput v-model="form.nombre" maxlength="120" class="w-full" />
        </UFormField>
        <UFormField label="Documento de quien recibe" :error="intento && errores.documento ? errores.documento : undefined" hint="Opcional · DPI de 13 dígitos">
          <UInput v-model="form.documento" placeholder="1234 56789 0101" maxlength="20" inputmode="numeric" class="w-full" />
        </UFormField>
        <UFormField label="Observaciones" :error="errores.observaciones || undefined" :hint="`Opcional · ${contador(form.observaciones, 300)}`">
          <UTextarea v-model="form.observaciones" :rows="2" maxlength="300" class="w-full" />
        </UFormField>
        <button type="submit" class="hidden" tabindex="-1" aria-hidden="true" />
      </form>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="secondary" icon="i-lucide-package-check" :loading="guardando" @click="entregar">Confirmar entrega</UButton>
      </div>
    </template>
  </UModal>
</template>
