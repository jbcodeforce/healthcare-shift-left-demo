/** Mock data aligned with README domain classes. Replace with API calls when backend endpoints exist. */

export const mockPatients = [
  { patientId: 'P001', name: 'Alice Smith', gender: 'F', birthDate: '1980-05-12', zipCode: '15201' },
  { patientId: 'P002', name: 'Bob Jones', gender: 'M', birthDate: '1975-11-03', zipCode: '15206' },
  { patientId: 'P003', name: 'Carol White', gender: 'F', birthDate: '1990-02-28', zipCode: '15217' },
  { patientId: 'P004', name: 'David Lee', gender: 'M', birthDate: '1988-07-19', zipCode: '15222' },
  { patientId: 'P005', name: 'Eve Brown', gender: 'F', birthDate: '1982-09-05', zipCode: '15232' },
]

export const mockDevices = [
  { device_id: 'DEV-P001', patientId: 'P001', pressureSetting: 10.0, flowRateSetting: 2.5, flowLevel: 3 },
  { device_id: 'DEV-P002', patientId: 'P002', pressureSetting: 12.0, flowRateSetting: 2.8, flowLevel: 4 },
  { device_id: 'DEV-P003', patientId: 'P003', pressureSetting: 8.0, flowRateSetting: 2.0, flowLevel: 2 },
  { device_id: 'DEV-P004', patientId: 'P004', pressureSetting: 11.0, flowRateSetting: 2.6, flowLevel: 3 },
  { device_id: 'DEV-P005', patientId: 'P005', pressureSetting: 9.5, flowRateSetting: 2.3, flowLevel: 3 },
]

export const mockPrescriptions = [
  {
    prescriptionId: 'RX001',
    patientId: 'P001',
    deviceId: 'DEV-P001',
    medicationOrTherapy: 'CPAP Oxygen Flow',
    metricName: 'Pressure',
    targetValue: 10.0,
    toleranceRange: 1.0,
    startDate: 1710000000000,
    endDate: 1741536000000,
  },
  {
    prescriptionId: 'RX002',
    patientId: 'P002',
    deviceId: 'DEV-P002',
    medicationOrTherapy: 'CPAP Oxygen Flow',
    metricName: 'FlowRate',
    targetValue: 2.5,
    toleranceRange: 0.5,
    startDate: 1710000000000,
    endDate: 1741536000000,
  },
  {
    prescriptionId: 'RX003',
    patientId: 'P003',
    deviceId: 'DEV-P003',
    medicationOrTherapy: 'CPAP Oxygen Flow',
    metricName: 'Pressure',
    targetValue: 8.0,
    toleranceRange: 0.8,
    startDate: 1710000000000,
    endDate: 1741536000000,
  },
]
