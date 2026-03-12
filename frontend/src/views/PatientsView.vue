<script setup>
import { ref, onMounted } from 'vue'
import { getPatients } from '../api/deviceGenerator.js'
import { mockPatients } from '../data/mockData.js'

const patients = ref([])
const error = ref(null)

onMounted(async () => {
  try {
    patients.value = await getPatients()
    error.value = null
  } catch (e) {
    error.value = e.message
    patients.value = mockPatients
  }
})
</script>

<template>
  <div class="list-view">
    <h2>Patients</h2>
    <p v-if="error" class="error-msg">Backend unavailable, showing mock data: {{ error }}</p>
    <table class="data-table">
      <thead>
        <tr>
          <th>Patient ID</th>
          <th>Name</th>
          <th>Gender</th>
          <th>Birth date</th>
          <th>Zip code</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="p in patients" :key="p.patientId">
          <td>{{ p.patientId }}</td>
          <td>{{ p.name }}</td>
          <td>{{ p.gender }}</td>
          <td>{{ p.birthDate }}</td>
          <td>{{ p.zipCode }}</td>
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
