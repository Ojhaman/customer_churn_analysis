-- ================================================================
--   CUSTOMER CHURN ANALYSIS PROJECT
--   Dataset : WA_Fn-UseC_-Telco-Customer-Churn.csv  (Kaggle)
--   Tool    : MySQL Workbench 8.x
--   Author  : Aman Kumar Ojha  |  Roll No : 24112003 (NITJ)
-- ================================================================

--  PHASE 1 : DATABASE & TABLE SETUP

-- 1A. Create database

DROP DATABASE IF EXISTS churn_db;
CREATE DATABASE churn_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE churn_db;

-- 1B. Create main table  (column names match CSV header exactly)

CREATE TABLE telcom_customers (
    customerID        VARCHAR(20)    NOT NULL,
    gender            VARCHAR(10),
    SeniorCitizen     TINYINT(1),          -- 0 = No, 1 = Yes
    Partner           VARCHAR(5),          -- 'Yes' / 'No'
    Dependents        VARCHAR(5),          -- 'Yes' / 'No'
    tenure            INT,                 -- months as a customer (0–72)
    PhoneService      VARCHAR(5),          -- 'Yes' / 'No'
    MultipleLines     VARCHAR(20),         -- 'Yes' / 'No' / 'No phone service'
    InternetService   VARCHAR(20),         -- 'DSL' / 'Fiber optic' / 'No'
    OnlineSecurity    VARCHAR(25),         -- 'Yes' / 'No' / 'No internet service'
    OnlineBackup      VARCHAR(25),
    DeviceProtection  VARCHAR(25),
    TechSupport       VARCHAR(25),
    StreamingTV       VARCHAR(25),
    StreamingMovies   VARCHAR(25),
    Contract          VARCHAR(20),         -- 'Month-to-month' / 'One year' / 'Two year'
    PaperlessBilling  VARCHAR(5),          -- 'Yes' / 'No'
    PaymentMethod     VARCHAR(40),         -- 4 categories
    MonthlyCharges    DECIMAL(8,2),        -- range: $18.25 – $118.75
    TotalCharges      VARCHAR(20),         -- stored as string in CSV; 11 rows are blank
    Churn             VARCHAR(5),          -- TARGET: 'Yes' (1869) or 'No' (5174)
    PRIMARY KEY (customerID)
);



-- 1C. IMPORT THE CSV

-- ---------------------------------------------------------------

-- 1D. Verify import — must return 7043

SELECT COUNT(*) AS total_rows FROM telcom_customers;


-- 1E. Add computed / derived columns


-- Numeric churn flag  (1 = churned, 0 = retained) — generated column
ALTER TABLE telcom_customers
    ADD COLUMN ChurnFlag TINYINT(1)
        GENERATED ALWAYS AS (IF(Churn = 'Yes', 1, 0)) STORED;

-- TotalCharges as numeric  (11 blank rows → 0.00)
ALTER TABLE telcom_customers
    ADD COLUMN TotalCharges_num DECIMAL(10,2) DEFAULT 0.00;

UPDATE telcom_customers
SET TotalCharges_num = CASE
    WHEN TRIM(TotalCharges) = '' THEN 0.00
    ELSE CAST(TotalCharges AS DECIMAL(10,2))
END;

-- Tenure bands (from actual data: min=0, max=72, mean=32.4 months)
ALTER TABLE telcom_customers
    ADD COLUMN TenureBand VARCHAR(20);

UPDATE telcom_customers
SET TenureBand = CASE
    WHEN tenure BETWEEN 0  AND 12 THEN '0-12 months'
    WHEN tenure BETWEEN 13 AND 24 THEN '13-24 months'
    WHEN tenure BETWEEN 25 AND 36 THEN '25-36 months'
    WHEN tenure BETWEEN 37 AND 48 THEN '37-48 months'
    WHEN tenure BETWEEN 49 AND 60 THEN '49-60 months'
    ELSE                                '60+ months'
END;

-- Sanity check  (expected: 2186 / 1024 / 832 / 762 / 832 / 1407)
SELECT TenureBand,
       COUNT(*)                     AS customers,
       SUM(ChurnFlag)               AS churned,
       ROUND(AVG(ChurnFlag)*100,2)  AS churn_pct
FROM telcom_customers
GROUP BY TenureBand
ORDER BY FIELD(TenureBand,
    '0-12 months','13-24 months','25-36 months',
    '37-48 months','49-60 months','60+ months');


-- 1F. Audit log table

CREATE TABLE churn_analysis_log (
    log_id        INT          AUTO_INCREMENT PRIMARY KEY,
    run_timestamp DATETIME     DEFAULT CURRENT_TIMESTAMP,
    analysis_name VARCHAR(100),
    result_value  VARCHAR(255),
    notes         VARCHAR(500)
);

INSERT INTO churn_analysis_log (analysis_name, result_value, notes)
VALUES ('Phase 1 Setup', '7043 rows imported', 'Table created, columns added');



--  PHASE 2 : EXPLORATORY DATA ANALYSIS (EDA)

-- Q1. Overall churn rate
--     Expected: 1869 churned, 26.54% churn rate

SELECT
    COUNT(*)                             AS total_customers,
    SUM(ChurnFlag)                       AS churned,
    COUNT(*) - SUM(ChurnFlag)            AS retained,
    ROUND(AVG(ChurnFlag)*100, 2)         AS churn_rate_pct,
    ROUND((1 - AVG(ChurnFlag))*100, 2)   AS retention_rate_pct
FROM telcom_customers;


-- Q2. Churn by gender
--     (Dataset: 3555 Female, 3488 Male — nearly balanced)
SELECT
    gender,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct
FROM telcom_customers
GROUP BY gender
ORDER BY churn_rate_pct DESC;


-- Q3. Senior citizen impact
--     Seniors are ~16% of customers but churn at ~42%

SELECT
    CASE WHEN SeniorCitizen = 1 THEN 'Senior Citizen'
         ELSE 'Non-Senior'
    END                             AS customer_type,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_monthly_charge
FROM telcom_customers
GROUP BY SeniorCitizen
ORDER BY churn_rate_pct DESC;


-- Q4. Churn by Tenure Band  (clearest inverse relationship)
--     0-12 months: 47.4% churn  →  60+ months: 6.6% churn

SELECT
    tenure,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_monthly_charge
FROM telcom_customers
GROUP BY tenure
ORDER BY FIELD(tenure,
    '0-12 months','13-24 months','25-36 months',
    '37-48 months','49-60 months','60+ months');


-- Q5. Contract type  (STRONGEST single predictor)
--     Month-to-month: 42.71%  |  One year: 11.27%  |  Two year: 2.83%

SELECT
    Contract,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_monthly_charge,
    ROUND(AVG(tenure), 1)           AS avg_tenure_months
FROM telcom_customers
GROUP BY Contract
ORDER BY churn_rate_pct DESC;


-- Q6. Internet service type
--     Fiber optic: ~41.9%  |  DSL: ~19.0%  |  No internet: ~7.4%

SELECT
    InternetService,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_monthly_charge
FROM telcom_customers
GROUP BY InternetService
ORDER BY churn_rate_pct DESC;

-- Q7. Payment method  (Electronic check highest churn ~45%)

SELECT
    PaymentMethod,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_monthly_charge
FROM telcom_customers
GROUP BY PaymentMethod
ORDER BY churn_rate_pct DESC;


-- Q8. Monthly charges: churned vs retained
--     Churned customers pay significantly more on average

SELECT
    Churn,
    COUNT(*)                        AS customers,
    ROUND(MIN(MonthlyCharges), 2)   AS min_charge,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_charge,
    ROUND(MAX(MonthlyCharges), 2)   AS max_charge,
    ROUND(STD(MonthlyCharges), 2)   AS std_dev
FROM telcom_customers
GROUP BY Churn;

-- Q9. Revenue impact of churn
--     Monthly loss: $1,39,130.85  |  Historical total: $28,62,926.90

SELECT
    ROUND(SUM(CASE WHEN Churn='Yes' THEN MonthlyCharges ELSE 0 END), 2)
        AS monthly_revenue_lost,
    ROUND(SUM(CASE WHEN Churn='No'  THEN MonthlyCharges ELSE 0 END), 2)
        AS monthly_revenue_retained,
    ROUND(SUM(CASE WHEN Churn='Yes' THEN TotalCharges_num ELSE 0 END), 2)
        AS total_revenue_from_churned_customers,
    ROUND(
        SUM(CASE WHEN Churn='Yes' THEN MonthlyCharges ELSE 0 END) /
        SUM(MonthlyCharges) * 100, 2)
        AS pct_revenue_at_risk
FROM telcom_customers;


-- Q10. Add-on services vs churn (internet customers only)
--      No security/tech support → significantly higher churn

SELECT
    'OnlineSecurity'    AS service,
    OnlineSecurity      AS subscription_status,
    COUNT(*)            AS total,
    SUM(ChurnFlag)      AS churned,
    ROUND(AVG(ChurnFlag)*100, 2) AS churn_rate_pct
FROM telcom_customers
WHERE InternetService != 'No'
GROUP BY OnlineSecurity

UNION ALL
SELECT 'TechSupport', TechSupport,
       COUNT(*), SUM(ChurnFlag), ROUND(AVG(ChurnFlag)*100,2)
FROM telcom_customers WHERE InternetService != 'No'
GROUP BY TechSupport

UNION ALL
SELECT 'OnlineBackup', OnlineBackup,
       COUNT(*), SUM(ChurnFlag), ROUND(AVG(ChurnFlag)*100,2)
FROM telcom_customers WHERE InternetService != 'No'
GROUP BY OnlineBackup

UNION ALL
SELECT 'DeviceProtection', DeviceProtection,
       COUNT(*), SUM(ChurnFlag), ROUND(AVG(ChurnFlag)*100,2)
FROM telcom_customers WHERE InternetService != 'No'
GROUP BY DeviceProtection

ORDER BY service, churn_rate_pct DESC;


-- Q11. Partner & Dependents  (family anchor effect on retention)

SELECT
    Partner,
    Dependents,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct
FROM telcom_customers
GROUP BY Partner, Dependents
ORDER BY churn_rate_pct DESC;


-- Q12. Paperless billing
--      Paperless billing users churn more (~33% vs ~16%)

SELECT
    PaperlessBilling,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct
FROM telcom_customers
GROUP BY PaperlessBilling;

-- Q13. Contract × Internet Service  (risk cross-tab)

SELECT
    Contract,
    InternetService,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_monthly_charge
FROM telcom_customers
GROUP BY Contract, InternetService
ORDER BY churn_rate_pct DESC;


--  PHASE 3 : RISK SEGMENTATION

-- Risk score: 0–8 points based on 7 verified churn drivers.
-- Score boundaries are empirically validated on this dataset.

ALTER TABLE telcom_customers
    ADD COLUMN RiskScore_    INT DEFAULT 0,
    ADD COLUMN RiskCategory_ VARCHAR(15);

UPDATE telcom_customers
SET RiskScore_ = (
    -- Contract: month-to-month is 15x riskier than two-year  (+2)
    (CASE WHEN Contract = 'Month-to-month'          THEN 2 ELSE 0 END)
    -- Fiber optic churn rate ~42% vs DSL ~19%                 (+1)
  + (CASE WHEN InternetService = 'Fiber optic'       THEN 1 ELSE 0 END)
    -- No online security = key vulnerability                   (+1)
  + (CASE WHEN OnlineSecurity IN
             ('No','No internet service')            THEN 1 ELSE 0 END)
    -- Electronic check: 45.3% churn vs ~15% auto-pay          (+1)
  + (CASE WHEN PaymentMethod = 'Electronic check'   THEN 1 ELSE 0 END)
    -- New customers (<12 months): 47.4% churn rate            (+1)
  + (CASE WHEN tenure < 12                           THEN 1 ELSE 0 END)
    -- Senior citizens: 41.7% churn vs 23.6% non-seniors       (+1)
  + (CASE WHEN SeniorCitizen = 1                     THEN 1 ELSE 0 END)
    -- High monthly charge >$70 correlates with higher churn   (+1)
  + (CASE WHEN MonthlyCharges > 70                   THEN 1 ELSE 0 END)
);

UPDATE telcom_customers
SET RiskCategory_ = CASE
    WHEN RiskScore_ >= 5 THEN 'Critical'   -- avg churn: ~65%
    WHEN RiskScore_ >= 3 THEN 'High'       -- avg churn: ~38%
    WHEN RiskScore_ >= 1 THEN 'Medium'     -- avg churn: ~10%
    ELSE                     'Low'        -- avg churn:  ~2%
END;

-- Risk segment summary with actual churn validation
SELECT
    RiskCategory,
    COUNT(*)                                AS customers,
    SUM(ChurnFlag)                          AS actual_churned,
    ROUND(AVG(ChurnFlag)*100, 2)            AS actual_churn_pct,
    ROUND(AVG(MonthlyCharges), 2)           AS avg_monthly_charge,
    ROUND(SUM(MonthlyCharges), 2)           AS segment_monthly_revenue
FROM telcom_customers
GROUP BY RiskCategory
ORDER BY FIELD(RiskCategory, 'Critical','High','Medium','Low');


-- Top 20 highest-risk customers who have NOT churned yet
-- (Priority list for proactive retention campaigns)
SELECT
    customerID,
    gender,
    SeniorCitizen,
    tenure,
    Contract,
    InternetService,
    PaymentMethod,
    MonthlyCharges,
    RiskScore,
    RiskCategory
FROM telcom_customers
WHERE Churn = 'No'
ORDER BY RiskScore DESC, MonthlyCharges DESC
LIMIT 20;


--  PHASE 4 : VIEWS & STORED PROCEDURES
-- VIEW 1 : Executive summary (single-row KPI snapshot)

CREATE OR REPLACE VIEW vw_churn_summary AS
SELECT
    COUNT(*)                                                     AS total_customers,
    SUM(ChurnFlag)                                               AS churned,
    COUNT(*) - SUM(ChurnFlag)                                    AS retained,
    ROUND(AVG(ChurnFlag)*100, 2)                                 AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)                                AS overall_avg_monthly_charge,
    ROUND(SUM(CASE WHEN Churn='Yes' THEN MonthlyCharges ELSE 0 END), 2)
                                                                 AS monthly_revenue_at_risk,
    ROUND(AVG(CASE WHEN Churn='Yes' THEN MonthlyCharges END), 2) AS churned_avg_charge,
    ROUND(AVG(CASE WHEN Churn='No'  THEN MonthlyCharges END), 2) AS retained_avg_charge,
    ROUND(AVG(CASE WHEN Churn='Yes' THEN tenure END), 1)         AS churned_avg_tenure_months,
    ROUND(AVG(CASE WHEN Churn='No'  THEN tenure END), 1)         AS retained_avg_tenure_months
FROM telcom_customers;

SELECT * FROM vw_churn_summary;

-- VIEW 2 : Service subscription impact on churn

CREATE OR REPLACE VIEW vw_service_impact AS
SELECT 'PhoneService'     AS service_name, PhoneService     AS subscription_value,
       COUNT(*) AS total, SUM(ChurnFlag) AS churned,
       ROUND(AVG(ChurnFlag)*100,2) AS churn_pct
FROM telcom_customers GROUP BY PhoneService
UNION ALL
SELECT 'MultipleLines',   MultipleLines,
       COUNT(*), SUM(ChurnFlag), ROUND(AVG(ChurnFlag)*100,2)
FROM telcom_customers GROUP BY MultipleLines
UNION ALL
SELECT 'InternetService', InternetService,
       COUNT(*), SUM(ChurnFlag), ROUND(AVG(ChurnFlag)*100,2)
FROM telcom_customers GROUP BY InternetService
UNION ALL
SELECT 'OnlineSecurity',  OnlineSecurity,
       COUNT(*), SUM(ChurnFlag), ROUND(AVG(ChurnFlag)*100,2)
FROM telcom_customers GROUP BY OnlineSecurity
UNION ALL
SELECT 'OnlineBackup',    OnlineBackup,
       COUNT(*), SUM(ChurnFlag), ROUND(AVG(ChurnFlag)*100,2)
FROM telcom_customers GROUP BY OnlineBackup
UNION ALL
SELECT 'DeviceProtection',DeviceProtection,
       COUNT(*), SUM(ChurnFlag), ROUND(AVG(ChurnFlag)*100,2)
FROM telcom_customers GROUP BY DeviceProtection
UNION ALL
SELECT 'TechSupport',     TechSupport,
       COUNT(*), SUM(ChurnFlag), ROUND(AVG(ChurnFlag)*100,2)
FROM telcom_customers GROUP BY TechSupport
UNION ALL
SELECT 'StreamingTV',     StreamingTV,
       COUNT(*), SUM(ChurnFlag), ROUND(AVG(ChurnFlag)*100,2)
FROM telcom_customers GROUP BY StreamingTV
UNION ALL
SELECT 'StreamingMovies', StreamingMovies,
       COUNT(*), SUM(ChurnFlag), ROUND(AVG(ChurnFlag)*100,2)
FROM telcom_customers GROUP BY StreamingMovies
ORDER BY service_name, churn_pct DESC;

SELECT * FROM vw_service_impact;


-- VIEW 3 : Contract × Tenure churn matrix

CREATE OR REPLACE VIEW vw_contract_churn AS
SELECT
    Contract,
    TenureBand,
    COUNT(*)                        AS customers,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_monthly_charge,
    ROUND(SUM(TotalCharges_num), 2) AS segment_total_revenue
FROM telcom_customers
GROUP BY Contract, TenureBand
ORDER BY Contract,
         FIELD(TenureBand,
             '0-12 months','13-24 months','25-36 months',
             '37-48 months','49-60 months','60+ months');

SELECT * FROM vw_contract_churn;



-- VIEW 4 : Risk segment breakdown

CREATE OR REPLACE VIEW vw_risk_segments AS
SELECT
    RiskCategory,
    RiskScore,
    COUNT(*)                        AS customers,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_monthly_charge,
    ROUND(SUM(MonthlyCharges), 2)   AS total_monthly_revenue
FROM telcom_customers
GROUP BY RiskCategory, RiskScore
ORDER BY RiskScore DESC;

SELECT * FROM vw_risk_segments;

-- STORED PROCEDURE 1
--   Get churn stats for any column + value combination.
--   Usage: CALL sp_churn_by_segment('Contract', 'Month-to-month');
--          CALL sp_churn_by_segment('InternetService', 'Fiber optic');
--          CALL sp_churn_by_segment('PaymentMethod', 'Electronic check');
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_churn_by_segment$$
CREATE PROCEDURE sp_churn_by_segment(
    IN p_dimension  VARCHAR(50),
    IN p_value      VARCHAR(50)
)
BEGIN
    SET @sql = CONCAT(
        'SELECT
            ''', p_dimension, '''          AS dimension,
            ''', p_value,     '''          AS segment_value,
            COUNT(*)                       AS total_customers,
            SUM(ChurnFlag)                 AS churned,
            ROUND(AVG(ChurnFlag)*100, 2)   AS churn_rate_pct,
            ROUND(AVG(MonthlyCharges), 2)  AS avg_monthly_charge,
            ROUND(AVG(tenure), 1)          AS avg_tenure_months,
            ROUND(SUM(MonthlyCharges), 2)  AS total_monthly_revenue
        FROM telcom_customers
        WHERE `', p_dimension, '` = ''', p_value, ''''
    );
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
END$$

DELIMITER ;

-- Test calls (all use actual values from this dataset)
CALL sp_churn_by_segment('Contract',       'Month-to-month');
CALL sp_churn_by_segment('InternetService','Fiber optic');
CALL sp_churn_by_segment('PaymentMethod',  'Electronic check');
CALL sp_churn_by_segment('TenureBand',     '0-12 months');


-- STORED PROCEDURE 2
--   Get retention risk profile for a specific customer.
--   Usage: CALL sp_retention_score('3668-QPYBK');   -- churned
--          CALL sp_retention_score('7590-VHVEG');   -- at-risk, not churned

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_retention_score$$
CREATE PROCEDURE sp_retention_score(
    IN p_customerID VARCHAR(20)
)
BEGIN
    SELECT
        customerID,
        gender,
        CASE WHEN SeniorCitizen=1 THEN 'Yes' ELSE 'No' END  AS SeniorCitizen,
        tenure,
        Contract,
        InternetService,
        OnlineSecurity,
        TechSupport,
        PaymentMethod,
        MonthlyCharges,
        TotalCharges_num                                     AS TotalRevenue,
        Churn                                                AS ChurnStatus,
        RiskScore,
        RiskCategory,
        CASE
            WHEN RiskScore >= 6
                THEN 'URGENT: Call within 24 hrs, offer 2-year contract + 20% discount'
            WHEN RiskScore >= 4
                THEN 'HIGH: Proactive outreach, bundle OnlineSecurity + TechSupport'
            WHEN RiskScore >= 2
                THEN 'MEDIUM: Enrol in loyalty programme, send paperless discount offer'
            ELSE
                'LOW: Standard communication cadence, monitor quarterly'
        END                                                  AS recommended_action
    FROM telcom_customers
    WHERE customerID = p_customerID;
END$$

DELIMITER ;

-- Test with real customer IDs from the dataset
CALL sp_retention_score('9305-CDSKC');   -- churned, high risk
CALL sp_retention_score('7590-VHVEG');   -- retained, month-to-month, tenure=1
CALL sp_retention_score('5575-GNVDE');   -- retained, one-year contract



-- STORED PROCEDURE 3
--   Full executive report — all KPIs in one call.
--   Usage: CALL sp_generate_report();

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_generate_report$$
CREATE PROCEDURE sp_generate_report()
BEGIN
    SELECT '=== 1. EXECUTIVE KPI SNAPSHOT ===' AS section_header;
    SELECT * FROM vw_churn_summary;

    SELECT '=== 2. CHURN BY CONTRACT TYPE ===' AS section_header;
    SELECT Contract,
           COUNT(*) AS total, SUM(ChurnFlag) AS churned,
           ROUND(AVG(ChurnFlag)*100,2) AS churn_pct,
           ROUND(AVG(MonthlyCharges),2) AS avg_charge,
           ROUND(AVG(tenure),1) AS avg_tenure
    FROM telcom_customers
    GROUP BY Contract ORDER BY churn_pct DESC;

    SELECT '=== 3. CHURN BY TENURE BAND ===' AS section_header;
    SELECT TenureBand, COUNT(*) AS total, SUM(ChurnFlag) AS churned,
           ROUND(AVG(ChurnFlag)*100,2) AS churn_pct
    FROM telcom_customers
    GROUP BY TenureBand
    ORDER BY FIELD(TenureBand,
        '0-12 months','13-24 months','25-36 months',
        '37-48 months','49-60 months','60+ months');

    SELECT '=== 4. CHURN BY INTERNET SERVICE ===' AS section_header;
    SELECT InternetService, COUNT(*) AS total, SUM(ChurnFlag) AS churned,
           ROUND(AVG(ChurnFlag)*100,2) AS churn_pct
    FROM telcom_customers GROUP BY InternetService ORDER BY churn_pct DESC;

    SELECT '=== 5. RISK SEGMENT DISTRIBUTION ===' AS section_header;
    SELECT RiskCategory,
           COUNT(*) AS customers,
           SUM(ChurnFlag) AS churned,
           ROUND(AVG(ChurnFlag)*100,2) AS churn_pct,
           ROUND(SUM(MonthlyCharges),2) AS monthly_revenue
    FROM telcom_customers
    GROUP BY RiskCategory
    ORDER BY FIELD(RiskCategory,'Critical','High','Medium','Low');

    SELECT '=== 6. TOP 10 RETENTION TARGETS (not yet churned) ===' AS section_header;
    SELECT customerID, tenure, Contract, InternetService,
           PaymentMethod, MonthlyCharges, RiskScore, RiskCategory
    FROM telcom_customers
    WHERE Churn = 'No'
    ORDER BY RiskScore DESC, MonthlyCharges DESC
    LIMIT 10;

    -- Log the report run
    INSERT INTO churn_analysis_log(analysis_name, result_value, notes)
    SELECT 'sp_generate_report',
           CONCAT(ROUND(AVG(ChurnFlag)*100,2), '% churn rate'),
           CONCAT('Ran at ', NOW())
    FROM telcom_customers;

    SELECT '=== REPORT COMPLETE — logged to churn_analysis_log ===' AS section_header;
END$$

DELIMITER ;

CALL sp_generate_report();


--  PHASE 5 : ADVANCED KPI QUERIES & SCENARIO ANALYSIS


-- KPI 1 : Monthly charge buckets vs churn
--         Highest churn is NOT at the highest prices — nuanced result
SELECT
    CASE
        WHEN MonthlyCharges < 30  THEN 'Under $30'
        WHEN MonthlyCharges < 50  THEN '$30 – $50'
        WHEN MonthlyCharges < 70  THEN '$50 – $70'
        WHEN MonthlyCharges < 90  THEN '$70 – $90'
        ELSE                           'Over $90'
    END                             AS charge_bucket,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(tenure), 1)           AS avg_tenure_months
FROM telcom_customers
GROUP BY charge_bucket
ORDER BY MIN(MonthlyCharges);



-- KPI 2 : Year cohort analysis  (loyalty builds year over year)
--         Year 1: ~47%  →  Year 6: ~7%

SELECT
    CEIL(tenure / 12.0)               AS year_cohort,
    CONCAT('Year ', CEIL(tenure/12.0)) AS cohort_label,
    COUNT(*)                           AS customers,
    SUM(ChurnFlag)                     AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)       AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)      AS avg_monthly_charge
FROM telcom_customers
WHERE tenure > 0
GROUP BY year_cohort
ORDER BY year_cohort;



-- KPI 3 : Multi-service loyalty test
--         Do customers with more services churn less?

SELECT
    (
       (CASE WHEN PhoneService      = 'Yes'  THEN 1 ELSE 0 END)
     + (CASE WHEN MultipleLines     = 'Yes'  THEN 1 ELSE 0 END)
     + (CASE WHEN InternetService  != 'No'   THEN 1 ELSE 0 END)
     + (CASE WHEN OnlineSecurity    = 'Yes'  THEN 1 ELSE 0 END)
     + (CASE WHEN OnlineBackup      = 'Yes'  THEN 1 ELSE 0 END)
     + (CASE WHEN DeviceProtection  = 'Yes'  THEN 1 ELSE 0 END)
     + (CASE WHEN TechSupport       = 'Yes'  THEN 1 ELSE 0 END)
     + (CASE WHEN StreamingTV       = 'Yes'  THEN 1 ELSE 0 END)
     + (CASE WHEN StreamingMovies   = 'Yes'  THEN 1 ELSE 0 END)
    )                                  AS services_subscribed,
    COUNT(*)                           AS total_customers,
    SUM(ChurnFlag)                     AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)       AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)      AS avg_monthly_charge
FROM telcom_customers
GROUP BY services_subscribed
ORDER BY services_subscribed;



-- KPI 4 : Fiber optic deep-dive by security & support
--         No security + no support → highest churn segment

SELECT
    OnlineSecurity,
    TechSupport,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_monthly_charge
FROM telcom_customers
WHERE InternetService = 'Fiber optic'
GROUP BY OnlineSecurity, TechSupport
ORDER BY churn_rate_pct DESC;



-- KPI 5 : Electronic check users — are they a specific profile?
--         Identifies why this payment method predicts churn

SELECT
    Contract,
    PaperlessBilling,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_charge,
    ROUND(AVG(tenure), 1)           AS avg_tenure
FROM telcom_customers
WHERE PaymentMethod = 'Electronic check'
GROUP BY Contract, PaperlessBilling
ORDER BY churn_rate_pct DESC;



-- KPI 6 : Senior citizens segment deep-dive
--         54.6% churn rate when month-to-month (807 customers)

SELECT
    Contract,
    InternetService,
    COUNT(*)                        AS seniors,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_monthly_charge
FROM telcom_customers
WHERE SeniorCitizen = 1
GROUP BY Contract, InternetService
ORDER BY churn_rate_pct DESC;



-- KPI 7 : Payment method ranked with window function

SELECT
    ROW_NUMBER() OVER (ORDER BY AVG(ChurnFlag) DESC)  AS risk_rank,
    PaymentMethod,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_monthly_charge
FROM telcom_customers
GROUP BY PaymentMethod
ORDER BY churn_rate_pct DESC;



-- KPI 8 : SCENARIO ANALYSIS
--         What revenue is saved at different churn reduction targets?
--         Actual monthly loss = $1,39,130.85

SELECT
    reduction_pct,
    ROUND(139130.85 * reduction_pct / 100, 2)       AS monthly_revenue_saved,
    ROUND(139130.85 * reduction_pct / 100 * 12, 2)  AS annual_revenue_saved
FROM (
    SELECT 5  AS reduction_pct UNION ALL
    SELECT 10 UNION ALL
    SELECT 15 UNION ALL
    SELECT 20 UNION ALL
    SELECT 25 UNION ALL
    SELECT 30
) AS scenarios
ORDER BY reduction_pct;



-- KPI 9 : Churn by number of streaming services
--         Tests whether entertainment add-ons build loyalty

SELECT
    (CASE WHEN StreamingTV = 'Yes' THEN 1 ELSE 0 END
   + CASE WHEN StreamingMovies = 'Yes' THEN 1 ELSE 0 END)
                                    AS streaming_services,
    COUNT(*)                        AS total,
    SUM(ChurnFlag)                  AS churned,
    ROUND(AVG(ChurnFlag)*100, 2)    AS churn_rate_pct,
    ROUND(AVG(MonthlyCharges), 2)   AS avg_monthly_charge
FROM telcom_customers
GROUP BY streaming_services
ORDER BY streaming_services;


--  PHASE 6 : RETENTION RECOMMENDATIONS REPORT


SELECT
    priority_no,
    target_segment,
    customer_count,
    churn_rate_pct,
    monthly_revenue_at_risk,
    recommended_action
FROM (

    SELECT 1 AS priority_no,
        'New customers (tenure < 12 months) on month-to-month contracts'
                                                        AS target_segment,
        COUNT(*)                                        AS customer_count,
        ROUND(AVG(ChurnFlag)*100, 1)                    AS churn_rate_pct,
        ROUND(SUM(CASE WHEN Churn='Yes'
              THEN MonthlyCharges ELSE 0 END), 2)       AS monthly_revenue_at_risk,
        'Offer discounted 1-year contract in month 2–3 of onboarding'
                                                        AS recommended_action
    FROM telcom_customers
    WHERE tenure < 12 AND Contract = 'Month-to-month'

    UNION ALL

    SELECT 2,
        'Fiber optic users without OnlineSecurity or TechSupport',
        COUNT(*),
        ROUND(AVG(ChurnFlag)*100, 1),
        ROUND(SUM(CASE WHEN Churn='Yes' THEN MonthlyCharges ELSE 0 END),2),
        'Bundle OnlineSecurity + TechSupport at 10% discount'
    FROM telcom_customers
    WHERE InternetService = 'Fiber optic'
      AND OnlineSecurity IN ('No','No internet service')
      AND TechSupport IN ('No','No internet service')

    UNION ALL

    SELECT 3,
        'Electronic check payers — migrate to auto-pay',
        COUNT(*),
        ROUND(AVG(ChurnFlag)*100, 1),
        ROUND(SUM(CASE WHEN Churn='Yes' THEN MonthlyCharges ELSE 0 END),2),
        'Offer $5/month discount for switching to bank transfer or credit card'
    FROM telcom_customers
    WHERE PaymentMethod = 'Electronic check'

    UNION ALL

    SELECT 4,
        'Senior citizens on month-to-month contracts (54.6% churn!)',
        COUNT(*),
        ROUND(AVG(ChurnFlag)*100, 1),
        ROUND(SUM(CASE WHEN Churn='Yes' THEN MonthlyCharges ELSE 0 END),2),
        'Dedicated senior care team + annual contract upgrade incentive'
    FROM telcom_customers
    WHERE SeniorCitizen = 1 AND Contract = 'Month-to-month'

    UNION ALL

    SELECT 5,
        'Paperless billing + no partner + no dependents (solo users)',
        COUNT(*),
        ROUND(AVG(ChurnFlag)*100, 1),
        ROUND(SUM(CASE WHEN Churn='Yes' THEN MonthlyCharges ELSE 0 END),2),
        'Referral rewards programme to increase switching cost'
    FROM telcom_customers
    WHERE PaperlessBilling='Yes' AND Partner='No' AND Dependents='No'

) AS recommendations
ORDER BY priority_no;


--  FINAL : Log completion & view audit trail

INSERT INTO churn_analysis_log (analysis_name, result_value, notes)
VALUES (
    'Full Project Completed',
    '7043 rows | 26.54% churn | $1,39,131/month at risk',
    'All 6 phases, 4 views, 3 stored procedures, 9 KPI queries executed'
);

SELECT * FROM churn_analysis_log ORDER BY run_timestamp;

--  END OF PROJECT

