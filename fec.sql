--- Inspect data

SELECT * FROM fec LIMIT 10

--- Adding political affiliation of candidates

ALTER TABLE 
	fec
ADD COLUMN
	"party" VARCHAR(12)


UPDATE 
	fec
SET 
	"party" = 
	CASE
		WHEN "cand_nm" = 'Obama, Barack' THEN 'Democrat'
	   	ELSE 'Republican'
	END

--- contb_receipt_amt includes negative values, which according to the information in receipt_desc column means refund.
--- Will exlude refunds and zero values from further analysis

-- Convert contribution amount column to a numeric format

ALTER TABLE
	fec
ALTER COLUMN
	contb_receipt_amt TYPE FLOAT USING contb_receipt_amt::double precision


DELETE FROM 
	fec
WHERE "contb_receipt_amt" <= 0

--- Check for duplicates

-- Get column names

SELECT string_agg('"' || column_name || '"', '\n') AS formatted_column_names
FROM information_schema.columns
WHERE table_name = 'fec';

WITH duplicates_cte AS
	(SELECT 
		*,
		ROW_NUMBER() OVER (PARTITION BY "file_num", "contb_receipt_amt", "cand_nm", "contbr_nm", "contbr_city", 
										"contbr_st", "contbr_zip", "contbr_employer", "contbr_occupation", "contb_receipt_dt", 
										"receipt_desc", "memo_cd", "memo_text", "form_tp", "cmte_id", "party", "cand_id") AS row_num
	FROM fec)
SELECT * FROM duplicates_cte WHERE row_num > 1

---- There are more than twenty thousand duplicate records. We drop them

WITH duplicates_cte AS
	(SELECT 
		*,
		ROW_NUMBER() OVER (PARTITION BY "file_num", "contb_receipt_amt", "cand_nm", "contbr_nm", "contbr_city", 
										"contbr_st", "contbr_zip", "contbr_employer", "contbr_occupation", "contb_receipt_dt", 
										"receipt_desc", "memo_cd", "memo_text", "form_tp", "cmte_id", "party", "cand_id") AS row_num,
	 ctid
	FROM fec)
DELETE FROM
	fec
USING 
	duplicates_cte
WHERE
	fec.ctid IN (SELECT ctid FROM duplicates_cte WHERE row_num > 1)


SELECT * FROM fec LIMIT 10

--- Check for null values

SELECT 
	*
FROM
	fec
WHERE NOT (fec IS NOT NULL)

-- Check for null values in contributor-state column
SELECT 
	*
FROM
	fec
WHERE 
	contbr_st IS NULL

--- Contributor state is null when the contributor's city is outside the US. So, null values in that column are replaced
--- with contbr_city

UPDATE 
	fec
SET 
	contbr_st = contbr_city
WHERE 
	contbr_st IS NULL



--- There are several null values in contributor city. Because that column is not needed for out intended analysis, we drop 
--- the column. The same goes for contributor-zip, contributir receipt date, receipt description, memo_cd, memo_text, form_tp,
--- file_num columns

ALTER TABLE
	fec
DROP COLUMN
	contbr_city,
DROP COLUMN
	contbr_zip,
DROP COLUMN 
	contb_receipt_dt,
DROP COLUMN 
	recipt_desc,
DROP COLUMN 
	memo_cd,
DROP COLUMN 
	memo_text,
DROP COLUMN 
	form_tp,
DROP COLUMN 
	file_num,


SELECT 
	*
FROM
	fec
WHERE 
	contbr_occupation LIKE 'INFORMATION REQUESTED%'

SELECT 
	*
FROM
	fec
WHERE 
	contbr_employer LIKE 'INFORMATION REQUESTED%'

--- There are many contributors whose occupation and employer is not provided and hence the respective columns have value of 
--- 'INFORMATION REQUESTED', 'REFUSED' or 'NONE'.Such values are replaced with 'NOT PROVIDED'
	
UPDATE 
	fec
SET 
	contbr_occupation = 'NOT PROVIDED' 
WHERE
	contbr_occupation LIKE 'INFORMATION REQUESTED%' OR contbr_occupation = 'NONE' OR contbr_occupation = 'REFUSED'
	OR contbr_occupation = 'REQUESTED' OR contbr_occupation = '--' OR contbr_occupation = '~' OR contbr_occupation = '-' 
	OR contbr_occupation LIKE '%NONE%' OR contbr_occupation IS NULL;

--- There are CEO and C.E.O. in contributor-occupation column and similar cases/ Need to standardize

UPDATE 
	fec
SET 
	contbr_occupation = 'CEO' 
WHERE
	contbr_occupation = 'C.E.O.';

UPDATE 
	fec
SET 
	contbr_occupation = 'CFO' 
WHERE
	contbr_occupation = 'C.F.O.' OR contbr_occupation = 'C.F.O';

UPDATE 
	fec
SET 
	contbr_occupation = 'RETIRED' 
WHERE
	contbr_occupation = 'NONE - RETIRED';
	

UPDATE 
	fec
SET 
	contbr_occupation = 'DISABLED VETERAN' 
WHERE
	contbr_occupation LIKE '%DISABLED VETERAN%';
	
UPDATE 
	fec
SET 
	contbr_employer = 'NOT PROVIDED' 
WHERE
	contbr_employer LIKE 'INFORMATION REQUESTED%' OR contbr_employer = 'NONE' OR contbr_employer = 'REFUSED' 
	OR contbr_employer = 'REQUESTED'

--- null values in contributor-employer column is filled with the values from contributor-occupation column if the latter value
--- is one of 'RETIRED', 'HOMEKEEPER', 'SELF-EMPLOYED', 'NOT EMPLOYED', 'NOT PROVIDED' or such

UPDATE 
	fec
SET
	contbr_employer = contbr_occupation
WHERE 
	contbr_employer IS NULL AND 
	(contbr_occupation = 'RETIRED' OR contbr_occupation = 'HOMEMAKER' OR contbr_occupation = 'SELF-EMPLOYED' OR 
	 contbr_occupation LIKE '%UNEMPLOYED%' OR contbr_occupation = 'SELF EMPLOYED' OR contbr_occupation = 'NOT EMPLOYED'
	OR contbr_occupation LIKE '%HOME%' OR contbr_occupation LIKE '%STUDENT%' OR contbr_occupation LIKE '%WIFE%'
	OR contbr_occupation LIKE '%MOTHER%' OR contbr_occupation LIKE '%HOUSE KEEPING%')

--- Identify the occupation of those whose occupation is provided, but whose employer is not

SELECT 
	DISTINCT(contbr_occupation)
FROM
	fec
WHERE 
	contbr_employer IS NULL AND 
	contbr_occupation IS NOT NULL;

--- Now, null values in contbr_employer are replaced with 'NOT PROVIDED'

UPDATE 
	fec
SET 
	contbr_employer = 'NOT PROVIDED'
WHERE 
	contbr_employer IS NULL;

