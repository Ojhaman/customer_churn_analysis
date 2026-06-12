# Customer Churn Analysis

## Project Overview
This project analyzes customer data to identify patterns behind subscription cancellations (churn).  
The goal is to evaluate user activity, engagement levels, and behavioral trends to determine key factors that lead to churn and suggest improvements for retention.

---

## Dataset
- **Source:** https://www.kaggle.com/code/suprithahalesh/telecom-customer-churn/input 
- **Format:** CSV  
- **Columns:**
    customerID        VARCHAR(20)
    gender            VARCHAR(10)
    SeniorCitizen     TINYINT(1)          
    Partner           VARCHAR(5)          
    Dependents        VARCHAR(5)         
    tenure            INT                
    PhoneService      VARCHAR(5)          
    MultipleLines     VARCHAR(20)         
    InternetService   VARCHAR(20)       
    OnlineSecurity    VARCHAR(25)        
    OnlineBackup      VARCHAR(25)
    DeviceProtection  VARCHAR(25)
    TechSupport       VARCHAR(25)
    StreamingTV       VARCHAR(25)
    StreamingMovies   VARCHAR(25)
    Contract          VARCHAR(20)         
    PaperlessBilling  VARCHAR(5)          
    PaymentMethod     VARCHAR(40)         
    MonthlyCharges    DECIMAL(8,2)
    TotalCharges      VARCHAR(20)      
    Churn             VARCHAR(5)

##  Project Phases
### Phase 1: Database & Table Setup
- Created schema `churn_db` and table `telcom_customers`.  
- Added derived columns:
  - `ChurnFlag` (numeric churn indicator).  
  - `TotalCharges_num` (numeric conversion).  
  - `TenureBand` (segmented tenure ranges).  
- Created audit log table `churn_analysis_log`.

### Phase 2: Exploratory Data Analysis (EDA)
- Overall churn rate (~26.5%).  
- Churn by gender, senior citizen status, tenure, contract type, internet service, payment method.  
- Revenue impact of churn.  
- Add-on services vs churn.  
- Family anchors (partner/dependents) effect.  
- Paperless billing impact.

### Phase 3: Risk Segmentation
- Built a **RiskScore (0–8)** based on 7 churn drivers.  
- Classified customers into **Critical, High, Medium, Low** risk categories.  
- Generated top 20 highest-risk retained customers for proactive retention.

### Phase 4: Views & Stored Procedures
- **Views:**
  - `vw_churn_summary` → executive KPI snapshot.  
  - `vw_service_impact` → service subscription impact.  
  - `vw_contract_churn` → contract × tenure churn matrix.  
  - `vw_risk_segments` → risk segment breakdown.  
- **Stored Procedures:**
  - `sp_churn_by_segment` → churn stats for any dimension.  
  - `sp_retention_score` → risk profile + recommended action for a customer.  
  - `sp_generate_report` → full executive report with KPIs.

### Phase 5: Advanced KPI Queries & Scenario Analysis
- Monthly charge buckets vs churn.  
- Year cohort loyalty analysis.  
- Multi-service loyalty test.  
- Fiber optic deep-dive (security & support).  
- Electronic check payment risk profile.  
- Senior citizen churn analysis.  
- Payment method risk ranking (window functions).  
- Scenario analysis: revenue saved at churn reduction targets.  
- Streaming services impact on churn.

### Phase 6: Retention Recommendations
- Targeted strategies for high-risk segments:
  1. New customers (<12 months, month-to-month).  
  2. Fiber optic users without security/support.  
  3. Electronic check payers.  
  4. Senior citizens on month-to-month contracts.  
  5. Solo users (paperless billing, no partner, no dependents).  
- Logged completion in `churn_analysis_log`.

## Key Insights
- **Contract type** is the strongest churn predictor (month-to-month ~43% churn).  
- **Tenure** inversely correlates with churn (new customers churn more).  
- **Fiber optic users** churn more than DSL.  
- **Electronic check payment** is highly risky (~45% churn).  
- **Senior citizens** churn at ~42% vs ~24% for non-seniors.  
- **Add-on services** (security, backup, support) reduce churn significantly.  
- **Paperless billing solo users** are more vulnerable.
