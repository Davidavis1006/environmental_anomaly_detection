--------------
-- n=2 step --
--------------

--上游清除委託的其他再利用機構 -> *
--上游列管事業委託的其他清除機構+再利用機構 -> **
CREATE TABLE RM_C
(
	fac_no NVARCHAR(100),	--事業機構管編
	cle_no NVARCHAR(100),	--清除機構管編
	reu_no NVARCHAR(100),	--再利用機構管編
	code_no NVARCHAR(100),	--代碼
	fac_type NVARCHAR(2)	--機構類型
)

DECLARE @reuse VARCHAR(100)			--再利用機構管編
SET @reuse = 'H47A6728'
DECLARE @fac_no NVARCHAR(100)		--機構管編
DECLARE @code_no NVARCHAR(100)		--代碼
DECLARE @fac_type NVARCHAR(2)		--機構類型
DECLARE @fac_name NVARCHAR(100)		--機構名稱
DECLARE @up_fac_no NVARCHAR(100)	--記錄: 上游機構
DECLARE @down_fac_no NVARCHAR(100)	--記錄: 下游機構
DECLARE load_cursor CURSOR FOR 
	SELECT fac_no, code_no, fac_type, fac_name, up_fac_no, down_fac_no
	FROM temp
OPEN load_cursor
FETCH NEXT FROM load_cursor INTO @fac_no, @code_no, @fac_type, @fac_name, @up_fac_no, @down_fac_no
WHILE @@FETCH_STATUS = 0
BEGIN
	IF @fac_type = 'C' --清除機構, 找它的其他再利用機構
	BEGIN 
		--再利用聯單
		INSERT INTO RM_C
		SELECT DISTINCT wdw.Dlist_no1, Cle_no, Reu_no, Waste_no, 'RM'
		FROM IMP_3.dbo.Waste_Dlist_wre1 wdw
		LEFT JOIN IMP_3.dbo.Waste_Dlist_wre2 wdw2 
			ON (wdw.Dlist_no1 = wdw2.Dlist_no1 AND wdw.Dlist_no2 = wdw2.Dlist_no2 AND wdw.Dlist_no3 = wdw2.Dlist_no3)
		WHERE Cle_no = @fac_no
			AND wdw.Dlist_no1 = @up_fac_no --要綁定上游事業機構
			AND Waste_no = @code_no
			AND Reu_no <> @reuse --不含原本的基準再利用
		UNION 
		--處理後聯單
		SELECT DISTINCT wdw3.Dlist_no1, Cle_no, Reu_no, Waste_no, 'RM'
		FROM IMP_3.dbo.Waste_Dlist_wt1 wdw3 
		LEFT JOIN IMP_3.dbo.Waste_Dlist_wt2 wdw4  
			ON (wdw3.Dlist_no1 = wdw4.Dlist_no1 AND wdw3.Dlist_no2 = wdw4.Dlist_no2 AND wdw3.Dlist_no3 = wdw4.Dlist_no3)
		WHERE Cle_no = @fac_no
			AND wdw3.Dlist_no1 = @up_fac_no
			AND Waste_no = @code_no
			AND Reu_no <> @reuse
	END
	ELSE --@fac_type = 'A1', 列管事業機構, 找它的其他清除機構+再利用機構
	BEGIN
		--再利用聯單
		INSERT INTO RM_C
		SELECT DISTINCT wdw5.Dlist_no1, Cle_no, Reu_no, Waste_no, 'C'
		FROM IMP_3.dbo.Waste_Dlist_wre1 wdw5 
		LEFT JOIN IMP_3.dbo.Waste_Dlist_wre2 wdw6 
			ON (wdw5.Dlist_no1 = wdw6.Dlist_no1 AND wdw5.Dlist_no2 = wdw6.Dlist_no2 AND wdw5.Dlist_no3 = wdw6.Dlist_no3)
		WHERE wdw5.Dlist_no1 = @fac_no
			AND Waste_no = @code_no
			AND Cle_no <> @down_fac_no --不含原本的下游清除
		UNION 
		--處理後聯單
		SELECT DISTINCT wdw7.Dlist_no1, Cle_no, Reu_no, Waste_no, 'C'
		FROM IMP_3.dbo.Waste_Dlist_wt1 wdw7 
		LEFT JOIN IMP_3.dbo.Waste_Dlist_wt2 wdw8 
			ON (wdw7.Dlist_no1 = wdw8.Dlist_no1 AND wdw7.Dlist_no2 = wdw8.Dlist_no2 AND wdw7.Dlist_no3 = wdw8.Dlist_no3)
		WHERE wdw7.Dlist_no1 = @fac_no
			AND Waste_no = @code_no
			AND Cle_no <> @down_fac_no
	END
	FETCH NEXT FROM load_cursor INTO @fac_no, @code_no, @fac_type, @fac_name, @up_fac_no, @down_fac_no
END
CLOSE load_cursor
DEALLOCATE load_cursor
GO

--補上再利用機構名稱
SELECT fac_no, cle_no, rc.reu_no, Reu_name, code_no, fac_type INTO #temp_table
FROM RM_C rc 
LEFT JOIN IMP_3.dbo.Waste_Reuse wr --回收再利用機構基本資料檔
	ON rc.reu_no = wr.Reu_no

--補上清除機構名稱
SELECT DISTINCT fac_no, #temp_table.cle_no, Cle_name, reu_no, Reu_name, code_no, fac_type INTO #temp_table2
FROM #temp_table
LEFT JOIN IMP_3.dbo.Waste_Clean wc --清除機構基本資料檔
	ON #temp_table.cle_no = wc.Cle_no 

--補上列管事業機構名稱
SELECT #temp_table2.fac_no, Fac_name, cle_no, Cle_name, reu_no, Reu_name, code_no, fac_type INTO #temp_table3
FROM #temp_table2
LEFT JOIN IMP_3.dbo.Waste_Factory wf --事業機構基本資料檔
	ON #temp_table2.fac_no = wf.Fac_no

--append上游清除的再利用機構到node table
INSERT INTO node
SELECT reu_no, code_no, 'RM', Reu_name, cle_no, NULL
FROM #temp_table3
WHERE fac_type = 'RM' --再利用單位(原料)

--append上游事業的清除機構到node table
INSERT INTO node
SELECT fac_no, code_no, 'C', Fac_name, fac_no, reu_no
FROM #temp_table3
WHERE fac_type = 'C'
	AND cle_no = 'C0000000' --自行清除
	
INSERT INTO node
SELECT reu_no, code_no, 'C', Reu_name, fac_no, reu_no
FROM #temp_table3
WHERE fac_type = 'C'
	AND cle_no = 'C1111111' --再利用者清除

INSERT INTO node
SELECT cle_no, code_no, 'C', Cle_name, fac_no, reu_no
FROM #temp_table3
WHERE fac_type = 'C'
	AND cle_no <> 'C0000000' --非自行清除
	AND cle_no <> 'C1111111' --非再利用者清除

--append上游事業的清除的再利用機構到node table
INSERT INTO node
SELECT reu_no, code_no, 'RM', Reu_name, cle_no, NULL
FROM #temp_table3
WHERE fac_type = 'C'

DROP TABLE #temp_table3

SELECT *
FROM node n 