-- Inspecting data
SELECT * FROM [dbo].[sales_data_sample]

--Checking unique values
SELECT DISTINCT status FROM sales_data_sample   --to plot
SELECT DISTINCT year_id FROM sales_data_sample
SELECT DISTINCT productline FROM sales_data_sample  --to plot
SELECT DISTINCT country FROM sales_data_sample    --to plot
SELECT DISTINCT territory FROM sales_data_sample    --to plot
SELECT DISTINCT dealsize FROM sales_data_sample     -- to plot

SELECT DISTINCT MONTH_ID FROM sales_data_sample
WHERE YEAR_ID = 2005


--ANALYSIS
--- grouping sales by productline
SELECT productline, SUM(sales) as Revenue
FROM sales_data_sample
GROUP BY PRODUCTLINE
ORDER BY 2 DESC

--- grouping sales by year
SELECT YEAR_ID, SUM(sales) as Revenue
FROM sales_data_sample
GROUP BY YEAR_ID
ORDER BY 2 DESC

--- grouping sales by dealsize
SELECT DEALSIZE, SUM(sales) as Revenue
FROM sales_data_sample
GROUP BY DEALSIZE
ORDER BY 2 DESC


--- What was the best month for sales in a specific year? How much was earned that month?
SELECT MONTH_ID, SUM(sales) as Revenue, COUNT(ORDERNUMBER) as Frequency
FROM sales_data_sample
where YEAR_ID = 2003  
GROUP BY MONTH_ID
ORDER BY 2 DESC

SELECT MONTH_ID, SUM(sales) as Revenue, COUNT(ORDERNUMBER) as Frequency
FROM sales_data_sample
where YEAR_ID = 2004  
GROUP BY MONTH_ID
ORDER BY 2 DESC
-- since 2005 only has 5 months of sales so not considered


--- Since November seems to be the best month, what products do they sell in November?
SELECT MONTH_ID, PRODUCTLINE, SUM(SALES) as Revenue, COUNT(ORDERNUMBER) as Frequency
FROM sales_data_sample
WHERE YEAR_ID = 2003 AND MONTH_ID = 11
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC

SELECT MONTH_ID, PRODUCTLINE, SUM(SALES) as Revenue, COUNT(ORDERNUMBER) as Frequency
FROM sales_data_sample
WHERE YEAR_ID = 2004 AND MONTH_ID = 11
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY 3 DESC


--- Who is the best customer?(using RFM analysis)

DROP TABLE IF EXISTS #rfm
;with rfm as
(	
	SELECT
		CUSTOMERNAME,
		SUM(SALES) as MonetaryValue,
		AVG(SALES) as AvgMonetaryValue,
		COUNT(ORDERNUMBER) as Frequency,
		MAX(ORDERDATE) as LastOrderDate,
		(SELECT MAX(ORDERDATE) FROM sales_data_sample) as MaxOrderDate,
		DATEDIFF(DD, MAX(ORDERDATE), (SELECT MAX(ORDERDATE) FROM sales_data_sample)) as  Recency
	FROM sales_data_sample
	GROUP BY CUSTOMERNAME
),
rfm_calc as
(
	SELECT r.*,
		NTILE(4) OVER(order by Recency) rfm_Recency,
		NTILE(4) OVER(order by Frequency) rfm_Frequency,
		NTILE(4) OVER(order by MonetaryValue) rfm_Monetary
	FROM rfm r
)
SELECT 
	c.*, rfm_Recency + rfm_Frequency + rfm_Monetary as rfm_cell,
	cast(rfm_Recency as varchar) + cast(rfm_Frequency as varchar) + cast(rfm_Monetary as varchar)rfm_cell_string
into #rfm
FROM rfm_calc c

SELECT CUSTOMERNAME, rfm_Recency, rfm_Frequency, rfm_Monetary,
	case
		when rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'  --lost customers
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Big spenders who haven’t purchased lately) slipping away
		when rfm_cell_string in (311, 411, 331) then 'new customers'
		when rfm_cell_string in (222, 223, 233, 322) then 'potential churners'
		when rfm_cell_string in (323, 333,321, 422, 332, 432) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
	end rfm_segment
 
FROM #rfm


-- What products are most often sold together?
--	SELECT * FROM sales_data_sample WHERE ORDERNUMBER = 10411

SELECT DISTINCT ORDERNUMBER, stuff(

	(SELECT ',' + PRODUCTCODE
	FROM sales_data_sample p
	WHERE ORDERNUMBER in
		(
			SELECT ORDERNUMBER
			FROM (
				SELECT ORDERNUMBER, count(*) rn
				FROM sales_data_sample
				WHERE STATUS = 'Shipped'
				GROUP BY ORDERNUMBER
			) m
			WHERE rn = 3
		)
		and p.ORDERNUMBER = s.ORDERNUMBER
		FOR xml path (''))
		
		, 1, 1, '') ProductCodes

FROM sales_data_sample s
ORDER BY 2 DESC