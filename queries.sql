.mode column
.headers on
.timer on
.echo on


-- #1 USE CASE: a fresh economics graduate has to familiarize himself with the data base and it's contents

-- find out OECD base year (2015)
SELECT DISTINCT "reference_period"
FROM "frontend_data_records"
WHERE "measure" LIKE '%OECD base year%';

-- observe overlap between the scored values measured in current vs constant prices in the OECD base year
SELECT DISTINCT dr1."subject", dr1."year" as 'current prices year', dr2."year" as 'constant prices year', dr1."reference_period" as 'OECD base reference year', dr1."value" as 'current prices indicator', dr2."value" as 'constant prices indicator'
FROM "frontend_data_records" dr1
CROSS JOIN "frontend_data_records" dr2
WHERE dr1."measure" LIKE '%OECD base year%' AND dr1."measure" LIKE '%current prices%'
AND dr2."measure" LIKE '%OECD base year%' AND dr2."measure" LIKE '%constant prices%'
AND dr1."subject" = dr2."subject"
AND dr1."indicator" = dr2."indicator"
AND dr1."unit" = dr2."unit"
AND dr1."value" = dr2."value"
AND dr1."value" != 0 AND dr1."value" NOT NULL
GROUP BY dr1."subject";

-- the reason we find, is the deflator index used for the transformation of currenct prices into constant ones, for example the one used to deflate the GDP to 2015 prices, when the index is at 100
SELECT "subject", "indicator","year", "reference_period", "value"
FROM "frontend_data_records"
WHERE "measure" LIKE '%deflator%'
AND "subject" = 'Germany'
AND "indicator" LIKE '%Gross domestic product%'
ORDER BY "indicator", "year";

-- let's find out if the deflator used on the expenditure derived GDP is the same as the one used for the expenditure derived GDP
SELECT dr1."subject", 'Gross domestic product', dr1."year", dr1."reference_period", dr1."value" - dr2."value" AS 'difference between approaches'
FROM "frontend_data_records" dr1
JOIN "frontend_data_records" dr2 USING ("year")
WHERE dr1."measure" LIKE '%deflator%'
AND dr2."measure" LIKE '%deflator%'
AND dr1."subject" = 'Germany'
AND dr2."subject" = 'Germany'
AND dr1."indicator" = 'Gross domestic product (output approach)'
AND dr2."indicator" = 'Gross domestic product (expenditure approach)'
AND dr1."year" = dr2."year"
ORDER BY dr1."year";

-- even further, let's find out if the expenditure and output approaches of calculating the GDP produced the same results (same indicator values)
SELECT dr1."subject", 'Gross domestic product', dr1."unit", dr1."year", dr1."reference_period", dr1."value" - dr2."value" AS 'difference between approaches'
FROM "frontend_data_records" dr1
JOIN "frontend_data_records" dr2 USING ("year")
WHERE dr1."measure" = 'Constant prices, national base year'
AND dr1."measure" = dr2."measure"
AND dr1."unit" = dr2."unit"
AND dr1."subject" = 'Germany'
AND dr2."subject" = 'Germany'
AND dr1."indicator" = 'Gross domestic product (output approach)'
AND dr2."indicator" = 'Gross domestic product (expenditure approach)'
AND dr1."year" = dr2."year"
AND dr1."reference_period" = dr2."reference_period"
AND dr1."dataset" = dr2."dataset"
ORDER BY dr1."year";

-- let's speed up the last query by restricting our search to the dataset comprised of aggregate national accounts, gross domestic product to be precise (much faster)
SELECT dr1."subject", 'Gross domestic product', dr1."unit", dr1."year", dr1."reference_period", dr1."value" - dr2."value" AS 'difference between approaches', dr1."dataset"
FROM "frontend_dataset_id_2" dr1
JOIN "frontend_dataset_id_2" dr2 USING ("year")
WHERE dr1."measure" = 'Constant prices, national base year'
AND dr1."measure" = dr2."measure"
AND dr1."unit" = dr2."unit"
AND dr1."subject" = 'Germany'
AND dr2."subject" = 'Germany'
AND dr1."indicator" = 'Gross domestic product (output approach)'
AND dr2."indicator" = 'Gross domestic product (expenditure approach)'
AND dr1."year" = dr2."year"
AND dr1."reference_period" = dr2."reference_period"
AND dr1."dataset" = dr2."dataset"
ORDER BY dr1."year";


-- #2 USE CASE(S):

/* it is a well known, often made point that governments do a poor job of "spending other peoples money", paying for the public service more than the private sector would
(reasons are the lack of competition and handing out lucrative government contracts to private enterprises in exchange for bribes or donations for political campaign funding, a.k.a corruption/collusion) */
-- we want to find out how much higher the inflation in consumption expenditure of the government is, compared to that of households, for each year, in the US
SELECT hsh."subject", hsh."year", hsh."measure", hsh."unit", hsh."value" AS 'households consumption expenditure', gov."value" AS 'government consumption expenditure', "yes" AS 'government did worse'
FROM "frontend_dataset_id_2" hsh
CROSS JOIN "frontend_dataset_id_2" gov
WHERE hsh."year" = gov."year"
AND hsh."indicator" = 'Final consumption expenditure of households'
AND gov."indicator" = 'Final consumption expenditure of general government'
AND hsh."subject" = gov."subject"
AND hsh."subject" = 'United States'
AND hsh."measure" = gov."measure"
AND hsh."measure" = 'Deflator'
AND ((hsh."year" > 2015 AND hsh."value" < gov."value") OR (hsh."year" < 2015 AND hsh."value" > gov."value"))
UNION
SELECT hsh."subject", hsh."year", hsh."measure", hsh."unit", hsh."value" AS 'households consumption expenditure', gov."value" AS 'government consumption expenditure', "no" AS 'government did worse'
FROM "frontend_dataset_id_2" hsh
CROSS JOIN "frontend_dataset_id_2" gov
WHERE hsh."year" = gov."year"
AND hsh."indicator" = 'Final consumption expenditure of households'
AND gov."indicator" = 'Final consumption expenditure of general government'
AND hsh."subject" = gov."subject"
AND hsh."subject" = 'United States'
AND hsh."measure" = gov."measure"
AND hsh."measure" = 'Deflator'
AND ((hsh."year" > 2015 AND hsh."value" > gov."value") OR (hsh."year" < 2015 AND hsh."value" < gov."value"))
ORDER BY hsh."year";

-- by a SIMILAR query we can verify if an industrial powerhouse like Germany experiences a greater inflation in exported goods than in imported ones (it does not, rather offers competitive prices)
SELECT exp."subject", exp."year", exp."measure", exp."unit", exp."value" AS 'inflation of exports', imp."value" AS 'inflation of imports', "yes" AS 'exports more bloated'
FROM "frontend_dataset_id_2" exp
CROSS JOIN "frontend_dataset_id_2" imp
WHERE exp."indicator" = 'Imports of goods'
AND imp."indicator" = 'Exports of goods'
AND exp."subject" = imp."subject"
AND imp."subject" = 'Germany'
AND exp."measure" = 'Deflator'
AND imp."measure" = exp."measure"
AND exp."year" = imp."year"
AND ((exp."year" > 2015 AND exp."value" > imp."value") OR (exp."year" < 2015 AND exp."value" < imp."value"))
UNION
SELECT exp."subject", exp."year", exp."measure", exp."unit", exp."value" AS 'inflation of exports', imp."value" AS 'inflation of imports', "no" AS 'exports more bloate'
FROM "frontend_dataset_id_2" exp
CROSS JOIN "frontend_dataset_id_2" imp
WHERE exp."indicator" = 'Imports of goods'
AND imp."indicator" = 'Exports of goods'
AND exp."subject" = imp."subject"
AND imp."subject" = 'Germany'
AND exp."measure" = 'Deflator'
AND imp."measure" = exp."measure"
AND exp."year" = imp."year"
AND ((exp."year" > 2015 AND imp."value" > exp."value") OR (exp."year" < 2015 AND imp."value" < exp."value"))
ORDER BY exp."year";


-- #3 USE CASE: query data for statistical analysis

-- compare Germany to Romania by the variance of their annual gpd output (constant prices at constant purchasing power parity)
/* a low score should indicate consistency of collective productive power, whereas a high score can reveal boom, bust, or boom-bust cycles
(low variance is indicative of little change over time, whereas high variance means steep increases and/or decreases in GDP over time) */
WITH
    "average_de" AS (
        SELECT AVG("value") AS 'average_de'
        FROM "frontend_dataset_id_2"
        WHERE "measure" LIKE '%growth rate%'
        AND "subject" = 'Germany'
        AND "indicator" LIKE '%Gross domestic product (expenditure approach)%'
        AND "year" >= (SELECT MIN("year") AS 'starting'
                        FROM "frontend_dataset_id_2"
                        WHERE "measure" LIKE '%growth rate%'
                        AND "subject" = 'Romania'
                        AND "indicator" LIKE '%Gross domestic product (expenditure approach)%')),
    "average_ro" AS (
        SELECT AVG("value") AS 'average_ro'
        FROM "frontend_dataset_id_2"
        WHERE "measure" LIKE '%growth rate%'
        AND "subject" = 'Romania'
        AND "indicator" LIKE '%Gross domestic product (expenditure approach)%')
SELECT "subject", "indicator", "measure", "unit", SUM(("value"-(SELECT "average_de" FROM "average_de"))*("value"-(SELECT "average_de" FROM "average_de"))) / (COUNT("year")) AS 'variance'
FROM "frontend_dataset_id_2"
WHERE "measure" LIKE '%growth rate%'
AND "subject" = 'Germany'
AND "indicator" LIKE '%Gross domestic product (expenditure approach)%'
UNION
SELECT "subject", "indicator", "measure", "unit", SUM(("value"-(SELECT "average_ro" FROM "average_ro"))*("value"-(SELECT "average_ro" FROM "average_ro"))) / (COUNT("year")) AS 'variance'
FROM "frontend_dataset_id_2"
WHERE "measure" LIKE '%growth rate%'
AND "subject" = 'Romania'
AND "indicator" LIKE '%Gross domestic product (expenditure approach)%';

-- the results show how Romania experienced much more economic instability than Germany, for detailed yearly observations we interogate:
SELECT "subject", "year", "indicator", "measure", "unit", "value", "flag"
FROM "frontend_dataset_id_2"
WHERE "measure" LIKE '%growth rate%'
AND "indicator" LIKE '%Gross domestic product (expenditure approach)%'
AND ("subject" = 'Romania' OR "subject" = 'Germany')
AND "year" >= (SELECT MIN("year") AS 'starting'
                        FROM "frontend_dataset_id_2"
                        WHERE "measure" LIKE '%growth rate%'
                        AND "subject" = 'Romania'
                        AND "indicator" LIKE '%Gross domestic product (expenditure approach)%')
ORDER BY  "year", "subject";


-- #4 USE CASE: alternative CPI(Shadowstats.com) for the deflation of the consumer expenditure component of the GDP(expenditure approach)
/* as a researcher, one might notice that not all standard methodologies are of best practice, and one might try to improve on them.
A non SNA compliant dataset can bring changes in the way GDP is calculated, and our database structure makes this possible...


