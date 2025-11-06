--1. Analyze Sales Performance Overtime(Over Years)
SELECT DISTINCT YEAR(order_date) AS "Year" ,
       SUM(sales_amount) AS "Total Sales" ,
       COUNT(DISTINCT customer_key) AS "Total Customers",
       SUM(quantity) AS "Total Quantity"
FROM fact_sales
WHERE YEAR(order_date) IS NOT NULL
GROUP BY YEAR(order_date) 
ORDER BY "Year" ASC


--Output:

---2010	  43419    14     14
---2011	  7075088  2216   2216
---2012	  5842231  3255  3397
---2013	  16344878 17427  52807
---2014	  45642    834    1970


--2. Analyze Sales Performance Overtime(Over Month)
SELECT DISTINCT FORMAT(order_date , 'yyyy-MMMM') AS "Order Month" ,
       SUM(sales_amount) AS "Total Sales" ,
       COUNT(DISTINCT customer_key) AS "Total Customers",
       SUM(quantity) AS "Total Quantity"
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date , 'yyyy-MMMM')
ORDER BY FORMAT(order_date , 'yyyy-MMMM') ASC

--Output:

---2010-December	43419	14	14
---2011-April	   502042	157	157
---2011-August	  614516	193	193
---2011-December  669395	222	222
---2011-February  466307	144	144
---2011-January	  469795	144	144
---2011-July	  596710	188	188
---2011-June	   737793	230	230
---2011-March	  485165	150	150
---2011-May	      561647	174	174
---2011-November  660507	208	208
---2011-October	  708164	221	221
---2011-September 603047	185	185
---2012-April	  400324	219	219
---2012-August	  523887	294	294
---2012-December  624454	354	483
---2012-February  506992	260	260
---2012-January	  495363	252	252
---2012-July	  444533	246	246
---2012-June	  555142	318	318
---2012-March	  373478	212	212
---2012-May	      358866	207	207
---2012-November  537918	324	324
---2012-October	  535125	313	313
---2012-September 486149   269 269
---2013-April	  1045860 1564 3979
---2013-August	 1545910	1898	4848
---2013-December 1874128	2133	5520
---2013-February  771218	1373	3454
---2013-January	  857758	627	    1677
--2013-July	     1371595	1796	4673
---2013-June	 1642948	1948	5025
---2013-March	 1049732	1631	4087
---2013-May	     1284456	1719	4400
---2013-November 1780688	2036	5224
---2013-October	 1673261	2073	5304
---2013-September 1447324	1832	4616
---2014-January	   45642	834	    1970



--2. Cumulative Analysis

---2.1 Calculate The Total Sales Per Month and The Running Total of Sales Overtime.
SELECT Order_Date,
       Total_Sales,
       SUM(Total_Sales) OVER(PARTITION BY YEAR(order_date) ORDER BY YEAR(order_date) ASC) AS "Runing Total Sales",
       Average_Price

FROM(
     SELECT DATETRUNC(YEAR,order_date) AS Order_Date,
            SUM(sales_amount) AS Total_Sales,
            AVG(price) AS Average_Price
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR,order_date)
) AS Sub_Query
GROUP BY Order_Date , Total_Sales , Average_Price



--3. Performance Analysis

---3.1 Analyze the yearly performance of products by comparing their sales to both the average sales performance
---of the product and the previous year's sales
WITH Yearly_Product_Sales AS (
SELECT YEAR(FS.order_date) AS Order_Year,
       DP.product_name,
       SUM(FS.sales_amount) AS Current_Sales
FROM fact_sales AS FS
LEFT OUTER JOIN dim_products AS DP
ON DP.product_key = FS.product_key
WHERE FS.order_date IS NOT NULL
GROUP BY YEAR(FS.order_date),
DP.product_name
)

SELECT Order_Year,
       product_name,
       Current_Sales,
       AVG(Current_Sales) OVER(PARTITION BY product_name) AS Avg_Sales,
       Current_Sales - AVG(Current_Sales) OVER (PARTITION BY product_name) AS Diff_Avg_Sales,
       CASE WHEN Current_Sales - AVG(Current_Sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
            WHEN Current_Sales - AVG(Current_Sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
            ELSE 'Avg' 
       END AS Avg_Change,
       LAG(Current_Sales) OVER (PARTITION BY product_name ORDER BY order_year) AS Previous_Year_Sales,
       Current_Sales - LAG(Current_Sales) OVER (PARTITION BY product_name ORDER BY order_year) AS Diff_Previous_Year_Sales,
       CASE WHEN Current_Sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
            WHEN Current_Sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
            ELSE 'Lag Avg'
            END AS Lag_Status
FROM Yearly_Product_Sales
ORDER BY product_name ASC , Order_Year ASC



--4. Part To Whole Analysis
---4.1 Which Categories Contribute the Most To Overall Sales
WITH Categories_Sales AS (
SELECT DISTINCT DP.category , 
                SUM(FS.sales_amount) AS Total_Sales
FROM fact_sales AS FS
INNER JOIN dim_products AS DP
ON DP.product_key = FS.product_key
WHERE category IS NOT NULL
GROUP BY DP.category
)

SELECT 
    category,
    CONVERT(INT , Total_Sales) AS Total_Sales,
    CONCAT(FORMAT(Total_Sales * 100.0 / SUM(Total_Sales) OVER (), 'N2'),'%') AS Percent_of_Total_Sales
FROM Categories_Sales
ORDER BY (Total_Sales * 100.0 / SUM(Total_Sales) OVER ()) DESC;


--Output:

---Bikes	    28316272	96.46%
---Accessories	  700262	 2.39%
---Clothing	      339716	 1.16%


--5. Data Segmentation

---5.1 Segment Products into Cost Ranges and Count How Many Products Fall Into Each Segment
WITH Cost_Status AS(
SELECT product_key , 
       product_name , 
       cost ,
       CASE WHEN cost < 100 THEN 'Below 100'
            WHEN cost BETWEEN 100 AND 500 THEN '100-500'
            WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
            ELSE 'Above 1000'
        END AS Cost_Range
FROM dim_products
)

SELECT COUNT(product_name) AS Total_Products , Cost_Range
FROM Cost_Status
GROUP BY Cost_Range
ORDER BY COUNT(product_name) DESC

--Output:

---110	Below 100
---101	100-500
---45	500-1000
---39	Above 1000


---5.2 Segment Customers into three Segments Based on Their Spending Behavior
WITH Customer_Status AS (
SELECT DC.first_name + ' ' + DC.last_name AS Customer_Name , 
       MIN(FS.order_date) AS First_Order_Date,
       MAX(FS.order_date) AS Last_Order_Date,
       DATEDIFF(MONTH,MIN(FS.order_date),MAX(FS.order_date)) AS Lifespan,
       SUM(DP.cost) AS Total_Spending
FROM dim_products AS DP
INNER JOIN fact_sales AS FS
ON DP.product_key = FS.product_key
INNER JOIN dim_customers AS DC
ON DC.customer_key = FS.customer_key
GROUP BY DC.first_name + ' ' + DC.last_name
)

SELECT Customer_Status_Type,       
COUNT(Customer_Name) AS Total_Customers
FROM (SELECT Customer_Name,
       Total_Spending,
       Lifespan,
       CASE WHEN Total_Spending > 5000 AND Lifespan >= 12 THEN 'VIP'
            WHEN Total_Spending <= 5000 AND Lifespan >= 12 THEN 'Regular'
        ELSE 'New'
        END AS Customer_Status_Type
FROM Customer_Status) AS T
GROUP BY Customer_Status_Type
ORDER BY Total_Customers DESC


--Output:

---New	   14543
---Regular	3800
---VIP	      56


/*
Customer Report
================================================================================
Purpose:
        This Report Consolidates Key Customer Mertics and Behaviors

Highlights:
           1. Gathers Essential Fields Such as Names , Ages , Transaction Details.
           2. Segments Customers into Categories (VIP , Regular , New) and Age Groups.
           3. Aggregates Customer Level Metrics:
              --Total Orders
              --Total Sales
              --Total Quantity Purchased
              --Total Products
              --Last Order Date
              --Lifespan (in months)
           4. Calculates Valuable KPIs:
              --Recency (Months Since Last Orders)
              --Average Order Value
              --Average Monthly Spend
================================================================================
*/

/*------------------------------------------------------------------------------
1) Base Query: Retrieves Core Columns From Tables
--------------------------------------------------------------------------------*/
CREATE VIEW Report_Customers
WITH ENCRYPTION
AS
WITH Base_Query AS (
SELECT FS.order_number,
       FS.product_key,
       FS.order_date,
       FS.sales_amount,
       FS.quantity,
       DC.customer_key,
       DC.customer_number,
       CONCAT(DC.first_name, ' '  , DC.last_name) AS Customer_Name,
       DATEDIFF(YEAR , DC.birthdate , GETDATE()) AS Age
FROM fact_sales AS FS
INNER JOIN dim_customers AS DC
ON DC.customer_key = FS.customer_key
WHERE FS.order_date IS NOT NULL AND DC.birthdate IS NOT NULL
) , 

/*
2)Customer Aggregations: Summarizes Key Metrics at the customer level
*/
Customer_Aggregation AS (
SELECT customer_key,
       customer_number,
       Customer_Name,
       Age,
       COUNT(DISTINCT order_number) AS Total_Orders,
       SUM(sales_amount) AS Total_Sales,
       SUM(quantity) AS Total_Quantity,
       COUNT(DISTINCT product_key) AS Total_Products,
       MAX(order_date) AS Last_Order_Date,
       DATEDIFF(MONTH , MIN(order_date) , MAX(order_date)) AS Lifespan
FROM Base_Query
GROUP BY customer_key , customer_number , Customer_Name  , Age)

SELECT
     customer_key,
     customer_number,
     Customer_Name,
     Age,

     CASE 
         WHEN Age < 20 THEN 'Under 20'
         WHEN Age BETWEEN 20 AND 29 THEN '20-29'
         WHEN Age BETWEEN 30 AND 39 THEN '30-39'
         WHEN Age BETWEEN 40 AND 49 THEN '40-49'
     ELSE '50 and Above'
     END AS Age_Group,

     Lifespan,

     CASE
         WHEN Lifespan >= 12 AND Total_Sales > 5000 THEN 'VIP'
         WHEN Lifespan >= 12 AND Total_Sales <= 5000 THEN 'Regular'
     ELSE 'New'
     END AS Customer_Segment,
     Total_Orders,
     Total_Sales,
     Total_Products,
     Last_Order_Date,
     DATEDIFF(MONTH , Last_Order_Date , GETDATE()) AS Recency,
     --Computing Average Order Value(AOV)
     CASE
        WHEN Total_Orders = 0 THEN 0
     ELSE Total_Sales / Total_Orders
     END AS Average_Order_Value,
     --Computing Average Monthly Spend
     CASE 
         WHEN Lifespan = 0 THEN Total_Sales
     ELSE Total_Sales / Lifespan
     END AS Average_Monthly_Spend
FROM Customer_Aggregation

SELECT *
FROM Report_Customers


SELECT Age_Group, 
       COUNT(customer_number) AS Total_Customers,
       SUM(Total_Sales) AS Total_Sales
FROM Report_Customers
GROUP BY Age_Group

--Output:

---50 and Above	   12166	19449234
---30-39	         196	279917
---40-49	        6103	9566103



/*
Product Report
================================================================================
Purpose:
        This Report Consolidates Key product Mertics and Behaviors

Highlights:
           1. Gathers Essential Fields Such as Product Name , Category , Subcategory , Cost.
           2. Segments Products By Revenue to identify High-Performance , Mid-Performance , Or Low-Performance.
           3. Aggregates Product Level Metrics:
              --Total Orders
              --Total Sales
              --Total Quantity Purchased
              --Total Products
              --Last Order Date
              --Lifespan (in months)
           4. Calculates Valuable KPIs:
              --Recency (Months Since Last Sale)
              --Average Order Revenue
              --Average Monthly Revenue
================================================================================
*/

--1) First Query: Gathers Essential Fields Such as Product Name , Category , Subcategory , Cost.
CREATE VIEW Product_Report
WITH ENCRYPTION AS
WITH Base_Product_Query AS (
SELECT FS.customer_key,
       FS.order_number,
       FS.order_date,
       DP.product_key,
       DP.product_number,
       DP.product_name,
       DP.product_line,
       DP.category,
       DP.subcategory,
       DP.start_date,
       DP.cost,
       FS.quantity,
       FS.price,
       FS.sales_amount
FROM fact_sales AS FS
INNER JOIN dim_products AS DP
ON DP.product_key = FS.product_key
WHERE order_date IS NOT NULL
) ,

--2) Second Query: Product Aggregations: Summarizes Key Metrics at the Product level
Product_Aggregations AS (
SELECT 
       product_key,
       product_name,
       product_line,
       category,
       subcategory,
       start_date,
       cost,
       COUNT(DISTINCT order_number) AS Total_Orders,
       SUM(sales_amount) AS Total_Sales,
       SUM(quantity) AS Total_Quantity_Sold,
       COUNT(DISTINCT customer_key) AS Total_Customers,
       AVG(price) AS Avg_Price,
       ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity,0)),1) AS Average_Selling_Price,
       MAX(order_date) AS Last_Order_Date,
       DATEDIFF(MONTH , MIN(order_date) , MAX(order_date)) AS Lifespan
FROM Base_Product_Query

GROUP BY
       product_key,
       product_name,
       product_line,
       category,
       subcategory,
       start_date,
       cost
) 

--3) Final Query: Combines all Product results into one output
SELECT 
       product_key,
       product_name,
       product_line,
       category,
       subcategory,
       start_date,
       cost,
       Total_Orders,
       Total_Sales,
       Total_Quantity_Sold,
       Total_Customers,
       Avg_Price,
       Average_Selling_Price,
       Last_Order_Date,
       Lifespan,

       --2. Segments Products By Revenue to identify High-Performance , Mid-Performance , Or Low-Performance.
       CASE
          WHEN Total_Sales > 50000 THEN 'High Performance'  
          WHEN Total_Sales >= 10000 THEN 'Mid Performance' 
       ELSE 'Low Pergormance'
       END AS Product_Performance,

       --Average Order Revenue
        CASE
           WHEN Total_Orders = 0 THEN 0
        ELSE Total_Sales / Total_Orders
        END AS Average_Order_Value,
     --Computing Average Monthly Revenue
     CASE 
         WHEN Lifespan = 0 THEN Total_Sales
     ELSE Total_Sales / Lifespan
     END AS Average_Monthly_Spend
FROM Product_Aggregations


SELECT Product_Performance , Count(product_key) AS Total_Products
FROM Product_Report
GROUP BY Product_Performance