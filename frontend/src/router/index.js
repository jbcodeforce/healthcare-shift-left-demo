import { createRouter, createWebHistory } from 'vue-router'
import DefaultLayout from '../layouts/DefaultLayout.vue'
import HomeView from '../views/HomeView.vue'
import PatientsView from '../views/PatientsView.vue'
import DevicesView from '../views/DevicesView.vue'
import PrescriptionsView from '../views/PrescriptionsView.vue'
import TelemetryView from '../views/TelemetryView.vue'
import DemonstrationView from '../views/DemonstrationView.vue'
import AnalyticsView from '../views/AnalyticsView.vue'

const routes = [
  {
    path: '/',
    component: DefaultLayout,
    children: [
      { path: '', name: 'Home', component: HomeView },
      { path: 'patients', name: 'Patients', component: PatientsView },
      { path: 'devices', name: 'Devices', component: DevicesView },
      { path: 'prescriptions', name: 'Prescriptions', component: PrescriptionsView },
      { path: 'telemetry', name: 'Telemetry', component: TelemetryView },
      { path: 'analytics', name: 'Analytics', component: AnalyticsView },
      { path: 'demonstration', name: 'Demonstration', component: DemonstrationView },
    ],
  },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
})

export default router
