USE salesanalysis1;

CREATE TABLE salestable (
	`orderId` INT NOT NULL,
    `date` DATE NOT NULL,
    `productId` INT NOT NULL,
    `customerId` INT NOT NULL,
    `employeeId` INT NOT NULL,
    `quantity` INT NOT NULL, 
    `unitPrice` DECIMAL(7,2),
    PRIMARY KEY(`orderId`)
);

CREATE TABLE productstable (
	`productId`INT NOT NULL,
    `productName` VARCHAR(50) NOT NULL,
    `category` VARCHAR(50) NOT NULL,
    PRIMARY KEY(`productId`)
);

CREATE TABLE customerTable (
	`customerId` INT NOT NULL,
    `customerName` VARCHAR(50) NOT NULL,
    `region` VARCHAR(50) NOT NULL,
    `gender` VARCHAR(50) NOT NULL,
    `age` INT NOT NULL,
    PRIMARY KEY (`customerId`)
);


-- SALES PERFORMANCE ANALYSIS
-- 1. Which products generate the highest total revenue?

SELECT
	st.productId,
    pt.productName,
    ROUND(quantity*unitPrice,2) AS totalRevenue
FROM salestable st
JOIN productstable pt
	ON st.productId = pt.productId
ORDER BY totalRevenue DESC;

-- 2. Which products have the lowest sales performance?

SELECT
	st.productId,
    pt.productName,
    ROUND(quantity*unitPrice,2) AS totalRevenue
FROM salestable st
JOIN productstable pt
	ON st.productId = pt.productId
ORDER BY totalRevenue ASC;

-- 3. What are the monthly sales trends of the company?

SELECT
    YEAR(date) AS years,
    MONTH(date) AS monthNum,
    MONTHNAME(date) AS monthName, 
    ROUND(SUM(quantity * unitPrice), 2) AS totalRevenue
FROM salestable
GROUP BY YEAR(date), MONTH(date), MONTHNAME(date)
ORDER BY years, monthNum;

-- 4. Which month has the highest sales?

SELECT
    YEAR(date) AS years,
    MONTH(date) AS monthNum,
    MONTHNAME(date) AS monthName, 
    ROUND(SUM(quantity * unitPrice), 2) AS totalRevenue
FROM salestable
GROUP BY YEAR(date), MONTH(date), MONTHNAME(date)
ORDER BY years, totalRevenue DESC;

-- 5. What is the average order value per month?

SELECT
	YEAR(date) AS years,
	MONTH(date) AS monthNum,
    MONTHNAME(date) AS monthName,
    ROUND(AVG(quantity*unitPrice),2) AS avgRevenue 
FROM salestable
GROUP BY YEAR(date), MONTH(date), MONTHNAME(date)
ORDER BY years, monthNum;

-- 6. Are sales growing or declining month-over-month?

WITH monthlySales AS (
    SELECT 
        DATE_FORMAT(date, '%Y-%m') AS month,
        SUM(quantity * unitPrice) AS totalSales
    FROM salestable
    GROUP BY month
)
SELECT 
    month,
    totalSales,
    LAG(totalSales) OVER (ORDER BY month) AS previousMonthSales,
    ROUND(((totalSales - LAG(totalSales) OVER (ORDER BY month))
            / LAG(totalSales) OVER (ORDER BY month)
        ) * 100,2) AS growthPercentage,
    CASE
        WHEN totalSales > LAG(totalSales) OVER (ORDER BY month)
            THEN 'Growing'
        WHEN totalSales < LAG(totalSales) OVER (ORDER BY month)
            THEN 'Declining'
        ELSE 'No Change' END AS salesTrend
FROM monthlySales
ORDER BY month;


-- 7. Which products show consistent monthly growth?

WITH monthlyProductSales AS (
    SELECT 
        p.productName,
        DATE_FORMAT(s.date, '%Y-%m') AS month,
        SUM(s.quantity * s.unitPrice) AS totalSales
    FROM salestable s
    JOIN productstable p
        ON s.productId = p.productId
    GROUP BY p.productName, month),
growthAnalysis AS (
    SELECT 
        productName,
        month,
        totalSales,
        LAG(totalSales) OVER (
            PARTITION BY productName
            ORDER BY month) AS previousMonthSales,
        ROUND(((totalSales - LAG(totalSales) OVER (
                    PARTITION BY productName
                    ORDER BY month))/ LAG(totalSales) OVER (
                    PARTITION BY productName
                    ORDER BY month)) * 100,2) AS growthPercentage
    FROM monthlyProductSales)
SELECT *
FROM growthAnalysis
ORDER BY productName, month;

-- 8. Which products are seasonal?

WITH monthlyProductSales AS (
    SELECT 
        p.productName,
        MONTH(s.date) AS monthNumber,
        SUM(s.quantity * s.unitPrice) AS totalSales
    FROM salestable s
    JOIN productstable p
        ON s.productId = p.productId
    GROUP BY p.productName, monthNumber
)
SELECT 
    productName,
    MIN(totalSales) AS lowest_month_sales,
    MAX(totalSales) AS highest_month_sales,
    ROUND(MAX(totalSales) - MIN(totalSales),2) AS salesFluctuation
FROM monthlyProductSales
GROUP BY productName
ORDER BY salesFluctuation DESC;

-- 9. Which categories contribute the most revenue?

SELECT
    pt.category,
    SUM(st.quantity * st.unitPrice) AS totalRevenue
FROM salestable st
JOIN productstable pt
ON st.productId = pt.productId
GROUP BY pt.category
ORDER BY totalRevenue DESC;

-- 10. Which categories are underperforming?

SELECT
    pt.category,
    SUM(st.quantity * st.unitPrice) AS totalRevenue
FROM salestable st
JOIN productstable pt
ON st.productId = pt.productId
GROUP BY pt.category
ORDER BY totalRevenue ASC;

-- PRODUCT ANALYSIS
-- 11. Which products are frequently purchased in high quantities?

SELECT
    pt.category,
    SUM(st.quantity) AS totalQuantities
FROM salestable st
JOIN productstable pt
ON st.productId = pt.productId
GROUP BY pt.category
ORDER BY totalQuantities DESC;

-- 12. Which products have declining demand over time?

WITH monthlyProductDemand AS (
	SELECT 
		pt.productName,
		DATE_FORMAT(st.date, '%Y-%M') AS month,
		SUM(st.quantity) AS totalQuantity
	FROM salestable st
	JOIN productstable pt
	ON st.productId = pt.productId
	GROUP BY pt.productName, month),
demandTrend AS (
	SELECT
		productName,
        month,
        totalQuantity,
        
        LAG(totalQuantity) OVER 
        (PARTITION BY productName ORDER BY month) AS previousMOnthQuantity
	FROM monthlyProductDemand)
	
SELECT
    productName,
    SUM(CASE WHEN totalQuantity < previousMOnthQuantity THEN 1 ELSE 0 END) AS decliningMonths,
    COUNT(*) AS totalMonths
FROM demandTrend 
GROUP BY productName
ORDER BY decliningMonths DESC;

-- 13. Which products contribute most to total quantity sold?

SELECT
    pt.productName,
    SUM(quantity) AS totalQuantitySold
FROM salestable st
JOIN productstable pt
ON st.productId = pt.productId
GROUP BY pt.productName
ORDER BY totalQuantitySold DESC;

-- 14 Which categories are growing the fastest?

WITH monthlyCategorySales AS (
    SELECT
        p.category,
        DATE_FORMAT(s.date, '%Y-%m') AS month,
        SUM(s.quantity * s.unitPrice) AS totalSales
    FROM salestable s
    JOIN productstable p ON s.productId = p.productId
    GROUP BY p.category, month
),
growthAnalysis AS (
    SELECT
        category,
        month,
        totalSales,
        LAG(totalSales) OVER (PARTITION BY category ORDER BY month) AS previousMonthSales,
        ROUND(
            ((totalSales - LAG(totalSales) OVER (PARTITION BY category ORDER BY month)) 
            / LAG(totalSales) OVER (PARTITION BY category ORDER BY month)) * 100, 2
        ) AS growthPercentage
    FROM monthlyCategorySales
)
SELECT
    category,
    ROUND(AVG(growthPercentage), 2) AS avgGrowthRate,
    MAX(growthPercentage) AS highestGrowth,
    MIN(growthPercentage) AS lowestGrowth
FROM growthAnalysis
WHERE growthPercentage IS NOT NULL
GROUP BY category
ORDER BY avgGrowthRate DESC;


-- 15. Which products should the company promote more aggressively?

SELECT
    p.productName,
    p.category,
    SUM(s.quantity) AS totalQuantitySold,
    ROUND(SUM(s.quantity * s.unitPrice), 2) AS totalRevenue,
    ROUND(AVG(s.unitPrice), 2) AS avgPrice
FROM salestable s
JOIN productstable p ON s.productId = p.productId
GROUP BY p.productName, p.category
HAVING totalQuantitySold < (
    SELECT AVG(productTotal)
    FROM (
        SELECT SUM(quantity) AS productTotal
        FROM salestable
        GROUP BY productId
    ) AS volume_subquery
)
ORDER BY totalRevenue DESC;


-- 16. Which products should the company consider discontinuing?

SELECT
	productName,
    category,
    SUM(quantity) AS totalQuantitySold,
    ROUND(SUM(quantity * unitPrice)) AS totalRevenue
FROM salestable s
JOIN productstable p
ON s.productId = p.productId
GROUP BY productName, category 
ORDER BY totalRevenue ASC, totalQuantitySold ASC;

-- 17. Which products have stable demand across all months?

SELECT	
	DATE_FORMAT(s.date, '%Y-%m') AS month,
	productName,
    category,
    SUM(quantity) AS totalQuantitySold
FROM salestable s
JOIN productstable p
ON s.productId = p.productId
GROUP BY month, productName, category
ORDER BY productName, category, month;

-- CUSTOMER ANALYSIS
-- 18. Which customers generate the highest revenue?

SELECT
	c.customerId,
    customerName,
    ROUND(SUM(quantity * unitPrice)) AS totalRevenue
FROM salestable s
JOIN customertable c
	ON s.customerId = c.customerId
GROUP BY c.customerId, customerName
ORDER BY totalRevenue DESC;

-- 19. Which regions have the highest number of customers?

SELECT
	region,
    COUNT(*) AS totalCount
FROM customertable
GROUP BY region
ORDER BY totalCount DESC;

-- 20. Which customer age group spends the most money? 

SELECT 
    CASE
        WHEN c.age BETWEEN 18 AND 25 THEN '18-25'
        WHEN c.age BETWEEN 26 AND 35 THEN '26-35'
        WHEN c.age BETWEEN 36 AND 45 THEN '36-45'
        WHEN c.age BETWEEN 46 AND 55 THEN '46-55'
        ELSE '56+'
    END AS ageGroup,
	ROUND(SUM(s.quantity * s.unitPrice),2) AS totalSpending,
    COUNT(DISTINCT c.customerId) AS totalCustomers,
    ROUND(AVG(s.quantity * s.unitPrice),2) AS avgTransactionValue
FROM salestable s
JOIN customerTable c
    ON s.customerId = c.customerId
GROUP BY ageGroup 
ORDER BY ageGroup;

-- 21. Do male or female customers purchase more products?

SELECT
	c.gender,
    SUM(s.quantity) AS totalPurchase
FROM salestable s
JOIN customertable c
	ON s.customerId = c.customerId 
GROUP BY c.gender;

-- 22. Which region has the highest sales revenue?

SELECT
	c.region,
    ROUND(SUM(quantity * unitPrice),2) AS totalRevenue
FROM salestable s
JOIN customertable c
	ON s.customerId = c.customerId 
GROUP BY c.region
ORDER BY totalRevenue DESC;

-- 23. What is the average spending per customer?

SELECT
	ROUND(AVG(customerSpending),2) AS avgCustomerTotalSpending
FROM (
	SELECT
		customerId,
        SUM(quantity * unitPrice) As customerSpending
        FROM salestable
        GROUP BY customerId ) customerTotalSpending;
        
-- 24. Which customers purchase most frequently?

SELECT
	s.customerId,
    c.customerName,
    COUNT(*) AS totalNumberOfPurchase
FROM salestable s   
JOIN customerTable c
    ON s.customerId = c.customerId 
GROUP BY s.customerId, c.customerName
ORDER BY totalNumberOfPurchase DESC;

-- REGIONAL BUSINESS ANALYSIS
-- 25. Which region generates the highest average order value?

SELECT
	c.region,
    SUM(quantity * unitPrice) AS salesRevenue
FROM salestable s
JOIN customertable c 
ON s.customerId = c.customerId
GROUP BY c.region
ORDER by salesRevenue DESC;

-- 26. Which regions have low sales but high customer counts?

SELECT
	c.region,
    COUNT(c.customerId) AS customerCount,
    SUM(quantity * unitPrice) AS salesRevenue
FROM salestable s
JOIN customertable c 
ON s.customerId = c.customerId
GROUP BY c.region
ORDER by salesRevenue ASC;


-- EMPLOYEE / SALES PERFORMANCE
-- 27. Which employees generate the highest revenue?

SELECT
	employeeId,
    SUM(quantity * unitPrice) AS totalRevenue
FROM salestable
GROUP BY employeeId
ORDER BY totalRevenue DESC;

-- 28. Which employees process the most orders?

SELECT
	employeeId,
    SUM(quantity ) AS totalQuantity
FROM salestable 
GROUP BY employeeId
ORDER BY totalQuantity DESC;


-- 29. Is there a relationship between price and quantity sold?

SELECT 
    ROUND((COUNT(*) * SUM(unitPrice * quantity) -
            SUM(unitPrice) * SUM(quantity))
        /
        SQRT((COUNT(*) * SUM(unitPrice * unitPrice) -
                POW(SUM(unitPrice), 2))
            *
            (COUNT(*) * SUM(quantity * quantity) -POW(SUM(quantity), 2))),
        4) AS correlationCoefficient
FROM salestable;

-- 30. What factors most influence total sales revenue?

SELECT 
    p.category,
    c.region,
    COUNT(s.orderId) AS totalOrders,
	SUM(s.quantity) AS totalQuantitySold,
	ROUND(AVG(s.unitPrice),2) AS avgUnitPrice,
	ROUND(SUM(s.quantity * s.unitPrice),2) AS totalRevenue,
    ROUND(AVG(s.quantity * s.unitPrice),2) AS avgOrderValue
FROM salestable s
JOIN productstable p
    ON s.productId = p.productId
JOIN customerTable c
    ON s.customerId = c.customerId
GROUP BY p.category, c.region
ORDER BY totalRevenue DESC;
