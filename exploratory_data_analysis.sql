-- Connect to database (MySQL only)
USE hospital_db;

-- OBJECTIVE 1: ENCOUNTERS OVERVIEW

-- a. How many total encounters occurred each year?
SELECT 
	YEAR(start) AS year
    ,COUNT(*) AS total_encounters
FROM encounters
GROUP BY year
ORDER BY year;

-- b. For each year, what percentage of all encounters belonged to each encounter class
-- (ambulatory, outpatient, wellness, urgent care, emergency, and inpatient)?
WITH total_encounters AS (
	-- This CTE gets the total encounters by encounter_class and year
    SELECT 
		encounter_class,
		YEAR(start) AS year,
		COUNT(*) as total_by_encounters
	FROM encounters
	GROUP BY year, encounter_class
)
SELECT
	encounter_class,
    year,
    ROUND((total_by_encounters / SUM(total_by_encounters) OVER(PARTITION BY year) * 100), 2) AS percentage_of_total
FROM total_encounters
GROUP BY encounter_class, year
ORDER BY year;

-- c. What percentage of encounters were over 24 hours versus under 24 hours?
SELECT
	COUNT(CASE WHEN (timestampdiff(minute, start, stop) / 60) > 24 THEN 1 END) AS over_24,
    (COUNT(CASE WHEN (timestampdiff(minute, start, stop) / 60) > 24 THEN 1 END) / COUNT(*)) * 100 AS over_24_pct,
    COUNT(CASE WHEN (timestampdiff(minute, start, stop) / 60) < 24 THEN 1 END) AS under_24,
    (COUNT(CASE WHEN (timestampdiff(minute, start, stop) / 60) < 24 THEN 1 END) / COUNT(*)) * 100 AS under_24_pct
FROM encounters;

-- OBJECTIVE 2: COST & COVERAGE INSIGHTS

-- a. How many encounters had zero payer coverage, and what percentage of total encounters does this represent?
SELECT 
    COUNT(*) AS total_encounters,
    (SELECT 
		COUNT(e.id)
	FROM encounters e
	JOIN payers p 
		ON e.payer = p.id
	WHERE p.name = 'NO_INSURANCE') AS no_insurance,
    (SELECT 
		COUNT(e.id)
	FROM encounters e
	JOIN payers p 
		ON e.payer = p.id
	WHERE p.name = 'NO_INSURANCE') / COUNT(*) * 100 AS no_insurance_pct
FROM
    encounters;
-- 8807 had no insurance, which represents 31.58 percent of encounters

-- b. What are the top 10 most frequent procedures performed and the average base cost for each?
SELECT 
	code,
    description,
    COUNT(*) AS number_of_procedures,
    AVG(base_cost) AS avg_base_cost
FROM procedures
GROUP BY code, description
ORDER BY number_of_procedures DESC
LIMIT 10;

-- c. What are the top 10 procedures with the highest average base cost and the number of times they were performed?
SELECT 
	code,
    description,
    COUNT(*) as number_of_procedures,
    ROUND(AVG(base_cost), 0) AS avg_base_cost
FROM procedures
GROUP BY code, description
ORDER BY avg_base_cost DESC
LIMIT 10;   

-- d. What is the average total claim cost for encounters, broken down by payer?
SELECT 
	p.name,
	AVG(total_claim_cost) AS avg_total_claim_cost
FROM encounters e
JOIN payers p 
	ON e.payer = p.id
GROUP BY p.name
ORDER BY avg_total_claim_cost DESC;

-- OBJECTIVE 3: PATIENT BEHAVIOR ANALYSIS

-- a. How many unique patients were admitted each quarter over time?

SELECT 
    QUARTER(Start) AS qtr,
    COUNT(DISTINCT patient) as admitted_patients
FROM encounters
GROUP BY qtr;

-- b. How many patients were readmitted within 30 days of a previous encounter?
SELECT 
    COUNT(DISTINCT p1.patient) AS patients_with_multiple_visits
FROM encounters p1
JOIN encounters p2 
	ON p1.patient = p2.patient
WHERE p1.start < p2.start -- Ensure we're comparing a previous visit to a later visit
AND p2.start <= DATE_ADD(p1.stop, INTERVAL 30 DAY); -- MySQL syntax for date addition

-- c. Which patients had the most readmissions?
SELECT
	patient,
    COUNT(id) AS visits
FROM encounters
GROUP BY patient
ORDER BY visits DESC;

-- OBJECTIVE 4: PATIENT DEMOGRAPHICS
-- a. What's the average age of each patient?
SELECT
	ROUND((AVG(datediff(NOW(), birthdate)) / 365),2) AS avg_age
FROM patients;

-- b. What is the percentage of men vs women?
SELECT * FROM encounters;

SELECT 
    e.encounter_class,
    ROUND((COUNT(CASE WHEN p.gender = 'M' THEN 1 END) / COUNT(e.id)) * 100, 2) AS pct_males,
    ROUND((COUNT(CASE WHEN p.gender = 'F' THEN 1 END) / COUNT(e.id)) * 100, 2) AS pct_females
FROM encounters e
JOIN patients p
	ON e.patient = p.id
GROUP BY e.encounter_class;

-- c. Average stay length of each patient
SELECT 
	ROUND(AVG(TIMESTAMPDIFF(hour, start, stop)),2) AS avg_stay_length
FROM encounters;