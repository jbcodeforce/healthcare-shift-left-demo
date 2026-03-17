with expected_results as (
    select 
    'device_id' as expected_device_id,    
    'patient_id' as expected_patient_id,    
    'ts' as expected_ts    
    
        
    -- union all -- add more union here for each potential test data
    
),
actual_results as (
    select 
        device_id,
        patient_id,
        ts
        
    from hc_fct_drift_evts_ut
),
validation_check as (
    select 
       
        e.expected_device_id,
        e.expected_patient_id,
        e.expected_ts,
        
        -- be sure to use the correct conditions for the check
        case when a.device_id = e.expected_device_id then 'PASS' else 'FAIL' end as device_id_check,
        case when a.patient_id = e.expected_patient_id then 'PASS' else 'FAIL' end as patient_id_check,
        case when a.ts = e.expected_ts then 'PASS' else 'FAIL' end as ts_check
        

    from expected_results e
    left join actual_results a on a.sid = e.sid -- !!! change the condition here
),
overall_result as (
    select 
        count(*) as total_expected_records,
        sum(case when device_id_check = 'PASS' AND patient_id_check = 'PASS' AND ts_check = 'PASS' then 1 else 0 end) as passing_records,
        (select count(*) from actual_results) as actual_record_count
    from validation_check
)
select 
    case 
        when total_expected_records = 1  -- should match the number of union
         and passing_records = 1
        then 'PASS' 
        else 'FAIL' 
    end as test_result,
    total_expected_records,
    passing_records
from overall_result