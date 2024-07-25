CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'P@ssWord24!'

--DROP DATABASE SCOPED CREDENTIAL MyAzureBlobStorageCredential
CREATE DATABASE SCOPED CREDENTIAL MyAzureBlobStorageCredential
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
SECRET = 'sp=r&st=2024-07-24T23:10:38Z&se=2024-07-25T07:10:38Z&spr=https&sv=2022-11-02&sr=c&sig=62qMg356o3m9ot9ClNVRF%2FAQFD5D8VKsNqshYenZ4y8%3D';

--DROP EXTERNAL DATA SOURCE MyAzureBlobStorage
CREATE EXTERNAL DATA SOURCE MyAzureBlobStorage
WITH (
    TYPE = BLOB_STORAGE,
    LOCATION = 'https://demodata18.blob.core.windows.net/hrdata',
	CREDENTIAL = MyAzureBlobStorageCredential
);


CREATE SCHEMA HR



CREATE TABLE [HR].[AllEmps]
(
	EmplID [int] ,
	[Age] [int],
	[BU] int,
	date datetime,
	EthnicGroup int,
	FP varchar(1),
	Gender varchar(1),
	HireDate datetime,
	PayTypeID varchar(1),
	TermDate datetime,
	TermReason varchar(1)
)



BULK INSERT [HR].[AllEmps]
FROM 'AllEmps.csv'
WITH (
    DATA_SOURCE = 'MyAzureBlobStorage',
    FORMAT = 'CSV',
	--FIELDTERMINATOR = '|',  -- Pipe delimiter
    ROWTERMINATOR = '\n',   -- Newline as row terminator
    FIRSTROW = 2            -- Skip header row
);



CREATE TABLE [HR].[Date]
(
	[Date] datetime,
	[Day] int,
	[Month] varchar(100),
	MonthEndDate datetime,
	MonthNumber int,
	MonthStartDate datetime,
	[Period] varchar(100),
	PeriodNumber int,
	Qtr int,
	QtrNumber varchar(100),
	[Year] int

)



BULK INSERT [HR].[Date]
FROM 'Date.csv'
WITH (
    DATA_SOURCE = 'MyAzureBlobStorage',
    FORMAT = 'CSV',
	--FIELDTERMINATOR = '|',  -- Pipe delimiter
    ROWTERMINATOR = '\n',   -- Newline as row terminator
    FIRSTROW = 2            -- Skip header row
);


CREATE TABLE [HR].TermReason
(
	SeparationTypeID varchar(1),
	SeparationReason varchar(100)
)



BULK INSERT [HR].TermReason
FROM 'TermReason.csv'
WITH (
    DATA_SOURCE = 'MyAzureBlobStorage',
    FORMAT = 'CSV',
	--FIELDTERMINATOR = '|',  -- Pipe delimiter
    ROWTERMINATOR = '\n',   -- Newline as row terminator
    FIRSTROW = 2            -- Skip header row
);


CREATE TABLE [HR].PayGroup
(
	PayTypeID varchar(1),
	PayType varchar(100)
)



BULK INSERT [HR].PayGroup
FROM 'PayGroup.csv'
WITH (
    DATA_SOURCE = 'MyAzureBlobStorage',
    FORMAT = 'CSV',
	--FIELDTERMINATOR = '|',  -- Pipe delimiter
    ROWTERMINATOR = '\n',   -- Newline as row terminator
    FIRSTROW = 2            -- Skip header row
);


CREATE TABLE [HR].FP
(
	FP varchar(1),
	FPDesc varchar(100)
)



BULK INSERT [HR].FP
FROM 'FP.csv'
WITH (
    DATA_SOURCE = 'MyAzureBlobStorage',
    FORMAT = 'CSV',
	--FIELDTERMINATOR = '|',  -- Pipe delimiter
    ROWTERMINATOR = '\n',   -- Newline as row terminator
    FIRSTROW = 2            -- Skip header row
);


CREATE TABLE [HR].BU
(
	BU [int] ,
	RegionSeq varchar(100),
	VP varchar(100)
)



BULK INSERT [HR].BU
FROM 'BU.csv'
WITH (
    DATA_SOURCE = 'MyAzureBlobStorage',
    FORMAT = 'CSV',
	--FIELDTERMINATOR = '|',  -- Pipe delimiter
    ROWTERMINATOR = '\n',   -- Newline as row terminator
    FIRSTROW = 2            -- Skip header row
);


ALTER TABLE HR.AllEmps 
ADD RowId INT IDENTITY(1,1);

UPDATE HR.AllEmps
SET EmplId = RowId;

ALTER TABLE HR.AllEmps
DROP COLUMN RowId;

UPDATE HR.AllEmps set TermDate = null, TermReason = null


-- Update approximately 15% of employees with TermDate and TermReason
WITH RandomEmployees AS (
    SELECT TOP 15 PERCENT EmplId, HireDate
    FROM  HR.AllEmps 
    ORDER BY NEWID()  -- Randomly order the rows
)
UPDATE  HR.AllEmps 
SET TermDate = DATEADD(DAY, ABS(CHECKSUM(NEWID()) % 365), e.HireDate),  -- Adding random days to HireDate
    TermReason = CASE 
                    WHEN ABS(CHECKSUM(NEWID()) % 100) < 80 THEN 'V'  -- 80% chance of 'V'
                    ELSE 'U'  -- 20% chance of 'U'
                 END
FROM  HR.AllEmps  e
JOIN RandomEmployees re ON e.EmplId = re.EmplId;


CREATE TABLE BUWeights (
    BU INT,
    Weight INT
);

-- Insert BU values with weights (higher weight means more employees will be assigned to that BU)
INSERT INTO BUWeights (BU, Weight) VALUES
(1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 1), (10, 1),
(11, 1), (12, 1), (13, 1), (14, 1), (15, 1), (16, 1), (17, 1), (18, 1), (19, 1), (20, 1),
(21, 1), (22, 1), (23, 1), (24, 1), (94, 10), (95, 10), (96, 10), (97, 10), (98, 10), (99, 10);

-- Higher weights (10) are assigned to BUs 94 to 99 to ensure they receive more employees.

-- Update Employees table with BU values based on weights
WITH WeightedBUs AS (
    SELECT BU
    FROM BUWeights
    CROSS APPLY (SELECT TOP (Weight) 1 AS Value FROM (SELECT 1 AS Value UNION ALL SELECT 1) AS v) AS x
),
RandomEmployees AS (
    SELECT e.EmplID,
           w.BU,
           ROW_NUMBER() OVER (ORDER BY NEWID()) AS RowNum
    FROM HR.AllEmps e
    CROSS JOIN WeightedBUs w
)
UPDATE HR.AllEmps
SET BU = re.BU
FROM HR.AllEmps e
JOIN (
    SELECT EmplID, BU, RowNum
    FROM RandomEmployees
) re ON e.EmplId = re.EmplId AND re.RowNum <= (SELECT COUNT(*) FROM HR.AllEmps);
 