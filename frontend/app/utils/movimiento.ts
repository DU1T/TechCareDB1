/*
  Ajustes de motion-v que comparten todas las pantallas. Son los mismos valores que las variables
  de movimiento de main.css (--dur-*, --ease-*), pero en segundos, que es lo que usa motion-v.

  Uso en una pantalla (no hace falta import: Nuxt los trae solos):
    <Motion :initial="{ opacity: 0, y: 12 }" :animate="{ opacity: 1, y: 0 }" :transition="{ ...RESORTE, delay: escalon(i) }">

  Con "reducir movimiento" activado, <MotionConfig> de app.vue hace que todo aparezca sin desplazarse.
*/
type Curva = [number, number, number, number]

export const DURACION = { rapida: 0.15, media: 0.25, lenta: 0.45, escena: 0.8 }

export const CURVA: { llega: Curva; seVa: Curva } = {
  llega: [0.2, 0.8, 0.2, 1],
  seVa: [0.4, 0, 1, 1],
}

// Resorte firme: menús, indicadores, insignias. Llega rápido y casi no rebota.
export const RESORTE = { type: 'spring', stiffness: 380, damping: 32 } as const

// Resorte suave: solo escenas (la etiqueta del login, tarjetas del tablero). Rebota un poco.
export const RESORTE_SUAVE = { type: 'spring', stiffness: 170, damping: 18 } as const

// Entrada escalonada: cada elemento llega un poco después del anterior.
// Tope de 8 pasos: en una lista larga, los de abajo no deben hacer esperar.
export function escalon(i: number, paso = 0.04) {
  return Math.min(i, 8) * paso
}
