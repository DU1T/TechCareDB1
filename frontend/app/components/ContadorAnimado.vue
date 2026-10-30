<script setup lang="ts">
/*
  Número que cuenta hacia arriba al aparecer (y de un valor al otro si cambia). Frena al llegar.
  <ContadorAnimado :valor="44" />   <ContadorAnimado :valor="3550.4" :formato="quetzales" />
  - Lectores de pantalla: leen solo el valor final (la cifra que se mueve está oculta para ellos).
  - Con "reducir movimiento" muestra el valor final de una vez.
*/
const props = withDefaults(
  defineProps<{ valor: number; formato?: (n: number) => string; duracion?: number; retraso?: number }>(),
  { formato: (n: number) => numero(Math.round(n)), duracion: 1200, retraso: 0 },
)

const reducido = useReducedMotion()
const mostrado = ref(0)
let cuadro = 0

function animar(desde: number, hasta: number) {
  cancelAnimationFrame(cuadro)
  if (reducido.value) {
    mostrado.value = hasta
    return
  }
  const inicio = performance.now() + props.retraso
  const paso = (t: number) => {
    const p = Math.min(1, Math.max(0, (t - inicio) / props.duracion))
    mostrado.value = desde + (hasta - desde) * (1 - Math.pow(1 - p, 3)) // curva que frena al final
    if (p < 1) cuadro = requestAnimationFrame(paso)
  }
  cuadro = requestAnimationFrame(paso)
}

onMounted(() => animar(0, props.valor))
watch(() => props.valor, (nuevo, anterior) => animar(anterior ?? 0, nuevo))
onBeforeUnmount(() => cancelAnimationFrame(cuadro))
</script>

<template>
  <span class="cifras">
    <span aria-hidden="true">{{ formato(mostrado) }}</span>
    <span class="sr-only">{{ formato(valor) }}</span>
  </span>
</template>
