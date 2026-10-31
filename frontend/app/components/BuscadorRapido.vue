<script setup lang="ts">
import type { CommandPaletteGroup, CommandPaletteItem } from '@nuxt/ui'

/*
  Buscador rápido: Ctrl+K (⌘K en Mac) o el botón "Buscar" del encabezado.
  - Pantallas: las del menú que el rol puede abrir (salen de utils/menu.ts, así las nuevas aparecen solas).
  - Orden por número: "42", "os-42" u "OS-000042" abre su trazabilidad, aunque ya esté entregada.
  - Órdenes: por número, cliente o equipo (GET /ordenes, se pide la primera vez que se abre).
  Solo atajos: cada pantalla sigue pidiendo su permiso (middleware y API).
*/
type Orden = { idOrden: number; numeroOrden: string; estado: string; cliente: string; tipoEquipo: string; marca: string; modelo: string }

const abierto = defineModel<boolean>('open', { default: false })
const auth = useAuthStore()
const api = useApi()
const termino = ref('')
// La paleta no expone maxlength: se recorta aquí al mismo límite que los demás buscadores
watch(termino, (t) => {
  if (t.length > LIMITE.busqueda) termino.value = t.slice(0, LIMITE.busqueda)
})

defineShortcuts({ meta_k: () => { abierto.value = !abierto.value } })

const veOrdenes = computed(() => auth.puede('REPORTE_VER'))
const ordenes = ref<Orden[]>([])
const cargandoOrdenes = ref(false)
let pedidas = false
watch(abierto, async (a) => {
  if (!a) {
    termino.value = ''
    return
  }
  if (pedidas || !veOrdenes.value) return
  pedidas = true
  cargandoOrdenes.value = true
  try {
    ordenes.value = await api<Orden[]>('/ordenes')
  } catch {
    pedidas = false // se reintenta la próxima vez que se abra
  } finally {
    cargandoOrdenes.value = false
  }
})

function ir(ruta: string) {
  abierto.value = false
  navigateTo(ruta)
}

const grupos = computed<CommandPaletteGroup<CommandPaletteItem>[]>(() => {
  const lista: CommandPaletteGroup<CommandPaletteItem>[] = []

  // Si lo escrito parece un número de orden, la primera opción es abrirla
  const t = termino.value.trim()
  if (veOrdenes.value && /^(os-?)?\d+$/i.test(t)) {
    const id = idDeOrden(t)
    if (id) {
      const numero = 'OS-' + String(id).padStart(6, '0')
      lista.push({
        id: 'orden-directa',
        label: 'Orden por número',
        ignoreFilter: true,
        items: [{ label: `Abrir la orden ${numero}`, suffix: 'Trazabilidad completa', icon: 'i-lucide-route', onSelect: () => ir(`/ordenes/${id}/trazabilidad`) }],
      })
    }
  }

  lista.push({
    id: 'pantallas',
    label: 'Pantallas',
    items: MENU.filter((i) => i.listo && (!i.permiso || auth.puede(i.permiso))).map((i) => ({
      label: i.etiqueta,
      suffix: i.descripcion,
      icon: i.icono,
      onSelect: () => ir(i.ruta),
    })),
  })

  if (veOrdenes.value) {
    lista.push({
      id: 'ordenes',
      label: 'Órdenes',
      // Con el buscador vacío no se listan las 60 órdenes: solo aparecen al escribir
      postFilter: (busqueda, items) => (busqueda.trim() ? items : []),
      items: ordenes.value.map((o) => ({
        label: o.numeroOrden,
        suffix: `${o.cliente} · ${o.tipoEquipo} ${o.marca} ${o.modelo} · ${ESTADO_ORDEN[o.estado]?.texto ?? o.estado}`,
        icon: 'i-lucide-wrench',
        onSelect: () => ir(`/ordenes/${o.idOrden}/trazabilidad`),
      })),
    })
  }

  lista.push({
    id: 'sesion',
    label: 'Sesión',
    items: [{ label: 'Cerrar sesión', icon: 'i-lucide-log-out', onSelect: () => { abierto.value = false; auth.logout() } }],
  })
  return lista
})
</script>

<template>
  <UModal v-model:open="abierto" title="Buscador rápido" description="Pantallas y órdenes" :ui="{ content: 'sm:max-w-xl' }">
    <template #content>
      <UCommandPalette
        v-model:search-term="termino"
        :groups="grupos"
        :loading="cargandoOrdenes"
        placeholder="Pantalla, número de orden, cliente o equipo…"
        :close="{ 'aria-label': 'Cerrar buscador' }"
        class="h-96"
        @update:open="abierto = $event"
      >
        <template #empty>
          <p class="py-6 text-center text-sm text-bruma-600">Nada coincide con «{{ termino }}».</p>
        </template>
      </UCommandPalette>
    </template>
  </UModal>
</template>
