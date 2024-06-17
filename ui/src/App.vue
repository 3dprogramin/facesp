<script setup>
import WebCam from './components/WebCam.vue'
</script>

<template>
  <main>
    <div class="container">
      <WebCam />
    </div>
  </main>
</template>

<style scoped>
.container {
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100vh;
    width: 100vw;
    position: absolute;
    top: 0;
    left: 0;
}
</style>