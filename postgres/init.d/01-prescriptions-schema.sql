-- Prescriptions table for backend CRUD and Debezium CDC.
-- Must exist before 02-debezium-replication.sh creates the publication.
-- Backend ensure_prescriptions_table() uses CREATE TABLE IF NOT EXISTS (no DROP).
CREATE TABLE IF NOT EXISTS public.prescriptions (
    id SERIAL PRIMARY KEY,
    prescription_id VARCHAR(128) NOT NULL UNIQUE,
    patient_id VARCHAR(64) NOT NULL,
    device_id VARCHAR(64) NOT NULL,
    medication_or_therapy VARCHAR(256),
    start_date BIGINT,
    end_date BIGINT,
    parameters TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
