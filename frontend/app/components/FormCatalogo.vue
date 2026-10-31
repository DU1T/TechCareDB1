<script setup lang="ts">
/*
  Alta y edición de un registro de cualquiera de los seis catálogos, guiada por su definición (utils/catalogos.ts).
  POST {ruta} crea y PUT {ruta}/{id} edita; el PUT envía todos los campos, así que el formulario parte de la fila completa.
*/
import type { DefCatalogo } from '~/utils/catalogos'

const props = defineProps<{ def: DefCatalogo; fila: Record<string, any> | null }>()
const abierto = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ guardado: [] }>()

const api = useApi()
const toast = useToast()
const { alcance, sacudir } = useSacudida() // sacude el formulario y lleva el foco al primer error
const editando = computed(() => !!props.fila)

const valores = reactive<Record<string, any>>({})
const estado = ref('')
const categorias = ref<{ label: string; value: number }[]>([])
const guardando = ref(false)
const intento = ref(false)

watch(abierto, async (v) => {
  if (!v) return
  intento.value = false
  for (const k of Object.keys(valores)) delete valores[k]
  for (const c of props.def.campos) {
    const x = props.fila?.[c.clave]
    valores[c.clave] = x == null ? (c.tipo === 'dinero' ? '' : c.tipo === 'categoria' ? undefined : '') : c.tipo === 'dinero' ? String(x) : x
  }
  estado.value = props.fila?.estado ?? props.def.estados?.activo ?? ''
  if (props.def.campos.some((c) => c.tipo === 'categoria') && !categorias.value.length) {
    try {
      const r = await api<{ idCategoria: number; nombre: string }[]>('/categorias')
      categorias.value = r.map((c) => ({ label: c.nombre, value: c.idCategoria }))
    } catch { /* useApi ya avisó */ }
  }
})

// La lista de la API puede no traer algunos datos opcionales (p. ej. descripción del repuesto, dirección del proveedor)
// y el PUT reemplaza la fila completa: se avisa para no borrarlos sin querer.
const noVienen = computed(() =>
  editando.value ? props.def.campos.filter((c) => c.tipo !== 'dinero' && c.tipo !== 'categoria' && !c.obligatorio && props.fila![c.clave] === undefined).map((c) => c.etiqueta.toLowerCase()) : [],
)

const errores = computed(() => {
  const e: Record<string, string> = {}
  for (const c of props.def.campos) {
    const v = valores[c.clave]
    if (c.tipo === 'dinero') {
      const t = String(v ?? '').trim()
      const n = Number(t)
      if (!t) e[c.clave] = 'Escribe el precio.'
      else if (Number.isNaN(n) || n < 0) e[c.clave] = 'Debe ser un número mayor o igual a 0.'
      else if (Math.round(n * 100) / 100 !== n) e[c.clave] = 'Máximo dos decimales.'
      else if (n > 9999999999.99) e[c.clave] = 'El valor es demasiado grande.'
    } else if (c.tipo === 'categoria') {
      if (!v) e[c.clave] = 'Elige la categoría.'
    } else {
      const t = String(v ?? '').trim()
      if (c.obligatorio && !t) e[c.clave] = 'Este dato es obligatorio.'
      else if (c.max && String(v ?? '').length > c.max) e[c.clave] = `Máximo ${c.max} caracteres.`
      else if (c.formato === 'nit' && t && !nitValido(t)) e[c.clave] = MENSAJE.nit
      else if (c.formato === 'telefono' && !telefonoValido(t)) e[c.clave] = MENSAJE.telefono
      else if (c.formato === 'codigo' && t && !codigoValido(t)) e[c.clave] = MENSAJE.codigo
      else if (c.formato === 'nombre' && t && errorNombre(t, c.max ?? 150, false)) e[c.clave] = errorNombre(t, c.max ?? 150, false)
      else if (c.formato === 'email' && !emailValido(t)) e[c.clave] = MENSAJE.email
    }
  }
  return e
})

async function guardar() {
  intento.value = true
  if (Object.keys(errores.value).length) {
    sacudir()
    return
  }
  guardando.value = true
  const body: Record<string, any> = {}
  for (const c of props.def.campos) {
    const v = valores[c.clave]
    body[c.clave] = c.tipo === 'dinero' ? Number(v) : c.tipo === 'categoria' ? v : String(v ?? '').trim() || undefined
  }
  if (props.def.estados) body.estado = estado.value
  try {
    await api(editando.value ? `${props.def.ruta}/${props.fila![props.def.id]}` : props.def.ruta, { method: editando.value ? 'PUT' : 'POST', body })
    toast.add({ title: editando.value ? 'Cambios guardados' : 'Registro creado', description: String(body.nombre ?? ''), color: 'success' })
    abierto.value = false
    emit('guardado')
  } catch {
    /* useApi mostró el mensaje de la API (por ejemplo, un código repetido) */
    sacudir(false)
  } finally {
    guardando.value = false
  }
}
</script>

<template>
  <UModal v-model:open="abierto" :title="(editando ? 'Editar ' : 'Agregar ') + def.singular">
    <template #body>
      <form ref="alcance" class="space-y-4" novalidate @submit.prevent="guardar">
        <UFormField
          v-for="c in def.campos" :key="c.clave" :label="c.etiqueta" :required="c.obligatorio"
          :error="mostrar(intento, errores[c.clave], valores[c.clave], c.formato && c.formato !== 'email' ? INVALIDO[c.formato] : c.formato === 'email' ? /\s/ : undefined)"
          :hint="c.tipo === 'texto' && c.max ? limite(String(valores[c.clave] ?? ''), c.max, c.ayuda ?? (c.obligatorio ? undefined : 'Opcional')) : c.tipo === 'area' && c.max ? contador(String(valores[c.clave] ?? ''), c.max) : undefined"
        >
          <USelect v-if="c.tipo === 'categoria'" v-model="valores[c.clave]" :items="categorias" placeholder="Selecciona" class="w-full" />
          <UTextarea v-else-if="c.tipo === 'area'" v-model="valores[c.clave]" :rows="2" :maxlength="c.max" class="w-full" />
          <UInput v-else-if="c.tipo === 'dinero'" v-model="valores[c.clave]" inputmode="decimal" class="w-full" />
          <UInput v-else v-model="valores[c.clave]" :maxlength="c.max" class="w-full" />
        </UFormField>
        <UFormField v-if="def.estados" label="Estado">
          <USelect
            v-model="estado" class="w-full"
            :items="[{ label: 'Activo', value: def.estados.activo }, { label: 'Inactivo', value: def.estados.inactivo }]"
          />
        </UFormField>
        <p v-if="noVienen.length" class="rounded-md bg-warning/10 p-2 text-xs text-bruma-700">
          La lista no trae {{ noVienen.join(', ') }}. Si lo dejas vacío y guardas, se borra el valor que tenga el registro.
        </p>
        <p v-if="def.clave === 'repuestos' && editando" class="text-xs text-bruma-500">
          Si cambias un precio, queda registrado en la auditoría. La existencia en bodega no se modifica desde aquí.
        </p>
        <button type="submit" class="hidden" tabindex="-1" aria-hidden="true" />
      </form>
    </template>
    <template #footer="{ close }">
      <div class="flex w-full justify-end gap-2">
        <UButton color="neutral" variant="ghost" @click="close">Cancelar</UButton>
        <UButton color="secondary" :loading="guardando" @click="guardar">{{ editando ? 'Guardar cambios' : 'Crear' }}</UButton>
      </div>
    </template>
  </UModal>
</template>
