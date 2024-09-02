--------------
-- n=3 step --
--------------

--*的銷售對象--
SELECT DISTINCT reu_no, code_no INTO #temp_table2
FROM #temp_table
WHERE fac_type = 'RM' --上游清除委託的其他再利用機構, 但有重複

DECLARE @reu_no NVARCHAR(100)	--再利用機構管編
DECLARE @code_no NVARCHAR(100)	--代碼
DECLARE load_cursor CURSOR FOR 
	SELECT reu_no, code_no 
	FROM #temp_table2
OPEN load_cursor
FETCH NEXT FROM load_cursor INTO @reu_no, @code_no
WHILE @@FETCH_STATUS = 0
BEGIN
	INSERT INTO node
	SELECT DISTINCT TargetID, ProductName, 'S', TargetName, OrganID, NULL
	FROM IMP.dbo.ReUse_ReuProductSale rurps 
	WHERE OrganID = @reu_no
		AND WasteName LIKE '%' + @code_no + '%' --廢棄物代碼+廢棄物名稱, 篩選出包含@code_no的, e.g. %R-0201%
	
	FETCH NEXT FROM load_cursor INTO @reu_no, @code_no
END
CLOSE load_cursor
DEALLOCATE load_cursor
GO

SELECT *
FROM node n 


--*的非列管事業機構+清除機構--
CREATE TABLE A2_C
(
	FacID NVARCHAR(100),	--事業機構管編
	Fac_Name NVARCHAR(100),	--事業機構名稱
	Cle_No NVARCHAR(100),	--清除機構管編
	Reu_No NVARCHAR(100),	--再利用機構管編
	Waste_No NVARCHAR(100)	--代碼
)

DECLARE @reu_no NVARCHAR(100)	--再利用機構管編
DECLARE @code_no NVARCHAR(100)	--代碼
DECLARE load_cursor CURSOR FOR 
	SELECT reu_no, code_no 
	FROM #temp_table2
OPEN load_cursor
FETCH NEXT FROM load_cursor INTO @reu_no, @code_no
WHILE @@FETCH_STATUS = 0
BEGIN
	INSERT INTO A2_C
	SELECT DISTINCT FacID, Fac_Name, Cle_No, Reu_No, Waste_No
	FROM IMP_1.dbo.Waste_ReuMonReportN_Commit wrmrnc
	WHERE Reu_No = @reu_no
		AND Waste_No = @code_no
	
	FETCH NEXT FROM load_cursor INTO @reu_no, @code_no
END
CLOSE load_cursor
DEALLOCATE load_cursor
GO

--補上清除機構名稱
SELECT DISTINCT FacID, Fac_Name, A2_C.Cle_No, Cle_name, Reu_No, Waste_No INTO #temp_table3
FROM A2_C
LEFT JOIN IMP_3.dbo.Waste_Clean wc --清除機構基本資料檔
	ON A2_C.Cle_No = wc.Cle_no

--良峰H51A6019在Waste_Clean有兩種名稱, 導致LEFT JOIN有多餘
SELECT *
FROM IMP_3.dbo.Waste_Clean wc 
WHERE Cle_no = 'H51A6019'

DELETE
FROM #temp_table3
WHERE Cle_name = '良峰實業股份有限公司' --8個重複

--補上再利用機構名稱
SELECT FacID, Fac_Name, Cle_No, Cle_name, #temp_table3.Reu_No, Reu_name, Waste_No INTO #temp_table4
FROM #temp_table3
LEFT JOIN IMP_3.dbo.Waste_Reuse wr --回收再利用機構基本資料檔
	ON #temp_table3.Reu_No = wr.Reu_no

--append非列管事業到node table
INSERT INTO node
SELECT FacID, Waste_No, 'A2', Fac_Name, NULL, Cle_No
FROM #temp_table4

--append清除機構到node table, 分為三種cases: (1)自行清除 (2)再利用者清除 (3)一般清除
--(1)
INSERT INTO node
SELECT FacID, Waste_No, 'C', Fac_Name, FacID, Reu_No
FROM #temp_table4
WHERE Cle_No = 'C0000000' --自行清除

--(2)
INSERT INTO node
SELECT Reu_No, Waste_No, 'C', Reu_name, FacID, Reu_No
FROM #temp_table4
WHERE Cle_No = 'C1111111' --再利用者清除

--(3)
INSERT INTO node
SELECT Cle_No, Waste_No, 'C', Cle_name, FacID, Reu_No
FROM #temp_table4
WHERE Cle_No <> 'C0000000' --非自行清除
	AND Cle_No <> 'C1111111' --非再利用者清除

DROP TABLE #temp_table3, #temp_table4

SELECT *
FROM node n 


--*的列管事業機構+清除機構 (再利用聯單)--
CREATE TABLE A1_C
(
	fac_no NVARCHAR(100),	--事業機構管編
	cle_no NVARCHAR(100),	--清除機構管編
	reu_no NVARCHAR(100),	--再利用機構管編
	code_no NVARCHAR(100)	--代碼
)

DECLARE @reu_no NVARCHAR(100)	--再利用機構管編
DECLARE @code_no NVARCHAR(100)	--代碼
DECLARE load_cursor CURSOR FOR 
	SELECT reu_no, code_no 
	FROM #temp_table2
OPEN load_cursor
FETCH NEXT FROM load_cursor INTO @reu_no, @code_no
WHILE @@FETCH_STATUS = 0
BEGIN
	INSERT INTO A1_C
	SELECT DISTINCT wdw.Dlist_no1, Cle_no, Reu_no, Waste_no
	FROM IMP_3.dbo.Waste_Dlist_wre1 wdw 
	LEFT JOIN IMP_3.dbo.Waste_Dlist_wre2 wdw2 
		ON (wdw.Dlist_no1 = wdw2.Dlist_no1 AND wdw.Dlist_no2 = wdw2.Dlist_no2 AND wdw.Dlist_no3 = wdw2.Dlist_no3)
	WHERE Reu_no = @reu_no
		AND Waste_no = @code_no
	
	FETCH NEXT FROM load_cursor INTO @reu_no, @code_no
END
CLOSE load_cursor
DEALLOCATE load_cursor
GO

--補上列管事業機構名稱
SELECT A1_C.fac_no, Fac_name, cle_no, reu_no, code_no INTO #temp_table3
FROM A1_C
LEFT JOIN IMP_3.dbo.Waste_Factory wf --事業機構基本資料檔
	ON A1_C.fac_no = wf.Fac_no

--補上清除機構名稱
SELECT DISTINCT fac_no, Fac_name, #temp_table3.cle_no, Cle_name, reu_no, code_no INTO #temp_table4
FROM #temp_table3
LEFT JOIN IMP_3.dbo.Waste_Clean wc --清除機構基本資料檔
	ON #temp_table3.cle_no = wc.Cle_no

--良峰H51A6019在Waste_Clean有兩種名稱, 導致LEFT JOIN有多餘
SELECT *
FROM IMP_3.dbo.Waste_Clean wc 
WHERE Cle_no = 'H51A6019'

DELETE
FROM #temp_table4
WHERE Cle_name = '良峰實業股份有限公司' --9個重複

--補上再利用機構名稱
SELECT fac_no, Fac_name, cle_no, Cle_name, #temp_table4.reu_no, Reu_name, code_no INTO #temp_table5
FROM #temp_table4
LEFT JOIN IMP_3.dbo.Waste_Reuse wr --回收再利用機構基本資料檔
	ON #temp_table4.reu_no = wr.Reu_no

--append列管事業機構到node table
INSERT INTO node
SELECT fac_no, code_no, 'A1', Fac_name, NULL, cle_no
FROM #temp_table5

--append清除機構到node table, 分為三種cases: (1)自行清除 (2)再利用者清除 (3)一般清除
--(1)
INSERT INTO node
SELECT DISTINCT fac_no, code_no, 'C', Fac_name, fac_no, reu_no
FROM #temp_table5
WHERE cle_no = 'C0000000' --自行清除

--(2)
INSERT INTO node
SELECT DISTINCT reu_no, code_no, 'C', Reu_name, fac_no, reu_no
FROM #temp_table5
WHERE cle_no = 'C1111111' --再利用者清除

--(3)
INSERT INTO node
SELECT DISTINCT cle_no, code_no, 'C', Cle_name, fac_no, reu_no
FROM #temp_table5
WHERE cle_no <> 'C0000000' --非自行清除
	AND cle_no <> 'C1111111' --非再利用者清除

DROP TABLE #temp_table3, #temp_table4, #temp_table5

SELECT *
FROM node n 


--*的列管事業機構+清除機構 (處理後聯單)--
CREATE TABLE C_A1
(
	fac_no NVARCHAR(100),	--事業機構管編
	cle_no NVARCHAR(100),	--清除機構管編
	reu_no NVARCHAR(100),	--再利用機構管編
	code_no NVARCHAR(100)	--代碼
)

DECLARE @reu_no NVARCHAR(100)	--再利用機構管編
DECLARE @code_no NVARCHAR(100)	--代碼
DECLARE load_cursor CURSOR FOR 
	SELECT reu_no, code_no 
	FROM #temp_table2
OPEN load_cursor
FETCH NEXT FROM load_cursor INTO @reu_no, @code_no
WHILE @@FETCH_STATUS = 0
BEGIN
	INSERT INTO C_A1
	SELECT DISTINCT wdw.Dlist_no1, Cle_no, Reu_no, Waste_no
	FROM IMP_3.dbo.Waste_Dlist_wt1 wdw 
	LEFT JOIN IMP_3.dbo.Waste_Dlist_wt2 wdw2 
		ON (wdw.Dlist_no1 = wdw2.Dlist_no1 AND wdw.Dlist_no2 = wdw2.Dlist_no2 AND wdw.Dlist_no3 = wdw2.Dlist_no3)
	WHERE Reu_no = @reu_no
		AND Waste_no = @code_no
	
	FETCH NEXT FROM load_cursor INTO @reu_no, @code_no
END
CLOSE load_cursor
DEALLOCATE load_cursor
GO 

--補上列管事業機構名稱
SELECT C_A1.fac_no, Fac_name, cle_no, reu_no, code_no INTO #temp_table3
FROM C_A1
LEFT JOIN IMP_3.dbo.Waste_Factory wf --事業機構基本資料檔
	ON C_A1.fac_no = wf.Fac_no

--補上清除機構名稱
SELECT DISTINCT fac_no, Fac_name, #temp_table3.cle_no, Cle_name, reu_no, code_no INTO #temp_table4
FROM #temp_table3
LEFT JOIN IMP_3.dbo.Waste_Clean wc --清除機構基本資料檔
	ON #temp_table3.cle_no = wc.Cle_no

--補上再利用機構名稱
SELECT fac_no, Fac_name, cle_no, Cle_name, #temp_table4.reu_no, Reu_name, code_no INTO #temp_table5
FROM #temp_table4
LEFT JOIN IMP_3.dbo.Waste_Reuse wr --回收再利用機構基本資料檔
	ON #temp_table4.reu_no = wr.Reu_no

--append列管事業機構到node table
INSERT INTO node
SELECT fac_no, code_no, 'A1', Fac_name, NULL, cle_no
FROM #temp_table5

--append清除機構到node table, 分為三種cases: (1)自行清除 (2)再利用者清除 (3)一般清除
--(1)
INSERT INTO node
SELECT DISTINCT fac_no, code_no, 'C', Fac_name, fac_no, reu_no
FROM #temp_table5
WHERE cle_no = 'C0000000' --自行清除

--(2)
INSERT INTO node
SELECT DISTINCT reu_no, code_no, 'C', Reu_name, fac_no, reu_no
FROM #temp_table5
WHERE cle_no = 'C1111111' --再利用者清除

--(3)
INSERT INTO node
SELECT DISTINCT cle_no, code_no, 'C', Cle_name, fac_no, reu_no
FROM #temp_table5
WHERE cle_no <> 'C0000000' --非自行清除
	AND cle_no <> 'C1111111' --非再利用者清除

DROP TABLE #temp_table3, #temp_table4, #temp_table5

--902 data in node table
SELECT *
FROM node n 


------------------------------
-- mapping: 最後要匯出的table --
------------------------------
CREATE TABLE mapping
(
	fac_no NVARCHAR(100),	--機構管編
	code_no NVARCHAR(100),	--代碼
	fac_type NVARCHAR(2),	--機構類型
	fac_name NVARCHAR(100)	--機構名稱
)

INSERT INTO mapping
SELECT DISTINCT fac_no, code_no, fac_type, fac_name 
FROM node n 

--569 data in mapping table
SELECT *
FROM mapping m 


--加入再利用機構-產品 (RP)--
SELECT DISTINCT reu_no, code_no, fac_type, Reu_name INTO #temp_table3
FROM #temp_table
WHERE fac_type = 'RM' --只要考慮上游清除的其他再利用就好，因為我們沒有去找上游事業的其他清除的再利用的銷售對象

SELECT DISTINCT reu_no, code_no, fac_type, Reu_name, ProductName INTO #temp_table4
FROM #temp_table3
LEFT JOIN IMP.dbo.ReUse_ReuProductSale rurps 
	ON OrganID = reu_no AND WasteName LIKE '%' + code_no + '%'

--append有銷售對象的再利用機構到mapping table
INSERT INTO mapping
SELECT reu_no, ProductName, 'RP', Reu_name
FROM #temp_table4
WHERE ProductName IS NOT NULL

DROP TABLE #temp_table3, #temp_table4

--573 data in mapping table
SELECT *
FROM mapping m 


--加入柯富伊(RM), 柯富伊(RP)--
INSERT INTO mapping
SELECT 'H47A6728', 'R-0201', 'RM', '柯富伊企業有限公司'

INSERT INTO mapping
SELECT 'H47A6728', '220099:其他未列名塑膠製品', 'RP', '柯富伊企業有限公司'

--575 data in mapping table
SELECT *
FROM mapping m 