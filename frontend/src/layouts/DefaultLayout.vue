<script setup>
import { RouterLink, RouterView } from 'vue-router'
</script>

<template>
  <div class="app-layout">
    <header class="app-header">
      <h1 class="app-title">
        <img src="/batchy.png" alt="" class="app-title-logo" />
        Healthcare Demo
      </h1>
    </header>
    <div class="app-body">
      <nav class="app-sidebar">
        <RouterLink to="/" class="nav-link" active-class="nav-link-active">Home</RouterLink>
        <RouterLink to="/patients" class="nav-link" active-class="nav-link-active">Patients</RouterLink>
        <RouterLink to="/devices" class="nav-link" active-class="nav-link-active">Devices</RouterLink>
        <RouterLink to="/prescriptions" class="nav-link" active-class="nav-link-active">Prescriptions</RouterLink>
        <RouterLink to="/telemetry" class="nav-link" active-class="nav-link-active">Device telemetry</RouterLink>
        <RouterLink to="/analytics" class="nav-link" active-class="nav-link-active">Analytics</RouterLink>
        <RouterLink to="/demonstration" class="nav-link" active-class="nav-link-active">Demonstration</RouterLink>
        <a href="https://confluent.cloud/environments" class="nav-link" target="_blank" rel="noopener noreferrer">Confluent console</a>
      </nav>
      <main class="app-main">
        <RouterView />
      </main>
    </div>
  </div>
</template>

<style scoped>
.app-layout {
  display: flex;
  flex-direction: column;
  min-height: 100vh;
}

.app-header {
  flex-shrink: 0;
  padding: 0.75rem 1.5rem;
  border-bottom: 1px solid var(--border);
  background: var(--bg);
}

.app-title {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
  color: var(--text-h);
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.app-title-logo {
  height: 1.5em;
  width: auto;
}

.app-body {
  display: flex;
  flex: 1;
  min-height: 0;
}

.app-sidebar {
  flex-shrink: 0;
  width: 220px;
  padding: 1rem 0;
  border-right: 1px solid var(--border);
  background: var(--bg);
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.nav-link {
  padding: 0.5rem 1rem;
  color: var(--text);
  text-decoration: none;
  border-radius: 4px;
  margin: 0 0.5rem;
  transition: background 0.2s, color 0.2s;
}

.nav-link:hover {
  background: var(--accent-bg);
  color: var(--accent);
}

.nav-link-active {
  background: var(--accent-bg);
  color: var(--accent);
  font-weight: 500;
}

.app-main {
  flex: 1;
  overflow: auto;
  padding: 1.5rem;
  background: var(--bg);
}
</style>
