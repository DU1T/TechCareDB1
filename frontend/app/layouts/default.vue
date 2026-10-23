<script setup lang="ts">
import type { ItemMenu } from '~/utils/menu'

const auth = useAuthStore()
const route = useRoute()
const config = useRuntimeConfig()

const menuAbierto = ref(false)
const modoSimulado = computed(() => String(config.public.apiBase).startsWith('/'))
watch(() => route.fullPath, () => { menuAbierto.value = false })

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
    <div
      v-if="menuAbierto"
      class="fixed inset-0 z-30 bg-placa-950/60 lg:hidden"
      aria-hidden="true"
      @click="menuAbierto = false"
    />

    <aside
      class="menu-oscuro fixed inset-y-0 left-0 z-40 flex w-[17rem] flex-col bg-placa-900 text-placa-100 transition-transform duration-200 motion-reduce:transition-none lg:sticky lg:top-0 lg:h-dvh lg:translate-x-0"
      :class="menuAbierto ? 'translate-x-0' : '-translate-x-full'"
      aria-label="Menú principal"
    >
      <div class="flex h-14 items-center gap-2.5 px-5">
        <span class="grid size-7 place-items-center rounded-md bg-acento-500 text-sm font-bold text-bruma-950">T</span>
        <span class="text-lg font-semibold tracking-tight text-white">TechCare</span>
      </div>

      <nav class="flex-1 overflow-y-auto px-3 py-4">
        <div v-for="g in grupos" :key="g.nombre" class="mb-5">
          <p class="mb-1.5 px-2 text-xs font-medium text-placa-300">{{ g.nombre }}</p>
          <ul class="space-y-0.5">
            <li v-for="item in g.items" :key="item.ruta">
              <NuxtLink
                v-if="item.listo"
                :to="item.ruta"
                class="relative flex items-center gap-3 rounded-md px-2 py-2 text-sm transition-colors motion-reduce:transition-none"
                :class="rutaActiva === item.ruta
                  ? 'bg-placa-800 font-medium text-white before:absolute before:inset-y-1.5 before:-left-3 before:w-1 before:rounded-r before:bg-acento-500'
                  : 'text-placa-100 hover:bg-placa-800 hover:text-white'"
                :aria-current="rutaActiva === item.ruta ? 'page' : undefined"
              >
                <UIcon :name="item.icono" class="size-5 shrink-0" />
                {{ item.etiqueta }}
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
        <h1 class="text-base font-semibold tracking-tight">{{ titulo }}</h1>
        <UBadge v-if="modoSimulado" color="neutral" variant="outline" class="ml-auto">API simulada</UBadge>
      </header>

      <main class="flex-1 px-4 py-6 lg:px-8">
        <slot />
      </main>
    </div>
  </div>
</template>
