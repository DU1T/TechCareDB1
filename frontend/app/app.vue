<template>
  <UApp>
    <!-- reduced-motion="user": si el sistema pide reducir movimiento, motion-v no anima (las de CSS, ver main.css) -->
    <MotionConfig reduced-motion="user">
      <NuxtLayout>
        <NuxtPage />
      </NuxtLayout>
    </MotionConfig>
  </UApp>
</template>
