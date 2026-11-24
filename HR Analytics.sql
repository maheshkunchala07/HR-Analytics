-- =====================================================================
--  HR ATTRITION PROJECT - SQL VERSION
--  Same project as the Excel dashboard: data prep -> KPIs -> 7 charts
--  -> slicer filters -> business questions with answers.
--  Written in standard SQL: runs on MySQL 8+, PostgreSQL and SQLite.
--  (SQL Server: replace LIMIT with TOP, and use "ALTER TABLE ... ADD col".)
--  The "-- Result:" lines under each query are the real answers from the
--  1,470-row data, so you can check your own output against them.
-- =====================================================================

-- PART 0 - FILES
--   hr_data.csv = the cleaned Excel data (21 useful columns, snake_case names).
--   The junk columns of the Excel file were already dropped:
--   Over18, Employee Count, Standard Hours, "-2", "0", CF_ helper columns.

-- PART 1 - CREATE THE TABLE AND IMPORT THE DATA
-- (MySQL: use a database first ->  CREATE DATABASE hr_project; USE hr_project;)

CREATE TABLE hr_data (
    employee_id                INT PRIMARY KEY,
    attrition                  VARCHAR(3),
    age                        INT,
    age_band                   VARCHAR(10),
    business_travel            VARCHAR(20),
    department                 VARCHAR(30),
    education                  VARCHAR(30),
    education_field            VARCHAR(30),
    gender                     VARCHAR(10),
    job_role                   VARCHAR(40),
    job_level                  INT,
    job_satisfaction           INT,
    marital_status             VARCHAR(15),
    monthly_income             INT,
    over_time                  VARCHAR(3),
    performance_rating         INT,
    work_life_balance          INT,
    years_at_company           INT,
    years_since_last_promotion INT,
    distance_from_home         INT,
    environment_satisfaction   INT
);

-- Import hr_data.csv (choose ONE way):
--   MySQL Workbench : right-click table hr_data > Table Data Import Wizard > pick hr_data.csv
--   MySQL command   : LOAD DATA LOCAL INFILE 'C:/path/hr_data.csv' INTO TABLE hr_data
--                     FIELDS TERMINATED BY ',' IGNORE 1 LINES;
--   PostgreSQL      : \copy hr_data FROM 'hr_data.csv' CSV HEADER
--   SQL Server      : right-click database > Tasks > Import Flat File
-- After import, run PART 2 first.



-- =====================================================================
-- PART 2 - DATA CLEANING CHECKS (run these before analysis)
-- =====================================================================

-- C1. How many rows are in the table? (expected: 1470)
SELECT COUNT(*) AS total_rows FROM hr_data;
-- Result:
-- total_rows
-- 1470

-- C2. Any duplicate employee IDs? (no rows = no duplicates)
SELECT employee_id, COUNT(*) AS times
FROM hr_data
GROUP BY employee_id
HAVING COUNT(*) > 1;
-- Result:
-- employee_id | times
-- (no rows)

-- C3. Any missing (NULL) values in key columns? (0 = none)
SELECT COUNT(*) - COUNT(attrition)      AS null_attrition,
       COUNT(*) - COUNT(department)     AS null_department,
       COUNT(*) - COUNT(job_role)       AS null_job_role,
       COUNT(*) - COUNT(monthly_income) AS null_income,
       COUNT(*) - COUNT(over_time)      AS null_overtime
FROM hr_data;
-- Result:
-- null_attrition | null_department | null_job_role | null_income | null_overtime
-- 0 | 0 | 0 | 0 | 0

-- C4. Are the text values clean? (only Yes / No expected)
SELECT attrition, COUNT(*) AS employees
FROM hr_data
GROUP BY attrition;
-- Result:
-- attrition | employees
-- No | 1233
-- Yes | 237

-- C5. Are numbers in a sensible range?
SELECT MIN(age) AS min_age, MAX(age) AS max_age,
       MIN(monthly_income) AS min_income, MAX(monthly_income) AS max_income,
       MIN(years_at_company) AS min_tenure, MAX(years_at_company) AS max_tenure
FROM hr_data;
-- Result:
-- min_age | max_age | min_income | max_income | min_tenure | max_tenure
-- 18 | 60 | 1009 | 19999 | 0 | 40


-- =====================================================================
-- PART 3 - CHANGES WE MAKE (same as Excel helper columns)
--   Excel: Attrition Flag  =IF([@Attrition]="Yes",1,0)  and  Years Group
--   SQL  : add 2 new columns, then fill them with UPDATE.
-- MySQL note: if you get "safe update mode" error, run  SET SQL_SAFE_UPDATES = 0;
-- =====================================================================

ALTER TABLE hr_data ADD COLUMN attrition_flag INT;
ALTER TABLE hr_data ADD COLUMN years_group VARCHAR(10);

UPDATE hr_data
SET attrition_flag = CASE WHEN attrition = 'Yes' THEN 1 ELSE 0 END
WHERE employee_id > 0;

UPDATE hr_data
SET years_group = CASE
        WHEN years_at_company <= 1  THEN '0-1'
        WHEN years_at_company <= 3  THEN '2-3'
        WHEN years_at_company <= 5  THEN '4-5'
        WHEN years_at_company <= 10 THEN '6-10'
        ELSE '10+' END
WHERE employee_id > 0;


-- =====================================================================
-- PART 4 - CHECK THE NEW COLUMNS
-- =====================================================================

-- D1. Leavers must be 237 and tenure groups must match Excel.
SELECT SUM(attrition_flag) AS leavers FROM hr_data;
-- Result:
-- leavers
-- 237

-- D2. Employees per tenure group (Years Group).
SELECT years_group, COUNT(*) AS employees
FROM hr_data
GROUP BY years_group
ORDER BY CASE years_group WHEN '0-1' THEN 1 WHEN '2-3' THEN 2 WHEN '4-5' THEN 3 WHEN '6-10' THEN 4 ELSE 5 END;
-- Result:
-- years_group | employees
-- 0-1 | 215
-- 2-3 | 255
-- 4-5 | 306
-- 6-10 | 448
-- 10+ | 246


-- =====================================================================
-- PART 5 - THE 5 KPIs
-- =====================================================================

-- K1. All 5 KPIs in one row (same as the 5 Excel KPI cards).
SELECT COUNT(*)                               AS total_headcount,
       SUM(attrition_flag)                    AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct,
       ROUND(AVG(monthly_income), 0)          AS avg_monthly_income,
       ROUND(AVG(years_at_company), 1)        AS avg_tenure_years,
       ROUND(AVG(job_satisfaction), 2)        AS avg_job_satisfaction
FROM hr_data;
-- Result:
-- total_headcount | leavers | attrition_rate_pct | avg_monthly_income | avg_tenure_years | avg_job_satisfaction
-- 1470 | 237 | 16.1 | 6503.0 | 7.0 | 2.63


-- =====================================================================
-- PART 6 - THE 7 CHARTS (one query = one chart)
-- =====================================================================

-- CHART 1. Attrition rate by department
SELECT department                    AS department,
       COUNT(*)                 AS headcount,
       SUM(attrition_flag)      AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY department
ORDER BY attrition_rate_pct DESC;
-- Result:
-- department | headcount | leavers | attrition_rate_pct
-- Sales | 446 | 92 | 20.6
-- HR | 63 | 12 | 19.0
-- R&D | 961 | 133 | 13.8

-- CHART 2. Attrition rate by job role (highest first)
SELECT job_role                    AS job_role,
       COUNT(*)                 AS headcount,
       SUM(attrition_flag)      AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY job_role
ORDER BY attrition_rate_pct DESC;
-- Result:
-- job_role | headcount | leavers | attrition_rate_pct
-- Sales Representative | 83 | 33 | 39.8
-- Laboratory Technician | 259 | 62 | 23.9
-- Human Resources | 52 | 12 | 23.1
-- Sales Executive | 326 | 57 | 17.5
-- Research Scientist | 292 | 47 | 16.1
-- Manufacturing Director | 145 | 10 | 6.9
-- Healthcare Representative | 131 | 9 | 6.9
-- Manager | 102 | 5 | 4.9
-- Research Director | 80 | 2 | 2.5

-- CHART 3. Attrition rate by age band
SELECT age_band                    AS age_band,
       COUNT(*)                 AS headcount,
       SUM(attrition_flag)      AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY age_band
ORDER BY CASE age_band WHEN 'Under 25' THEN 1 WHEN '25 - 34' THEN 2 WHEN '35 - 44' THEN 3 WHEN '45 - 54' THEN 4 ELSE 5 END;
-- Result:
-- age_band | headcount | leavers | attrition_rate_pct
-- Under 25 | 97 | 38 | 39.2
-- 25 - 34 | 554 | 112 | 20.2
-- 35 - 44 | 505 | 51 | 10.1
-- 45 - 54 | 245 | 25 | 10.2
-- Over 55 | 69 | 11 | 15.9

-- CHART 4. Attrition rate by education field
SELECT education_field                    AS education_field,
       COUNT(*)                 AS headcount,
       SUM(attrition_flag)      AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY education_field
ORDER BY attrition_rate_pct DESC;
-- Result:
-- education_field | headcount | leavers | attrition_rate_pct
-- Human Resources | 27 | 7 | 25.9
-- Technical Degree | 132 | 32 | 24.2
-- Marketing | 159 | 35 | 22.0
-- Life Sciences | 606 | 89 | 14.7
-- Medical | 464 | 63 | 13.6
-- Other | 82 | 11 | 13.4

-- CHART 5. Average monthly income by job level: stayed vs left
SELECT job_level,
       ROUND(AVG(CASE WHEN attrition = 'No'  THEN monthly_income END), 0) AS avg_income_stayed,
       ROUND(AVG(CASE WHEN attrition = 'Yes' THEN monthly_income END), 0) AS avg_income_left
FROM hr_data
GROUP BY job_level
ORDER BY job_level;
-- Result:
-- job_level | avg_income_stayed | avg_income_left
-- 1 | 2854.0 | 2598.0
-- 2 | 5474.0 | 5760.0
-- 3 | 9891.0 | 9388.0
-- 4 | 15620.0 | 13150.0
-- 5 | 19171.0 | 19464.0

-- CHART 6. Leavers and attrition rate by years at company
SELECT years_group                    AS years_group,
       COUNT(*)                 AS headcount,
       SUM(attrition_flag)      AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY years_group
ORDER BY CASE years_group WHEN '0-1' THEN 1 WHEN '2-3' THEN 2 WHEN '4-5' THEN 3 WHEN '6-10' THEN 4 ELSE 5 END;
-- Result:
-- years_group | headcount | leavers | attrition_rate_pct
-- 0-1 | 215 | 75 | 34.9
-- 2-3 | 255 | 47 | 18.4
-- 4-5 | 306 | 40 | 13.1
-- 6-10 | 448 | 55 | 12.3
-- 10+ | 246 | 20 | 8.1

-- CHART 7. Workforce by gender
SELECT gender,
       COUNT(*) AS headcount,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM hr_data
GROUP BY gender;
-- Result:
-- gender | headcount | share_pct
-- Female | 588 | 40.0
-- Male | 882 | 60.0


-- =====================================================================
-- PART 7 - SLICER = WHERE  (a slicer click is just a filter)
-- =====================================================================

-- S1. Slicer "Department = Sales": KPIs for Sales only.
SELECT COUNT(*) AS headcount,
       SUM(attrition_flag) AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct,
       ROUND(AVG(monthly_income), 0) AS avg_income
FROM hr_data
WHERE department = 'Sales';
-- Result:
-- headcount | leavers | attrition_rate_pct | avg_income
-- 446 | 92 | 20.6 | 6959.0

-- S2. Two slicers together: Over Time = Yes AND Gender = Female.
SELECT COUNT(*) AS headcount,
       SUM(attrition_flag) AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
WHERE over_time = 'Yes' AND gender = 'Female';
-- Result:
-- headcount | leavers | attrition_rate_pct
-- 180 | 47 | 26.1


-- =====================================================================
-- PART 8 - BUSINESS QUESTIONS AND ANSWERS
-- =====================================================================

-- B1. Does overtime increase attrition?
SELECT over_time                    AS over_time,
       COUNT(*)                 AS headcount,
       SUM(attrition_flag)      AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY over_time
ORDER BY attrition_rate_pct DESC;
-- Result:
-- over_time | headcount | leavers | attrition_rate_pct
-- Yes | 416 | 127 | 30.5
-- No | 1054 | 110 | 10.4

-- B2. How does business travel affect attrition?
SELECT business_travel                    AS business_travel,
       COUNT(*)                 AS headcount,
       SUM(attrition_flag)      AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY business_travel
ORDER BY attrition_rate_pct DESC;
-- Result:
-- business_travel | headcount | leavers | attrition_rate_pct
-- Travel_Frequently | 277 | 69 | 24.9
-- Travel_Rarely | 1043 | 156 | 15.0
-- Non-Travel | 150 | 12 | 8.0

-- B3. Which marital status leaves the most?
SELECT marital_status                    AS marital_status,
       COUNT(*)                 AS headcount,
       SUM(attrition_flag)      AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY marital_status
ORDER BY attrition_rate_pct DESC;
-- Result:
-- marital_status | headcount | leavers | attrition_rate_pct
-- Single | 470 | 120 | 25.5
-- Married | 673 | 84 | 12.5
-- Divorced | 327 | 33 | 10.1

-- B4. Does low job satisfaction mean more leavers? (1 = low, 4 = high)
SELECT job_satisfaction                    AS job_satisfaction,
       COUNT(*)                 AS headcount,
       SUM(attrition_flag)      AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY job_satisfaction
ORDER BY job_satisfaction;
-- Result:
-- job_satisfaction | headcount | leavers | attrition_rate_pct
-- 1 | 280 | 65 | 23.2
-- 2 | 374 | 54 | 14.4
-- 3 | 431 | 62 | 14.4
-- 4 | 385 | 56 | 14.5

-- B5. Does work-life balance matter? (1 = bad, 4 = best)
SELECT work_life_balance                    AS work_life_balance,
       COUNT(*)                 AS headcount,
       SUM(attrition_flag)      AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY work_life_balance
ORDER BY work_life_balance;
-- Result:
-- work_life_balance | headcount | leavers | attrition_rate_pct
-- 1 | 80 | 25 | 31.3
-- 2 | 344 | 58 | 16.9
-- 3 | 893 | 127 | 14.2
-- 4 | 153 | 27 | 17.6

-- B6. Which job roles are ABOVE the company average attrition?
SELECT job_role,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY job_role
HAVING 100.0 * SUM(attrition_flag) / COUNT(*) >
       (SELECT 100.0 * SUM(attrition_flag) / COUNT(*) FROM hr_data)
ORDER BY attrition_rate_pct DESC;
-- Result:
-- job_role | attrition_rate_pct
-- Sales Representative | 39.8
-- Laboratory Technician | 23.9
-- Human Resources | 23.1
-- Sales Executive | 17.5

-- B7. Do leavers earn less than stayers? (overall)
SELECT attrition,
       COUNT(*) AS employees,
       ROUND(AVG(monthly_income), 0) AS avg_income,
       ROUND(AVG(years_at_company), 1) AS avg_tenure
FROM hr_data
GROUP BY attrition;
-- Result:
-- attrition | employees | avg_income | avg_tenure
-- No | 1233 | 6833.0 | 7.4
-- Yes | 237 | 4787.0 | 5.1

-- B8. Attrition by income band
SELECT CASE WHEN monthly_income < 3000  THEN '1. Below 3k'
            WHEN monthly_income < 6000  THEN '2. 3k - 6k'
            WHEN monthly_income < 10000 THEN '3. 6k - 10k'
            ELSE '4. 10k and above' END AS income_band,
       COUNT(*) AS headcount,
       SUM(attrition_flag) AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY 1
ORDER BY 1;
-- Result:
-- income_band | headcount | leavers | attrition_rate_pct
-- 1. Below 3k | 395 | 113 | 28.6
-- 2. 3k - 6k | 519 | 66 | 12.7
-- 3. 6k - 10k | 275 | 33 | 12.0
-- 4. 10k and above | 281 | 25 | 8.9

-- B9. Highest-risk group: Under 25 AND working overtime.
SELECT COUNT(*) AS headcount,
       SUM(attrition_flag) AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
WHERE age_band = 'Under 25' AND over_time = 'Yes';
-- Result:
-- headcount | leavers | attrition_rate_pct
-- 31 | 21 | 67.7

-- B10. Rank job roles by attrition rate (window function RANK).
SELECT job_role,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct,
       RANK() OVER (ORDER BY 100.0 * SUM(attrition_flag) / COUNT(*) DESC) AS risk_rank
FROM hr_data
GROUP BY job_role
ORDER BY risk_rank;
-- Result:
-- job_role | attrition_rate_pct | risk_rank
-- Sales Representative | 39.8 | 1
-- Laboratory Technician | 23.9 | 2
-- Human Resources | 23.1 | 3
-- Sales Executive | 17.5 | 4
-- Research Scientist | 16.1 | 5
-- Manufacturing Director | 6.9 | 6
-- Healthcare Representative | 6.9 | 7
-- Manager | 4.9 | 8
-- Research Director | 2.5 | 9

-- B11. Which department contributes the most leavers? (share of all 237)
SELECT department,
       SUM(attrition_flag) AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / SUM(SUM(attrition_flag)) OVER (), 1) AS share_of_all_leavers_pct
FROM hr_data
GROUP BY department
ORDER BY leavers DESC;
-- Result:
-- department | leavers | share_of_all_leavers_pct
-- R&D | 133 | 56.1
-- Sales | 92 | 38.8
-- HR | 12 | 5.1

-- B12. Department x overtime: where is the problem biggest?
SELECT department, over_time,
       COUNT(*) AS headcount,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY department, over_time
ORDER BY attrition_rate_pct DESC;
-- Result:
-- department | over_time | headcount | attrition_rate_pct
-- Sales | Yes | 128 | 37.5
-- HR | Yes | 17 | 29.4
-- R&D | Yes | 271 | 27.3
-- HR | No | 46 | 15.2
-- Sales | No | 318 | 13.8
-- R&D | No | 690 | 8.6

-- B13. Are promotions slow for leavers? (avg years since last promotion)
SELECT attrition,
       ROUND(AVG(years_since_last_promotion), 2) AS avg_years_since_promotion
FROM hr_data
GROUP BY attrition;
-- Result:
-- attrition | avg_years_since_promotion
-- No | 2.23
-- Yes | 1.95


-- =====================================================================
-- PART 9 - OPTIONAL: SAVE THE DASHBOARD DATA AS A VIEW (reusable in Power BI / Tableau)
-- =====================================================================
CREATE VIEW v_attrition_by_department AS
SELECT department,
       COUNT(*) AS headcount,
       SUM(attrition_flag) AS leavers,
       ROUND(100.0 * SUM(attrition_flag) / COUNT(*), 1) AS attrition_rate_pct
FROM hr_data
GROUP BY department;

-- SELECT * FROM v_attrition_by_department;
