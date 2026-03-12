<script setup>
import { ref, onMounted } from 'vue'
import { getDevices } from '../api/deviceGenerator.js'
import { mockDevices } from '../data/mockData.js'

const devices = ref([])
const error = ref(null)

onMounted(async () => {
  try {
    devices.value = await getDevices()
    error.value = null
  } catch (e) {
    error.value = e.message
    devices.value = mockDevices
  }
})
</script>

<template>
  <div class="list-view">
    <h2>Devices</h2>
    <p v-if="error" class="error-msg">Backend unavailable, showing mock data: {{ error }}</p>
    <table class="data-table">
      <thead>
        <tr>
          <th>Device ID</th>
          <th>Patient ID</th>
          <th>Pressure setting</th>
          <th>Flow rate setting</th>
          <th>Flow level</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="d in devices" :key="d.device_id">
          <td>{{ d.device_id }}</td>
          <td>{{ d.patientId }}</td>
          <td>{{ d.pressureSetting }}</td>
          <td>{{ d.flowRateSetting }}</td>
          <td>{{ d.flowLevel }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.list-view h2 {
  margin-bottom: 1rem;
}
.data-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9rem;
}
.data-table th,
.data-table td {
  padding: 0.5rem 0.75rem;
  text-align: left;
  border-bottom: 1px solid var(--border);
}
.data-table th {
  font-weight: 600;
  color: var(--text-h);
  background: var(--code-bg);
}
.error-msg {
  color: #b91c1c;
  font-size: 0.9rem;
  margin-bottom: 0.5rem;
}
</style>
