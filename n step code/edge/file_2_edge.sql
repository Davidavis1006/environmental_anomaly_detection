CREATE TABLE edge
(
	fac_no1 NVARCHAR(100),		--機構管編
	code_no1 NVARCHAR(100),		--代碼
	fac_type1 NVARCHAR(2),		--機構類型
	fac_name1 NVARCHAR(100),	--機構名稱
	fac_no2 NVARCHAR(100),
	code_no2 NVARCHAR(100),
	fac_type2 NVARCHAR(2),
	fac_name2 NVARCHAR(100)
)

--
--edge list
--

--
--再利用單位-原料(RM) -> 再利用單位-產品(RP)
--

SELECT * INTO #temp_table
FROM mapping
WHERE fac_type = 'RP'

SELECT *
FROM #temp_table

INSERT INTO edge
SELECT fac_no, 'R-0201', 'RM', fac_name, fac_no, code_no, fac_type, fac_name
FROM #temp_table

SELECT *
FROM edge 

--
--再利用單位-產品(RP) -> 銷售對象(S)
--

SELECT DISTINCT * INTO #temp_table2
FROM node 
WHERE fac_type = 'S'

SELECT *
FROM #temp_table2

INSERT INTO edge
SELECT #temp_table.fac_no, #temp_table.code_no, #temp_table.fac_type, #temp_table.fac_name, #temp_table2.fac_no, #temp_table2.code_no, #temp_table2.fac_type, #temp_table2.fac_name
FROM #temp_table2
LEFT JOIN #temp_table
	ON #temp_table2.up_fac_no = #temp_table.fac_no

SELECT *
FROM edge

--
--列管事業(A1) -> 清除單位(C)
--

--正常清除的
SELECT DISTINCT * INTO #temp_table
FROM node
WHERE fac_type = 'A1'
	AND down_fac_no <> 'C0000000'
	AND down_fac_no <> 'C1111111'

SELECT *
FROM #temp_table
ORDER BY fac_no

INSERT INTO edge
SELECT #temp_table.fac_no, #temp_table.code_no, #temp_table.fac_type, #temp_table.fac_name, mapping.fac_no, mapping.code_no, mapping.fac_type, mapping.fac_name
FROM #temp_table
LEFT JOIN mapping
	ON #temp_table.down_fac_no = mapping.fac_no AND mapping.fac_type = 'C'

SELECT *
FROM edge

--自行清除的
SELECT DISTINCT * INTO #temp_table2
FROM node
WHERE fac_type = 'A1'
	AND down_fac_no = 'C0000000'

SELECT *
FROM #temp_table2

INSERT INTO edge
SELECT #temp_table2.fac_no, #temp_table2.code_no, #temp_table2.fac_type, #temp_table2.fac_name, node.fac_no, node.code_no, node.fac_type, node.fac_name
FROM #temp_table2
LEFT JOIN node 
	ON #temp_table2.fac_no = node.fac_no AND node.fac_type = 'C'

SELECT *
FROM edge
	
--再利用者清除的
SELECT DISTINCT * INTO #temp_table3
FROM node
WHERE fac_type = 'A1'
	AND down_fac_no = 'C1111111'

SELECT *
FROM #temp_table3

INSERT INTO edge
SELECT #temp_table3.fac_no, #temp_table3.code_no, #temp_table3.fac_type, #temp_table3.fac_name, node.fac_no, node.code_no, node.fac_type, node.fac_name
FROM #temp_table3
LEFT JOIN node 
	ON #temp_table3.fac_no = node.up_fac_no AND node.fac_type = 'C' AND node.fac_no = node.down_fac_no

SELECT *
FROM edge

DROP TABLE #temp_table, #temp_table2, #temp_table3

--
--非列管事業(A2) -> 清除單位(C)
--

--正常清除的
SELECT DISTINCT * INTO #temp_table
FROM node 
WHERE fac_type = 'A2'
	AND down_fac_no <> 'C0000000'
	AND down_fac_no <> 'C1111111'

SELECT *
FROM #temp_table
ORDER BY fac_no

INSERT INTO edge
SELECT #temp_table.fac_no, #temp_table.code_no, #temp_table.fac_type, #temp_table.fac_name, mapping.fac_no, mapping.code_no, mapping.fac_type, mapping.fac_name
FROM #temp_table
LEFT JOIN mapping
	ON #temp_table.down_fac_no = mapping.fac_no AND mapping.fac_type = 'C'

SELECT *
FROM edge
	
--自行清除的
SELECT DISTINCT * INTO #temp_table2
FROM node
WHERE fac_type = 'A2'
	AND down_fac_no = 'C0000000'
	
SELECT *
FROM #temp_table2
ORDER BY fac_no

INSERT INTO edge
SELECT DISTINCT #temp_table2.fac_no, #temp_table2.code_no, #temp_table2.fac_type, #temp_table2.fac_name, node.fac_no, node.code_no, node.fac_type, node.fac_name
FROM #temp_table2
LEFT JOIN node 
	ON #temp_table2.fac_no = node.fac_no AND node.fac_type = 'C' AND #temp_table2.fac_name = node.fac_name
	
SELECT *
FROM edge

--再利用者清除的
SELECT DISTINCT * INTO #temp_table3
FROM node
WHERE fac_type = 'A2'
	AND down_fac_no = 'C1111111'
	
SELECT *
FROM #temp_table3

INSERT INTO edge
SELECT #temp_table3.fac_no, #temp_table3.code_no, #temp_table3.fac_type, #temp_table3.fac_name, node.fac_no, node.code_no, node.fac_type, node.fac_name
FROM #temp_table3
LEFT JOIN node 
	ON #temp_table3.fac_no = node.up_fac_no AND node.fac_type = 'C' AND node.fac_no = node.down_fac_no
		
SELECT *
FROM edge

DROP TABLE #temp_table, #temp_table2, #temp_table3

--
--清除單位(C) -> 再利用單位-原料(RM)
--

SELECT DISTINCT fac_no, code_no, fac_type, fac_name, down_fac_no INTO #temp_table --只看下游再利用單位
FROM node
WHERE fac_type = 'C'

SELECT *
FROM #temp_table

INSERT INTO edge
SELECT #temp_table.fac_no, #temp_table.code_no, #temp_table.fac_type, #temp_table.fac_name, m.fac_no, m.code_no, m.fac_type, m.fac_name
FROM #temp_table
LEFT JOIN mapping m 
	ON #temp_table.down_fac_no = m.fac_no AND m.fac_type = 'RM'

SELECT *
FROM edge 
	
DROP TABLE edge

SELECT wdw.Dlist_no1, wdw.Dlist_no2, wdw.Dlist_no3, Fac_no, Cle_no, Reu_no, Wcle_date, wdw2.Waste_no, wdw2.App_Qty 
FROM IMP_3.dbo.Waste_Dlist_wre1 wdw 
LEFT JOIN IMP_3.dbo.Waste_Dlist_wre2 wdw2 
	ON (wdw.Dlist_no1 = wdw2.Dlist_no1 AND wdw.Dlist_no2 = wdw2.Dlist_no2 AND wdw.Dlist_no3 = wdw2.Dlist_no3)
WHERE wdw.Dlist_no1 = 'H4604228'
	AND Cle_no = 'F23A3423'
	AND Waste_no = 'R-0201'
ORDER BY Wcle_date 

SELECT *
FROM IMP.dbo.Industry i 
WHERE AccName = '桂森企業有限公司' OR AccName = '發彩環保工程有限公司'

--
--edge weight
--

--
--再利用單位-原料(RM) -> 再利用單位-產品(RP)
--
SELECT *
FROM IMP_3.dbo.Waste_tmp_month_statistics wtms 
WHERE fac_no = 'K8200222'
	AND CodeNo = 'R-0201'
	AND AppType = 'manu' --使用
	AND DType = 1 --原料
ORDER BY AppTime

--
--再利用單位-產品(RP) -> 銷售對象(S)
--
SELECT *
FROM IMP.dbo.ReUse_ReuProductSale rurps 
WHERE OrganID = 'H51A9221'
	AND (TargetID = '97337016' OR TargetName = '慶毅有限公司')
	AND WasteName LIKE '%R-0201%'
ORDER BY YMDate --申報年月

--
--列管事業(A1) -> 清除單位(C)
--
SELECT wdw.Dlist_no1, Cle_no, Reu_no, Wcle_date, Waste_no, App_Qty INTO #temp_table
FROM IMP_3.dbo.Waste_Dlist_wre1 wdw 
LEFT JOIN IMP_3.dbo.Waste_Dlist_wre2 wdw2 
	ON wdw.Dlist_no1 = wdw2.Dlist_no1 
WHERE wdw.Dlist_no2 = wdw2.Dlist_no2 
	AND wdw.Dlist_no3 = wdw2.Dlist_no3 
	AND wdw.Dlist_no1 = 'R9000269'
	AND Cle_no = 'C1111111'
	AND Reu_no = 'K8200222'
	AND Waste_no = 'R-0201'
UNION
SELECT wdw3.Dlist_no1, Cle_no, Reu_no, Wcle_date, Waste_no, App_Qty
FROM IMP_3.dbo.Waste_Dlist_wt1 wdw3 
LEFT JOIN IMP_3.dbo.Waste_Dlist_wt2 wdw4  
	ON wdw3.Dlist_no1 = wdw4.Dlist_no1 
WHERE wdw3.Dlist_no2 = wdw4.Dlist_no2 
	AND wdw3.Dlist_no3 = wdw4.Dlist_no3 
	AND wdw3.Dlist_no1 = 'R9000269'
	AND Cle_no = 'C1111111'
	AND Reu_no = 'K8200222'
	AND Waste_no = 'R-0201'
	
SELECT *
FROM #temp_table
ORDER BY Wcle_date --清運日期

SELECT SUM(App_Qty), MONTH(Wcle_date), YEAR(Wcle_date)
FROM #temp_table
GROUP BY MONTH(Wcle_date), YEAR(Wcle_date)

DROP TABLE #temp_table

--
--非列管事業(A2) -> 清除單位(C)
--
SELECT Reu_No, FacID, Cle_No, Waste_No, ReuQty, Rec_Date, Reu_Date INTO #temp_table
FROM IMP_1.dbo.Waste_ReuMonReportN_Commit wrmrnc 
WHERE FacID = '07568009'
	AND Cle_No = 'C1111111'
	AND Waste_No = 'R-0201'

SELECT *
FROM #temp_table
ORDER BY Rec_Date --接受處理(再利用)日期

SELECT SUM(ReuQty), MONTH(Rec_Date), YEAR(Rec_Date)
FROM #temp_table
GROUP BY MONTH(Rec_Date), YEAR(Rec_Date)

DROP TABLE #temp_table

SELECT *
FROM IMP.dbo.Industry i 
WHERE BusinessLicenseID IN ('16955115', '24424648', '84994278')

SELECT *
FROM IMP.dbo.Industry i 
WHERE ControlNo = 'H46B5841'

--
--清除單位(C) -> 再利用單位-原料(RM)
--
SELECT wdw.Dlist_no1, Cle_no, Reu_no, Wcle_date, Waste_no, App_Qty INTO #temp_table
FROM IMP_3.dbo.Waste_Dlist_wre1 wdw 
LEFT JOIN IMP_3.dbo.Waste_Dlist_wre2 wdw2 
	ON wdw.Dlist_no1 = wdw2.Dlist_no1
WHERE wdw.Dlist_no2 = wdw2.Dlist_no2
	AND wdw.Dlist_no3 = wdw2.Dlist_no3
	AND Cle_no = 'C0000000'
	AND Reu_no = 'H5200215'
	AND Waste_no = 'R-0201'
	AND wdw.Dlist_no1 = '07568009'
UNION
SELECT wdw3.Dlist_no1, Cle_no, Reu_no, Wcle_date, Waste_no, App_Qty
FROM IMP_3.dbo.Waste_Dlist_wt1 wdw3
LEFT JOIN IMP_3.dbo.Waste_Dlist_wt2 wdw4 
	ON wdw3.Dlist_no1 = wdw4.Dlist_no1 
WHERE wdw3.Dlist_no2 = wdw4.Dlist_no2 
	AND wdw3.Dlist_no3 = wdw4.Dlist_no3 
	AND Cle_no = 'C0000000'
	AND Reu_no = 'H5200215'
	AND Waste_no = 'R-0201'
	AND wdw3.Dlist_no1 = '07568009'
UNION
SELECT FacID AS Dlist_no1, Cle_No AS Cle_no, Reu_No AS Reu_no, Rec_Date AS Wcle_date, Waste_No AS Waste_no, ReuQty AS App_Qty
FROM IMP_1.dbo.Waste_ReuMonReportN_Commit wrmrnc
WHERE Cle_No = 'C0000000'
	AND Reu_No = 'H5200215'
	AND Waste_No = 'R-0201'
	AND FacID = '07568009'
	
SELECT *
FROM #temp_table
ORDER BY Wcle_date

SELECT SUM(App_Qty), MONTH(Wcle_date), YEAR(Wcle_date)
FROM #temp_table
GROUP BY MONTH(Wcle_date), YEAR(Wcle_date)
--ORDER BY YEAR(Wcle_date), MONTH(Wcle_date)

DROP TABLE #temp_table

USE tempdb
GO

-- 強制釋放佔用的記憶體
DBCC FREESYSTEMCACHE ('ALL')
DBCC FREEPROCCACHE
DBCC DROPCLEANBUFFERS
DBCC FREESESSIONCACHE
GO

SELECT *
FROM IMP.dbo.Industry i 
WHERE ControlNo IN ('H46B5841', 'H46B9873')

SELECT *
FROM IMP.dbo.Industry i 
WHERE AccName = '振銘環保工程股份有限公司'

SELECT *
FROM IMP.dbo.Industry i 
WHERE BusinessLicenseID = '80252978'