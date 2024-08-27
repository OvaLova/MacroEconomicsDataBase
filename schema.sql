.mode list
.headers on
.timer on
.echo on


-- start
BEGIN TRANSACTION;


-- #0 create temporary table shema

CREATE TABLE "BOP6_temp" (
    "indicator_code" TEXT,
    "indicator" TEXT,
    "country_code" TEXT,
    "country" TEXT,
    "measure_code" TEXT,
    "measure" TEXT,
    "frequency_code" TEXT,
    "frequency" TEXT,
    "time_code" TEXT,
    "time" TEXT,
    "unit_code" TEXT,
    "unit" TEXT,
    "powercode_code" TEXT,
    "powercode" TEXT,
    "reference_period_code" TEXT,
    "reference_period" TEXT,
    "value" TEXT,
    "flag_code" TEXT,
    "flag" TEXT
);

CREATE TABLE "SNA_GDP_temp" (
    "country_code" TEXT,
    "country" TEXT,
    "indicator_code" TEXT,
    "indicator" TEXT,
    "measure_code" TEXT,
    "measure" TEXT,
    "time_code" TEXT,
    "time" TEXT,
    "unit_code" TEXT,
    "unit" TEXT,
    "powercode_code" TEXT,
    "powercode" TEXT,
    "reference_period_code" TEXT,
    "reference_period" TEXT,
    "value" TEXT,
    "flag_code" TEXT,
    "flag" TEXT
);

CREATE TABLE "SNA_GmainAgg_temp" (
    "country_code" TEXT,
    "country" TEXT,
    "indicator_code" TEXT,
    "indicator" TEXT,
    "sector_code" TEXT,
    "sector" TEXT,
    "measure_code" TEXT,
    "measure" TEXT,
    "time_code" TEXT,
    "time" TEXT,
    "unit_code" TEXT,
    "unit" TEXT,
    "powercode_code" TEXT,
    "powercode" TEXT,
    "reference_period_code" TEXT,
    "reference_period" TEXT,
    "value" TEXT,
    "flag_code" TEXT,
    "flag" TEXT
);


-- #1 download and import data in temporary tables

.import --csv --skip 1 "DataSets/Balance of Payments/MEI_BOP6-2023.csv" BOP6_temp
.import --csv --skip 1 "DataSets/Aggregate National Accounts Gross domestic product/SNA_TABLE1-2023.csv" SNA_GDP_temp
--.import --csv --skip 1 "DataSets/Aggregate National Accounts Disposable income and net lending:borrowing/SNA_TABLE2-2023.csv" SNA_DI&nL/B_temp
--.import --csv --skip 1 "DataSets/Aggregate National Accounts Population and employment by main activity/SNA_TABLE3-2023.csv" SNA_Pop&Emp_temp
.import --csv --skip 1 "DataSets/General Government Accounts Main aggregates/SNA_TABLE12-2023.csv" SNA_GmainAgg_temp
--.import --csv --skip 1 "DataSets/General Government Accounts Government expenditure by function/SNA_TABLE11-2023.csv" SNA_GExpFct_temp
--.import --csv --skip 1 "DataSets/Detailed National Accounts Final consumption expenditure of households/SNA_TABLE5-2023.csv" SNA_HhExp_temp


-- #2 create permanent table shema

CREATE TABLE "subjects" (
    "id" INTEGER,
    "name" TEXT NOT NULL UNIQUE,
    PRIMARY KEY("id")
);

CREATE TABLE "countries" (
    "id" INTEGER,
    "subject_id" INTEGER,
    "currency" TEXT NOT NULL DEFAULT '???',
    PRIMARY KEY("id"),
    FOREIGN KEY("id") REFERENCES "subjects"("id")
);

CREATE TABLE "groups" (
    "id" INTEGER,
    "subject_id" INTEGER,
    "common_currency" TEXT NOT NULL DEFAULT 'No (economic forum)' CHECK("common_currency" IN ('Yes (monetary union)','No (economic forum)', 'No (economic union)')),
    PRIMARY KEY("id"),
    FOREIGN KEY("id") REFERENCES "subjects"("id")
);

CREATE TABLE "memberships" (
    "group" INTEGER,
    "country" INTEGER,
    FOREIGN KEY("group") REFERENCES "groups"("id"),
    FOREIGN KEY("country") REFERENCES "countries"("id")
);

CREATE TABLE "indicators" (
    "id" INTEGER,
    "code" TEXT,
    "name" TEXT,
    "dataset" INTEGER,
    PRIMARY KEY("id"),
    FOREIGN KEY("dataset") REFERENCES "datasets"("id")
);

CREATE TABLE "datasets" (
    "id" INTEGER,
    "name" TEXT NOT NULL UNIQUE,
    "standards_compliant" TEXT NOT NULL CHECK("standards_compliant" IN ('yes','no')),
    "year" INT DEFAULT NULL,
    "publisher" TEXT DEFAULT NULL,
    "link" TEXT DEFAULT NULL,
    PRIMARY KEY("id")
);

CREATE TABLE "measures" (
    "id" INTEGER,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "unit" TEXT NOT NULL,
    "power" TEXT NOT NULL,
    PRIMARY KEY("id")
);

CREATE TABLE "scopes" (
    "id" INTEGER,
    "frequency" TEXT NOT NULL DEFAULT 'Annual' CHECK("frequency" IN ('Annual','Quarterly','Monthly')),
    "time" TEXT NOT NULL,
    "year" INT NOT NULL DEFAULT '???',
    "quarter" TEXT DEFAULT '???' CHECK("quarter" IN ('Q1','Q2','Q3','Q4')),
    "month" INT DEFAULT '???' CHECK("month" IN ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec')),
    "reference_period" INT,
    PRIMARY KEY("id")
);

CREATE TABLE "flags" (
    "id" INTEGER,
    "name" TEXT DEFAULT NULL UNIQUE CHECK("name" IN ('Estimated value','Provisional value','Break','Low reliability','Difference in methodology', '')),
    PRIMARY KEY("id")
);

CREATE TABLE "scores" (
    "id" INTEGER,
    "subject_id" INTEGER,
    "indicator_id" INTEGER,
    "measure_id" INTEGER,
    "scope_id" INTEGER,
    "value" NUMERIC,
    "flag_id" INTEGER,
    PRIMARY KEY("id"),
    FOREIGN KEY("subject_id") REFERENCES "subjects"("id"),
    FOREIGN KEY("indicator_id") REFERENCES "indicators"("id"),
    FOREIGN KEY("measure_id") REFERENCES "measures"("id"),
    FOREIGN KEY("scope_id") REFERENCES "scopes"("id"),
    FOREIGN KEY("flag_id") REFERENCES "flags"("id")
);


-- #3 clean and normalize data

INSERT INTO "subjects" ("name")
SELECT DISTINCT "country" FROM (
    SELECT DISTINCT "country" FROM "BOP6_temp"
    UNION
    SELECT DISTINCT "country" FROM "SNA_GDP_temp"
    UNION
    SELECT DISTINCT "country" FROM "SNA_GmainAgg_temp");

INSERT INTO "groups" ("subject_id")
SELECT DISTINCT "id" FROM "subjects"
WHERE "name" LIKE 'G__'
OR "name" LIKE 'G_'
OR "name" LIKE '%OECD%';

INSERT INTO "groups" ("subject_id","common_currency")
SELECT DISTINCT "id", 'No (economic union)' FROM "subjects"
WHERE "name" LIKE '%European Union%';

INSERT INTO "groups" ("subject_id","common_currency")
SELECT DISTINCT "id", 'Yes (monetary union)' FROM "subjects"
WHERE "name" LIKE '%Euro area%';

UPDATE "groups"
SET "common_currency" = 'Yes (monetary union)'
WHERE "name" LIKE '%Euro area%';

INSERT INTO "countries" ("subject_id", "currency")
SELECT DISTINCT s."id", c."unit"
FROM "subjects" s
JOIN (SELECT DISTINCT "unit", "country", "measure"
      FROM ( SELECT DISTINCT "unit", "country", "measure" FROM "BOP6_temp"
             UNION
             SELECT DISTINCT "unit", "country", "measure" FROM "SNA_GDP_temp"
             UNION
             SELECT DISTINCT "unit", "country", "measure" FROM "SNA_GmainAgg_temp")) c
ON s."name" = c."country"
WHERE (c."measure" LIKE 'current prices' OR c."measure" LIKE 'national currency')
AND s."name" NOT LIKE '%Euro area%'
AND s."name" NOT LIKE '%European Union%'
AND s."name" NOT LIKE 'G__'
AND s."name" NOT LIKE 'G_'
AND s."name" NOT LIKE '%OECD%';

INSERT INTO "memberships"
SELECT grp."id", ctr."id"
FROM "groups" grp
CROSS JOIN "countries" ctr
JOIN "subjects" sbj1 ON sbj1."id" = grp."subject_id"
JOIN "subjects" sbj2 ON sbj2."id" = ctr."subject_id"
WHERE sbj1."name" LIKE '%european union%' AND sbj1."name" LIKE '%15%'
AND sbj2."id" IN (SELECT "id"
                    FROM "subjects"
                    WHERE "name" NOT LIKE '%Former %' AND (
                    "name" LIKE '%Austria%'
                    OR "name" LIKE '%Belgium%'
                    OR "name" LIKE '%Denmark%'
                    OR "name" LIKE '%Finland%'
                    OR "name" LIKE '%France%'
                    OR "name" LIKE '%Germany%'
                    OR "name" LIKE '%Greece%'
                    OR "name" LIKE '%Ireland%'
                    OR "name" LIKE '%Italy%'
                    OR "name" LIKE '%Luxembourg%'
                    OR "name" LIKE '%Netherlands%'
                    OR "name" LIKE '%Portugal%'
                    OR "name" LIKE '%Spain%'
                    OR "name" LIKE '%Sweden%'
                    OR "name" LIKE '%United Kingdom%'));

INSERT INTO "memberships"
SELECT grp."id", ctr."id"
FROM "groups" grp
CROSS JOIN "countries" ctr
JOIN "subjects" sbj1 ON sbj1."id" = grp."subject_id"
JOIN "subjects" sbj2 ON sbj2."id" = ctr."subject_id"
WHERE sbj1."name" LIKE '%european union%' AND sbj1."name" LIKE '%27%'
AND sbj2."id" IN (SELECT "id"
                    FROM "subjects"
                    WHERE "name" NOT LIKE '%Former %' AND (
                    "name" LIKE '%Austria%'
                    OR "name" LIKE '%Belgium%'
                    OR "name" LIKE '%Bulgaria%'
                    OR "name" LIKE '%Cyprus%'
                    OR "name" LIKE '%Croatia%'
                    OR "name" LIKE '%Czechia%'
                    OR "name" LIKE '%Denmark%'
                    OR "name" LIKE '%Estonia%'
                    OR "name" LIKE '%Finland%'
                    OR "name" LIKE '%France%'
                    OR "name" LIKE '%Germany%'
                    OR "name" LIKE '%Greece%'
                    OR "name" LIKE '%Hungary%'
                    OR "name" LIKE '%Ireland%'
                    OR "name" LIKE '%Italy%'
                    OR "name" LIKE '%Latvia%'
                    OR "name" LIKE '%Lithuania%'
                    OR "name" LIKE '%Luxembourg%'
                    OR "name" LIKE '%Malta%'
                    OR "name" LIKE '%Netherlands%'
                    OR "name" LIKE '%Poland%'
                    OR "name" LIKE '%Portugal%'
                    OR "name" LIKE '%Romania%'
                    OR "name" LIKE '%Slovak%'
                    OR "name" LIKE '%Slovenia%'
                    OR "name" LIKE '%Spain%'
                    OR "name" LIKE '%Sweden%'));

INSERT INTO "memberships"
SELECT grp."id", ctr."id"
FROM "groups" grp
CROSS JOIN "countries" ctr
JOIN "subjects" sbj1 ON sbj1."id" = grp."subject_id"
JOIN "subjects" sbj2 ON sbj2."id" = ctr."subject_id"
WHERE sbj1."name" LIKE '%G20%'
AND sbj2."id" IN (SELECT "id"
                    FROM "subjects"
                    WHERE "name" NOT LIKE '%Former %' AND (
                    "name" LIKE '%France%'
                    OR "name" LIKE '%Germany%'
                    OR "name" LIKE '%Italy%'
                    OR "name" LIKE '%United Kingdom%'
                    OR "name" LIKE '%United States%'
                    OR "name" LIKE '%Australia%'
                    OR "name" LIKE '%Saudi Arabia%'
                    OR "name" LIKE '%Canada%'
                    OR ("name" LIKE '%China%' AND "name" LIKE "%People's Republic%")
                    OR "name" LIKE '%Japan%'
                    OR "name" LIKE '%Indonesia%'
                    OR "name" LIKE '%Korea%'
                    OR "name" LIKE '%India%'
                    OR "name" LIKE '%Russia%'
                    OR "name" LIKE '%South Africa%'
                    OR "name" LIKE '%T_rk%'
                    OR "name" LIKE '%Argentina%'
                    OR "name" LIKE '%Brazil%'
                    OR "name" LIKE '%Mexic%'));

INSERT INTO "memberships"
SELECT grp."id", ctr."id"
FROM "groups" grp
CROSS JOIN "countries" ctr
JOIN "subjects" sbj1 ON sbj1."id" = grp."subject_id"
JOIN "subjects" sbj2 ON sbj2."id" = ctr."subject_id"
WHERE sbj1."name" LIKE '%G7%'
AND sbj2."id" IN (SELECT "id"
                    FROM "subjects"
                    WHERE "name" NOT LIKE '%Former %' AND (
                    "name" LIKE '%Canada%'
                    OR "name" LIKE '%France%'
                    OR "name" LIKE '%Germany%'
                    OR "name" LIKE '%Italy%'
                    OR "name" LIKE '%Japan%'
                    OR "name" LIKE '%United Kingdom%'
                    OR "name" LIKE '%United States%'));

INSERT INTO "memberships"
SELECT grp."id", ctr."id"
FROM "groups" grp
CROSS JOIN "countries" ctr
JOIN "subjects" sbj1 ON sbj1."id" = grp."subject_id"
JOIN "subjects" sbj2 ON sbj2."id" = ctr."subject_id"
WHERE sbj1."name" LIKE '%Euro area%' AND sbj1."name" LIKE '%20%'
AND sbj2."id" IN (SELECT "id"
                    FROM "subjects"
                    WHERE "name" NOT LIKE '%Former %' AND (
                    "name" LIKE '%Austria%'
                    OR "name" LIKE '%Belgium%'
                    OR "name" LIKE '%Bulgaria%'
                    OR "name" LIKE '%Cyprus%'
                    OR "name" LIKE '%Croatia%'
                    OR "name" LIKE '%Estonia%'
                    OR "name" LIKE '%Finland%'
                    OR "name" LIKE '%France%'
                    OR "name" LIKE '%Germany%'
                    OR "name" LIKE '%Greece%'
                    OR "name" LIKE '%Ireland%'
                    OR "name" LIKE '%Italy%'
                    OR "name" LIKE '%Latvia%'
                    OR "name" LIKE '%Lithuania%'
                    OR "name" LIKE '%Luxembourg%'
                    OR "name" LIKE '%Malta%'
                    OR "name" LIKE '%Netherlands%'
                    OR "name" LIKE '%Portugal%'
                    OR "name" LIKE '%Slovenia%'
                    OR "name" LIKE '%Spain%'));

INSERT INTO "memberships"
SELECT grp."id", ctr."id"
FROM "groups" grp
CROSS JOIN "countries" ctr
JOIN "subjects" sbj1 ON sbj1."id" = grp."subject_id"
JOIN "subjects" sbj2 ON sbj2."id" = ctr."subject_id"
WHERE sbj1."name" LIKE '%Euro area%' AND sbj1."name" LIKE '%19%'
AND sbj2."id" IN (SELECT "id"
                    FROM "subjects"
                    WHERE "name" NOT LIKE '%Former %' AND (
                    "name" LIKE '%Austria%'
                    OR "name" LIKE '%Belgium%'
                    OR "name" LIKE '%Bulgaria%'
                    OR "name" LIKE '%Cyprus%'
                    OR "name" LIKE '%Estonia%'
                    OR "name" LIKE '%Finland%'
                    OR "name" LIKE '%France%'
                    OR "name" LIKE '%Germany%'
                    OR "name" LIKE '%Greece%'
                    OR "name" LIKE '%Ireland%'
                    OR "name" LIKE '%Italy%'
                    OR "name" LIKE '%Latvia%'
                    OR "name" LIKE '%Lithuania%'
                    OR "name" LIKE '%Luxembourg%'
                    OR "name" LIKE '%Malta%'
                    OR "name" LIKE '%Netherlands%'
                    OR "name" LIKE '%Portugal%'
                    OR "name" LIKE '%Slovenia%'
                    OR "name" LIKE '%Spain%'));

INSERT INTO "datasets" ("name","standards_compliant","year","publisher","link")
VALUES
    ('Balance of payments BPM6', 'yes', 2023,'OECD','https://www.oecd-ilibrary.org/balance-of-payments-bpm6-edition-2023_2a7f09d0-en.zip?itemId=%2Fcontent%2Fdata%2F2a7f09d0-en&containerItemId=%2Fcontent%2Fcollection%2Fmei-data-en'),
    ('Aggregate National Accounts, SNA 2008: Gross domestic product', 'yes', 2023,'OECD','https://www.oecd-ilibrary.org/aggregate-national-accounts-sna-2008-gross-domestic-product-edition-2023_28f03bac-en.zip?itemId=%2Fcontent%2Fdata%2F28f03bac-en&containerItemId=%2Fcontent%2Fcollection%2Fna-data-en'),
    ('General Government Accounts, SNA 2008: Main aggregates', 'yes', 2023,'OECD','https://www.oecd-ilibrary.org/general-government-accounts-sna-2008-main-aggregates-edition-2023_082dadd3-en.zip?itemId=%2Fcontent%2Fdata%2F082dadd3-en&containerItemId=%2Fcontent%2Fcollection%2Fna-data-en');

INSERT INTO "indicators" ("code", "name", "dataset")
SELECT * FROM (SELECT DISTINCT "indicator_code",
                                "indicator",
                                (SELECT "id" FROM "datasets" WHERE "name" = 'Balance of payments BPM6')
                FROM "BOP6_temp");

INSERT INTO "indicators" ("code", "name", "dataset")
SELECT * FROM (SELECT DISTINCT "indicator_code",
                                "indicator",
                                (SELECT "id" FROM "datasets" WHERE "name" = 'Aggregate National Accounts, SNA 2008: Gross domestic product')
                FROM "SNA_GDP_temp");

INSERT INTO "indicators" ("code", "name", "dataset")
SELECT * FROM (SELECT DISTINCT "indicator_code",
                                "indicator",
                                (SELECT "id" FROM "datasets" WHERE "name" = 'General Government Accounts, SNA 2008: Main aggregates')
                FROM "SNA_GmainAgg_temp");

INSERT INTO "measures" ("code", "name", "unit", "power")
SELECT DISTINCT "measure_code", "measure", "unit", "powercode_code" FROM (
    SELECT DISTINCT "measure_code", "measure", "unit", "powercode_code" FROM "BOP6_temp"
    UNION
    SELECT DISTINCT "measure_code", "measure", "unit", "powercode_code" FROM "SNA_GDP_temp"
    UNION
    SELECT DISTINCT "measure_code", "measure", "unit", "powercode_code" FROM "SNA_GmainAgg_temp");

INSERT INTO "scopes" ("frequency", "time", "year", "quarter", "month", "reference_period")
    SELECT DISTINCT 'Annual',
                    "time",
                    "time",
                    NULL,
                    NULL,
                    "reference_period"
    FROM (
        SELECT DISTINCT "time", "reference_period" FROM "BOP6_temp"
        UNION
        SELECT DISTINCT "time", "reference_period" FROM "SNA_GDP_temp"
        UNION
        SELECT DISTINCT "time", "reference_period" FROM "SNA_GmainAgg_temp")
    WHERE "time" NOT LIKE '%-%'
UNION
    SELECT DISTINCT 'Quarterly',
                    "time",
                    substr("time", instr("time", '-')+1),
                    substr("time", 1, instr("time", '-')-1),
                    NULL,
                    "reference_period"
    FROM (
        SELECT DISTINCT "time", "reference_period" FROM "BOP6_temp"
        UNION
        SELECT DISTINCT "time", "reference_period" FROM "SNA_GDP_temp"
        UNION
        SELECT DISTINCT "time", "reference_period" FROM "SNA_GmainAgg_temp")
    WHERE "time" LIKE '%-%' AND "time" LIKE 'Q_%'
UNION
    SELECT DISTINCT 'Monthly',
                    "time",
                    substr("time", instr("time", '-')+1),
                    NULL,
                    substr("time", 1, instr("time", '-')-1),
                    "reference_period"
    FROM (
        SELECT DISTINCT "time", "reference_period" FROM "BOP6_temp"
        UNION
        SELECT DISTINCT "time", "reference_period" FROM "SNA_GDP_temp"
        UNION
        SELECT DISTINCT "time", "reference_period" FROM "SNA_GmainAgg_temp")
    WHERE "time" LIKE '%-%' AND "time" NOT LIKE 'Q_%';

INSERT INTO "flags" ("name")
SELECT DISTINCT "flag" FROM (
    SELECT DISTINCT "flag" FROM "BOP6_temp"
    UNION
    SELECT DISTINCT "flag" FROM "SNA_GDP_temp"
    UNION
    SELECT DISTINCT "flag" FROM "SNA_GmainAgg_temp");

ALTER TABLE "BOP6_temp" ADD "row_id";
UPDATE "BOP6_temp"
SET "row_id" = ROWID;

ALTER TABLE "SNA_GDP_temp" ADD "row_id";
UPDATE "SNA_GDP_temp"
SET "row_id" = ROWID;

ALTER TABLE "SNA_GmainAgg_temp" ADD "row_id";
UPDATE "SNA_GmainAgg_temp"
SET "row_id" = ROWID;


-- #4 move data from temporary tables to permanent table (temp -> scores)

-- BOP6_temp
CREATE TABLE "subject_ids" ("id" INTEGER, "subject_id" INTEGER, PRIMARY KEY("id"));
CREATE TABLE "indicator_ids" ("id" INTEGER, "indicator_id" INTEGER, PRIMARY KEY("id"));
CREATE TABLE "measure_ids" ("id" INTEGER, "measure_id" INTEGER, PRIMARY KEY("id"));
CREATE TABLE "scope_ids" ("id" INTEGER, "scope_id" INTEGER, PRIMARY KEY("id"));
CREATE TABLE "values" ("id" INTEGER, "value" NUMERIC, PRIMARY KEY("id"));
CREATE TABLE "flag_ids" ("id" INTEGER, "flag_id" INTEGER, PRIMARY KEY("id"));

INSERT INTO "subject_ids"
SELECT bop."row_id", sbj."id" FROM "BOP6_temp" bop JOIN "subjects" sbj ON sbj."name" = bop."country";
INSERT INTO "indicator_ids"
SELECT bop."row_id", ind."id" FROM "BOP6_temp" bop JOIN "indicators" ind ON ind."name" = bop."indicator" WHERE ind."dataset" = 1;
INSERT INTO "measure_ids"
SELECT bop."row_id", msr."id" FROM "BOP6_temp" bop JOIN "measures" msr ON msr."name" = bop."measure" AND msr."unit" = bop."unit";
INSERT INTO "scope_ids"
SELECT bop."row_id", scp."id" FROM "BOP6_temp" bop JOIN "scopes" scp ON scp."time" = bop."time" AND scp."reference_period" = bop."reference_period";
INSERT INTO "values"
SELECT bop."row_id", bop."value" FROM "BOP6_temp" bop;
INSERT INTO "flag_ids"
SELECT bop."row_id", flg."id" FROM "BOP6_temp" bop JOIN "flags" flg ON flg."name" = bop."flag";

INSERT INTO "scores" ("id", "subject_id", "indicator_id", "measure_id", "scope_id", "value", "flag_id")
SELECT val."id", sbj."subject_id", ind."indicator_id", msr."measure_id", scp."scope_id", val."value", flg."flag_id"
FROM "values" val
JOIN "subject_ids" sbj ON sbj."id" = val."id"
JOIN "indicator_ids" ind ON ind."id" = val."id"
JOIN "measure_ids" msr ON msr."id" = val."id"
JOIN "scope_ids" scp ON scp."id" = val."id"
JOIN "flag_ids" flg ON flg."id" = val."id";

-- SNA_GDP_temp
DELETE FROM "subject_ids";
DELETE FROM "indicator_ids";
DELETE FROM "measure_ids";
DELETE FROM "scope_ids";
DELETE FROM "values";
DELETE FROM "flag_ids";

INSERT INTO "subject_ids"
SELECT gdp."row_id", sbj."id" FROM "SNA_GDP_temp" gdp JOIN "subjects" sbj ON sbj."name" = gdp."country";
INSERT INTO "indicator_ids"
SELECT gdp."row_id", ind."id" FROM "SNA_GDP_temp" gdp JOIN "indicators" ind ON ind."name" = gdp."indicator" WHERE ind."dataset" = 2 GROUP BY gdp."row_id";
INSERT INTO "measure_ids"
SELECT gdp."row_id", msr."id" FROM "SNA_GDP_temp" gdp JOIN "measures" msr ON msr."name" = gdp."measure" AND msr."unit" = gdp."unit";
INSERT INTO "scope_ids"
SELECT gdp."row_id", scp."id" FROM "SNA_GDP_temp" gdp JOIN "scopes" scp ON scp."time" = gdp."time" AND scp."reference_period" = gdp."reference_period";
INSERT INTO "values"
SELECT gdp."row_id", gdp."value" FROM "SNA_GDP_temp" gdp;
INSERT INTO "flag_ids"
SELECT gdp."row_id", flg."id" FROM "SNA_GDP_temp" gdp JOIN "flags" flg ON flg."name" = gdp."flag";

INSERT INTO "scores" ("subject_id", "indicator_id", "measure_id", "scope_id", "value", "flag_id")
SELECT sbj."subject_id", ind."indicator_id", msr."measure_id", scp."scope_id", val."value", flg."flag_id"
FROM "values" val
JOIN "subject_ids" sbj ON sbj."id" = val."id"
JOIN "indicator_ids" ind ON ind."id" = val."id"
JOIN "measure_ids" msr ON msr."id" = val."id"
JOIN "scope_ids" scp ON scp."id" = val."id"
JOIN "flag_ids" flg ON flg."id" = val."id";

-- SNA_GmainAgg_temp
DELETE FROM "subject_ids";
DELETE FROM "indicator_ids";
DELETE FROM "measure_ids";
DELETE FROM "scope_ids";
DELETE FROM "values";
DELETE FROM "flag_ids";

INSERT INTO "subject_ids"
SELECT gov."row_id", sbj."id" FROM "SNA_GmainAgg_temp" gov JOIN "subjects" sbj ON sbj."name" = gov."country";
INSERT INTO "indicator_ids"
SELECT gov."row_id", ind."id" FROM "SNA_GmainAgg_temp" gov JOIN "indicators" ind ON ind."name" = gov."indicator" WHERE ind."dataset" = 3 GROUP BY gov."row_id";
INSERT INTO "measure_ids"
SELECT gov."row_id", msr."id" FROM "SNA_GmainAgg_temp" gov JOIN "measures" msr ON msr."name" = gov."measure" AND msr."unit" = gov."unit";
INSERT INTO "scope_ids"
SELECT gov."row_id", scp."id" FROM "SNA_GmainAgg_temp" gov JOIN "scopes" scp ON scp."time" = gov."time" AND scp."reference_period" = gov."reference_period";
INSERT INTO "values"
SELECT gov."row_id", gov."value" FROM "SNA_GmainAgg_temp" gov;
INSERT INTO "flag_ids"
SELECT gov."row_id", flg."id" FROM "SNA_GmainAgg_temp" gov JOIN "flags" flg ON flg."name" = gov."flag";

INSERT INTO "scores" ("subject_id", "indicator_id", "measure_id", "scope_id", "value", "flag_id")
SELECT sbj."subject_id", ind."indicator_id", msr."measure_id", scp."scope_id", val."value", flg."flag_id"
FROM "values" val
JOIN "subject_ids" sbj ON sbj."id" = val."id"
JOIN "indicator_ids" ind ON ind."id" = val."id"
JOIN "measure_ids" msr ON msr."id" = val."id"
JOIN "scope_ids" scp ON scp."id" = val."id"
JOIN "flag_ids" flg ON flg."id" = val."id";

DROP TABLE "subject_ids";
DROP TABLE "indicator_ids";
DROP TABLE "measure_ids";
DROP TABLE "scope_ids";
DROP TABLE "values";
DROP TABLE "flag_ids";


-- #5 drop temporary tables

--DROP TABLE "H41_temp";
DROP TABLE "BOP6_temp";
DROP TABLE "SNA_GDP_temp";
--DROP TABLE "SNA_DI&nL/B_temp";
--DROP TABLE "SNA_Pop&Emp_temp";
DROP TABLE "SNA_GmainAgg_temp";


-- #6 create indexes

--CREATE INDEX "Scores_on_Id" ON "scores"("id");


-- #7 create user views

-- detailed dataset breakdowns / indicator groupings
CREATE VIEW "datasets_structure" ("dataset_id", "dataset", "standards_compliant", "publisher", "publication_year", "indicator_id", "code", "name")
AS SELECT dts."id", dts."name",dts."standards_compliant", dts."publisher", dts."year", ind."id", ind."code", ind."name"
FROM "indicators" ind
JOIN "datasets" dts ON ind."dataset" = dts."id";

-- detailed organisation of subjects
CREATE VIEW "subjects_info" ("group", "membership", "country", "common_currency", "currency")
AS SELECT * FROM
(SELECT NULL, 'no group', sbj."name", "not the case", ctr."currency"
FROM "subjects" sbj
JOIN "countries" ctr ON ctr."subject_id" = sbj."id"
WHERE ctr."id" NOT IN (SELECT DISTINCT "country" FROM "memberships")
UNION
SELECT sbj1."name", 'part of', sbj2."name", grp."common_currency", ctr."currency"
FROM "subjects" sbj1
CROSS JOIN "subjects" sbj2
JOIN "groups" grp ON grp."subject_id" = sbj1."id"
JOIN "countries" ctr ON ctr."subject_id" = sbj2."id"
JOIN "memberships" mbr ON mbr."group" = grp."id" AND mbr."country" = ctr."id");

--*** Bulk Data ***--
-- all data records from all datasets
CREATE VIEW "frontend_data_records" ("id", "subject", "indicator", "dataset", "measure", "frequency", "year", "quarter", "month", "unit", "power", "value", "reference_period", "flag")
AS SELECT scr."id", sbj."name", ind."name", ind."dataset", msr."name", scp."frequency", scp."year", scp."quarter", scp."month", msr."unit", msr."power", scr."value", scp."reference_period", flg."name"
FROM "scores" scr
JOIN "subjects" sbj ON sbj."id" = scr."subject_id"
JOIN "indicators" ind ON ind."id" = scr."indicator_id"
JOIN "measures" msr ON msr."id" = scr."measure_id"
JOIN "scopes" scp ON scp."id" = scr."scope_id"
JOIN "flags" flg ON flg."id" = scr."flag_id";

--*** Granular Data ***--
-- use "subjects_info" to choose the right granular view
-- all data records from dataset with id '1'
CREATE VIEW "frontend_dataset_id_1" ("id", "subject", "indicator", "dataset", "measure", "frequency", "year", "quarter", "month", "unit", "power", "value", "reference_period", "flag")
AS SELECT scr."id", sbj."name", ind."name", ind."dataset", msr."name", scp."frequency", scp."year", scp."quarter", scp."month", msr."unit", msr."power", scr."value", scp."reference_period", flg."name"
FROM "scores" scr
JOIN "subjects" sbj ON sbj."id" = scr."subject_id"
JOIN "indicators" ind ON ind."id" = scr."indicator_id"
JOIN "measures" msr ON msr."id" = scr."measure_id"
JOIN "scopes" scp ON scp."id" = scr."scope_id"
JOIN "flags" flg ON flg."id" = scr."flag_id"
WHERE ind."dataset" = 1;

-- all data records from dataset with id '2'
CREATE VIEW "frontend_dataset_id_2" ("id", "subject", "indicator", "dataset", "measure", "frequency", "year", "quarter", "month", "unit", "power", "value", "reference_period", "flag")
AS SELECT scr."id", sbj."name", ind."name", ind."dataset", msr."name", scp."frequency", scp."year", scp."quarter", scp."month", msr."unit", msr."power", scr."value", scp."reference_period", flg."name"
FROM "scores" scr
JOIN "subjects" sbj ON sbj."id" = scr."subject_id"
JOIN "indicators" ind ON ind."id" = scr."indicator_id"
JOIN "measures" msr ON msr."id" = scr."measure_id"
JOIN "scopes" scp ON scp."id" = scr."scope_id"
JOIN "flags" flg ON flg."id" = scr."flag_id"
WHERE ind."dataset" = 2;

-- all data records from dataset with id '3'
CREATE VIEW "frontend_dataset_id_3" ("id", "subject", "indicator", "dataset", "measure", "frequency", "year", "quarter", "month", "unit", "power", "value", "reference_period", "flag")
AS SELECT scr."id", sbj."name", ind."name", ind."dataset", msr."name", scp."frequency", scp."year", scp."quarter", scp."month", msr."unit", msr."power", scr."value", scp."reference_period", flg."name"
FROM "scores" scr
JOIN "subjects" sbj ON sbj."id" = scr."subject_id"
JOIN "indicators" ind ON ind."id" = scr."indicator_id"
JOIN "measures" msr ON msr."id" = scr."measure_id"
JOIN "scopes" scp ON scp."id" = scr."scope_id"
JOIN "flags" flg ON flg."id" = scr."flag_id"
WHERE ind."dataset" = 3;


-- end
COMMIT;
VACUUM;


