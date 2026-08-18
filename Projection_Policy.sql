-- ============================================================
-- REAL-WORLD EXAMPLE: HEALTHCARE SYSTEM
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE PROJECTION_POLICY_DEMO_DB;
USE SCHEMA HR_SCHEMA;

-- Scenario: A hospital has a PATIENTS table. Doctors can see
-- diagnosis info, but billing staff should NEVER project medical
-- columns — they only need name + insurance + billing codes.

-- Policy: Only DOCTOR_ROLE can project medical columns
CREATE OR REPLACE PROJECTION POLICY medical_records_policy
  AS () RETURNS PROJECTION_CONSTRAINT ->
    CASE
      WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'DOCTOR_ROLE')
        THEN PROJECTION_CONSTRAINT(ALLOW => TRUE)
      ELSE
        PROJECTION_CONSTRAINT(ALLOW => FALSE)
    END;

-- Policy: Only BILLING_ROLE can project financial columns
CREATE OR REPLACE PROJECTION POLICY billing_data_policy
  AS () RETURNS PROJECTION_CONSTRAINT ->
    CASE
      WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'BILLING_ROLE')
        THEN PROJECTION_CONSTRAINT(ALLOW => TRUE)
      ELSE
        PROJECTION_CONSTRAINT(ALLOW => FALSE)
    END;

-- Create the patients table
CREATE OR REPLACE TABLE PATIENTS (
    PATIENT_ID       INT,
    FULL_NAME        VARCHAR(100),
    DATE_OF_BIRTH    DATE,
    -- Medical columns (protected for billing staff)
    DIAGNOSIS        VARCHAR(200),
    MEDICATION       VARCHAR(200),
    -- Financial columns (protected for doctors)
    INSURANCE_ID     VARCHAR(50),
    BILLING_CODE     VARCHAR(20),
    AMOUNT_OWED      NUMBER(10,2)
);

-- Attach policies to columns
ALTER TABLE PATIENTS MODIFY COLUMN DIAGNOSIS  SET PROJECTION POLICY medical_records_policy;
ALTER TABLE PATIENTS MODIFY COLUMN MEDICATION SET PROJECTION POLICY medical_records_policy;
ALTER TABLE PATIENTS MODIFY COLUMN INSURANCE_ID SET PROJECTION POLICY billing_data_policy;
ALTER TABLE PATIENTS MODIFY COLUMN BILLING_CODE SET PROJECTION POLICY billing_data_policy;
ALTER TABLE PATIENTS MODIFY COLUMN AMOUNT_OWED  SET PROJECTION POLICY billing_data_policy;

-- Insert sample patient records
INSERT INTO PATIENTS VALUES
  (101, 'John Doe',     '1985-03-15', 'Type 2 Diabetes',  'Metformin 500mg',  'INS-44821', 'E11.9', 1250.00),
  (102, 'Jane Roe',     '1992-07-22', 'Hypertension',     'Lisinopril 10mg',  'INS-77234', 'I10',    890.00),
  (103, 'Sam Wilson',   '1978-11-03', 'Asthma',           'Albuterol Inhaler', 'INS-55192', 'J45.0',  450.00);

-- Create roles
CREATE ROLE IF NOT EXISTS DOCTOR_ROLE;
CREATE ROLE IF NOT EXISTS BILLING_ROLE;
GRANT ROLE DOCTOR_ROLE  TO USER ALEXANDERSKS;
GRANT ROLE BILLING_ROLE TO USER ALEXANDERSKS;

-- Grant access to both roles
GRANT USAGE ON DATABASE PROJECTION_POLICY_DEMO_DB TO ROLE DOCTOR_ROLE;
GRANT USAGE ON SCHEMA HR_SCHEMA TO ROLE DOCTOR_ROLE;
GRANT SELECT ON TABLE PATIENTS TO ROLE DOCTOR_ROLE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE DOCTOR_ROLE;

GRANT USAGE ON DATABASE PROJECTION_POLICY_DEMO_DB TO ROLE BILLING_ROLE;
GRANT USAGE ON SCHEMA HR_SCHEMA TO ROLE BILLING_ROLE;
GRANT SELECT ON TABLE PATIENTS TO ROLE BILLING_ROLE;
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE BILLING_ROLE;

-- ============================================================
-- TEST AS DOCTOR_ROLE
-- ============================================================
-- Doctors CAN see medical columns but CANNOT see billing columns

USE ROLE DOCTOR_ROLE;
USE WAREHOUSE COMPUTE_WH;

-- This SUCCEEDS — doctors can see diagnosis and medication
SELECT PATIENT_ID, FULL_NAME, DIAGNOSIS, MEDICATION
FROM PROJECTION_POLICY_DEMO_DB.HR_SCHEMA.PATIENTS;

-- This FAILS — doctors cannot project billing columns
SELECT PATIENT_ID, FULL_NAME, INSURANCE_ID, AMOUNT_OWED
FROM PROJECTION_POLICY_DEMO_DB.HR_SCHEMA.PATIENTS;

-- ============================================================
-- TEST AS BILLING_ROLE
-- ============================================================
-- Billing staff CAN see financial columns but CANNOT see medical

USE ROLE BILLING_ROLE;
USE WAREHOUSE COMPUTE_WH;

-- This SUCCEEDS — billing can see insurance and amounts
SELECT PATIENT_ID, FULL_NAME, INSURANCE_ID, BILLING_CODE, AMOUNT_OWED
FROM PROJECTION_POLICY_DEMO_DB.HR_SCHEMA.PATIENTS;

-- This FAILS — billing cannot project medical columns
SELECT PATIENT_ID, FULL_NAME, DIAGNOSIS, MEDICATION
FROM PROJECTION_POLICY_DEMO_DB.HR_SCHEMA.PATIENTS;
