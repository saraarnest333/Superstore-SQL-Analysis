USE superstore;


-- =========================================================
-- 1. CUSTOMERS
-- =========================================================

SELECT
    [Customer ID],
    [Customer Name],
    Segment
INTO Customers
FROM [dbo].[Customers$];


ALTER TABLE Customers
ALTER COLUMN [Customer ID] VARCHAR(100) NOT NULL;

ALTER TABLE Customers
ALTER COLUMN [Customer Name] VARCHAR(100);

ALTER TABLE Customers
ALTER COLUMN Segment VARCHAR(100);


ALTER TABLE Customers
ADD CONSTRAINT PK_Customers
PRIMARY KEY ([Customer ID]);



-- =========================================================
-- 2. PRODUCTS
-- =========================================================

SELECT
    [Product ID],
    Category,
    [Sub-Category],
    [Product Name]
INTO Products
FROM [dbo].[Products$];


ALTER TABLE Products
ALTER COLUMN [Product ID] VARCHAR(100) NOT NULL;

ALTER TABLE Products
ALTER COLUMN Category VARCHAR(100);

ALTER TABLE Products
ALTER COLUMN [Sub-Category] VARCHAR(100);

ALTER TABLE Products
ALTER COLUMN [Product Name] VARCHAR(200);


-- Product ID is not unique in the source data,
-- so a surrogate key is used.

ALTER TABLE Products
ADD ProductKey INT IDENTITY(1,1);


ALTER TABLE Products
ADD CONSTRAINT PK_Products
PRIMARY KEY (ProductKey);



-- =========================================================
-- 3. ORDERS
-- =========================================================

SELECT DISTINCT
    [Order ID],
    [Order Date],
    [Ship Date],
    [Ship Mode],
    [Customer ID]
INTO Orders
FROM [dbo].[ORDERS$];


DELETE FROM Orders
WHERE [Order ID] IS NULL;


ALTER TABLE Orders
ALTER COLUMN [Order ID] VARCHAR(100) NOT NULL;

ALTER TABLE Orders
ALTER COLUMN [Order Date] DATE;

ALTER TABLE Orders
ALTER COLUMN [Ship Date] DATE;

ALTER TABLE Orders
ALTER COLUMN [Ship Mode] VARCHAR(100);

ALTER TABLE Orders
ALTER COLUMN [Customer ID] VARCHAR(100) NOT NULL;


ALTER TABLE Orders
ADD CONSTRAINT PK_Orders
PRIMARY KEY ([Order ID]);


ALTER TABLE Orders
ADD CONSTRAINT FK_Orders_Customers
FOREIGN KEY ([Customer ID])
REFERENCES Customers([Customer ID]);



-- =========================================================
-- 4. LOCATION
-- =========================================================

SELECT DISTINCT
    Country,
    City,
    State,
    [Postal Code],
    Region
INTO Location
FROM [dbo].[LOCATION$];


ALTER TABLE Location
ADD LocationKey INT IDENTITY(1,1);


ALTER TABLE Location
ADD CONSTRAINT PK_Location
PRIMARY KEY (LocationKey);


ALTER TABLE Location
ALTER COLUMN Country VARCHAR(100);

ALTER TABLE Location
ALTER COLUMN City VARCHAR(100);

ALTER TABLE Location
ALTER COLUMN State VARCHAR(100);

ALTER TABLE Location
ALTER COLUMN [Postal Code] INT;

ALTER TABLE Location
ALTER COLUMN Region VARCHAR(100);



-- =========================================================
-- 5. ORDERS_DETAILS
-- =========================================================

SELECT
    [Row ID],
    [Order ID],
    [Product ID],
    Sales,
    Quantity,
    Discount,
    Profit
INTO Orders_Details
FROM [dbo].[ORDERS_DETIALS$];


ALTER TABLE Orders_Details
ALTER COLUMN [Row ID] INT NOT NULL;

ALTER TABLE Orders_Details
ALTER COLUMN [Order ID] VARCHAR(100) NOT NULL;

ALTER TABLE Orders_Details
ALTER COLUMN [Product ID] VARCHAR(100) NOT NULL;

ALTER TABLE Orders_Details
ALTER COLUMN Sales DECIMAL(18,2);

ALTER TABLE Orders_Details
ALTER COLUMN Quantity INT;

ALTER TABLE Orders_Details
ALTER COLUMN Discount DECIMAL(5,2);

ALTER TABLE Orders_Details
ALTER COLUMN Profit DECIMAL(18,2);


ALTER TABLE Orders_Details
ADD CONSTRAINT PK_Orders_Details
PRIMARY KEY ([Row ID]);



-- =========================================================
-- 6. LINK ORDERS_DETAILS TO PRODUCTS
-- =========================================================

ALTER TABLE Orders_Details
ADD ProductKey INT;


UPDATE OD
SET ProductKey = P.ProductKey
FROM Orders_Details OD
JOIN Products P
    ON OD.[Product ID] = P.[Product ID];


-- Check for unmatched products
SELECT *
FROM Orders_Details
WHERE ProductKey IS NULL;


ALTER TABLE Orders_Details
ALTER COLUMN ProductKey INT NOT NULL;


ALTER TABLE Orders_Details
ADD CONSTRAINT FK_Details_Orders
FOREIGN KEY ([Order ID])
REFERENCES Orders([Order ID]);


ALTER TABLE Orders_Details
ADD CONSTRAINT FK_Details_Products
FOREIGN KEY (ProductKey)
REFERENCES Products(ProductKey);



-- =========================================================
-- 7. LINK ORDERS_DETAILS TO LOCATION
-- =========================================================
-- The source LOCATION$ table does not contain a business key
-- that directly identifies the corresponding Orders_Details row.
-- Therefore, the source row order is used as a temporary
-- mapping mechanism.

ALTER TABLE Orders_Details
ADD LocationKey INT;


SELECT
    ROW_NUMBER() OVER (ORDER BY [Row ID]) AS RowNum,
    [Row ID]
INTO #Details
FROM [dbo].[ORDERS_DETIALS$];


SELECT
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum,
    Country,
    City,
    State,
    [Postal Code],
    Region
INTO #Loc
FROM [dbo].[LOCATION$];


UPDATE OD
SET OD.LocationKey = L.LocationKey
FROM Orders_Details OD
JOIN #Details D
    ON OD.[Row ID] = D.[Row ID]
JOIN #Loc LO
    ON D.RowNum = LO.RowNum
JOIN Location L
    ON LO.Country = L.Country
    AND LO.City = L.City
    AND LO.State = L.State
    AND LO.[Postal Code] = L.[Postal Code]
    AND LO.Region = L.Region;


-- Check for unmatched locations
SELECT *
FROM Orders_Details
WHERE LocationKey IS NULL;


DROP TABLE #Details;
DROP TABLE #Loc;


ALTER TABLE Orders_Details
ALTER COLUMN LocationKey INT NOT NULL;


ALTER TABLE Orders_Details
ADD CONSTRAINT FK_Details_Location
FOREIGN KEY (LocationKey)
REFERENCES Location(LocationKey);



-- =========================================================
-- 8. DATA VALIDATION
-- =========================================================

SELECT
    COUNT(*) AS TotalOrderDetails,
    COUNT(ProductKey) AS RowsWithProduct,
    COUNT(LocationKey) AS RowsWithLocation
FROM Orders_Details;


SELECT *
FROM Customers;

SELECT *
FROM Products;

SELECT *
FROM Orders;

SELECT *
FROM Orders_Details;

SELECT *
FROM Location;



-- =========================================================
-- 9. CUSTOMER ANALYSIS
-- =========================================================

-- Customers by Segment

SELECT
    Segment,
    COUNT(*) AS CustomerCount
FROM Customers
GROUP BY Segment;



-- Customers by Segment and Ship Mode

SELECT
    C.Segment,
    O.[Ship Mode],
    COUNT(*) AS OrderCount
FROM Customers C
LEFT JOIN Orders O
    ON C.[Customer ID] = O.[Customer ID]
GROUP BY
    C.Segment,
    O.[Ship Mode]
ORDER BY
    C.Segment,
    OrderCount DESC;



-- Top 10 Customers by Profit

SELECT TOP 10
    C.[Customer ID],
    C.Segment,
    SUM(OD.Sales) AS TotalSales,
    SUM(OD.Profit) AS TotalProfit
FROM Customers C
JOIN Orders O
    ON C.[Customer ID] = O.[Customer ID]
JOIN Orders_Details OD
    ON O.[Order ID] = OD.[Order ID]
GROUP BY
    C.[Customer ID],
    C.Segment
ORDER BY
    TotalProfit DESC;



-- Sales and Profit by Segment

SELECT
    C.Segment,
    SUM(OD.Sales) AS TotalSales,
    SUM(OD.Profit) AS TotalProfit
FROM Customers C
JOIN Orders O
    ON C.[Customer ID] = O.[Customer ID]
JOIN Orders_Details OD
    ON O.[Order ID] = OD.[Order ID]
GROUP BY
    C.Segment
ORDER BY
    TotalSales DESC,
    TotalProfit DESC;



-- Customers Above Average Sales

SELECT
    C.[Customer ID],
    C.[Customer Name],
    SUM(OD.Sales) AS TotalSales
FROM Customers C
JOIN Orders O
    ON C.[Customer ID] = O.[Customer ID]
JOIN Orders_Details OD
    ON O.[Order ID] = OD.[Order ID]
GROUP BY
    C.[Customer ID],
    C.[Customer Name]
HAVING SUM(OD.Sales) >
(
    SELECT AVG(CustomerTotalSales)
    FROM
    (
        SELECT
            C1.[Customer ID],
            SUM(OD1.Sales) AS CustomerTotalSales
        FROM Customers C1
        JOIN Orders O1
            ON C1.[Customer ID] = O1.[Customer ID]
        JOIN Orders_Details OD1
            ON O1.[Order ID] = OD1.[Order ID]
        GROUP BY
            C1.[Customer ID]
    ) AS CustomerSales
)
ORDER BY
    TotalSales DESC;



-- =========================================================
-- 10. SHIPPING ANALYSIS
-- =========================================================

-- Shipping Performance by Ship Mode

SELECT
    O.[Ship Mode],
    AVG(DATEDIFF(DAY, O.[Order Date], O.[Ship Date])) AS AvgShippingDays,
    COUNT(O.[Order ID]) AS TotalOrders
FROM Orders O
GROUP BY
    O.[Ship Mode]
ORDER BY
    AvgShippingDays;



-- Shipping Performance by Year

SELECT
    YEAR(O.[Order Date]) AS OrderYear,
    AVG(DATEDIFF(DAY, O.[Order Date], O.[Ship Date])) AS AvgShippingDays
FROM Orders O
GROUP BY
    YEAR(O.[Order Date])
ORDER BY
    OrderYear;



-- =========================================================
-- 11. SALES & PROFIT ANALYSIS
-- =========================================================

-- Sales and Profit by Ship Mode

SELECT
    O.[Ship Mode],
    COUNT(DISTINCT O.[Order ID]) AS TotalOrders,
    SUM(OD.Sales) AS TotalSales,
    SUM(OD.Profit) AS TotalProfit
FROM Orders O
JOIN Orders_Details OD
    ON O.[Order ID] = OD.[Order ID]
GROUP BY
    O.[Ship Mode]
ORDER BY
    TotalSales DESC;



-- Sales and Profit by Product Category

SELECT
    P.Category,
    SUM(OD.Sales) AS TotalSales,
    SUM(OD.Profit) AS TotalProfit
FROM Products P
JOIN Orders_Details OD
    ON P.ProductKey = OD.ProductKey
GROUP BY
    P.Category
ORDER BY
    TotalSales DESC;



-- Sales and Profit by Sub-Category

SELECT
    P.[Sub-Category],
    SUM(OD.Sales) AS TotalSales,
    SUM(OD.Profit) AS TotalProfit
FROM Products P
JOIN Orders_Details OD
    ON P.ProductKey = OD.ProductKey
GROUP BY
    P.[Sub-Category]
ORDER BY
    TotalProfit DESC;



-- Sales and Profit by Discount

SELECT
    OD.Discount,
    SUM(OD.Sales) AS TotalSales,
    SUM(OD.Profit) AS TotalProfit
FROM Orders_Details OD
GROUP BY
    OD.Discount
ORDER BY
    OD.Discount;



-- Monthly Sales and Profit Across All Years

SELECT
    MONTH(O.[Order Date]) AS OrderMonth,
    SUM(OD.Sales) AS TotalSales,
    SUM(OD.Profit) AS TotalProfit,
    CASE
        WHEN SUM(OD.Profit) > 1000 THEN 'High Profit'
        WHEN SUM(OD.Profit) > 0 THEN 'Profitable'
        ELSE 'Loss'
    END AS ProfitState
FROM Orders O
JOIN Orders_Details OD
    ON O.[Order ID] = OD.[Order ID]
GROUP BY
    MONTH(O.[Order Date])
ORDER BY
    OrderMonth;



-- Yearly Sales and Profit

SELECT
    YEAR(O.[Order Date]) AS OrderYear,
    SUM(OD.Sales) AS TotalSales,
    SUM(OD.Profit) AS TotalProfit,
    CASE
        WHEN SUM(OD.Profit) > 1000 THEN 'High Profit'
        WHEN SUM(OD.Profit) > 0 THEN 'Profitable'
        ELSE 'Loss'
    END AS ProfitState
FROM Orders O
JOIN Orders_Details OD
    ON O.[Order ID] = OD.[Order ID]
GROUP BY
    YEAR(O.[Order Date])
ORDER BY
    OrderYear;



-- =========================================================
-- 12. PRODUCT ANALYSIS
-- =========================================================

-- Products Below Average Profit

SELECT
    P.ProductKey,
    P.[Product ID],
    P.[Product Name],
    P.Category,
    SUM(OD.Profit) AS TotalProfit
FROM Products P
JOIN Orders_Details OD
    ON P.ProductKey = OD.ProductKey
GROUP BY
    P.ProductKey,
    P.[Product ID],
    P.[Product Name],
    P.Category
HAVING SUM(OD.Profit) <
(
    SELECT AVG(ProductTotalProfit)
    FROM
    (
        SELECT
            P1.ProductKey,
            SUM(OD1.Profit) AS ProductTotalProfit
        FROM Products P1
        JOIN Orders_Details OD1
            ON P1.ProductKey = OD1.ProductKey
        GROUP BY
            P1.ProductKey
    ) AS ProductProfits
)
ORDER BY
    TotalProfit DESC;



-- Highest Profit Product in Each Category

SELECT
    P.Category,
    P.[Product Name],
    SUM(OD.Profit) AS TotalProfit
FROM Products P
JOIN Orders_Details OD
    ON P.ProductKey = OD.ProductKey
GROUP BY
    P.Category,
    P.[ProductKey],
    P.[Product Name]
HAVING SUM(OD.Profit) =
(
    SELECT MAX(CategoryProductProfit)
    FROM
    (
        SELECT
            P1.ProductKey,
            SUM(OD1.Profit) AS CategoryProductProfit
        FROM Products P1
        JOIN Orders_Details OD1
            ON P1.ProductKey = OD1.ProductKey
        WHERE P1.Category = P.Category
        GROUP BY
            P1.ProductKey
    ) AS CategoryProfits
)
ORDER BY
    TotalProfit DESC;



-- =========================================================
-- 13. CTE ANALYSIS
-- =========================================================

-- Top Customer by Total Sales in Each Segment

WITH TotalCustomer AS
(
    SELECT
        C.Segment,
        C.[Customer ID],
        C.[Customer Name],
        SUM(OD.Sales) AS TotalSales
    FROM Customers C
    JOIN Orders O
        ON C.[Customer ID] = O.[Customer ID]
    JOIN Orders_Details OD
        ON O.[Order ID] = OD.[Order ID]
    GROUP BY
        C.Segment,
        C.[Customer ID],
        C.[Customer Name]
),
MaxCustomer AS
(
    SELECT
        Segment,
        MAX(TotalSales) AS MaxSegmentSales
    FROM TotalCustomer
    GROUP BY
        Segment
)
SELECT
    T.Segment,
    T.[Customer ID],
    T.[Customer Name],
    T.TotalSales
FROM TotalCustomer T
JOIN MaxCustomer M
    ON T.Segment = M.Segment
    AND T.TotalSales = M.MaxSegmentSales
ORDER BY
    T.Segment;



-- Monthly Sales Compared with Average Monthly Sales
-- of the Same Year

WITH MonthCalc AS
(
    SELECT
        YEAR(O.[Order Date]) AS OrderYear,
        MONTH(O.[Order Date]) AS OrderMonth,
        SUM(OD.Sales) AS TotalSales
    FROM Orders O
    JOIN Orders_Details OD
        ON O.[Order ID] = OD.[Order ID]
    GROUP BY
        YEAR(O.[Order Date]),
        MONTH(O.[Order Date])
),
MonthAvg AS
(
    SELECT
        OrderYear,
        AVG(TotalSales) AS AvgSales
    FROM MonthCalc
    GROUP BY
        OrderYear
)
SELECT
    MC.OrderYear,
    MC.OrderMonth,
    MC.TotalSales,
    MA.AvgSales,
    CASE
        WHEN MC.TotalSales > MA.AvgSales THEN 'Above Average'
        WHEN MC.TotalSales < MA.AvgSales THEN 'Below Average'
        ELSE 'Average'
    END AS SalesState
FROM MonthCalc MC
JOIN MonthAvg MA
    ON MC.OrderYear = MA.OrderYear
ORDER BY
    MC.OrderYear,
    MC.OrderMonth;



-- =========================================================
-- 14. KPI REPORT
-- =========================================================

SELECT
    SUM(OD.Sales) AS TotalSales,
    SUM(OD.Profit) AS TotalProfit,
    COUNT(DISTINCT OD.[Order ID]) AS TotalOrders,
    COUNT(DISTINCT C.[Customer ID]) AS TotalCustomers,
    SUM(OD.Quantity) AS TotalQuantity,
    (SUM(OD.Profit) / NULLIF(SUM(OD.Sales), 0)) * 100 AS ProfitMargin
FROM Customers C
JOIN Orders O
    ON C.[Customer ID] = O.[Customer ID]
JOIN Orders_Details OD
    ON O.[Order ID] = OD.[Order ID];



-- =========================================================
-- 15. REGIONAL PERFORMANCE
-- =========================================================

SELECT
    L.Region,
    SUM(OD.Sales) AS TotalSales,
    SUM(OD.Profit) AS TotalProfit,
    COUNT(DISTINCT OD.[Order ID]) AS TotalOrders
FROM Location L
JOIN Orders_Details OD
    ON L.LocationKey = OD.LocationKey
GROUP BY
    L.Region
ORDER BY
    TotalSales DESC;



-- =========================================================
-- 16. CITY PERFORMANCE
-- =========================================================

WITH CityPerformance AS
(
    SELECT
        L.City,
        SUM(OD.Sales) AS TotalSales,
        SUM(OD.Profit) AS TotalProfit
    FROM Location L
    JOIN Orders_Details OD
        ON L.LocationKey = OD.LocationKey
    GROUP BY
        L.City
)
SELECT
    'Highest Sales' AS Metric,
    City,
    TotalSales AS Value
FROM CityPerformance
WHERE TotalSales =
(
    SELECT MAX(TotalSales)
    FROM CityPerformance
)

UNION ALL

SELECT
    'Highest Profit' AS Metric,
    City,
    TotalProfit AS Value
FROM CityPerformance
WHERE TotalProfit =
(
    SELECT MAX(TotalProfit)
    FROM CityPerformance
);



-- =========================================================
-- 17. VIEW: MONTHLY SALES PERFORMANCE
-- =========================================================

CREATE VIEW vw_Monthly_Sales_Performance
AS
SELECT
    YEAR(O.[Order Date]) AS OrderYear,
    MONTH(O.[Order Date]) AS OrderMonth,
    SUM(OD.Sales) AS TotalSales,
    SUM(OD.Profit) AS TotalProfit,
    COUNT(DISTINCT O.[Order ID]) AS TotalOrders,
    (SUM(OD.Profit) / NULLIF(SUM(OD.Sales), 0)) * 100 AS ProfitMargin
FROM Orders O
JOIN Orders_Details OD
    ON O.[Order ID] = OD.[Order ID]
GROUP BY
    YEAR(O.[Order Date]),
    MONTH(O.[Order Date]);


SELECT *
FROM vw_Monthly_Sales_Performance
ORDER BY
    OrderYear,
    OrderMonth;



-- =========================================================
-- 18. VIEW: CUSTOMER PERFORMANCE
-- =========================================================

CREATE VIEW vw_Customer_Performance
AS
SELECT
    C.[Customer ID],
    C.[Customer Name],
    C.Segment,
    COUNT(DISTINCT O.[Order ID]) AS OrderCount,
    SUM(OD.Sales) AS TotalSales,
    SUM(OD.Profit) AS TotalProfit,
    SUM(OD.Sales) /
        NULLIF(COUNT(DISTINCT O.[Order ID]), 0) AS AverageOrderValue
FROM Customers C
JOIN Orders O
    ON C.[Customer ID] = O.[Customer ID]
JOIN Orders_Details OD
    ON O.[Order ID] = OD.[Order ID]
GROUP BY
    C.[Customer ID],
    C.[Customer Name],
    C.Segment;


SELECT *
FROM vw_Customer_Performance
ORDER BY
    TotalSales DESC;



-- =========================================================
-- 19. STORED PROCEDURE: SALES BY DATE RANGE
-- =========================================================

CREATE PROCEDURE sp_Sales_By_Date_Range
    @StartDate DATE,
    @EndDate DATE
AS
BEGIN

    SET NOCOUNT ON;

    SELECT
        SUM(OD.Sales) AS TotalSales,
        SUM(OD.Profit) AS TotalProfit,
        COUNT(DISTINCT O.[Order ID]) AS TotalOrders,
        (SUM(OD.Profit) / NULLIF(SUM(OD.Sales), 0)) * 100 AS ProfitMargin
    FROM Orders O
    JOIN Orders_Details OD
        ON O.[Order ID] = OD.[Order ID]
    WHERE O.[Order Date] BETWEEN @StartDate AND @EndDate;

END;


-- Example

EXEC sp_Sales_By_Date_Range
    @StartDate = '2016-01-01',
    @EndDate = '2016-12-31';



-- =========================================================
-- 20. STORED PROCEDURE: REGIONAL PERFORMANCE
-- =========================================================

CREATE PROCEDURE sp_Regional_Performance
    @Region VARCHAR(100)
AS
BEGIN

    SET NOCOUNT ON;

    SELECT
        L.Region,
        SUM(OD.Sales) AS TotalSales,
        SUM(OD.Profit) AS TotalProfit,
        COUNT(DISTINCT OD.[Order ID]) AS TotalOrders
    FROM Location L
    JOIN Orders_Details OD
        ON L.LocationKey = OD.LocationKey
    WHERE L.Region = @Region
    GROUP BY
        L.Region;

END;


-- Example

EXEC sp_Regional_Performance
    @Region = 'Central';