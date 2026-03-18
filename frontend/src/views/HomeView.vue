<script setup>
</script>

<template>
  <div class="home-view">
    <h2>Welcome</h2>
    <p>Use the left navigation to view Patients, Devices, and Prescriptions, or run device telemetry from the control plane.</p>
    <figure class="home-figure">
      <img
        src="/demo/demo_components.png"
        alt="Demonstration components architecture"
        class="home-diagram"
        width="964"
        height="561"
      />
      <figcaption>Demonstration components</figcaption>
    </figure>
  </div>
</template>

<style scoped>
.home-view {
  max-width: 960px;
}
.home-view h2 {
  margin-bottom: 0.5rem;
}
.home-view p {
  color: var(--text);
  line-height: 1.5;
}
.home-figure {
  margin: 1.75rem 0 0;
}
.home-diagram {
  display: block;
  width: 100%;
  max-width: 100%;
  height: auto;
  border-radius: 8px;
  border: 1px solid var(--border, rgba(0, 0, 0, 0.12));
}
.home-figure figcaption {
  margin-top: 0.5rem;
  font-size: 0.875rem;
  color: var(--text-muted, #666);
}
</style>
