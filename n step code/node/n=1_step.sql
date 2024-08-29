CREATE TABLE node
(
	fac_no NVARCHAR(100),		--機構管編
	code_no NVARCHAR(100),		--代碼
	fac_type NVARCHAR(2),		--機構類型
	fac_name NVARCHAR(100),		--機構名稱
	up_fac_no NVARCHAR(100),	--記錄: 上游機構
	down_fac_no NVARCHAR(100)	--記錄: 下游機構
)

CREATE TABLE temp
(
	fac_no NVARCHAR(100),		--機構管編
	code_no NVARCHAR(100),		--代碼
	fac_type NVARCHAR(2),		--機構類型
	fac_name NVARCHAR(100),		--機構名稱
	up_fac_no NVARCHAR(100),	--記錄: 上游機構
	down_fac_no NVARCHAR(100)	--記錄: 下游機構
)

--------------
-- n=1 step --
--------------

--銷售對象--
DECLARE @reuse VARCHAR(100)		--再利用機構管編
DECLARE @code_no VARCHAR(100)	--代碼
SET @reuse = 'H47A6728' --柯富伊
SET @code_no = 'R-0201' --廢塑膠
INSERT INTO node
SELECT DISTINCT TargetID, ProductName, 'S', TargetName, OrganID, NULL
FROM IMP.dbo.ReUse_ReuProductSale rurps 
WHERE OrganID = @reuse
	AND WasteName LIKE '%' + @code_no + '%' --廢棄物代碼+廢棄物名稱, 篩選出包含@code_no的, e.g. %R-0201%

SELECT *
FROM node n 


--非列管事業機構+清除機構--
DECLARE @reuse VARCHAR(100)		--再利用機構管編
DECLARE @code_no VARCHAR(100)	--代碼
SET @reuse = 'H47A6728'
SET @code_no = 'R-0201'
SELECT DISTINCT FacID, Fac_Name, Cle_No, Reu_No, Waste_No INTO #temp_table
FROM IMP_1.dbo.Waste_ReuMonReportN_Commit wrmrnc 
WHERE Reu_No = @reuse
	AND Waste_No = @code_no

--補上清除機構名稱
SELECT DISTINCT FacID, Fac_Name, #temp_table.Cle_No, Cle_name, Reu_No, Waste_No INTO #temp_table2
FROM #temp_table
LEFT JOIN IMP_3.dbo.Waste_Clean wc --清除機構基本資料檔
	ON #temp_table.Cle_No = wc.Cle_no

--補上再利用機構名稱
SELECT FacID, Fac_Name, Cle_No, Cle_name, #temp_table2.Reu_No, Reu_name, Waste_No INTO #temp_table3
FROM #temp_table2
LEFT JOIN IMP_3.dbo.Waste_Reuse wr --回收再利用機構基本資料檔
	ON #temp_table2.Reu_No = wr.Reu_no

--append非列管事業到node table
INSERT INTO node
SELECT FacID, Waste_No, 'A2', Fac_Name, NULL, Cle_No
FROM #temp_table3

--append清除機構到node table, 分為三種cases: (1)自行清除 (2)再利用者清除 (3)一般清除
--(1)
INSERT INTO node
SELECT FacID, Waste_No, 'C', Fac_Name, FacID, Reu_No
FROM #temp_table3
WHERE Cle_No = 'C0000000' --自行清除

--(2)
INSERT INTO node
SELECT Reu_No, Waste_No, 'C', Reu_name, FacID, Reu_No
FROM #temp_table3
WHERE Cle_No = 'C1111111' --再利用者清除

--(3)
INSERT INTO node
SELECT Cle_No, Waste_No, 'C', Cle_name, FacID, Reu_No
FROM #temp_table3
WHERE Cle_No <> 'C0000000' --非自行清除
	AND Cle_No <> 'C1111111' --非再利用者清除

DROP TABLE #temp_table, #temp_table2, #temp_table3

SELECT *
FROM node n 


--列管事業機構+清除機構 (再利用聯單)--
DECLARE @reuse VARCHAR(100)		--再利用機構管編
DECLARE @code_no VARCHAR(100) 	--代碼
SET @reuse = 'H47A6728'
SET @code_no = 'R-0201'
SELECT DISTINCT wdw.Dlist_no1, Cle_no, Reu_no, Waste_no INTO #temp_table
FROM IMP_3.dbo.Waste_Dlist_wre1 wdw 
LEFT JOIN IMP_3.dbo.Waste_Dlist_wre2 wdw2 
	ON (wdw.Dlist_no1 = wdw2.Dlist_no1 AND wdw.Dlist_no2 = wdw2.Dlist_no2 AND wdw.Dlist_no3 = wdw2.Dlist_no3)
WHERE Reu_no = @reuse
	AND Waste_no = @code_no

--補上列管事業機構名稱
SELECT Dlist_no1, Fac_name, Cle_no, Reu_no, Waste_no INTO #temp_table2
FROM #temp_table
LEFT JOIN IMP_3.dbo.Waste_Factory wf --事業機構基本資料檔
	ON Dlist_no1 = Fac_no

--補上清除機構名稱
SELECT DISTINCT Dlist_no1, Fac_name, #temp_table2.Cle_no, Cle_name, Reu_no, Waste_no INTO #temp_table3
FROM #temp_table2
LEFT JOIN IMP_3.dbo.Waste_Clean wc --清除機構基本資料檔
	ON #temp_table2.Cle_no = wc.Cle_no 

--補上再利用機構名稱
SELECT Dlist_no1, Fac_name, Cle_no, Cle_name, #temp_table3.Reu_no, Reu_name, Waste_no INTO #temp_table4
FROM #temp_table3
LEFT JOIN IMP_3.dbo.Waste_Reuse wr --回收再利用機構基本資料檔
	ON #temp_table3.Reu_no = wr.Reu_no

--append列管事業機構到node table
INSERT INTO node
SELECT Dlist_no1, Waste_no, 'A1', Fac_name, NULL, Cle_no
FROM #temp_table4

--暫存一份到temp table
INSERT INTO temp
SELECT Dlist_no1, Waste_no, 'A1', Fac_name, NULL, Cle_no
FROM #temp_table4

--append清除機構到node table, 分為三種cases: (1)自行清除 (2)再利用者清除 (3)一般清除
--(1)
INSERT INTO node
SELECT Dlist_no1, Waste_no, 'C', Fac_name, Dlist_no1, Reu_no
FROM #temp_table4
WHERE Cle_no = 'C0000000' --自行清除

--(2)
INSERT INTO node
SELECT Reu_no, Waste_no, 'C', Reu_name, Dlist_no1, Reu_no
FROM #temp_table4
WHERE Cle_no = 'C1111111' --再利用者清除

--(3)
INSERT INTO node
SELECT Cle_no, Waste_no, 'C', Cle_name, Dlist_no1, Reu_no
FROM #temp_table4
WHERE Cle_no <> 'C0000000' --非自行清除
	AND Cle_no <> 'C1111111' --非再利用者清除

--暫存一份到temp table (不用考慮Cle_no = '自行清除', '再利用者清除'了，因為 自行清除, 再利用者清除 不會有其他再利用機構)
INSERT INTO temp
SELECT Cle_no, Waste_no, 'C', Cle_name, Dlist_no1, Reu_no
FROM #temp_table4
WHERE Cle_no <> 'C0000000' --非自行清除
	AND Cle_no <> 'C1111111' --非再利用者清除

DROP TABLE #temp_table, #temp_table2, #temp_table3, #temp_table4

SELECT *
FROM node n 


--列管事業機構+清除機構 (處理後聯單)--
DECLARE @reuse VARCHAR(100)		--再利用機構管編
DECLARE @code_no VARCHAR(100)	--代碼
SET @reuse = 'H47A6728'
SET @code_no = 'R-0201'
SELECT DISTINCT wdw.Dlist_no1, Cle_no, Reu_no, Waste_no INTO #temp_table
FROM IMP_3.dbo.Waste_Dlist_wt1 wdw 
LEFT JOIN IMP_3.dbo.Waste_Dlist_wt2 wdw2 
	ON (wdw.Dlist_no1 = wdw2.Dlist_no1 AND wdw.Dlist_no2 = wdw2.Dlist_no2 AND wdw.Dlist_no3 = wdw2.Dlist_no3)
WHERE Reu_no = @reuse
	AND Waste_no = @code_no

--補上列管事業機構名稱
SELECT Dlist_no1, Fac_name, Cle_no, Reu_no, Waste_no INTO #temp_table2
FROM #temp_table
LEFT JOIN IMP_3.dbo.Waste_Factory wf 
	ON Dlist_no1 = Fac_no

--補上清除機構名稱
SELECT DISTINCT Dlist_no1, Fac_name, #temp_table2.Cle_no, Cle_name, Reu_no, Waste_no INTO #temp_table3
FROM #temp_table2
LEFT JOIN IMP_3.dbo.Waste_Clean wc 
	ON #temp_table2.Cle_no = wc.Cle_no

--補上再利用機構名稱
SELECT Dlist_no1, Fac_name, Cle_no, Cle_name, #temp_table3.Reu_no, Reu_name, Waste_no INTO #temp_table4
FROM #temp_table3
LEFT JOIN IMP_3.dbo.Waste_Reuse wr --回收再利用機構基本資料檔
	ON #temp_table3.Reu_no = wr.Reu_no

--append列管事業機構到node table
INSERT INTO node
SELECT Dlist_no1, Waste_no, 'A1', Fac_name, NULL, Cle_no
FROM #temp_table4

--暫存一份到temp table
INSERT INTO temp
SELECT Dlist_no1, Waste_no, 'A1', Fac_name, NULL, Cle_no
FROM #temp_table4

--append清除機構到node table, 分為三種cases: (1)自行清除 (2)再利用者清除 (3)一般清除
--(1)
INSERT INTO node
SELECT Dlist_no1, Waste_no, 'C', Fac_name, Dlist_no1, Reu_no
FROM #temp_table4
WHERE Cle_no = 'C0000000' --自行清除

--(2)
INSERT INTO node
SELECT Reu_no, Waste_no, 'C', Reu_name, Dlist_no1, Reu_no
FROM #temp_table4
WHERE Cle_no = 'C1111111' --再利用者清除

--(3)
INSERT INTO node
SELECT Cle_no, Waste_no, 'C', Cle_name, Dlist_no1, Reu_no
FROM #temp_table4
WHERE Cle_no <> 'C0000000' --非自行清除
	AND Cle_no <> 'C1111111' --非再利用者清除

--暫存一份到temp table (不用考慮Cle_no = '自行清除', '再利用者清除'了，因為 自行清除, 再利用者清除 不會有其他再利用機構)
INSERT INTO temp
SELECT Cle_no, Waste_no, 'C', Cle_name, Dlist_no1, Reu_no
FROM #temp_table4
WHERE Cle_no <> 'C0000000' --非自行清除
	AND Cle_no <> 'C1111111' --非再利用者清除

DROP TABLE #temp_table, #temp_table2, #temp_table3, #temp_table4

SELECT *
FROM node n 