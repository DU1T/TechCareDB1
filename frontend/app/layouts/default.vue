<script setup lang="ts">
import type { ItemMenu } from '~/utils/menu'

const auth = useAuthStore()
const route = useRoute()
const config = useRuntimeConfig()

const menuAbierto = ref(false)
const buscador = ref(false)
const modoSimulado = computed(() => config.public.modoSimulado === true)
watch(() => route.fullPath, () => { menuAbierto.value = false })

// Escape cierra el menú móvil, aunque el foco esté fuera del menú (por eso se escucha en la ventana)
function alEscape(e: KeyboardEvent) {
  if (e.key === 'Escape') menuAbierto.value = false
}
onMounted(() => window.addEventListener('keydown', alEscape))
onBeforeUnmount(() => window.removeEventListener('keydown', alEscape))

// Solo se muestran los ítems que el rol puede usar, agrupados
const grupos = computed(() => {
  const mapa = new Map<string, ItemMenu[]>()
  for (const item of MENU) {
    if (item.permiso && !auth.puede(item.permiso)) continue
    mapa.set(item.grupo, [...(mapa.get(item.grupo) ?? []), item])
  }
  return [...mapa].map(([nombre, items]) => ({ nombre, items }))
})

// La ruta más específica gana: /ordenes/nueva no enciende también /ordenes
const rutaActiva = computed(() => {
  const coincide = (r: string) => (r === '/' ? route.path === '/' : route.path === r || route.path.startsWith(r + '/'))
  return MENU.map((i) => i.ruta).filter(coincide).sort((a, b) => b.length - a.length)[0]
})

const rolesTexto = computed(() => (auth.usuario?.roles ?? []).map(nombreRol).join(', '))
const titulo = computed(() => String(route.meta.titulo ?? 'TechCare'))
</script>

<template>
  <div class="min-h-dvh lg:grid lg:grid-cols-[17rem_minmax(0,1fr)]">
    <Transition name="marco">
      <div
        v-if="menuAbierto"
        class="fixed inset-0 z-30 bg-placa-950/60 lg:hidden"
        aria-hidden="true"
        @click="menuAbierto = false"
      />
    </Transition>

    <aside
      class="menu-oscuro fixed inset-y-0 left-0 z-40 flex w-[17rem] flex-col bg-placa-900 text-placa-100 transition-[translate,visibility] duration-300 ease-llega motion-reduce:transition-none lg:sticky lg:top-0 lg:h-dvh lg:translate-x-0"
      :class="menuAbierto ? 'translate-x-0' : '-translate-x-full invisible lg:visible'"
      aria-label="Menú principal"
    >
      <div class="flex h-14 items-center gap-2.5 px-5">
        <span class="grid size-7 place-items-center rounded-md bg-acento-500 text-sm font-bold text-bruma-950">T</span>
        <span class="text-lg font-semibold tracking-tight text-white">TechCare</span>
      </div>

      <nav class="flex-1 overflow-y-auto px-3 py-4">
        <div v-for="g in grupos" :key="g.nombre" class="mb-5">
          <p class="relative z-10 mb-1.5 px-2 text-xs font-medium text-placa-300">{{ g.nombre }}</p>
          <ul class="space-y-0.5">
            <li v-for="item in g.items" :key="item.ruta">
              <NuxtLink
                v-if="item.listo"
                :to="item.ruta"
                class="relative flex items-center gap-3 rounded-md px-2 py-2 text-sm transition-colors motion-reduce:transition-none"
                :class="rutaActiva === item.ruta ? 'font-medium text-white' : 'text-placa-100 hover:bg-placa-800/60 hover:text-white'"
                :aria-current="rutaActiva === item.ruta ? 'page' : undefined"
              >
                <!-- Marca del ítem activo: es UNA sola pieza (layout-id) que viaja de un ítem a otro con resorte -->
                <Motion
                  v-if="rutaActiva === item.ruta"
                  layout-id="menu-activo"
                  class="absolute inset-0 z-0 rounded-md bg-placa-800"
                  :transition="RESORTE"
                >
                  <span class="absolute inset-y-1.5 -left-3 w-1 rounded-r bg-acento-500" />
                </Motion>
                <UIcon :name="item.icono" class="relative z-10 size-5 shrink-0" />
                <span class="relative z-10">{{ item.etiqueta }}</span>
              </NuxtLink>
              <span
                v-else
                class="flex items-center gap-3 rounded-md px-2 py-2 text-sm text-placa-300/70"
                aria-disabled="true"
              >
                <UIcon :name="item.icono" class="size-5 shrink-0" />
                {{ item.etiqueta }}
                <span class="ml-auto rounded bg-placa-800 px-1.5 py-0.5 text-xs text-placa-300">Pronto</span>
              </span>
            </li>
          </ul>
        </div>
      </nav>

      <div class="border-t border-placa-800 p-3">
        <div class="flex items-center gap-3 px-2 py-1.5">
          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-medium text-white">{{ auth.usuario?.nombreCompleto }}</p>
            <p class="truncate text-xs text-placa-300">{{ rolesTexto }}</p>
          </div>
          <UButton
            icon="i-lucide-log-out"
            color="neutral"
            variant="ghost"
            class="text-placa-100 hover:bg-placa-800 hover:text-white"
            aria-label="Cerrar sesión"
            @click="auth.logout()"
          />
        </div>
      </div>
    </aside>

    <div class="flex min-w-0 flex-col">
      <header class="sticky top-0 z-20 flex h-14 items-center gap-3 border-b border-bruma-200 bg-bruma-100/90 px-4 backdrop-blur lg:px-8">
        <UButton
          class="lg:hidden"
          icon="i-lucide-menu"
          color="neutral"
          variant="ghost"
          aria-label="Abrir menú"
          @click="menuAbierto = true"
        />
        <Transition name="aparece" mode="out-in">
          <h1 :key="titulo" class="text-base font-semibold tracking-tight">{{ titulo }}</h1>
        </Transition>
        <UBadge v-if="modoSimulado" color="neutral" variant="outline" class="ml-auto">API simulada</UBadge>
        <UButton
          color="neutral"
          variant="outline"
          icon="i-lucide-search"
          :class="modoSimulado ? '' : 'ml-auto'"
          aria-label="Buscar pantallas y órdenes"
          aria-keyshortcuts="Control+K Meta+K"
          @click="buscador = true"
        >
          <span class="hidden text-bruma-600 sm:inline">Buscar</span>
          <span class="hidden gap-0.5 sm:flex">
            <UKbd value="meta" />
            <UKbd value="K" />
          </span>
        </UButton>
      </header>

      <BuscadorRapido v-model:open="buscador" />

      <main class="flex-1 px-4 py-6 lg:px-8">
        <slot />
      </main>
    </div>
  </div>
</template>