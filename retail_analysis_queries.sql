select *from dbo.analytics_data

CREATE TABLE Product (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(100),
    Category VARCHAR(50),
    Brand VARCHAR(50),
    SKU VARCHAR(50),
    Price DECIMAL(10,2),
    Rating DECIMAL(3,2),
    Reviews INT,
    Discount DECIMAL(5,2)
);
INSERT INTO Product
SELECT DISTINCT
    Product_ID,
    Product_Name,
    Category,
    Brand,
    SKU,
    Price,
    Rating,
    Reviews,
    Discount
FROM analytics_data;

CREATE TABLE Warehouse (
    WarehouseID INT IDENTITY(1,1) PRIMARY KEY,
    WarehouseName VARCHAR(100),
    ReturnPolicy VARCHAR(50)
);
INSERT INTO Warehouse (WarehouseName, ReturnPolicy)
SELECT DISTINCT
    Warehouse,
    Return_Policy
FROM analytics_data;

CREATE TABLE Supplier (
    SupplierID INT IDENTITY(1,1) PRIMARY KEY,
    SupplierName VARCHAR(100),
    SupplierContact VARCHAR(50)
);

INSERT INTO Supplier (SupplierName, SupplierContact)
SELECT DISTINCT
    Supplier,
    Supplier_Contact
FROM analytics_data;

CREATE TABLE Inventory (
    InventoryID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT,
    WarehouseID INT,
    SupplierID INT,
    StockQuantity INT,
    FOREIGN KEY (ProductID) REFERENCES Product(ProductID),
    FOREIGN KEY (WarehouseID) REFERENCES Warehouse(WarehouseID),
    FOREIGN KEY (SupplierID) REFERENCES Supplier(SupplierID)
);

INSERT INTO Inventory (ProductID, WarehouseID, SupplierID, StockQuantity)
SELECT
    a.Product_ID,
    w.WarehouseID,
    s.SupplierID,
    a.Stock_Quantity
FROM analytics_data a
JOIN Warehouse w
    ON a.Warehouse = w.WarehouseName
   AND a.Return_Policy = w.ReturnPolicy
JOIN Supplier s
    ON a.Supplier = s.SupplierName
   AND a.Supplier_Contact = s.SupplierContact;

--1.  Identifies products with prices higher than the average price within their category.
  
SELECT 
    p.ProductID,
    p.ProductName,
    p.Category,
    p.Price,
    AVG(p2.Price) OVER (PARTITION BY p.Category) AS AvgCategoryPrice
FROM Product p
JOIN Product p2 
    ON p.Category = p2.Category
WHERE p.Price >
      (SELECT AVG(p3.Price)
       FROM Product p3
       WHERE p3.Category = p.Category);

--2.Finding Categories with Highest Average Rating Across Products
SELECT 
    Category,
    AVG(Rating) AS AvgRating
FROM Product
GROUP BY Category
ORDER BY AvgRating DESC;

--only 1 highest
SELECT TOP 1
    Category,
    AVG(Rating) AS AvgRating
FROM Product
GROUP BY Category
ORDER BY AvgRating DESC;


--3.Find the most reviewed product in each warehouse

WITH RankedProducts AS (
    SELECT
        w.WarehouseName,
        p.ProductID,
        p.ProductName,
        p.Reviews,
        ROW_NUMBER() OVER (
            PARTITION BY w.WarehouseID
            ORDER BY p.Reviews DESC
        ) AS rn
    FROM Inventory i
    JOIN Product p ON i.ProductID = p.ProductID
    JOIN Warehouse w ON i.WarehouseID = w.WarehouseID
)
SELECT
    WarehouseName,
    ProductID,
    ProductName,
    Reviews
FROM RankedProducts
WHERE rn = 1;


--4.find products that have higher-than-average prices within their category, along with their discount and supplier

SELECT
    p.ProductID,
    p.ProductName,
    p.Category,
    p.Price,
    p.Discount,
    s.SupplierName
FROM Product p
JOIN Inventory i ON p.ProductID = i.ProductID
JOIN Supplier s ON i.SupplierID = s.SupplierID
WHERE p.Price >
    (
        SELECT AVG(p2.Price)
        FROM Product p2
        WHERE p2.Category = p.Category
    );



--5.Query to find the top 2 products with the highest average rating in each category

WITH RankedRatings AS (
    SELECT
        ProductID,
        ProductName,
        Category,
        Rating,
        ROW_NUMBER() OVER (
            PARTITION BY Category
            ORDER BY Rating DESC
        ) AS rn
    FROM Product
)
SELECT
    ProductID,
    ProductName,
    Category,
    Rating
FROM RankedRatings
WHERE rn <= 2
ORDER BY Category, Rating DESC;


--6.Analysis Across All Return Policy Categories(Count, Avgstock, total stock, weighted_avg_rating, etc)

--Analysis across Return Policy categories
Metrics:
--Product count
--Average stock
--Total stock
--Weighted average rating
--Weighted Avg Rating formula:
--SUM(Rating * StockQuantity) / SUM(StockQuantity)

SELECT
    w.ReturnPolicy,
    COUNT(DISTINCT p.ProductID) AS ProductCount,
    AVG(i.StockQuantity) AS AvgStock,
    SUM(i.StockQuantity) AS TotalStock,
    SUM(p.Rating * i.StockQuantity) * 1.0 / NULLIF(SUM(i.StockQuantity), 0)
        AS WeightedAvgRating
FROM Inventory i
JOIN Product p ON i.ProductID = p.ProductID
JOIN Warehouse w ON i.WarehouseID = w.WarehouseID
GROUP BY w.ReturnPolicy
ORDER BY TotalStock DESC;

--Category + ReturnPolicy combined analysis

SELECT
    p.Category,
    w.ReturnPolicy,
    COUNT(DISTINCT p.ProductID) AS ProductCount,
    SUM(i.StockQuantity) AS TotalStock,
    AVG(p.Price) AS AvgPrice,
    AVG(p.Rating) AS AvgRating
FROM Inventory i
JOIN Product p ON i.ProductID = p.ProductID
JOIN Warehouse w ON i.WarehouseID = w.WarehouseID
GROUP BY p.Category, w.ReturnPolicy

ORDER BY p.Category;
