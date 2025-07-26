

-- ======================================================================
-- 📘 INFORMAL TABLE CLASSIFICATION
-- ======================================================================
-- DIMENSION TABLES
-- Table Name                  | Sub-Type         | Notes
-- ---------------------------|------------------|-----------------------------
-- CustomerDim                | Normal           | Basic customer info
-- DateDim                    | Normal (RP)      | Role-played via views
-- StoreDim                   | Normal (RP+OL)   | Retail/Wholesale (via license outrigger)
-- StoreLicenseDim            | Slowly Changing   | SCD Type 2 with license metadata
-- WarehouseDim               | Normal           | For inventory locations
-- FactoryDim                 | Normal           | Manufacturing units
-- SupplierDim                | Normal           | Milk cooperatives / suppliers
-- PaymentDim                 | Normal (Outrigger)| Used via OrderPaymentBridge
-- CategoryDim                | Normal           | Product category hierarchy
-- BrandDim                   | Derived           | Belongs to CategoryDim
-- ProductDim                 | Derived           | Belongs to BrandDim
-- PromoDim                  | Derived           | Campaign info
-- ReasonDim                  | Derived           | For returns/failures
-- JunkDim                    | Derived           | Encodes 4 binary flags
-- OrderDim                   | Role-Playing      | Generalized BUY / RETURN source
-- OrderPaymentBridge         | Bridge            | Many-to-many Order ↔ Payment

-- FACT TABLES
-- Table Name                        | Sub-Type         | Notes
-- ----------------------------------|------------------|-----------------------------
-- SalesFact                         | Normal           | Uses OrderDim with OrderType='BUY'
-- ReturnsFact                       | Normal           | Uses OrderDim with OrderType='RETURN'
-- CustomerFeedbackFact              | Normal           | For Product/Order feedbacks
-- ProductionFact                    | Normal           | Factory-level stats
-- InventoryFact                     | Normal           | Product stock snapshots
-- SupplierSupplyFact                | Normal           | Supplies from suppliers
-- FailedFact                        | Normal           | Product failures (defects, etc.)
-- DistributionFact                  | Normal (RP Use)  | Tracks flow from Wholesale → Retail
-- ProductViewFact                   | Factless         | Product views, no measures
-- CategorySales_Aggregate           | Aggregate        | SUM by Category, Customer, Store, Date
-- StoreSales_Aggregate              | Aggregate        | Store-based daily sales summary
-- ProductPerformance_Aggregate      | Aggregate        | Per-product sales & quantity per day

-- 🔹 RP = Role-Playing Dimension
-- 🔸 Derived = From normalization/multi-use abstraction
-- 📎 OL = Outrigger Linked

-- ======================================================================
-- 📘 CONCEPTS IMPLEMENTED IN THIS DATA WAREHOUSE SCHEMA
-- ======================================================================
-- ✅ Star Schema                 - All facts connected via dimensional keys
-- ✅ Role-Playing Dimensions     - DateDim (Order, Return, etc.), StoreDim (Wholesale, Retail)
-- ✅ Derived Dimensions          - BrandDim, ProductDim, PromoDim, ReasonDim
-- ✅ Slowly Changing Dimension   - StoreLicenseDim (SCD Type 2)
-- ✅ Junk Dimension              - JunkDim with 4 binary flags (promo, returnable, etc.)
-- ✅ Bridge Tables               - ProductPromoBridge, OrderPaymentBridge (M:N resolution)
-- ✅ Snowflaking                 - Brand → Category → Product (normalized)
-- ✅ Aggregate Fact Tables       - Category/Store/Product performance summaries
-- ✅ Factless Fact Table         - ProductViewFact for logging interactions
-- ✅ Degenerate Dimension        - BillNumber (in SalesFact)
-- ✅ Conformed Dimensions        - DateDim, StoreDim used in multiple fact tables

-- ======================================================================
-- 🧱 ENHANCED DATA WAREHOUSE SCHEMA (FULL)
-- ======================================================================
-- Covers: transactional flow (orders), supply chain (factories/suppliers),
-- customer insights (feedback/views), promotions (campaign tracking), and
-- analytics (aggregates, RP views).


CREATE TABLE CategoryDim (
    CategoryID INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName VARCHAR(50)
);
GO

CREATE TABLE BrandDim (
    BrandID INT IDENTITY(1,1) PRIMARY KEY,
    BrandName VARCHAR(255),
    CategoryID INT,
    FOREIGN KEY (CategoryID) REFERENCES CategoryDim(CategoryID)
);
GO

CREATE TABLE ProductDim (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(50),
    BrandID INT,
    Price DECIMAL(10,2),
    FOREIGN KEY (BrandID) REFERENCES BrandDim(BrandID)
);
GO

CREATE TABLE CustomerDim (
    CustomerID INT PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    Country VARCHAR(50),
    Email VARCHAR(255),
    Phone VARCHAR(20)
);
GO

------------------------------------------------------------
-- 2) DateDim: full daily coverage for ~2 years
------------------------------------------------------------
CREATE TABLE DateDim (
    DateID INT PRIMARY KEY,
    ActualDate DATE,
    Month   VARCHAR(20),
    Quarter VARCHAR(20),
    Year    INT
);
GO

------------------------------------------------------------
-- 3) StoreLicenseDim (Outrigger to StoreDim)
------------------------------------------------------------
CREATE TABLE StoreLicenseDim (
    StoreLicenseSK INT IDENTITY(1,1) PRIMARY KEY,
    LicenseType VARCHAR(50),
    LicenseIssued DATE,
    LicenseExpiry DATE,
    ValidFrom DATE,
    ValidTo DATE,
    CurrentFlag BIT,
    IsRetailStore BIT,
    IsWholesaleStore BIT
);
GO

------------------------------------------------------------
-- 4) StoreDim
------------------------------------------------------------
CREATE TABLE StoreDim (
    StoreID INT PRIMARY KEY,
    StoreName VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    Country VARCHAR(50),
    StoreLicenseSK INT NULL,
    FOREIGN KEY (StoreLicenseSK) REFERENCES StoreLicenseDim(StoreLicenseSK)
);
GO

------------------------------------------------------------
-- 5) WarehouseDim
------------------------------------------------------------
CREATE TABLE WarehouseDim (
    WarehouseID INT PRIMARY KEY,
    WarehouseName VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    Country VARCHAR(50),
    StorageCapacity DECIMAL(10,2)
);
GO

------------------------------------------------------------
-- 6) JunkDim
------------------------------------------------------------
CREATE TABLE JunkDim (
    JunkID INT IDENTITY(1,1) PRIMARY KEY,
    IsPromotional BIT,
    IsOnline BIT,
    IsReturnable BIT,
    IsClearance BIT
);
GO

------------------------------------------------------------
-- 7) PaymentDim (Outrigger for OrderDim)
------------------------------------------------------------
CREATE TABLE PaymentDim (
    PaymentID INT PRIMARY KEY,
    PaymentMethod VARCHAR(50) NOT NULL
);
GO

------------------------------------------------------------
-- 8) ReasonDim
------------------------------------------------------------
CREATE TABLE ReasonDim (
    ReasonID INT PRIMARY KEY,
    Reason VARCHAR(50)
);
GO

------------------------------------------------------------
-- 9) SupplierDim
------------------------------------------------------------
CREATE TABLE SupplierDim (
    SupplierID INT PRIMARY KEY,
    SupplierName VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    Country VARCHAR(50),
    ContactNumber VARCHAR(20)
);
GO

------------------------------------------------------------
-- 10) FactoryDim
------------------------------------------------------------
CREATE TABLE FactoryDim (
    FactoryID INT PRIMARY KEY,
    FactoryName VARCHAR(50),
    City VARCHAR(50),
    State VARCHAR(50),
    Country VARCHAR(50)
);
GO

------------------------------------------------------------
-- 11) WarehouseDim (already done in step 5)
--    Skipping repeated definitions
------------------------------------------------------------

------------------------------------------------------------
-- 12) PromoDim + Bridge to Product
------------------------------------------------------------
CREATE TABLE PromoDim (
    PromotionID INT IDENTITY(1,1) PRIMARY KEY,
    PromotionName VARCHAR(50)
);
GO

CREATE TABLE ProductPromoBridge (
    ProductID INT,
    PromotionID INT,
    PRIMARY KEY (ProductID, PromotionID),
    FOREIGN KEY (ProductID) REFERENCES ProductDim(ProductID),
    FOREIGN KEY (PromotionID) REFERENCES PromoDim(PromotionID)
);
GO

------------------------------------------------------------
-- 13) Additional Role Dimensions for Orders, etc.
--     We unify "buy" and "return" in OrderDim (OrderType='BUY' or 'RETURN')
------------------------------------------------------------

CREATE TABLE OrderDim (
    OrderDimID INT IDENTITY(1,1) PRIMARY KEY,
    OrderType VARCHAR(10),       -- e.g. 'BUY', 'RETURN'
    OrderDateID INT NOT NULL,    -- references DateDim for the date
    OrderSource VARCHAR(15),     -- 'CUSTOMER' or 'RETAIL_STORE'
    CustomerID INT NULL,         -- if from an end-customer
    StoreID INT NULL,            -- if from a store

    FOREIGN KEY (OrderDateID) REFERENCES DateDim(DateID),
    FOREIGN KEY (CustomerID) REFERENCES CustomerDim(CustomerID),
    FOREIGN KEY (StoreID) REFERENCES StoreDim(StoreID)
);
GO

------------------------------------------------------------
-- 14) Bridge: OrderPaymentBridge (for PaymentDim)
------------------------------------------------------------
CREATE TABLE OrderPaymentBridge (
    OrderDimID INT NOT NULL,
    PaymentID INT NOT NULL,
    PRIMARY KEY (OrderDimID, PaymentID),
    FOREIGN KEY (OrderDimID) REFERENCES OrderDim(OrderDimID),
    FOREIGN KEY (PaymentID) REFERENCES PaymentDim(PaymentID)
);
GO

------------------------------------------------------------
-- 15) Fact Tables
------------------------------------------------------------

-- a) SalesFact (BUY orders)
CREATE TABLE SalesFact (
    SalesFactID INT IDENTITY(1,1) PRIMARY KEY,
    OrderDimID INT NOT NULL,     -- references an order with OrderType='BUY'
    ProductID INT NOT NULL,
    QuantitySold INT,
    SalesAmount DECIMAL(10,2),
    BillNumber VARCHAR(50),
    JunkID INT,

    FOREIGN KEY (OrderDimID) REFERENCES OrderDim(OrderDimID),
    FOREIGN KEY (ProductID) REFERENCES ProductDim(ProductID),
    FOREIGN KEY (JunkID) REFERENCES JunkDim(JunkID)
);
GO

-- b) ReturnsFact (RETURN orders)
CREATE TABLE ReturnsFact (
    ReturnsFactID INT IDENTITY(1,1) PRIMARY KEY,
    OrderDimID INT NOT NULL,     -- references an order with OrderType='RETURN'
    ProductID INT NOT NULL,
    ReturnReason VARCHAR(100),
    QuantityReturned INT,
    JunkID INT,

    FOREIGN KEY (OrderDimID) REFERENCES OrderDim(OrderDimID),
    FOREIGN KEY (ProductID) REFERENCES ProductDim(ProductID),
    FOREIGN KEY (JunkID) REFERENCES JunkDim(JunkID)
);
GO

-- c) CustomerFeedbackFact
CREATE TABLE CustomerFeedbackFact (
    FeedbackFactID INT IDENTITY(1,1) PRIMARY KEY,
    OrderDimID INT NOT NULL,     -- e.g. if feedback is for an existing order
    ProductID INT NOT NULL,      -- which product is being reviewed
    Rating INT,
    FeedbackComment VARCHAR(255),
    FeedbackDateID INT NOT NULL, -- references DateDim

    FOREIGN KEY (OrderDimID) REFERENCES OrderDim(OrderDimID),
    FOREIGN KEY (ProductID) REFERENCES ProductDim(ProductID),
    FOREIGN KEY (FeedbackDateID) REFERENCES DateDim(DateID)
);
GO

-- d) SupplierSupplyFact
CREATE TABLE SupplierSupplyFact (
    SupplyID INT IDENTITY(1,1) PRIMARY KEY,
    SupplierID INT,
    ProductID INT,
    SupplyDateID INT,
    QuantitySupplied INT,
    SupplyCost DECIMAL(10,2),

    FOREIGN KEY (SupplierID) REFERENCES SupplierDim(SupplierID),
    FOREIGN KEY (ProductID) REFERENCES ProductDim(ProductID),
    FOREIGN KEY (SupplyDateID) REFERENCES DateDim(DateID)
);
GO

-- e) ProductionFact
CREATE TABLE ProductionFact (
    ProductionID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT,
    FactoryID INT,
    ProductionDateID INT,
    QuantityProduced INT,
    ProductCost DECIMAL(10,2),

    FOREIGN KEY (ProductID) REFERENCES ProductDim(ProductID),
    FOREIGN KEY (FactoryID) REFERENCES FactoryDim(FactoryID),
    FOREIGN KEY (ProductionDateID) REFERENCES DateDim(DateID)
);
GO

-- f) InventoryFact
CREATE TABLE InventoryFact (
    InventoryID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT,
    WarehouseID INT,
    SnapshotDateID INT,
    QuantityOnHand INT,

    FOREIGN KEY (ProductID) REFERENCES ProductDim(ProductID),
    FOREIGN KEY (WarehouseID) REFERENCES WarehouseDim(WarehouseID),
    FOREIGN KEY (SnapshotDateID) REFERENCES DateDim(DateID)
);
GO

-- g) DistributionFact
CREATE TABLE DistributionFact (
    DistributionID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT,
    WholesaleStoreID INT,
    RetailStoreID INT,
    DateID INT,
    Quantity INT,

    FOREIGN KEY (ProductID) REFERENCES ProductDim(ProductID),
    FOREIGN KEY (WholesaleStoreID) REFERENCES StoreDim(StoreID),
    FOREIGN KEY (RetailStoreID) REFERENCES StoreDim(StoreID),
    FOREIGN KEY (DateID) REFERENCES DateDim(DateID)
);
GO

-- h) FailedFact
CREATE TABLE FailedFact (
    FailedID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT,
    Status VARCHAR(50),
    ReasonID INT,
    FailedQuantity INT NOT NULL,

    FOREIGN KEY (ProductID) REFERENCES ProductDim(ProductID),
    FOREIGN KEY (ReasonID) REFERENCES ReasonDim(ReasonID)
);
GO

-- i) ProductViewFact (factless)
CREATE TABLE ProductViewFact (
    ProductID INT,
    CustomerID INT,
    ViewDateID INT,

    FOREIGN KEY (ProductID) REFERENCES ProductDim(ProductID),
    FOREIGN KEY (CustomerID) REFERENCES CustomerDim(CustomerID),
    FOREIGN KEY (ViewDateID) REFERENCES DateDim(DateID)
);
GO



------------------------------------------------------------
-- 16) Aggregate Facts
------------------------------------------------------------

-- CategorySales_Aggregate
CREATE TABLE CategorySales_Aggregate (
    CategoryAgg_ID INT IDENTITY(1,1) PRIMARY KEY,
    CategoryID INT,
    CustomerID INT,
    StoreID INT,
    DateID INT,
    SalesAmount DECIMAL(10,2),

    FOREIGN KEY (CategoryID) REFERENCES CategoryDim(CategoryID),
    FOREIGN KEY (CustomerID) REFERENCES CustomerDim(CustomerID),
    FOREIGN KEY (StoreID) REFERENCES StoreDim(StoreID),
    FOREIGN KEY (DateID) REFERENCES DateDim(DateID)
);
GO

-- StoreSales_Aggregate
CREATE TABLE StoreSales_Aggregate (
    StoreAgg_ID INT IDENTITY(1,1) PRIMARY KEY,
    StoreID INT,
    DateID INT,
    TotalSales DECIMAL(10,2),
    TotalQuantitySold INT,

    FOREIGN KEY (StoreID) REFERENCES StoreDim(StoreID),
    FOREIGN KEY (DateID) REFERENCES DateDim(DateID)
);
GO

-- ProductPerformance_Aggregate
CREATE TABLE ProductPerformance_Aggregate (
    ProductAgg_ID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT,
    DateID INT,
    TotalSales DECIMAL(10,2),
    TotalQuantitySold INT,

    FOREIGN KEY (ProductID) REFERENCES ProductDim(ProductID),
    FOREIGN KEY (DateID) REFERENCES DateDim(DateID)
);
GO



-- a) Add columns to CategorySales_Aggregate
ALTER TABLE CategorySales_Aggregate
ADD CategoryName VARCHAR(50), 
    StoreName VARCHAR(50), 
    ActualDate DATE;
GO

-- b) Add columns to StoreSales_Aggregate
ALTER TABLE StoreSales_Aggregate
ADD StoreName VARCHAR(50), 
    ActualDate DATE;
GO

-- c) Add columns to ProductPerformance_Aggregate
ALTER TABLE ProductPerformance_Aggregate
ADD ProductName VARCHAR(50), 
    ActualDate DATE;
GO

------------------------------------------------------------
-- ✅ Order Dates (from BUY orders in OrderDim)
------------------------------------------------------------
CREATE OR ALTER VIEW OrderDateDim AS
SELECT DISTINCT d.*
FROM DateDim d
JOIN OrderDim o ON o.OrderDateID = d.DateID
WHERE o.OrderType = 'BUY';
GO

------------------------------------------------------------
-- 🔄 Return Dates (from RETURN orders in OrderDim)
------------------------------------------------------------
CREATE OR ALTER VIEW ReturnDateDim AS
SELECT DISTINCT d.*
FROM DateDim d
JOIN OrderDim o ON o.OrderDateID = d.DateID
WHERE o.OrderType = 'RETURN';
GO

------------------------------------------------------------
-- 🗣️ Feedback Dates (from CustomerFeedbackFact)
------------------------------------------------------------
CREATE OR ALTER VIEW FeedbackDateDim AS
SELECT DISTINCT d.*
FROM DateDim d
JOIN CustomerFeedbackFact f ON f.FeedbackDateID = d.DateID;
GO

------------------------------------------------------------
-- 🚚 Supply Dates (from SupplierSupplyFact)
------------------------------------------------------------
CREATE OR ALTER VIEW SupplyDateDim AS
SELECT DISTINCT d.*
FROM DateDim d
JOIN SupplierSupplyFact s ON s.SupplyDateID = d.DateID;
GO

------------------------------------------------------------
-- 🏭 Production Dates (from ProductionFact)
------------------------------------------------------------
CREATE OR ALTER VIEW ProductionDateDim AS
SELECT DISTINCT d.*
FROM DateDim d
JOIN ProductionFact p ON p.ProductionDateID = d.DateID;
GO

------------------------------------------------------------
-- 📦 Inventory Snapshot Dates (from InventoryFact)
------------------------------------------------------------
CREATE OR ALTER VIEW SnapshotDateDim AS
SELECT DISTINCT d.*
FROM DateDim d
JOIN InventoryFact i ON i.SnapshotDateID = d.DateID;
GO



------------------------------------------------------------
-- Insertion Queries :
------------------------------------------------------------

SET IDENTITY_INSERT CategoryDim ON;
INSERT INTO CategoryDim (CategoryID, CategoryName)
VALUES
(1, 'Liquid Milk'),
(2, 'Flavored Milk'),
(3, 'Butter'),
(4, 'Cheese'),
(5, 'Ghee'),
(6, 'Yogurt'),
(7, 'Paneer'),
(8, 'Ice Cream'),
(9, 'Milk Powder'),
(10, 'Dahi');
SET IDENTITY_INSERT CategoryDim OFF;
GO


SET IDENTITY_INSERT BrandDim ON;
INSERT INTO BrandDim (BrandID, BrandName, CategoryID)
VALUES
(1, 'Amul Gold', 1),
(2, 'Amul Taaza', 1),
(3, 'Amul Shakti', 1),
(4, 'Amul Slim & Trim', 1),

(5, 'Amul Kool Kesar', 2),
(6, 'Amul Kool Elaichi', 2),
(7, 'Amul Kool Café', 2),
(8, 'Amul Lassi', 2),

(9, 'Amul Pasteurized Butter', 3),
(10, 'Amul Garlic Butter', 3),
(11, 'Amul Masti Butter', 3),

(12, 'Amul Processed Cheese', 4),
(13, 'Amul Cheese Cubes', 4),
(14, 'Amul Cheese Slices', 4),
(15, 'Amul Cheese Spread', 4),

(16, 'Amul Pure Ghee', 5),
(17, 'Amul Cow Ghee', 5),
(18, 'Amul Desi Ghee', 5),

(19, 'Amul Masti Dahi', 6),
(20, 'Amul Probiotic Dahi', 6),
(21, 'Amul Dahi Lite', 6),

(22, 'Amul Fresh Paneer', 7),
(23, 'Amul Malai Paneer', 7),
(24, 'Amul Tikka Paneer', 7),

(25, 'Amul Vanilla Ice Cream', 8),
(26, 'Amul Chocolate Ice Cream', 8),
(27, 'Amul Mango Ice Cream', 8),
(28, 'Amul Butterscotch Ice Cream', 8),

(29, 'Amul Skimmed Milk Powder', 9),
(30, 'Amul Whole Milk Powder', 9),

(31, 'Amul Premium Dahi', 10),
(32, 'Amul Thick Dahi', 10),
(33, 'Amul Greek Yogurt Strawberry', 6),
(34, 'Amul Greek Yogurt Blueberry', 6),
(35, 'Amul Diet Dahi', 10),
(36, 'Amul Gold Pouch', 1),
(37, 'Amul Cool Cafe Latte', 2),
(38, 'Amul Shrikhand Mango', 6),
(39, 'Amul Shrikhand Elaichi', 6),
(40, 'Amul Buttermilk', 2);
SET IDENTITY_INSERT BrandDim OFF;
GO


INSERT INTO ProductDim (ProductID, ProductName, BrandID, Price)
VALUES
(1, 'Amul Gold 500ml', 1, 25.00),
(2, 'Amul Gold 1L', 1, 48.00),
(3, 'Amul Gold 6-pack', 1, 140.00),
(4, 'Amul Taaza 500ml', 2, 22.00),
(5, 'Amul Taaza 1L', 2, 44.00),
(6, 'Amul Taaza 6-pack', 2, 130.00),
(7, 'Amul Shakti 1L', 3, 46.00),
(8, 'Amul Slim & Trim 1L', 4, 40.00),
(9, 'Amul Kool Kesar 200ml', 5, 20.00),
(10, 'Amul Kool Kesar 6-pack', 5, 110.00),
(11, 'Amul Kool Elaichi 200ml', 6, 20.00),
(12, 'Amul Kool Café 200ml', 7, 25.00),
(13, 'Amul Lassi 250ml', 8, 18.00),
(14, 'Amul Lassi 6-pack', 8, 100.00),
(15, 'Amul Butter 100g', 9, 48.00),
(16, 'Amul Butter 200g', 9, 94.00),
(17, 'Amul Garlic Butter 100g', 10, 55.00),
(18, 'Amul Masti Butter 100g', 11, 47.00),
(19, 'Amul Processed Cheese 200g', 12, 90.00),
(20, 'Amul Cheese Cubes 200g', 13, 95.00),
(21, 'Amul Cheese Slices 10s', 14, 110.00),
(22, 'Amul Cheese Spread 200g', 15, 95.00),
(23, 'Amul Pure Ghee 500ml', 16, 200.00),
(24, 'Amul Cow Ghee 500ml', 17, 210.00),
(25, 'Amul Desi Ghee 500ml', 18, 220.00),
(26, 'Amul Masti Dahi 400g', 19, 35.00),
(27, 'Amul Probiotic Dahi 400g', 20, 40.00),
(28, 'Amul Dahi Lite 400g', 21, 38.00),
(29, 'Amul Fresh Paneer 200g', 22, 75.00),
(30, 'Amul Malai Paneer 200g', 23, 78.00),
(31, 'Amul Tikka Paneer 200g', 24, 82.00),
(32, 'Amul Vanilla Ice Cream 100ml', 25, 30.00),
(33, 'Amul Choco Ice Cream 100ml', 26, 30.00),
(34, 'Amul Mango Ice Cream 100ml', 27, 30.00),
(35, 'Amul Butterscotch Ice Cream 100ml', 28, 32.00),
(36, 'Amul SMP 500g', 29, 180.00),
(37, 'Amul WMP 500g', 30, 190.00),
(38, 'Amul Premium Dahi 400g', 31, 42.00),
(39, 'Amul Thick Dahi 400g', 32, 40.00),
(40, 'Amul Greek Yogurt Strawberry', 33, 55.00),
(41, 'Amul Greek Yogurt Blueberry', 34, 58.00),
(42, 'Amul Diet Dahi 400g', 35, 38.00),
(43, 'Amul Gold Pouch 500ml', 36, 25.00),
(44, 'Amul Cool Cafe Latte 200ml', 37, 30.00),
(45, 'Amul Shrikhand Mango 250g', 38, 50.00),
(46, 'Amul Shrikhand Elaichi 250g', 39, 50.00),
(47, 'Amul Buttermilk 200ml', 40, 15.00),
(48, 'Amul Buttermilk Family Pack 1L', 40, 45.00),
(49, 'Amul Taaza Tetra Pack 1L', 2, 46.00),
(50, 'Amul Gold Tetra Pack 1L', 1, 50.00),
(51, 'Amul Masti Chaas 250ml', 40, 18.00),
(52, 'Amul Rose Lassi 250ml', 8, 20.00),
(53, 'Amul Elaichi Milk 200ml', 6, 22.00),
(54, 'Amul Badam Milk 200ml', 6, 25.00),
(55, 'Amul Chocolate Milk 200ml', 6, 25.00),
(56, 'Amul Malai Kulfi 60ml', 25, 20.00),
(57, 'Amul Rajbhog Ice Cream 500ml', 28, 95.00),
(58, 'Amul Ice Cream Party Pack 1L', 28, 180.00),
(59, 'Amul Pouch Curd 500ml', 31, 38.00),
(60, 'Amul UHT Milk 1L', 1, 52.00),
(61, 'Amul Lactose Free Milk 500ml', 20, 60.00),
(62, 'Amul Rasmalai 300g', 38, 85.00),
(63, 'Amul Spiced Buttermilk 250ml', 40, 18.00),
(64, 'Amul Slim Milk 500ml', 4, 30.00),
(65, 'Amul Lite Cheese Slices', 14, 105.00),
(66, 'Amul Chocolate Spread 200g', 15, 110.00),
(67, 'Amul Masti Curd 200g', 19, 22.00),
(68, 'Amul Milk Cream 200ml', 9, 60.00),
(69, 'Amul Mithai Mate 200g', 30, 55.00),
(70, 'Amul Rose Milk 200ml', 6, 24.00),
(71, 'Amul Mocha Milk 200ml', 7, 26.00),
(72, 'Amul Fruit Yogurt Mix 100g', 33, 28.00),
(73, 'Amul Greek Yogurt Natural', 33, 52.00),
(74, 'Amul Ice Cream Combo Pack', 28, 160.00),
(75, 'Amul Mango Dahi 400g', 31, 42.00),
(76, 'Amul Milk Shake Vanilla 200ml', 6, 24.00),
(77, 'Amul Spicy Paneer Cubes 200g', 24, 85.00),
(78, 'Amul Mitha Dahi 400g', 32, 40.00),
(79, 'Amul Shrikhand Variety Pack', 38, 145.00),
(80, 'Amul Salted Lassi 200ml', 8, 16.00),
(81, 'Amul Milk Powder Pouch 500g', 29, 170.00),
(82, 'Amul Probiotic Lassi 250ml', 8, 22.00),
(83, 'Amul Gold 2L Family Pack', 1, 95.00),
(84, 'Amul Gold 5L Bulk', 1, 230.00),
(85, 'Amul Processed Cheese 400g', 12, 160.00),
(86, 'Amul Cheese Spread Spicy 200g', 15, 98.00),
(87, 'Amul Whipping Cream 1L', 9, 145.00),
(88, 'Amul Toned Milk 1L', 3, 42.00),
(89, 'Amul Low Fat Milk 1L', 4, 40.00),
(90, 'Amul Elaichi Milkshake 200ml', 6, 26.00),
(91, 'Amul Double Toned Milk 500ml', 3, 20.00),
(92, 'Amul Masti Lassi Lite 250ml', 8, 18.00),
(93, 'Amul Paneer 500g Block', 22, 130.00),
(94, 'Amul Malai Paneer 500g', 23, 135.00),
(95, 'Amul Tikka Paneer 500g', 24, 145.00),
(96, 'Amul Cheese Pizza Cut 500g', 39, 190.00),
(97, 'Amul WMP 1kg Tin', 30, 350.00),
(98, 'Amul SMP 1kg Pouch', 29, 320.00),
(99, 'Amul Dahi Tetra Pack 1L', 31, 80.00),
(100, 'Amul Buttermilk Spiced 1L', 40, 42.00);
GO
INSERT INTO ProductDim (ProductID, ProductName, BrandID, Price)
VALUES
(101, 'Amul Gold Family Pack 2L', 1, 96.00),
(102, 'Amul Gold 5L Bulk Pack', 1, 230.00),
(103, 'Amul Taaza 2L', 2, 90.00),
(104, 'Amul Taaza 5L', 2, 220.00),
(105, 'Amul Shakti Toned Milk 1L', 3, 48.00),
(106, 'Amul Shakti 500ml Pouch', 3, 25.00),
(107, 'Amul Slim 500ml', 4, 24.00),
(108, 'Amul Slim 1L Tetra', 4, 47.00),
(109, 'Amul Kool Kesar Family Pack', 5, 105.00),
(110, 'Amul Kool Elaichi 6-Pack', 6, 110.00),
(111, 'Amul Kool Café Lite 200ml', 7, 22.00),
(112, 'Amul Lassi Spiced 250ml', 8, 20.00),
(113, 'Amul Butter Unsalted 100g', 9, 50.00),
(114, 'Amul Butter Tikka 200g', 9, 98.00),
(115, 'Amul Butter Garlic Spread', 10, 70.00),
(116, 'Amul Masti Butter Unsalted', 11, 52.00),
(117, 'Amul Processed Cheese 400g', 12, 165.00),
(118, 'Amul Cheese Cubes Spicy 200g', 13, 100.00),
(119, 'Amul Cheese Slice Combo', 14, 180.00),
(120, 'Amul Cheese Spread Jalapeno', 15, 110.00),
(121, 'Amul Pure Ghee 1L', 16, 395.00),
(122, 'Amul Cow Ghee 1L', 17, 410.00),
(123, 'Amul Desi Ghee 1L', 18, 425.00),
(124, 'Amul Masti Dahi 1kg', 19, 80.00),
(125, 'Amul Probiotic Dahi 1kg', 20, 90.00),
(126, 'Amul Dahi Lite 1kg', 21, 85.00),
(127, 'Amul Fresh Paneer 1kg', 22, 240.00),
(128, 'Amul Malai Paneer 1kg', 23, 250.00),
(129, 'Amul Tikka Paneer 1kg', 24, 265.00),
(130, 'Amul Vanilla Ice Cream 1L', 25, 180.00),
(131, 'Amul Choco Ice Cream 1L', 26, 185.00),
(132, 'Amul Mango Ice Cream 1L', 27, 185.00),
(133, 'Amul Butterscotch Ice Cream 1L', 28, 190.00),
(134, 'Amul SMP 1kg', 29, 320.00),
(135, 'Amul WMP 1kg', 30, 350.00),
(136, 'Amul Premium Dahi 1kg', 31, 90.00),
(137, 'Amul Thick Dahi 1kg', 32, 88.00),
(138, 'Amul Greek Yogurt Strawberry 500g', 33, 100.00),
(139, 'Amul Greek Yogurt Blueberry 500g', 34, 110.00),
(140, 'Amul Diet Dahi 1kg', 35, 85.00),
(141, 'Amul Gold Cream 200ml', 36, 70.00),
(142, 'Amul Cool Cafe Latte 6-pack', 37, 155.00),
(143, 'Amul Shrikhand Mango 500g', 38, 90.00),
(144, 'Amul Shrikhand Elaichi 500g', 39, 90.00),
(145, 'Amul Buttermilk 500ml', 40, 25.00),
(146, 'Amul Gold Tetra Family Pack 5L', 1, 240.00),
(147, 'Amul Taaza Lite Tetra 1L', 2, 46.00),
(148, 'Amul Butter Pouch 500g', 9, 130.00),
(149, 'Amul Cheese Shreds 200g', 12, 105.00),
(150, 'Amul Paneer Tikka Cubes 200g', 24, 88.00),
(151, 'Amul Paneer Biryani Mix 200g', 24, 95.00),
(152, 'Amul Gold 500ml Longlife', 1, 30.00),
(153, 'Amul Lassi Rose 200ml', 8, 18.00),
(154, 'Amul SMP Pouch 200g', 29, 110.00),
(155, 'Amul WMP Tin 200g', 30, 120.00),
(156, 'Amul Toned Milk 500ml', 3, 24.00),
(157, 'Amul Cheese Block 1kg', 12, 290.00),
(158, 'Amul Cheese Slices 20s', 14, 190.00),
(159, 'Amul Dahi Probiotic Lite', 20, 44.00),
(160, 'Amul Greek Yogurt Plain', 33, 55.00),
(161, 'Amul Gold Cream 500ml', 36, 120.00),
(162, 'Amul Ice Cream Mango Bar', 27, 25.00),
(163, 'Amul Masti Dahi 200ml Cup', 19, 20.00),
(164, 'Amul Shrikhand Mixed Pack', 38, 175.00),
(165, 'Amul Pouch Milk 250ml', 2, 15.00),
(166, 'Amul UHT Milk Full Cream 1L', 1, 55.00),
(167, 'Amul Paneer Cubes 100g', 22, 40.00),
(168, 'Amul Ice Cream Combo (Vanilla/Choco)', 25, 90.00),
(169, 'Amul Flavored Milk Almond', 5, 25.00),
(170, 'Amul Flavored Milk Rose', 6, 25.00),
(171, 'Amul Flavored Milk Saffron', 5, 26.00),
(172, 'Amul Slim Milk Pouch 500ml', 4, 22.00),
(173, 'Amul Milkshake Vanilla 180ml', 6, 20.00),
(174, 'Amul Shrikhand Dryfruit 250g', 38, 60.00),
(175, 'Amul Paneer Tikka 500g', 24, 145.00),
(176, 'Amul Buttermilk Mint 250ml', 40, 18.00),
(177, 'Amul Ice Cream Butterscotch Stick', 28, 25.00),
(178, 'Amul Ice Cream Cone Chocolate', 26, 30.00),
(179, 'Amul WMP Pouch 500g', 30, 180.00),
(180, 'Amul SMP Pouch 500g', 29, 170.00),
(181, 'Amul Milk Powder Skimmed 200g', 29, 75.00),
(182, 'Amul Ice Cream Mango Stick', 27, 25.00),
(183, 'Amul Ice Cream Rajbhog Family', 28, 160.00),
(184, 'Amul Greek Yogurt Mango 100g', 33, 28.00),
(185, 'Amul Lassi Lite 200ml', 8, 16.00),
(186, 'Amul Paneer Masala 250g', 24, 85.00),
(187, 'Amul SMP Family Tin 2kg', 29, 600.00),
(188, 'Amul Ice Cream Orange Bar', 27, 25.00),
(189, 'Amul Toned Milk Longlife 1L', 3, 50.00),
(190, 'Amul Butter Garlic 200g', 10, 95.00),
(191, 'Amul Desi Ghee Jar 1L', 18, 430.00),
(192, 'Amul Ice Cream Cassata', 25, 60.00),
(193, 'Amul Cheese Slices Cheddar', 14, 130.00),
(194, 'Amul Cheese Spread Herbs', 15, 115.00),
(195, 'Amul Rasmalai Cup', 38, 70.00),
(196, 'Amul Mitha Dahi 500g', 32, 50.00),
(197, 'Amul Shrikhand Elaichi Cup', 39, 50.00),
(198, 'Amul Ice Cream Vanilla 1L', 25, 185.00),
(199, 'Amul Gold 1L Pouch Toned', 1, 45.00),
(200, 'Amul WMP Instant Mix 500g', 30, 175.00);
GO
INSERT INTO ProductDim (ProductID, ProductName, BrandID, Price)
VALUES
(201, 'Amul Gold Longlife 1L', 1, 52.00),
(202, 'Amul Gold Homogenized Milk 1L', 1, 54.00),
(203, 'Amul Taaza Homogenized Milk 1L', 2, 50.00),
(204, 'Amul Taaza Lite 500ml', 2, 23.00),
(205, 'Amul Shakti Milk Family Pack 2L', 3, 92.00),
(206, 'Amul Slim Skimmed Milk 1L', 4, 42.00),
(207, 'Amul Kool Kesar 1L Pack', 5, 90.00),
(208, 'Amul Kool Elaichi Tetra 500ml', 6, 45.00),
(209, 'Amul Kool Café Bulk 1L', 7, 95.00),
(210, 'Amul Lassi Pouch 500ml', 8, 25.00),
(211, 'Amul Lassi Family Pack 1L', 8, 48.00),
(212, 'Amul Butter 500g Tub', 9, 135.00),
(213, 'Amul Garlic Butter Tub 500g', 10, 140.00),
(214, 'Amul Masti Butter Tub 200g', 11, 96.00),
(215, 'Amul Processed Cheese 1kg', 12, 295.00),
(216, 'Amul Cheese Cubes 400g', 13, 190.00),
(217, 'Amul Cheese Slices 30s', 14, 280.00),
(218, 'Amul Cheese Spread Mexican Salsa', 15, 125.00),
(219, 'Amul Pure Ghee 2L Jar', 16, 780.00),
(220, 'Amul Cow Ghee 2L', 17, 820.00),
(221, 'Amul Desi Ghee 2L Tin', 18, 840.00),
(222, 'Amul Masti Dahi 2kg Tub', 19, 150.00),
(223, 'Amul Probiotic Dahi 2kg', 20, 160.00),
(224, 'Amul Dahi Lite 2kg', 21, 155.00),
(225, 'Amul Fresh Paneer Slab 500g', 22, 130.00),
(226, 'Amul Malai Paneer Slab 500g', 23, 135.00),
(227, 'Amul Tikka Paneer Slab 500g', 24, 140.00),
(228, 'Amul Vanilla Ice Cream Tetra 500ml', 25, 85.00),
(229, 'Amul Choco Ice Cream Tetra 500ml', 26, 90.00),
(230, 'Amul Mango Ice Cream Tetra 500ml', 27, 88.00),
(231, 'Amul Butterscotch Ice Cream Tetra 500ml', 28, 92.00),
(232, 'Amul SMP Instant 200g', 29, 80.00),
(233, 'Amul WMP Instant 200g', 30, 90.00),
(234, 'Amul Premium Dahi 2kg Tub', 31, 160.00),
(235, 'Amul Thick Dahi 2kg Tub', 32, 158.00),
(236, 'Amul Greek Yogurt Mango 500g', 33, 110.00),
(237, 'Amul Greek Yogurt Natural 500g', 33, 105.00),
(238, 'Amul Diet Dahi 2kg', 35, 160.00),
(239, 'Amul Milk Cream 1L', 36, 150.00),
(240, 'Amul Cool Cafe Latte 1L Bottle', 37, 100.00),
(241, 'Amul Shrikhand Mixed Fruit 500g', 38, 90.00),
(242, 'Amul Shrikhand Cardamom 500g', 39, 90.00),
(243, 'Amul Buttermilk 2L', 40, 60.00),
(244, 'Amul Gold Bulk Can 10L', 1, 450.00),
(245, 'Amul Taaza 10L Pack', 2, 440.00),
(246, 'Amul Shakti 5L Can', 3, 225.00),
(247, 'Amul Slim & Trim 2L', 4, 80.00),
(248, 'Amul Kool Strawberry 200ml', 5, 22.00),
(249, 'Amul Kool Mango 200ml', 5, 22.00),
(250, 'Amul Masti Dahi Cup 100g', 19, 10.00),
(251, 'Amul Paneer Cubes Spicy 200g', 24, 85.00),
(252, 'Amul Paneer Cubes Garlic 200g', 24, 85.00),
(253, 'Amul WMP 2kg Tin', 30, 650.00),
(254, 'Amul SMP 2kg Pouch', 29, 640.00),
(255, 'Amul Ice Cream Mini Cup Vanilla 50ml', 25, 15.00),
(256, 'Amul Ice Cream Mini Cup Choco 50ml', 26, 15.00),
(257, 'Amul Ice Cream Mini Cup Mango 50ml', 27, 15.00),
(258, 'Amul Ice Cream Mini Cup Butter 50ml', 28, 15.00),
(259, 'Amul Greek Yogurt Strawberry 100g', 33, 25.00),
(260, 'Amul Greek Yogurt Mixed Berry 100g', 34, 25.00),
(261, 'Amul Ice Cream Pistachio 500ml', 28, 92.00),
(262, 'Amul Ice Cream Almond Fudge 500ml', 28, 95.00),
(263, 'Amul Butter Pouch 100g', 9, 47.00),
(264, 'Amul Butter Garlic 100g', 10, 53.00),
(265, 'Amul Cheese Spread Original 100g', 15, 48.00),
(266, 'Amul Cheese Spread Chilli 100g', 15, 50.00),
(267, 'Amul Paneer Tikka Masala 200g', 24, 90.00),
(268, 'Amul Ice Cream Cup Rajbhog 100ml', 27, 30.00),
(269, 'Amul Milkshake Strawberry 180ml', 6, 22.00),
(270, 'Amul Chocolate Milkshake 180ml', 6, 24.00),
(271, 'Amul Masala Buttermilk 200ml', 40, 18.00),
(272, 'Amul Paneer Chilli 250g', 24, 90.00),
(273, 'Amul Dahi Family Pack 5L', 31, 190.00),
(274, 'Amul Ghee Combo Pack 3L', 16, 1150.00),
(275, 'Amul SMP Jar 1kg', 29, 320.00),
(276, 'Amul Cheese Singles 10s', 14, 110.00),
(277, 'Amul Cheese Triangles 8s', 14, 90.00),
(278, 'Amul Milkshake Chocolate 1L', 7, 90.00),
(279, 'Amul Lassi Meetha 1L', 8, 40.00),
(280, 'Amul Cow Ghee Jar 1L', 17, 415.00),
(281, 'Amul SMP Tin 5kg', 29, 1500.00),
(282, 'Amul WMP Tin 5kg', 30, 1550.00),
(283, 'Amul Ice Cream Cassata 125ml', 25, 40.00),
(284, 'Amul Rasmalai 500g', 38, 100.00),
(285, 'Amul Shrikhand Malai 500g', 39, 90.00),
(286, 'Amul Milk Powder Full Cream 500g', 30, 185.00),
(287, 'Amul Malai Paneer Cubes 100g', 23, 45.00),
(288, 'Amul Tikka Paneer Cubes 100g', 24, 47.00),
(289, 'Amul Slim Milk Family 2L', 4, 82.00),
(290, 'Amul Lassi Mint 200ml', 8, 17.00),
(291, 'Amul Gold Milkshake Vanilla 200ml', 1, 28.00),
(292, 'Amul Kool Cafe Hazelnut 200ml', 7, 30.00),
(293, 'Amul Ghee Sachet 100ml', 16, 95.00),
(294, 'Amul Ghee Sachet 200ml', 16, 180.00),
(295, 'Amul Masti Dahi Pouch 200g', 19, 18.00),
(296, 'Amul Pouch Dahi 1kg', 19, 78.00),
(297, 'Amul Ghee Premium 1L', 16, 440.00),
(298, 'Amul Ice Cream Kesar Pista 1L', 25, 185.00),
(299, 'Amul SMP Instant Pouch 1kg', 29, 330.00),
(300, 'Amul Milkshake Badam 180ml', 6, 26.00);
GO
INSERT INTO ProductDim (ProductID, ProductName, BrandID, Price)
VALUES
(301, 'Amul Gold Cow Milk 500ml', 1, 28.00),
(302, 'Amul Gold Cow Milk 1L', 1, 54.00),
(303, 'Amul Taaza Fresh Milk 500ml', 2, 26.00),
(304, 'Amul Shakti Buffalo Milk 1L', 3, 58.00),
(305, 'Amul Slim UHT Milk 1L', 4, 49.00),
(306, 'Amul Kool Rose Petal 200ml', 5, 26.00),
(307, 'Amul Kool Cardamom 200ml', 5, 27.00),
(308, 'Amul Kool Coffee 1L', 7, 100.00),
(309, 'Amul Lassi Salted 1L', 8, 40.00),
(310, 'Amul Butter Cup 20g', 9, 12.00),
(311, 'Amul Butter Unsalted 500g', 9, 135.00),
(312, 'Amul Garlic Butter 200g', 10, 80.00),
(313, 'Amul Butter Chocolate Spread 200g', 11, 100.00),
(314, 'Amul Cheese Slices Burger 5s', 14, 80.00),
(315, 'Amul Cheese Slices Pizza 10s', 14, 130.00),
(316, 'Amul Cheese Spread Olive 200g', 15, 110.00),
(317, 'Amul Cheese Spread Creamy 200g', 15, 105.00),
(318, 'Amul Ghee Pouch 500ml', 16, 195.00),
(319, 'Amul Ghee Pouch 1L', 16, 385.00),
(320, 'Amul Cow Ghee Sachet 100ml', 17, 90.00),
(321, 'Amul Desi Ghee Sachet 200ml', 18, 175.00),
(322, 'Amul Masti Dahi Cup Mango 100g', 19, 15.00),
(323, 'Amul Masti Dahi Cup Strawberry 100g', 19, 15.00),
(324, 'Amul Probiotic Dahi Blueberry 100g', 20, 20.00),
(325, 'Amul Probiotic Dahi Kiwi 100g', 20, 20.00),
(326, 'Amul Dahi Lite Mango 200g', 21, 25.00),
(327, 'Amul Fresh Paneer Cubes 500g', 22, 135.00),
(328, 'Amul Paneer Bhurji Mix 250g', 23, 85.00),
(329, 'Amul Tikka Paneer BBQ 250g', 24, 92.00),
(330, 'Amul Vanilla Ice Cream Bar', 25, 20.00),
(331, 'Amul Chocolate Ice Cream Bar', 26, 22.00),
(332, 'Amul Mango Ice Cream Bar', 27, 22.00),
(333, 'Amul Butterscotch Ice Cream Bar', 28, 23.00),
(334, 'Amul SMP Sachet 50g', 29, 25.00),
(335, 'Amul WMP Sachet 50g', 30, 30.00),
(336, 'Amul Premium Dahi Strawberry 100g', 31, 18.00),
(337, 'Amul Thick Dahi Vanilla 100g', 32, 18.00),
(338, 'Amul Greek Yogurt Peach 100g', 33, 28.00),
(339, 'Amul Greek Yogurt Pineapple 100g', 33, 28.00),
(340, 'Amul Greek Yogurt Guava 100g', 34, 28.00),
(341, 'Amul Diet Dahi Mint 100g', 35, 18.00),
(342, 'Amul Milk Cream Jar 400ml', 36, 80.00),
(343, 'Amul Cafe Latte Bottle 200ml', 37, 28.00),
(344, 'Amul Shrikhand Rose 200g', 38, 50.00),
(345, 'Amul Shrikhand Cardamom 200g', 39, 50.00),
(346, 'Amul Buttermilk 6-Pack 200ml', 40, 85.00),
(347, 'Amul Ice Cream Family Combo 1L', 25, 180.00),
(348, 'Amul Choco Vanilla Cone 120ml', 26, 30.00),
(349, 'Amul Mango Cup Ice Cream 120ml', 27, 28.00),
(350, 'Amul Butterscotch Cup Ice Cream 120ml', 28, 28.00),
(351, 'Amul SMP 250g Pouch', 29, 90.00),
(352, 'Amul WMP 250g Pouch', 30, 95.00),
(353, 'Amul Probiotic Dahi Apple 100g', 20, 20.00),
(354, 'Amul Paneer Pizza Cut 250g', 24, 95.00),
(355, 'Amul Cheese 5kg Bulk', 12, 1000.00),
(356, 'Amul Butter 5kg Bulk', 9, 1200.00),
(357, 'Amul Ice Cream 5L Bulk', 25, 600.00),
(358, 'Amul SMP Bulk 5kg Tin', 29, 1500.00),
(359, 'Amul Lassi Bulk 5L', 8, 190.00),
(360, 'Amul Ghee Bulk 5L Tin', 16, 1900.00),
(361, 'Amul Toned Milk 250ml', 3, 15.00),
(362, 'Amul Slim Milk 250ml', 4, 14.00),
(363, 'Amul UHT Milk 250ml', 1, 17.00),
(364, 'Amul Shrikhand Combo (Mango + Elaichi)', 38, 95.00),
(365, 'Amul Milkshake 6-Pack Assorted', 6, 140.00),
(366, 'Amul Ice Cream Chocolate Sandwich', 26, 35.00),
(367, 'Amul Buttermilk Pouch 500ml', 40, 20.00),
(368, 'Amul Cheese Flavored Cubes 100g', 13, 60.00),
(369, 'Amul Butter Tikka Spread 200g', 11, 80.00),
(370, 'Amul Ice Cream Strawberry Swirl 1L', 25, 180.00),
(371, 'Amul Yogurt Natural 500g', 33, 50.00),
(372, 'Amul SMP Travel Pack 100g', 29, 45.00),
(373, 'Amul WMP Travel Pack 100g', 30, 50.00),
(374, 'Amul Greek Yogurt Kiwi 100g', 33, 27.00),
(375, 'Amul Rasmalai Pouch 300g', 38, 85.00),
(376, 'Amul Paneer Cubes Masala 200g', 24, 90.00),
(377, 'Amul Cool Choco Drink 180ml', 7, 24.00),
(378, 'Amul Ice Cream Tiramisu 500ml', 25, 200.00),
(379, 'Amul Misti Doi 200g', 32, 30.00),
(380, 'Amul Probiotic Dahi Mixed Berry 100g', 20, 20.00),
(381, 'Amul Tetra Paneer 200g', 22, 70.00),
(382, 'Amul SMP Carton 10kg', 29, 2900.00),
(383, 'Amul WMP Carton 10kg', 30, 3000.00),
(384, 'Amul Ice Cream Family Box 2L', 25, 350.00),
(385, 'Amul Rose Lassi Cup 200ml', 8, 22.00),
(386, 'Amul Flavored Dahi Mango 100g', 31, 18.00),
(387, 'Amul Malai Paneer Family Pack 1kg', 23, 240.00),
(388, 'Amul Butter Salted Cup 50g', 9, 20.00),
(389, 'Amul Ice Cream Sundae Cup', 25, 35.00),
(390, 'Amul Fruit Yogurt Mix 6-Pack', 33, 160.00),
(391, 'Amul Dahi Lite 5kg', 21, 320.00),
(392, 'Amul WMP Single Serve 25g', 30, 15.00),
(393, 'Amul SMP Single Serve 25g', 29, 14.00),
(394, 'Amul Rasmalai Mix Dry 250g', 38, 100.00),
(395, 'Amul Buttermilk Lemon Mint 200ml', 40, 18.00),
(396, 'Amul Chocolate Yogurt 100g', 33, 30.00),
(397, 'Amul Chilli Paneer Cubes 250g', 24, 100.00),
(398, 'Amul Thick Dahi 5kg Bulk', 32, 280.00),
(399, 'Amul Greek Yogurt Natural 2kg', 33, 250.00),
(400, 'Amul Masti Dahi Mango 1kg', 19, 85.00);
GO
INSERT INTO ProductDim (ProductID, ProductName, BrandID, Price)
VALUES
(401, 'Amul Gold Fresh Cow Milk 1L', 1, 55.00),
(402, 'Amul Taaza Pouch 250ml', 2, 12.00),
(403, 'Amul Shakti Cow Milk 2L', 3, 100.00),
(404, 'Amul Slim Skimmed Milk 2L', 4, 82.00),
(405, 'Amul Kool Kesar 500ml PET', 5, 40.00),
(406, 'Amul Kool Elaichi 500ml PET', 6, 42.00),
(407, 'Amul Kool Café Tetra 1L', 7, 95.00),
(408, 'Amul Lassi Sweet Tetra 500ml', 8, 30.00),
(409, 'Amul Butter 50g', 9, 24.00),
(410, 'Amul Garlic Butter 50g', 10, 26.00),
(411, 'Amul Masti Butter 500g', 11, 130.00),
(412, 'Amul Cheese Spread Spicy 100g', 15, 50.00),
(413, 'Amul Cheese Slices Sandwich 10s', 14, 110.00),
(414, 'Amul Cheese Block 500g', 12, 220.00),
(415, 'Amul Cheese Cubes Mix 200g', 13, 95.00),
(416, 'Amul Ghee PET Jar 500ml', 16, 200.00),
(417, 'Amul Cow Ghee Pouch 500ml', 17, 205.00),
(418, 'Amul Desi Ghee Pouch 1L', 18, 420.00),
(419, 'Amul Masti Dahi Fruit Cup 200g', 19, 25.00),
(420, 'Amul Probiotic Dahi Vanilla 100g', 20, 20.00),
(421, 'Amul Dahi Lite Strawberry 100g', 21, 20.00),
(422, 'Amul Fresh Paneer Diced 200g', 22, 80.00),
(423, 'Amul Malai Paneer Cubes 200g', 23, 82.00),
(424, 'Amul Tikka Paneer BBQ 500g', 24, 150.00),
(425, 'Amul Vanilla Ice Cream Cone', 25, 25.00),
(426, 'Amul Chocolate Ice Cream Cone', 26, 28.00),
(427, 'Amul Mango Ice Cream Cone', 27, 28.00),
(428, 'Amul Butterscotch Ice Cream Cone', 28, 28.00),
(429, 'Amul SMP Box 250g', 29, 100.00),
(430, 'Amul WMP Box 250g', 30, 110.00),
(431, 'Amul Premium Dahi 400g Cup', 31, 45.00),
(432, 'Amul Thick Dahi 400g Cup', 32, 44.00),
(433, 'Amul Greek Yogurt Mint 100g', 33, 28.00),
(434, 'Amul Greek Yogurt Chocolate 100g', 34, 30.00),
(435, 'Amul Diet Dahi Chilli 100g', 35, 20.00),
(436, 'Amul Milk Cream 200g Cup', 36, 65.00),
(437, 'Amul Cafe Mocha 200ml', 37, 28.00),
(438, 'Amul Shrikhand Kesar 200g', 38, 52.00),
(439, 'Amul Shrikhand Pineapple 200g', 39, 52.00),
(440, 'Amul Buttermilk PET 1L', 40, 40.00),
(441, 'Amul Ice Cream Classic Combo 2L', 25, 350.00),
(442, 'Amul Ice Cream Chocolate Brownie 1L', 26, 190.00),
(443, 'Amul Mango Fruit Ice Cream 1L', 27, 185.00),
(444, 'Amul Butterscotch Fudge 1L', 28, 185.00),
(445, 'Amul SMP 50g Travel Sachet', 29, 22.00),
(446, 'Amul WMP 50g Travel Sachet', 30, 26.00),
(447, 'Amul Thick Dahi Tetra 1L', 32, 78.00),
(448, 'Amul Greek Yogurt Natural 100g', 33, 27.00),
(449, 'Amul Yogurt Strawberry 100g', 33, 28.00),
(450, 'Amul SMP Tin 250g', 29, 90.00),
(451, 'Amul WMP Tin 250g', 30, 95.00),
(452, 'Amul Butter Methi Flavor 100g', 9, 55.00),
(453, 'Amul Milk Powder Family 2kg', 30, 680.00),
(454, 'Amul Paneer Slab Bulk 2kg', 23, 450.00),
(455, 'Amul Cheese Spread Butter Garlic 200g', 15, 115.00),
(456, 'Amul Dahi Rich Mango 400g', 31, 42.00),
(457, 'Amul Ice Cream Chocolate Nuts 500ml', 26, 98.00),
(458, 'Amul Lassi Kesar 250ml', 8, 20.00),
(459, 'Amul Greek Yogurt Lime 100g', 34, 27.00),
(460, 'Amul WMP Bulk Sack 25kg', 30, 6500.00),
(461, 'Amul SMP Bulk Sack 25kg', 29, 6300.00),
(462, 'Amul Buttermilk Lemon 500ml', 40, 22.00),
(463, 'Amul Paneer Shreds 200g', 24, 92.00),
(464, 'Amul Paneer Tandoori 200g', 24, 95.00),
(465, 'Amul Ice Cream Cup Mix 4-Pack', 25, 100.00),
(466, 'Amul Choco Lassi 200ml', 8, 22.00),
(467, 'Amul SMP Sachet 1kg', 29, 320.00),
(468, 'Amul WMP Sachet 1kg', 30, 330.00),
(469, 'Amul Cheese Sticks 6-Pack', 14, 135.00),
(470, 'Amul Malai Paneer Low Fat 200g', 23, 75.00),
(471, 'Amul Tikka Paneer Low Fat 200g', 24, 78.00),
(472, 'Amul Fresh Paneer Fat Free 200g', 22, 72.00),
(473, 'Amul Milk Cream Whipped 200g', 36, 95.00),
(474, 'Amul Dahi Sweetened 500g', 31, 50.00),
(475, 'Amul Ice Cream Brownie Choco 500ml', 25, 110.00),
(476, 'Amul Butter Olive Oil 200g', 10, 85.00),
(477, 'Amul Cheese Cheddar Block 500g', 12, 230.00),
(478, 'Amul Yogurt Litchi 100g', 33, 28.00),
(479, 'Amul SMP Shaker Bottle 500g', 29, 180.00),
(480, 'Amul WMP Shaker Bottle 500g', 30, 185.00),
(481, 'Amul Shrikhand Chocolate 250g', 38, 58.00),
(482, 'Amul Masti Lassi Strawberry 250ml', 8, 20.00),
(483, 'Amul Masti Dahi Elaichi 400g', 19, 35.00),
(484, 'Amul Rasmalai Dry Mix 100g', 38, 80.00),
(485, 'Amul Ice Cream Stick Combo Pack', 28, 160.00),
(486, 'Amul Cheese Cubes Spicy Mix 200g', 13, 98.00),
(487, 'Amul Choco Lassi 6-Pack', 8, 120.00),
(488, 'Amul Mango Yogurt 100g', 33, 28.00),
(489, 'Amul Strawberry Yogurt 100g', 33, 28.00),
(490, 'Amul Cafe Vanilla Latte 200ml', 7, 28.00),
(491, 'Amul Cafe Mocha 6-Pack', 7, 160.00),
(492, 'Amul SMP Family Tin 1kg', 29, 330.00),
(493, 'Amul WMP Family Tin 1kg', 30, 340.00),
(494, 'Amul Greek Yogurt Diet 100g', 34, 27.00),
(495, 'Amul Rasmalai Box 1kg', 38, 190.00),
(496, 'Amul Thick Curd Family 2kg', 32, 160.00),
(497, 'Amul Milk Powder for Tea 500g', 30, 175.00),
(498, 'Amul Butter Stick 100g', 9, 52.00),
(499, 'Amul Malai Paneer Shreds 250g', 23, 98.00),
(500, 'Amul Ice Cream Premium Vanilla 2L', 25, 360.00);
GO


INSERT INTO CustomerDim (CustomerID, FirstName, LastName, City, State, Country, Email, Phone)
VALUES
(1, 'Raj', 'Mehta', 'Ahmedabad', 'Gujarat', 'India', 'raj.mehta@gmail.com', '9876543210'),
(2, 'Sneha', 'Patel', 'Surat', 'Gujarat', 'India', 'sneha.patel@yahoo.com', '9876001122'),
(3, 'Karan', 'Shah', 'Vadodara', 'Gujarat', 'India', 'karan.shah@outlook.com', '9822012345'),
(4, 'Anjali', 'Desai', 'Mumbai', 'Maharashtra', 'India', 'anjali.desai@gmail.com', '9867005566'),
(5, 'Amit', 'Joshi', 'Pune', 'Maharashtra', 'India', 'amit.joshi@rediffmail.com', '9833221133'),
(6, 'Priya', 'Nair', 'Nashik', 'Maharashtra', 'India', 'priya.nair@yahoo.in', '9845123456'),
(7, 'Rohan', 'Kumar', 'Delhi', 'Delhi', 'India', 'rohan.kumar@gmail.com', '9810101010'),
(8, 'Neha', 'Verma', 'Gurgaon', 'Haryana', 'India', 'neha.verma@live.com', '9873009876'),
(9, 'Aditya', 'Singh', 'Noida', 'Uttar Pradesh', 'India', 'aditya.singh@gmail.com', '9898989898'),
(10, 'Shalini', 'Yadav', 'Lucknow', 'Uttar Pradesh', 'India', 'shalini.yadav@gmail.com', '9786543210'),
(11, 'Aarav', 'Reddy', 'Hyderabad', 'Telangana', 'India', 'aarav.reddy@gmail.com', '9848012345'),
(12, 'Meera', 'Nair', 'Kochi', 'Kerala', 'India', 'meera.nair@rediff.com', '9447123456'),
(13, 'Dev', 'Sharma', 'Chandigarh', 'Chandigarh', 'India', 'dev.sharma@gmail.com', '9818001000'),
(14, 'Isha', 'Kapoor', 'Amritsar', 'Punjab', 'India', 'isha.kapoor@gmail.com', '9800002222'),
(15, 'Kabir', 'Gill', 'Ludhiana', 'Punjab', 'India', 'kabir.gill@hotmail.com', '9811112222'),
(16, 'Nikita', 'Malhotra', 'Bhopal', 'Madhya Pradesh', 'India', 'nikita.malhotra@gmail.com', '9755012345'),
(17, 'Tushar', 'Dubey', 'Indore', 'Madhya Pradesh', 'India', 'tushar.dubey@gmail.com', '9767123456'),
(18, 'Ritika', 'Singhania', 'Jaipur', 'Rajasthan', 'India', 'ritika.singhania@gmail.com', '9782512345'),
(19, 'Manish', 'Choudhary', 'Jodhpur', 'Rajasthan', 'India', 'manish.choudhary@gmail.com', '9726012345'),
(20, 'Aishwarya', 'Sinha', 'Kolkata', 'West Bengal', 'India', 'aishwarya.sinha@gmail.com', '9831012345'),
(21, 'Vikram', 'Das', 'Howrah', 'West Bengal', 'India', 'vikram.das@gmail.com', '9830112345'),
(22, 'Simran', 'Kaur', 'Mohali', 'Punjab', 'India', 'simran.kaur@gmail.com', '9812223344'),
(23, 'Harsh', 'Arora', 'Panipat', 'Haryana', 'India', 'harsh.arora@gmail.com', '9878887777'),
(24, 'Pooja', 'Mishra', 'Kanpur', 'Uttar Pradesh', 'India', 'pooja.mishra@gmail.com', '9799887766'),
(25, 'Yash', 'Khandelwal', 'Ajmer', 'Rajasthan', 'India', 'yash.khandelwal@gmail.com', '9781123456'),
(26, 'Tanvi', 'Chopra', 'Shimla', 'Himachal Pradesh', 'India', 'tanvi.chopra@gmail.com', '9805123456'),
(27, 'Ayaan', 'Shaikh', 'Nagpur', 'Maharashtra', 'India', 'ayaan.shaikh@gmail.com', '9850012345'),
(28, 'Sakshi', 'Pandey', 'Varanasi', 'Uttar Pradesh', 'India', 'sakshi.pandey@gmail.com', '9789098765'),
(29, 'Naman', 'Tripathi', 'Raipur', 'Chhattisgarh', 'India', 'naman.tripathi@gmail.com', '9820011122'),
(30, 'Kiara', 'Agarwal', 'Patna', 'Bihar', 'India', 'kiara.agarwal@gmail.com', '9700012345'),
(31, 'Aman', 'Bhatt', 'Dehradun', 'Uttarakhand', 'India', 'aman.bhatt@gmail.com', '9767894321'),
(32, 'Divya', 'Rawat', 'Rishikesh', 'Uttarakhand', 'India', 'divya.rawat@gmail.com', '9787698234'),
(33, 'Rajat', 'Thakur', 'Solan', 'Himachal Pradesh', 'India', 'rajat.thakur@gmail.com', '9809009123'),
(34, 'Alok', 'Mali', 'Udaipur', 'Rajasthan', 'India', 'alok.mali@gmail.com', '9774567890'),
(35, 'Vaani', 'Kashyap', 'Delhi', 'Delhi', 'India', 'vaani.kashyap@gmail.com', '9898234567'),
(36, 'Om', 'Chaturvedi', 'Gwalior', 'Madhya Pradesh', 'India', 'om.chaturvedi@gmail.com', '9756789012'),
(37, 'Ananya', 'Joshi', 'Thane', 'Maharashtra', 'India', 'ananya.joshi@gmail.com', '9812345678'),
(38, 'Ravi', 'Jain', 'Ghaziabad', 'Uttar Pradesh', 'India', 'ravi.jain@gmail.com', '9798563412'),
(39, 'Kavya', 'Dixit', 'Faridabad', 'Haryana', 'India', 'kavya.dixit@gmail.com', '9812012345'),
(40, 'Nikhil', 'Bansal', 'Rohtak', 'Haryana', 'India', 'nikhil.bansal@gmail.com', '9823112233'),
(41, 'Swati', 'Sen', 'Kolkata', 'West Bengal', 'India', 'swati.sen@gmail.com', '9831234567'),
(42, 'Siddharth', 'Dasgupta', 'Asansol', 'West Bengal', 'India', 'siddharth.dg@gmail.com', '9800112233'),
(43, 'Bhavna', 'Bhatnagar', 'Bikaner', 'Rajasthan', 'India', 'bhavna.bhat@gmail.com', '9777899000'),
(44, 'Deepak', 'Kumar', 'Chennai', 'Tamil Nadu', 'India', 'deepak.kumar@gmail.com', '9840000001'),
(45, 'Ritu', 'Menon', 'Madurai', 'Tamil Nadu', 'India', 'ritu.menon@gmail.com', '9840111122'),
(46, 'Ashwin', 'Pillai', 'Trivandrum', 'Kerala', 'India', 'ashwin.pillai@gmail.com', '9447000001'),
(47, 'Bhavesh', 'Rathod', 'Rajkot', 'Gujarat', 'India', 'bhavesh.rathod@gmail.com', '9877001234'),
(48, 'Sanya', 'Goyal', 'Ambala', 'Haryana', 'India', 'sanya.goyal@gmail.com', '9812309876'),
(49, 'Zoya', 'Ahmed', 'Bhopal', 'Madhya Pradesh', 'India', 'zoya.ahmed@gmail.com', '9790112233'),
(50, 'Rakesh', 'Kumar', 'Agra', 'Uttar Pradesh', 'India', 'rakesh.kumar@gmail.com', '9784567890');
-- 50 more coming in next message...

INSERT INTO CustomerDim (CustomerID, FirstName, LastName, City, State, Country, Email, Phone)
VALUES
(51, 'Ankit', 'Mishra', 'Prayagraj', 'Uttar Pradesh', 'India', 'ankit.mishra@gmail.com', '9788123456'),
(52, 'Lavanya', 'Deshmukh', 'Nanded', 'Maharashtra', 'India', 'lavanya.deshmukh@gmail.com', '9845678912'),
(53, 'Aftab', 'Ansari', 'Lucknow', 'Uttar Pradesh', 'India', 'aftab.ansari@gmail.com', '9790099000'),
(54, 'Geeta', 'Naik', 'Hubli', 'Karnataka', 'India', 'geeta.naik@gmail.com', '9888000011'),
(55, 'Sahil', 'Khan', 'Nagpur', 'Maharashtra', 'India', 'sahil.khan@gmail.com', '9876655443'),
(56, 'Rohini', 'Shinde', 'Kolhapur', 'Maharashtra', 'India', 'rohini.shinde@gmail.com', '9823445566'),
(57, 'Ansh', 'Verma', 'Raipur', 'Chhattisgarh', 'India', 'ansh.verma@gmail.com', '9765432109'),
(58, 'Mahima', 'Khatri', 'Indore', 'Madhya Pradesh', 'India', 'mahima.khatri@gmail.com', '9755664321'),
(59, 'Devika', 'Rao', 'Bengaluru', 'Karnataka', 'India', 'devika.rao@gmail.com', '9845098765'),
(60, 'Akhil', 'Murthy', 'Mysuru', 'Karnataka', 'India', 'akhil.murthy@gmail.com', '9845909876'),
(61, 'Suresh', 'Patil', 'Nashik', 'Maharashtra', 'India', 'suresh.patil@gmail.com', '9820011123'),
(62, 'Harshita', 'Iyer', 'Chennai', 'Tamil Nadu', 'India', 'harshita.iyer@gmail.com', '9840999911'),
(63, 'Neeraj', 'Singh', 'Jamshedpur', 'Jharkhand', 'India', 'neeraj.singh@gmail.com', '9800887766'),
(64, 'Prerna', 'Jaiswal', 'Varanasi', 'Uttar Pradesh', 'India', 'prerna.jaiswal@gmail.com', '9811122233'),
(65, 'Ravi', 'Mishra', 'Gorakhpur', 'Uttar Pradesh', 'India', 'ravi.mishra@gmail.com', '9797111222'),
(66, 'Mrunal', 'Kulkarni', 'Aurangabad', 'Maharashtra', 'India', 'mrunal.kulkarni@gmail.com', '9877123456'),
(67, 'Ritesh', 'Bora', 'Guwahati', 'Assam', 'India', 'ritesh.bora@gmail.com', '9834009988'),
(68, 'Chaitanya', 'Chavan', 'Solapur', 'Maharashtra', 'India', 'chaitanya.chavan@gmail.com', '9823223344'),
(69, 'Farhan', 'Ali', 'Bhiwandi', 'Maharashtra', 'India', 'farhan.ali@gmail.com', '9822111222'),
(70, 'Pallavi', 'Sen', 'Durgapur', 'West Bengal', 'India', 'pallavi.sen@gmail.com', '9831198765'),
(71, 'Vaibhav', 'Vyas', 'Udaipur', 'Rajasthan', 'India', 'vaibhav.vyas@gmail.com', '9818877665'),
(72, 'Shreya', 'Kapadia', 'Porbandar', 'Gujarat', 'India', 'shreya.kapadia@gmail.com', '9876543344'),
(73, 'Dhruv', 'Desai', 'Valsad', 'Gujarat', 'India', 'dhruv.desai@gmail.com', '9822345666'),
(74, 'Namrata', 'Bhagat', 'Bhuj', 'Gujarat', 'India', 'namrata.bhagat@gmail.com', '9898765432'),
(75, 'Rehan', 'Shaikh', 'Malegaon', 'Maharashtra', 'India', 'rehan.shaikh@gmail.com', '9812223333'),
(76, 'Asmita', 'Karlekar', 'Ratnagiri', 'Maharashtra', 'India', 'asmita.karlekar@gmail.com', '9823344556'),
(77, 'Arpit', 'Rathi', 'Bilaspur', 'Chhattisgarh', 'India', 'arpit.rathi@gmail.com', '9755443321'),
(78, 'Bhavya', 'Modi', 'Panaji', 'Goa', 'India', 'bhavya.modi@gmail.com', '9822001100'),
(79, 'Rupesh', 'Chand', 'Agartala', 'Tripura', 'India', 'rupesh.chand@gmail.com', '9778811223'),
(80, 'Asha', 'Lal', 'Shillong', 'Meghalaya', 'India', 'asha.lal@gmail.com', '9867001123'),
(81, 'Tejas', 'Kamble', 'Satara', 'Maharashtra', 'India', 'tejas.kamble@gmail.com', '9845022331'),
(82, 'Anurag', 'Dwivedi', 'Jhansi', 'Uttar Pradesh', 'India', 'anurag.dwivedi@gmail.com', '9798123456'),
(83, 'Avantika', 'Rana', 'Shimla', 'Himachal Pradesh', 'India', 'avantika.rana@gmail.com', '9800123456'),
(84, 'Vinay', 'Negi', 'Dehradun', 'Uttarakhand', 'India', 'vinay.negi@gmail.com', '9765431234'),
(85, 'Gaurav', 'Rawal', 'Ajmer', 'Rajasthan', 'India', 'gaurav.rawal@gmail.com', '9789012345'),
(86, 'Tanya', 'Bhatt', 'Ranikhet', 'Uttarakhand', 'India', 'tanya.bhatt@gmail.com', '9701234567'),
(87, 'Rahul', 'Saxena', 'Gwalior', 'Madhya Pradesh', 'India', 'rahul.saxena@gmail.com', '9756001234'),
(88, 'Nidhi', 'Tripathi', 'Jabalpur', 'Madhya Pradesh', 'India', 'nidhi.tripathi@gmail.com', '9766012345'),
(89, 'Sumit', 'Rawat', 'Roorkee', 'Uttarakhand', 'India', 'sumit.rawat@gmail.com', '9785012345'),
(90, 'Trisha', 'Kaul', 'Pauri', 'Uttarakhand', 'India', 'trisha.kaul@gmail.com', '9799998888'),
(91, 'Jay', 'Saxena', 'Ghaziabad', 'Uttar Pradesh', 'India', 'jay.saxena@gmail.com', '9832123456'),
(92, 'Saloni', 'Jain', 'Panipat', 'Haryana', 'India', 'saloni.jain@gmail.com', '9876554432'),
(93, 'Nikhita', 'Gupta', 'Rewari', 'Haryana', 'India', 'nikhita.gupta@gmail.com', '9823223344'),
(94, 'Ayush', 'Goel', 'Ambala', 'Haryana', 'India', 'ayush.goel@gmail.com', '9811002222'),
(95, 'Rashi', 'Mittal', 'Meerut', 'Uttar Pradesh', 'India', 'rashi.mittal@gmail.com', '9799887765'),
(96, 'Manoj', 'Rana', 'Haldwani', 'Uttarakhand', 'India', 'manoj.rana@gmail.com', '9777788990'),
(97, 'Garima', 'Kohli', 'Nainital', 'Uttarakhand', 'India', 'garima.kohli@gmail.com', '9766001234'),
(98, 'Samar', 'Joshi', 'Almora', 'Uttarakhand', 'India', 'samar.joshi@gmail.com', '9755551212'),
(99, 'Sheetal', 'Tiwari', 'Pithoragarh', 'Uttarakhand', 'India', 'sheetal.tiwari@gmail.com', '9744441212'),
(100, 'Kunal', 'Arun', 'Bareilly', 'Uttar Pradesh', 'India', 'kunal.arun@gmail.com', '9787612345');
GO
INSERT INTO CustomerDim (CustomerID, FirstName, LastName, City, State, Country, Email, Phone)
VALUES
(101, 'Raghav', 'Menon', 'Thrissur', 'Kerala', 'India', 'raghav.menon@gmail.com', '9447012345'),
(102, 'Komal', 'Shetty', 'Mangalore', 'Karnataka', 'India', 'komal.shetty@gmail.com', '9845022334'),
(103, 'Imran', 'Qureshi', 'Aligarh', 'Uttar Pradesh', 'India', 'imran.qureshi@gmail.com', '9833312345'),
(104, 'Juhi', 'Saxena', 'Varanasi', 'Uttar Pradesh', 'India', 'juhi.saxena@gmail.com', '9797891234'),
(105, 'Sanjay', 'Narayan', 'Silchar', 'Assam', 'India', 'sanjay.narayan@gmail.com', '9864443210'),
(106, 'Mehul', 'Rana', 'Hisar', 'Haryana', 'India', 'mehul.rana@gmail.com', '9812340001'),
(107, 'Payal', 'Mehta', 'Bhavnagar', 'Gujarat', 'India', 'payal.mehta@gmail.com', '9877005678'),
(108, 'Ajay', 'Modi', 'Vadodara', 'Gujarat', 'India', 'ajay.modi@gmail.com', '9824091234'),
(109, 'Shruti', 'Chouhan', 'Ajmer', 'Rajasthan', 'India', 'shruti.chouhan@gmail.com', '9785112233'),
(110, 'Tanmay', 'Rawat', 'Tehri', 'Uttarakhand', 'India', 'tanmay.rawat@gmail.com', '9765098765'),
(111, 'Ishita', 'Dubey', 'Rewa', 'Madhya Pradesh', 'India', 'ishita.dubey@gmail.com', '9756012233'),
(112, 'Sameer', 'Pathak', 'Bareilly', 'Uttar Pradesh', 'India', 'sameer.pathak@gmail.com', '9818787878'),
(113, 'Sana', 'Nizami', 'Bhopal', 'Madhya Pradesh', 'India', 'sana.nizami@gmail.com', '9755556677'),
(114, 'Ronit', 'Shah', 'Mumbai', 'Maharashtra', 'India', 'ronit.shah@gmail.com', '9833445566'),
(115, 'Vidhi', 'Seth', 'Pune', 'Maharashtra', 'India', 'vidhi.seth@gmail.com', '9867009900'),
(116, 'Nirav', 'Patel', 'Anand', 'Gujarat', 'India', 'nirav.patel@gmail.com', '9876005566'),
(117, 'Snehal', 'Gandhi', 'Navsari', 'Gujarat', 'India', 'snehal.gandhi@gmail.com', '9876899000'),
(118, 'Tanuj', 'Saxena', 'Jhansi', 'Uttar Pradesh', 'India', 'tanuj.saxena@gmail.com', '9800099900'),
(119, 'Reet', 'Bajwa', 'Patiala', 'Punjab', 'India', 'reet.bajwa@gmail.com', '9812233445'),
(120, 'Aaliya', 'Khan', 'Aligarh', 'Uttar Pradesh', 'India', 'aaliya.khan@gmail.com', '9790011223'),
(121, 'Saurav', 'Mitra', 'Kolkata', 'West Bengal', 'India', 'saurav.mitra@gmail.com', '9830011223'),
(122, 'Zainab', 'Rizvi', 'Lucknow', 'Uttar Pradesh', 'India', 'zainab.rizvi@gmail.com', '9789001122'),
(123, 'Tushar', 'Thakkar', 'Rajkot', 'Gujarat', 'India', 'tushar.thakkar@gmail.com', '9877012345'),
(124, 'Nupur', 'Chhabra', 'Delhi', 'Delhi', 'India', 'nupur.chhabra@gmail.com', '9811123456'),
(125, 'Viraj', 'Chauhan', 'Noida', 'Uttar Pradesh', 'India', 'viraj.chauhan@gmail.com', '9898987777'),
(126, 'Ritika', 'Kapoor', 'Chandigarh', 'Chandigarh', 'India', 'ritika.kapoor@gmail.com', '9818887777'),
(127, 'Akhilesh', 'Sharma', 'Ambala', 'Haryana', 'India', 'akhilesh.sharma@gmail.com', '9810001234'),
(128, 'Bhavika', 'Jadhav', 'Nanded', 'Maharashtra', 'India', 'bhavika.jadhav@gmail.com', '9845001234'),
(129, 'Ravindra', 'Kamble', 'Aurangabad', 'Maharashtra', 'India', 'ravindra.kamble@gmail.com', '9822005678'),
(130, 'Supriya', 'Chatterjee', 'Kolkata', 'West Bengal', 'India', 'supriya.chatterjee@gmail.com', '9830223344'),
(131, 'Deepanshu', 'Rathore', 'Indore', 'Madhya Pradesh', 'India', 'deepanshu.rathore@gmail.com', '9755551234'),
(132, 'Arya', 'Bhaskar', 'Patna', 'Bihar', 'India', 'arya.bhaskar@gmail.com', '9700001111'),
(133, 'Raman', 'Ghosh', 'Howrah', 'West Bengal', 'India', 'raman.ghosh@gmail.com', '9830009999'),
(134, 'Smita', 'Roy', 'Siliguri', 'West Bengal', 'India', 'smita.roy@gmail.com', '9831212345'),
(135, 'Sahil', 'Nanda', 'Jammu', 'Jammu & Kashmir', 'India', 'sahil.nanda@gmail.com', '9797001122'),
(136, 'Nikita', 'Joshi', 'Kullu', 'Himachal Pradesh', 'India', 'nikita.joshi@gmail.com', '9800113344'),
(137, 'Rishabh', 'Verma', 'Mathura', 'Uttar Pradesh', 'India', 'rishabh.verma@gmail.com', '9798112233'),
(138, 'Nisha', 'Rana', 'Saharanpur', 'Uttar Pradesh', 'India', 'nisha.rana@gmail.com', '9786567890'),
(139, 'Umesh', 'Sutar', 'Ratnagiri', 'Maharashtra', 'India', 'umesh.sutar@gmail.com', '9844112233'),
(140, 'Shraddha', 'Pawar', 'Satara', 'Maharashtra', 'India', 'shraddha.pawar@gmail.com', '9834123456'),
(141, 'Ritika', 'Taneja', 'Firozabad', 'Uttar Pradesh', 'India', 'ritika.taneja@gmail.com', '9798995566'),
(142, 'Himanshu', 'Singhal', 'Alwar', 'Rajasthan', 'India', 'himanshu.singhal@gmail.com', '9787456123'),
(143, 'Nitin', 'Bhardwaj', 'Haridwar', 'Uttarakhand', 'India', 'nitin.bhardwaj@gmail.com', '9767001122'),
(144, 'Sweta', 'Basu', 'Jamshedpur', 'Jharkhand', 'India', 'sweta.basu@gmail.com', '9800112211'),
(145, 'Mayank', 'Jain', 'Jhansi', 'Uttar Pradesh', 'India', 'mayank.jain@gmail.com', '9812345432'),
(146, 'Vani', 'Saxena', 'Kanpur', 'Uttar Pradesh', 'India', 'vani.saxena@gmail.com', '9800011122'),
(147, 'Usha', 'Krishnan', 'Kochi', 'Kerala', 'India', 'usha.krishnan@gmail.com', '9447123456'),
(148, 'Ashok', 'Das', 'Cuttack', 'Odisha', 'India', 'ashok.das@gmail.com', '9861004321'),
(149, 'Salil', 'Rastogi', 'Lucknow', 'Uttar Pradesh', 'India', 'salil.rastogi@gmail.com', '9797999999'),
(150, 'Geetanjali', 'Thakur', 'Shimla', 'Himachal Pradesh', 'India', 'geetanjali.thakur@gmail.com', '9800111122');
-- Continue from 151–200 in next batch
INSERT INTO CustomerDim (CustomerID, FirstName, LastName, City, State, Country, Email, Phone)
VALUES
(151, 'Ravina', 'Deshpande', 'Nagpur', 'Maharashtra', 'India', 'ravina.deshpande@gmail.com', '9823123456'),
(152, 'Nandan', 'Pillai', 'Kollam', 'Kerala', 'India', 'nandan.pillai@gmail.com', '9447001122'),
(153, 'Ashima', 'Rao', 'Mysuru', 'Karnataka', 'India', 'ashima.rao@gmail.com', '9845022987'),
(154, 'Jayant', 'Shastri', 'Ujjain', 'Madhya Pradesh', 'India', 'jayant.shastri@gmail.com', '9755998844'),
(155, 'Vaidehi', 'Kulkarni', 'Aurangabad', 'Maharashtra', 'India', 'vaidehi.kulkarni@gmail.com', '9847000987'),
(156, 'Arnav', 'Gupta', 'Delhi', 'Delhi', 'India', 'arnav.gupta@gmail.com', '9818012345'),
(157, 'Ritika', 'Rathi', 'Gwalior', 'Madhya Pradesh', 'India', 'ritika.rathi@gmail.com', '9755544332'),
(158, 'Irfan', 'Khan', 'Srinagar', 'Jammu & Kashmir', 'India', 'irfan.khan@gmail.com', '9797007654'),
(159, 'Divyanshi', 'Bhatia', 'Roorkee', 'Uttarakhand', 'India', 'divyanshi.bhatia@gmail.com', '9767004567'),
(160, 'Jignesh', 'Patel', 'Anand', 'Gujarat', 'India', 'jignesh.patel@gmail.com', '9876002345'),
(161, 'Sourabh', 'Agarwal', 'Kota', 'Rajasthan', 'India', 'sourabh.agarwal@gmail.com', '9787901234'),
(162, 'Meenakshi', 'Sinha', 'Patna', 'Bihar', 'India', 'meenakshi.sinha@gmail.com', '9700023456'),
(163, 'Kishore', 'Raj', 'Chennai', 'Tamil Nadu', 'India', 'kishore.raj@gmail.com', '9840004321'),
(164, 'Snehal', 'Thakur', 'Pune', 'Maharashtra', 'India', 'snehal.thakur@gmail.com', '9867345567'),
(165, 'Dipti', 'Yadav', 'Noida', 'Uttar Pradesh', 'India', 'dipti.yadav@gmail.com', '9812341111'),
(166, 'Varun', 'Jaiswal', 'Lucknow', 'Uttar Pradesh', 'India', 'varun.jaiswal@gmail.com', '9797654321'),
(167, 'Sanya', 'Gupta', 'Agra', 'Uttar Pradesh', 'India', 'sanya.gupta@gmail.com', '9780987123'),
(168, 'Tarun', 'Gopal', 'Panaji', 'Goa', 'India', 'tarun.gopal@gmail.com', '9823123987'),
(169, 'Chitra', 'Sarkar', 'Durgapur', 'West Bengal', 'India', 'chitra.sarkar@gmail.com', '9831144556'),
(170, 'Rohit', 'Talwar', 'Jalandhar', 'Punjab', 'India', 'rohit.talwar@gmail.com', '9818877111'),
(171, 'Sneha', 'Mahajan', 'Amritsar', 'Punjab', 'India', 'sneha.mahajan@gmail.com', '9800223344'),
(172, 'Karan', 'Malik', 'Faridabad', 'Haryana', 'India', 'karan.malik@gmail.com', '9878011223'),
(173, 'Srishti', 'Kohli', 'Panchkula', 'Haryana', 'India', 'srishti.kohli@gmail.com', '9819991122'),
(174, 'Anup', 'Tiwari', 'Kanpur', 'Uttar Pradesh', 'India', 'anup.tiwari@gmail.com', '9788234567'),
(175, 'Ridhi', 'Nair', 'Thrissur', 'Kerala', 'India', 'ridhi.nair@gmail.com', '9447011223'),
(176, 'Ankur', 'Chhabra', 'Gurgaon', 'Haryana', 'India', 'ankur.chhabra@gmail.com', '9876009876'),
(177, 'Priyanshi', 'Mittal', 'Delhi', 'Delhi', 'India', 'priyanshi.mittal@gmail.com', '9818877000'),
(178, 'Zaid', 'Ansari', 'Aligarh', 'Uttar Pradesh', 'India', 'zaid.ansari@gmail.com', '9797676767'),
(179, 'Bhavana', 'Verma', 'Bhopal', 'Madhya Pradesh', 'India', 'bhavana.verma@gmail.com', '9755777788'),
(180, 'Arvind', 'Rajput', 'Jabalpur', 'Madhya Pradesh', 'India', 'arvind.rajput@gmail.com', '9755223344'),
(181, 'Preeti', 'Bansal', 'Raipur', 'Chhattisgarh', 'India', 'preeti.bansal@gmail.com', '9765432221'),
(182, 'Sameeksha', 'Naidu', 'Bengaluru', 'Karnataka', 'India', 'sameeksha.naidu@gmail.com', '9845661234'),
(183, 'Samar', 'Dev', 'Belgaum', 'Karnataka', 'India', 'samar.dev@gmail.com', '9845112233'),
(184, 'Rajat', 'Arora', 'Delhi', 'Delhi', 'India', 'rajat.arora@gmail.com', '9818561234'),
(185, 'Sanjana', 'Khanna', 'Mohali', 'Punjab', 'India', 'sanjana.khanna@gmail.com', '9817766543'),
(186, 'Neerav', 'Sood', 'Patiala', 'Punjab', 'India', 'neerav.sood@gmail.com', '9817763210'),
(187, 'Kanika', 'Garg', 'Ludhiana', 'Punjab', 'India', 'kanika.garg@gmail.com', '9800110099'),
(188, 'Yuvraj', 'Bhalla', 'Shimla', 'Himachal Pradesh', 'India', 'yuvraj.bhalla@gmail.com', '9800998899'),
(189, 'Devanshi', 'Pandey', 'Jaipur', 'Rajasthan', 'India', 'devanshi.pandey@gmail.com', '9780765432'),
(190, 'Hardik', 'Goenka', 'Bikaner', 'Rajasthan', 'India', 'hardik.goenka@gmail.com', '9780043210'),
(191, 'Vasudha', 'Gaur', 'Kota', 'Rajasthan', 'India', 'vasudha.gaur@gmail.com', '9780767890'),
(192, 'Shanaya', 'Arvind', 'Bhilai', 'Chhattisgarh', 'India', 'shanaya.arvind@gmail.com', '9768883344'),
(193, 'Rohit', 'Mathur', 'Ajmer', 'Rajasthan', 'India', 'rohit.mathur@gmail.com', '9789901123'),
(194, 'Nimish', 'Kumar', 'Dehradun', 'Uttarakhand', 'India', 'nimish.kumar@gmail.com', '9767112234'),
(195, 'Kashish', 'Malhotra', 'Mumbai', 'Maharashtra', 'India', 'kashish.malhotra@gmail.com', '9876034567'),
(196, 'Sonal', 'Goswami', 'Ahmedabad', 'Gujarat', 'India', 'sonal.goswami@gmail.com', '9876767676'),
(197, 'Utkarsh', 'Nanda', 'Gandhinagar', 'Gujarat', 'India', 'utkarsh.nanda@gmail.com', '9876700123'),
(198, 'Simran', 'Jaggi', 'Pune', 'Maharashtra', 'India', 'simran.jaggi@gmail.com', '9867887654'),
(199, 'Anvi', 'Kapadia', 'Surat', 'Gujarat', 'India', 'anvi.kapadia@gmail.com', '9876009000'),
(200, 'Parth', 'Brahmbhatt', 'Valsad', 'Gujarat', 'India', 'parth.brahmbhatt@gmail.com', '9876012345');
GO
INSERT INTO CustomerDim (CustomerID, FirstName, LastName, City, State, Country, Email, Phone)
VALUES
(201, 'Rhea', 'Naik', 'Margao', 'Goa', 'India', 'rhea.naik@gmail.com', '9823012345'),
(202, 'Ishan', 'Vyas', 'Junagadh', 'Gujarat', 'India', 'ishan.vyas@gmail.com', '9876123456'),
(203, 'Vaishnavi', 'Shah', 'Dahod', 'Gujarat', 'India', 'vaishnavi.shah@gmail.com', '9876112233'),
(204, 'Rajeev', 'Bora', 'Tezpur', 'Assam', 'India', 'rajeev.bora@gmail.com', '9863001234'),
(205, 'Arpita', 'Majumdar', 'Malda', 'West Bengal', 'India', 'arpita.majumdar@gmail.com', '9837012345'),
(206, 'Niranjan', 'Ghosh', 'Burdwan', 'West Bengal', 'India', 'niranjan.ghosh@gmail.com', '9834009876'),
(207, 'Chinmay', 'Rana', 'Porbandar', 'Gujarat', 'India', 'chinmay.rana@gmail.com', '9876045678'),
(208, 'Deepali', 'Nayak', 'Bhubaneswar', 'Odisha', 'India', 'deepali.nayak@gmail.com', '9861012345'),
(209, 'Anshika', 'Dwivedi', 'Satna', 'Madhya Pradesh', 'India', 'anshika.dwivedi@gmail.com', '9755588899'),
(210, 'Tarika', 'Vernekar', 'Mapusa', 'Goa', 'India', 'tarika.vernekar@gmail.com', '9823056789'),
(211, 'Ashutosh', 'Rai', 'Gonda', 'Uttar Pradesh', 'India', 'ashutosh.rai@gmail.com', '9798123000'),
(212, 'Mahi', 'Mali', 'Bhuj', 'Gujarat', 'India', 'mahi.mali@gmail.com', '9876777788'),
(213, 'Sarvesh', 'Iyer', 'Kollam', 'Kerala', 'India', 'sarvesh.iyer@gmail.com', '9447098765'),
(214, 'Neha', 'Modi', 'Rajkot', 'Gujarat', 'India', 'neha.modi@gmail.com', '9876987654'),
(215, 'Sagar', 'Tiwari', 'Pithoragarh', 'Uttarakhand', 'India', 'sagar.tiwari@gmail.com', '9766543211'),
(216, 'Prachi', 'Mehra', 'Gandhidham', 'Gujarat', 'India', 'prachi.mehra@gmail.com', '9876999888'),
(217, 'Aarushi', 'Khare', 'Khandwa', 'Madhya Pradesh', 'India', 'aarushi.khare@gmail.com', '9756677889'),
(218, 'Punit', 'Rawal', 'Beed', 'Maharashtra', 'India', 'punit.rawal@gmail.com', '9867888999'),
(219, 'Kritika', 'Rathod', 'Vapi', 'Gujarat', 'India', 'kritika.rathod@gmail.com', '9876111555'),
(220, 'Jatin', 'Chandel', 'Bilaspur', 'Chhattisgarh', 'India', 'jatin.chandel@gmail.com', '9765401234'),
(221, 'Ruchi', 'Narayan', 'Ambikapur', 'Chhattisgarh', 'India', 'ruchi.narayan@gmail.com', '9765432987'),
(222, 'Siddhi', 'Kaushik', 'Dewas', 'Madhya Pradesh', 'India', 'siddhi.kaushik@gmail.com', '9755022244'),
(223, 'Shaurya', 'Deshmukh', 'Nanded', 'Maharashtra', 'India', 'shaurya.deshmukh@gmail.com', '9845999111'),
(224, 'Avni', 'Malik', 'Tinsukia', 'Assam', 'India', 'avni.malik@gmail.com', '9863333456'),
(225, 'Omkar', 'Gogoi', 'Dibrugarh', 'Assam', 'India', 'omkar.gogoi@gmail.com', '9863111234'),
(226, 'Naina', 'Wadkar', 'Ratnagiri', 'Maharashtra', 'India', 'naina.wadkar@gmail.com', '9845111144'),
(227, 'Diksha', 'Chauhan', 'Solan', 'Himachal Pradesh', 'India', 'diksha.chauhan@gmail.com', '9800099111'),
(228, 'Jaya', 'Mahapatra', 'Rourkela', 'Odisha', 'India', 'jaya.mahapatra@gmail.com', '9861001010'),
(229, 'Madhav', 'Sen', 'Barasat', 'West Bengal', 'India', 'madhav.sen@gmail.com', '9830001010'),
(230, 'Aditi', 'Pandey', 'Raigarh', 'Chhattisgarh', 'India', 'aditi.pandey@gmail.com', '9765412345'),
(231, 'Yogesh', 'Tripathi', 'Ghazipur', 'Uttar Pradesh', 'India', 'yogesh.tripathi@gmail.com', '9798223344'),
(232, 'Priyanka', 'Das', 'Kharagpur', 'West Bengal', 'India', 'priyanka.das@gmail.com', '9831022334'),
(233, 'Tanmay', 'Kumar', 'Samastipur', 'Bihar', 'India', 'tanmay.kumar@gmail.com', '9700067890'),
(234, 'Vidya', 'Singhania', 'Aurangabad', 'Bihar', 'India', 'vidya.singhania@gmail.com', '9700034567'),
(235, 'Dev', 'Chakraborty', 'Bardhaman', 'West Bengal', 'India', 'dev.chakraborty@gmail.com', '9830044556'),
(236, 'Raghav', 'Chouhan', 'Ujjain', 'Madhya Pradesh', 'India', 'raghav.chouhan@gmail.com', '9755098776'),
(237, 'Shivani', 'Agrawal', 'Rewa', 'Madhya Pradesh', 'India', 'shivani.agrawal@gmail.com', '9755001122'),
(238, 'Alisha', 'Kohli', 'Bathinda', 'Punjab', 'India', 'alisha.kohli@gmail.com', '9812011123'),
(239, 'Rahul', 'Grover', 'Ambala', 'Haryana', 'India', 'rahul.grover@gmail.com', '9812123456'),
(240, 'Mitali', 'Sethia', 'Dhanbad', 'Jharkhand', 'India', 'mitali.sethia@gmail.com', '9800989898'),
(241, 'Nakul', 'Bhargava', 'Jamshedpur', 'Jharkhand', 'India', 'nakul.bhargava@gmail.com', '9800123012'),
(242, 'Ayesha', 'Syed', 'Hyderabad', 'Telangana', 'India', 'ayesha.syed@gmail.com', '9848098765'),
(243, 'Reyansh', 'Sethi', 'Warangal', 'Telangana', 'India', 'reyansh.sethi@gmail.com', '9848003344'),
(244, 'Namita', 'Prasad', 'Nellore', 'Andhra Pradesh', 'India', 'namita.prasad@gmail.com', '9848001122'),
(245, 'Aryan', 'Bora', 'Guwahati', 'Assam', 'India', 'aryan.bora@gmail.com', '9863002222'),
(246, 'Devika', 'Gupta', 'Visakhapatnam', 'Andhra Pradesh', 'India', 'devika.gupta@gmail.com', '9848101234'),
(247, 'Aadil', 'Ahmed', 'Srinagar', 'Jammu & Kashmir', 'India', 'aadil.ahmed@gmail.com', '9797004455'),
(248, 'Shravya', 'Shetty', 'Mangalore', 'Karnataka', 'India', 'shravya.shetty@gmail.com', '9845011223'),
(249, 'Zubin', 'Irani', 'Ahmednagar', 'Maharashtra', 'India', 'zubin.irani@gmail.com', '9822001111'),
(250, 'Preetam', 'Joshi', 'Amravati', 'Maharashtra', 'India', 'preetam.joshi@gmail.com', '9822098765');
GO

INSERT INTO CustomerDim (CustomerID, FirstName, LastName, City, State, Country, Email, Phone)
VALUES
(301, 'Kavya', 'Thakkar', 'Bhavnagar', 'Gujarat', 'India', 'kavya.thakkar@gmail.com', '9876201101'),
(302, 'Raj', 'Kulkarni', 'Pune', 'Maharashtra', 'India', 'raj.kulkarni@gmail.com', '9867000102'),
(303, 'Ishaan', 'Shinde', 'Nashik', 'Maharashtra', 'India', 'ishaan.shinde@gmail.com', '9845000103'),
(304, 'Amrita', 'Chowdhury', 'Kolkata', 'West Bengal', 'India', 'amrita.chowdhury@gmail.com', '9831000104'),
(305, 'Sarthak', 'Bansal', 'Agra', 'Uttar Pradesh', 'India', 'sarthak.bansal@gmail.com', '9798000105'),
(306, 'Devansh', 'Trivedi', 'Jamnagar', 'Gujarat', 'India', 'devansh.trivedi@gmail.com', '9876700106'),
(307, 'Aanya', 'Kashyap', 'Haridwar', 'Uttarakhand', 'India', 'aanya.kashyap@gmail.com', '9768000107'),
(308, 'Kabir', 'Joshi', 'Thane', 'Maharashtra', 'India', 'kabir.joshi@gmail.com', '9867600108'),
(309, 'Srishti', 'Mehta', 'Vadodara', 'Gujarat', 'India', 'srishti.mehta@gmail.com', '9876400109'),
(310, 'Aarav', 'Malhotra', 'Delhi', 'Delhi', 'India', 'aarav.malhotra@gmail.com', '9818000110'),
(311, 'Mitali', 'Saxena', 'Lucknow', 'Uttar Pradesh', 'India', 'mitali.saxena@gmail.com', '9798500111'),
(312, 'Tanmay', 'Kapoor', 'Ghaziabad', 'Uttar Pradesh', 'India', 'tanmay.kapoor@gmail.com', '9789500112'),
(313, 'Nehal', 'Rathore', 'Indore', 'Madhya Pradesh', 'India', 'nehal.rathore@gmail.com', '9755500113'),
(314, 'Siddharth', 'Goyal', 'Chandigarh', 'Chandigarh', 'India', 'siddharth.goyal@gmail.com', '9818700114'),
(315, 'Charvi', 'Gupta', 'Jaipur', 'Rajasthan', 'India', 'charvi.gupta@gmail.com', '9780700115'),
(316, 'Aniket', 'Yadav', 'Rewari', 'Haryana', 'India', 'aniket.yadav@gmail.com', '9812700116'),
(317, 'Mahima', 'Sood', 'Jalandhar', 'Punjab', 'India', 'mahima.sood@gmail.com', '9805700117'),
(318, 'Harshit', 'Pandya', 'Rajkot', 'Gujarat', 'India', 'harshit.pandya@gmail.com', '9876100118'),
(319, 'Krishna', 'Rao', 'Vijayawada', 'Andhra Pradesh', 'India', 'krishna.rao@gmail.com', '9848200119'),
(320, 'Jasleen', 'Singh', 'Amritsar', 'Punjab', 'India', 'jasleen.singh@gmail.com', '9812900120'),
(321, 'Karthik', 'Sharma', 'Coimbatore', 'Tamil Nadu', 'India', 'karthik.sharma@gmail.com', '9843200121'),
(322, 'Bhakti', 'Tiwari', 'Ujjain', 'Madhya Pradesh', 'India', 'bhakti.tiwari@gmail.com', '9755200122'),
(323, 'Om', 'Agnihotri', 'Kanpur', 'Uttar Pradesh', 'India', 'om.agnihotri@gmail.com', '9798700123'),
(324, 'Arohi', 'Sen', 'Howrah', 'West Bengal', 'India', 'arohi.sen@gmail.com', '9830200124'),
(325, 'Rahul', 'Iyer', 'Thiruvananthapuram', 'Kerala', 'India', 'rahul.iyer@gmail.com', '9447100125'),
(326, 'Vani', 'Khatri', 'Dehradun', 'Uttarakhand', 'India', 'vani.khatri@gmail.com', '9767400126'),
(327, 'Anshika', 'Garg', 'Meerut', 'Uttar Pradesh', 'India', 'anshika.garg@gmail.com', '9798100127'),
(328, 'Parag', 'Taneja', 'Faridabad', 'Haryana', 'India', 'parag.taneja@gmail.com', '9812400128'),
(329, 'Reema', 'Patel', 'Ahmedabad', 'Gujarat', 'India', 'reema.patel@gmail.com', '9876200129'),
(330, 'Yuvika', 'Rawat', 'Mussoorie', 'Uttarakhand', 'India', 'yuvika.rawat@gmail.com', '9767000130'),
(331, 'Jayesh', 'Lal', 'Bilaspur', 'Chhattisgarh', 'India', 'jayesh.lal@gmail.com', '9765400131'),
(332, 'Tanisha', 'Prajapati', 'Gaya', 'Bihar', 'India', 'tanisha.prajapati@gmail.com', '9700100132'),
(333, 'Laksh', 'Nagpal', 'Surat', 'Gujarat', 'India', 'laksh.nagpal@gmail.com', '9876300133'),
(334, 'Muskan', 'Roy', 'Kharagpur', 'West Bengal', 'India', 'muskan.roy@gmail.com', '9830200134'),
(335, 'Dev', 'Nambiar', 'Kochi', 'Kerala', 'India', 'dev.nambiar@gmail.com', '9447200135'),
(336, 'Avni', 'Pathania', 'Shimla', 'Himachal Pradesh', 'India', 'avni.pathania@gmail.com', '9800200136'),
(337, 'Ibrahim', 'Shaikh', 'Mumbai', 'Maharashtra', 'India', 'ibrahim.shaikh@gmail.com', '9867100137'),
(338, 'Rudra', 'Bhatnagar', 'Allahabad', 'Uttar Pradesh', 'India', 'rudra.bhatnagar@gmail.com', '9798100138'),
(339, 'Anaya', 'Chugh', 'Panipat', 'Haryana', 'India', 'anaya.chugh@gmail.com', '9812000139'),
(340, 'Zara', 'Farooq', 'Srinagar', 'Jammu & Kashmir', 'India', 'zara.farooq@gmail.com', '9797000140'),
(341, 'Neil', 'Chatterjee', 'Asansol', 'West Bengal', 'India', 'neil.chatterjee@gmail.com', '9830100141'),
(342, 'Meera', 'Parikh', 'Navsari', 'Gujarat', 'India', 'meera.parikh@gmail.com', '9876600142'),
(343, 'Yash', 'Barot', 'Bhuj', 'Gujarat', 'India', 'yash.barot@gmail.com', '9876888888'),
(344, 'Kiran', 'Murthy', 'Bengaluru', 'Karnataka', 'India', 'kiran.murthy@gmail.com', '9845000144'),
(345, 'Ritika', 'Naidu', 'Chennai', 'Tamil Nadu', 'India', 'ritika.naidu@gmail.com', '9840000145'),
(346, 'Arya', 'Banerjee', 'Kolkata', 'West Bengal', 'India', 'arya.banerjee@gmail.com', '9831000146'),
(347, 'Tanya', 'Verma', 'Indore', 'Madhya Pradesh', 'India', 'tanya.verma@gmail.com', '9755400147'),
(348, 'Veer', 'Chand', 'Siliguri', 'West Bengal', 'India', 'veer.chand@gmail.com', '9831100148'),
(349, 'Rashi', 'Goyal', 'Ranchi', 'Jharkhand', 'India', 'rashi.goyal@gmail.com', '9800123456'),
(350, 'Alok', 'Nair', 'Ernakulam', 'Kerala', 'India', 'alok.nair@gmail.com', '9447000149');
GO
INSERT INTO CustomerDim (CustomerID, FirstName, LastName, City, State, Country, Email, Phone)
VALUES
(351, 'Sneha', 'Bhatia', 'Varanasi', 'Uttar Pradesh', 'India', 'sneha.bhatia@gmail.com', '9780012345'),
(352, 'Rajan', 'Kapadia', 'Surat', 'Gujarat', 'India', 'rajan.kapadia@gmail.com', '9876012345'),
(353, 'Zaid', 'Qureshi', 'Aligarh', 'Uttar Pradesh', 'India', 'zaid.qureshi@gmail.com', '9798123987'),
(354, 'Ishika', 'Talwar', 'Pune', 'Maharashtra', 'India', 'ishika.talwar@gmail.com', '9867012345'),
(355, 'Shanaya', 'Gill', 'Mohali', 'Punjab', 'India', 'shanaya.gill@gmail.com', '9812212345'),
(356, 'Lakshay', 'Kohli', 'Jalandhar', 'Punjab', 'India', 'lakshay.kohli@gmail.com', '9812012345'),
(357, 'Aarushi', 'Mehra', 'New Delhi', 'Delhi', 'India', 'aarushi.mehra@gmail.com', '9818912345'),
(358, 'Adnan', 'Ali', 'Lucknow', 'Uttar Pradesh', 'India', 'adnan.ali@gmail.com', '9798312345'),
(359, 'Ritika', 'Gandhi', 'Vadodara', 'Gujarat', 'India', 'ritika.gandhi@gmail.com', '9876112345'),
(360, 'Siddhant', 'Jain', 'Ajmer', 'Rajasthan', 'India', 'siddhant.jain@gmail.com', '9781112345'),
(361, 'Kiara', 'Deshmukh', 'Mumbai', 'Maharashtra', 'India', 'kiara.deshmukh@gmail.com', '9867612345'),
(362, 'Viraj', 'Mahajan', 'Aurangabad', 'Maharashtra', 'India', 'viraj.mahajan@gmail.com', '9845112345'),
(363, 'Ira', 'Pandey', 'Kanpur', 'Uttar Pradesh', 'India', 'ira.pandey@gmail.com', '9798512345'),
(364, 'Tushar', 'Kapoor', 'Gurgaon', 'Haryana', 'India', 'tushar.kapoor@gmail.com', '9812312345'),
(365, 'Isha', 'Arora', 'Faridabad', 'Haryana', 'India', 'isha.arora@gmail.com', '9812412345'),
(366, 'Kartik', 'Goswami', 'Ujjain', 'Madhya Pradesh', 'India', 'kartik.goswami@gmail.com', '9755512345'),
(367, 'Anjali', 'Chopra', 'Jabalpur', 'Madhya Pradesh', 'India', 'anjali.chopra@gmail.com', '9755612345'),
(368, 'Parth', 'Verma', 'Agra', 'Uttar Pradesh', 'India', 'parth.verma@gmail.com', '9781212345'),
(369, 'Sanya', 'Sharma', 'Noida', 'Uttar Pradesh', 'India', 'sanya.sharma@gmail.com', '9798612345'),
(370, 'Harshit', 'Mittal', 'Rewari', 'Haryana', 'India', 'harshit.mittal@gmail.com', '9812512345'),
(371, 'Prachi', 'Patel', 'Anand', 'Gujarat', 'India', 'prachi.patel@gmail.com', '9876212345'),
(372, 'Rehan', 'Shaikh', 'Thane', 'Maharashtra', 'India', 'rehan.shaikh@gmail.com', '9867712345'),
(373, 'Devika', 'Rana', 'Roorkee', 'Uttarakhand', 'India', 'devika.rana@gmail.com', '9767412345'),
(374, 'Rohit', 'Rajput', 'Bhopal', 'Madhya Pradesh', 'India', 'rohit.rajput@gmail.com', '9755712345'),
(375, 'Aisha', 'Sinha', 'Patna', 'Bihar', 'India', 'aisha.sinha@gmail.com', '9700212345'),
(376, 'Aryan', 'Tripathi', 'Prayagraj', 'Uttar Pradesh', 'India', 'aryan.tripathi@gmail.com', '9798412345'),
(377, 'Palak', 'Yadav', 'Bareilly', 'Uttar Pradesh', 'India', 'palak.yadav@gmail.com', '9781312345'),
(378, 'Rudra', 'Nath', 'Guwahati', 'Assam', 'India', 'rudra.nath@gmail.com', '9863012345'),
(379, 'Myra', 'Banerjee', 'Asansol', 'West Bengal', 'India', 'myra.banerjee@gmail.com', '9831312345'),
(380, 'Zoya', 'Hussain', 'Srinagar', 'Jammu & Kashmir', 'India', 'zoya.hussain@gmail.com', '9797012345'),
(381, 'Anaya', 'Mehta', 'Gandhinagar', 'Gujarat', 'India', 'anaya.mehta@gmail.com', '9876312345'),
(382, 'Nishant', 'Thakur', 'Shimla', 'Himachal Pradesh', 'India', 'nishant.thakur@gmail.com', '9800312345'),
(383, 'Avani', 'Mali', 'Nashik', 'Maharashtra', 'India', 'avani.mali@gmail.com', '9845212345'),
(384, 'Ibrahim', 'Rizvi', 'Varanasi', 'Uttar Pradesh', 'India', 'ibrahim.rizvi@gmail.com', '9781412345'),
(385, 'Dhruv', 'Taneja', 'Chandigarh', 'Chandigarh', 'India', 'dhruv.taneja@gmail.com', '9818812345'),
(386, 'Tanvi', 'Seth', 'Dhanbad', 'Jharkhand', 'India', 'tanvi.seth@gmail.com', '9800412345'),
(387, 'Vivaan', 'Joshi', 'Jamnagar', 'Gujarat', 'India', 'vivaan.joshi@gmail.com', '9876412345'),
(388, 'Rhea', 'Rane', 'Panaji', 'Goa', 'India', 'rhea.rane@gmail.com', '9823112345'),
(389, 'Shaurya', 'Kumar', 'Gaya', 'Bihar', 'India', 'shaurya.kumar@gmail.com', '9700312345'),
(390, 'Diya', 'Bhatt', 'Ernakulam', 'Kerala', 'India', 'diya.bhatt@gmail.com', '9447312345'),
(391, 'Yashika', 'Naik', 'Thrissur', 'Kerala', 'India', 'yashika.naik@gmail.com', '9447412345'),
(392, 'Vedant', 'Dasgupta', 'Howrah', 'West Bengal', 'India', 'vedant.dasgupta@gmail.com', '9831412345'),
(393, 'Snehal', 'Kulkarni', 'Satara', 'Maharashtra', 'India', 'snehal.kulkarni@gmail.com', '9845312345'),
(394, 'Kritika', 'Saxena', 'Meerut', 'Uttar Pradesh', 'India', 'kritika.saxena@gmail.com', '9781512345'),
(395, 'Yuvraj', 'Mishra', 'Jhansi', 'Uttar Pradesh', 'India', 'yuvraj.mishra@gmail.com', '9798712345'),
(396, 'Navya', 'Khandelwal', 'Ajmer', 'Rajasthan', 'India', 'navya.khandelwal@gmail.com', '9781612345'),
(397, 'Rudraksh', 'Desai', 'Navsari', 'Gujarat', 'India', 'rudraksh.desai@gmail.com', '9876512345'),
(398, 'Meghna', 'Rawat', 'Nainital', 'Uttarakhand', 'India', 'meghna.rawat@gmail.com', '9767512345'),
(399, 'Ayaan', 'Shaikh', 'Malegaon', 'Maharashtra', 'India', 'ayaan.shaikh@gmail.com', '9867812345'),
(400, 'Lavanya', 'Kumar', 'Tirupati', 'Andhra Pradesh', 'India', 'lavanya.kumar@gmail.com', '9848212345');
GO


INSERT INTO CustomerDim (CustomerID, FirstName, LastName, City, State, Country, Email, Phone)
VALUES
(401, 'Aarav', 'Mehrotra', 'Lucknow', 'Uttar Pradesh', 'India', 'aarav.mehrotra@gmail.com', '9798912345'),
(402, 'Simran', 'Tandon', 'Kanpur', 'Uttar Pradesh', 'India', 'simran.tandon@gmail.com', '9781712345'),
(403, 'Neil', 'Chawla', 'Ludhiana', 'Punjab', 'India', 'neil.chawla@gmail.com', '9812612345'),
(404, 'Sanya', 'Chugh', 'Jalandhar', 'Punjab', 'India', 'sanya.chugh@gmail.com', '9812712345'),
(405, 'Ansh', 'Dwivedi', 'Varanasi', 'Uttar Pradesh', 'India', 'ansh.dwivedi@gmail.com', '9781812345'),
(406, 'Vidhi', 'Joshi', 'Nagpur', 'Maharashtra', 'India', 'vidhi.joshi@gmail.com', '9867912345'),
(407, 'Kunal', 'Khatri', 'Raipur', 'Chhattisgarh', 'India', 'kunal.khatri@gmail.com', '9765612345'),
(408, 'Mira', 'Vernekar', 'Panaji', 'Goa', 'India', 'mira.vernekar@gmail.com', '9823212345'),
(409, 'Aarushi', 'Bhattacharya', 'Kolkata', 'West Bengal', 'India', 'aarushi.bhattacharya@gmail.com', '9831512345'),
(410, 'Ayush', 'Sen', 'Siliguri', 'West Bengal', 'India', 'ayush.sen@gmail.com', '9831612345'),
(411, 'Radhika', 'Kapoor', 'Delhi', 'Delhi', 'India', 'radhika.kapoor@gmail.com', '9818912355'),
(412, 'Nikhil', 'Thakur', 'Gurgaon', 'Haryana', 'India', 'nikhil.thakur@gmail.com', '9812312355'),
(413, 'Megha', 'Singh', 'Faridabad', 'Haryana', 'India', 'megha.singh@gmail.com', '9812412355'),
(414, 'Rajat', 'Bansal', 'Ghaziabad', 'Uttar Pradesh', 'India', 'rajat.bansal@gmail.com', '9798512355'),
(415, 'Prisha', 'Dhingra', 'Noida', 'Uttar Pradesh', 'India', 'prisha.dhingra@gmail.com', '9781912345'),
(416, 'Alok', 'Narayan', 'Patna', 'Bihar', 'India', 'alok.narayan@gmail.com', '9700312355'),
(417, 'Arjun', 'Kashyap', 'Ranchi', 'Jharkhand', 'India', 'arjun.kashyap@gmail.com', '9800512355'),
(418, 'Ragini', 'Desai', 'Anand', 'Gujarat', 'India', 'ragini.desai@gmail.com', '9876622345'),
(419, 'Tara', 'Khan', 'Srinagar', 'Jammu & Kashmir', 'India', 'tara.khan@gmail.com', '9797112355'),
(420, 'Aditya', 'Bhat', 'Shimla', 'Himachal Pradesh', 'India', 'aditya.bhat@gmail.com', '9800412355'),
(421, 'Kavita', 'Modi', 'Surat', 'Gujarat', 'India', 'kavita.modi@gmail.com', '9876712345'),
(422, 'Ayaan', 'Iqbal', 'Bareilly', 'Uttar Pradesh', 'India', 'ayaan.iqbal@gmail.com', '9782012345'),
(423, 'Snehal', 'Lal', 'Jabalpur', 'Madhya Pradesh', 'India', 'snehal.lal@gmail.com', '9755812345'),
(424, 'Jiya', 'Aggarwal', 'Agra', 'Uttar Pradesh', 'India', 'jiya.aggarwal@gmail.com', '9782112345'),
(425, 'Aakash', 'Reddy', 'Hyderabad', 'Telangana', 'India', 'aakash.reddy@gmail.com', '9848012345'),
(426, 'Vishal', 'Kumar', 'Bengaluru', 'Karnataka', 'India', 'vishal.kumar@gmail.com', '9845012345'),
(427, 'Shivangi', 'Shetty', 'Mangalore', 'Karnataka', 'India', 'shivangi.shetty@gmail.com', '9845112345'),
(428, 'Arnav', 'Nayak', 'Bhubaneswar', 'Odisha', 'India', 'arnav.nayak@gmail.com', '9861012345'),
(429, 'Ishita', 'Raut', 'Raipur', 'Chhattisgarh', 'India', 'ishita.raut@gmail.com', '9765712345'),
(430, 'Yuvraj', 'Saxena', 'Dehradun', 'Uttarakhand', 'India', 'yuvraj.saxena@gmail.com', '9767812345'),
(431, 'Arya', 'Pawar', 'Kolhapur', 'Maharashtra', 'India', 'arya.pawar@gmail.com', '9845212355'),
(432, 'Harsh', 'Kale', 'Satara', 'Maharashtra', 'India', 'harsh.kale@gmail.com', '9845312345'),
(433, 'Rhea', 'Chaturvedi', 'Udaipur', 'Rajasthan', 'India', 'rhea.chaturvedi@gmail.com', '9782212345'),
(434, 'Ishaan', 'Jaiswal', 'Bikaner', 'Rajasthan', 'India', 'ishaan.jaiswal@gmail.com', '9782312345'),
(435, 'Zara', 'Bhansali', 'Mumbai', 'Maharashtra', 'India', 'zara.bhansali@gmail.com', '9867812345'),
(436, 'Pranav', 'Khanna', 'Gaya', 'Bihar', 'India', 'pranav.khanna@gmail.com', '9700412345'),
(437, 'Riddhi', 'Saxena', 'Varanasi', 'Uttar Pradesh', 'India', 'riddhi.saxena@gmail.com', '9782512345'),
(438, 'Krish', 'Raj', 'Chennai', 'Tamil Nadu', 'India', 'krish.raj@gmail.com', '9840012345'),
(439, 'Tanya', 'Agarwal', 'Ahmedabad', 'Gujarat', 'India', 'tanya.agarwal@gmail.com', '9876822345'),
(440, 'Atharv', 'Goel', 'Jaipur', 'Rajasthan', 'India', 'atharv.goel@gmail.com', '9782612345'),
(441, 'Sanika', 'Dey', 'Kolkata', 'West Bengal', 'India', 'sanika.dey@gmail.com', '9831612355'),
(442, 'Reyansh', 'Jain', 'Delhi', 'Delhi', 'India', 'reyansh.jain@gmail.com', '9818912365'),
(443, 'Anvi', 'Srivastava', 'Gorakhpur', 'Uttar Pradesh', 'India', 'anvi.srivastava@gmail.com', '9798812345'),
(444, 'Darsh', 'Menon', 'Kochi', 'Kerala', 'India', 'darsh.menon@gmail.com', '9447412345'),
(445, 'Nidhi', 'Malik', 'Chandigarh', 'Chandigarh', 'India', 'nidhi.malik@gmail.com', '9818812375'),
(446, 'Shaurya', 'Patil', 'Thane', 'Maharashtra', 'India', 'shaurya.patil@gmail.com', '9867912355'),
(447, 'Diya', 'Rai', 'Lucknow', 'Uttar Pradesh', 'India', 'diya.rai@gmail.com', '9798912355'),
(448, 'Aayushi', 'Choudhary', 'Indore', 'Madhya Pradesh', 'India', 'aayushi.choudhary@gmail.com', '9755912355'),
(449, 'Neil', 'Sarma', 'Guwahati', 'Assam', 'India', 'neil.sarma@gmail.com', '9863112355'),
(450, 'Tanisha', 'Yadav', 'Ambala', 'Haryana', 'India', 'tanisha.yadav@gmail.com', '9812312355');
GO
INSERT INTO CustomerDim (CustomerID, FirstName, LastName, City, State, Country, Email, Phone)
VALUES
(451, 'Vedika', 'Rastogi', 'Agra', 'Uttar Pradesh', 'India', 'vedika.rastogi@gmail.com', '9782612365'),
(452, 'Aryan', 'Vernekar', 'Panaji', 'Goa', 'India', 'aryan.vernekar@gmail.com', '9823212365'),
(453, 'Moksha', 'Kumar', 'Patna', 'Bihar', 'India', 'moksha.kumar@gmail.com', '9700512365'),
(454, 'Riyan', 'Kohli', 'Jammu', 'Jammu & Kashmir', 'India', 'riyan.kohli@gmail.com', '9797212365'),
(455, 'Aashi', 'Kapoor', 'Delhi', 'Delhi', 'India', 'aashi.kapoor@gmail.com', '9818912375'),
(456, 'Ishant', 'Goswami', 'Udaipur', 'Rajasthan', 'India', 'ishant.goswami@gmail.com', '9782712365'),
(457, 'Meher', 'Shetty', 'Bengaluru', 'Karnataka', 'India', 'meher.shetty@gmail.com', '9845012365'),
(458, 'Rudraksh', 'Shah', 'Ahmedabad', 'Gujarat', 'India', 'rudraksh.shah@gmail.com', '9876812365'),
(459, 'Kiara', 'Joshi', 'Vadodara', 'Gujarat', 'India', 'kiara.joshi@gmail.com', '9876912365'),
(460, 'Aarav', 'Saxena', 'Ghaziabad', 'Uttar Pradesh', 'India', 'aarav.saxena@gmail.com', '9798612365'),
(461, 'Saanvi', 'Sood', 'Ludhiana', 'Punjab', 'India', 'saanvi.sood@gmail.com', '9812912365'),
(462, 'Reyansh', 'Khan', 'Bareilly', 'Uttar Pradesh', 'India', 'reyansh.khan@gmail.com', '9782812365'),
(463, 'Mira', 'Srivastava', 'Kanpur', 'Uttar Pradesh', 'India', 'mira.srivastava@gmail.com', '9798912365'),
(464, 'Harshit', 'Mishra', 'Gorakhpur', 'Uttar Pradesh', 'India', 'harshit.mishra@gmail.com', '9799012365'),
(465, 'Ansh', 'Chatterjee', 'Kolkata', 'West Bengal', 'India', 'ansh.chatterjee@gmail.com', '9831712365'),
(466, 'Advika', 'Reddy', 'Hyderabad', 'Telangana', 'India', 'advika.reddy@gmail.com', '9848012365'),
(467, 'Samar', 'Iqbal', 'Srinagar', 'Jammu & Kashmir', 'India', 'samar.iqbal@gmail.com', '9797312365'),
(468, 'Nysa', 'Garg', 'Ambala', 'Haryana', 'India', 'nysa.garg@gmail.com', '9812512365'),
(469, 'Aryan', 'Patel', 'Rajkot', 'Gujarat', 'India', 'aryan.patel@gmail.com', '9876512365'),
(470, 'Tisha', 'Verma', 'Varanasi', 'Uttar Pradesh', 'India', 'tisha.verma@gmail.com', '9782912365'),
(471, 'Darsh', 'Mehra', 'Indore', 'Madhya Pradesh', 'India', 'darsh.mehra@gmail.com', '9755912365'),
(472, 'Krisha', 'Dixit', 'Bhopal', 'Madhya Pradesh', 'India', 'krisha.dixit@gmail.com', '9755812365'),
(473, 'Veer', 'Kapadia', 'Surat', 'Gujarat', 'India', 'veer.kapadia@gmail.com', '9876612365'),
(474, 'Nitya', 'Desai', 'Navsari', 'Gujarat', 'India', 'nitya.desai@gmail.com', '9876712365'),
(475, 'Arnav', 'Rana', 'Dehradun', 'Uttarakhand', 'India', 'arnav.rana@gmail.com', '9767912365'),
(476, 'Trisha', 'Rawat', 'Haridwar', 'Uttarakhand', 'India', 'trisha.rawat@gmail.com', '9767812365'),
(477, 'Rian', 'Bhardwaj', 'Ajmer', 'Rajasthan', 'India', 'rian.bhardwaj@gmail.com', '9783012365'),
(478, 'Avika', 'Khanna', 'Jaipur', 'Rajasthan', 'India', 'avika.khanna@gmail.com', '9783112365'),
(479, 'Neel', 'Yadav', 'Allahabad', 'Uttar Pradesh', 'India', 'neel.yadav@gmail.com', '9799112365'),
(480, 'Aanya', 'Shukla', 'Satna', 'Madhya Pradesh', 'India', 'aanya.shukla@gmail.com', '9755612365'),
(481, 'Shaurya', 'Tripathi', 'Rewa', 'Madhya Pradesh', 'India', 'shaurya.tripathi@gmail.com', '9755512365'),
(482, 'Anvi', 'Naidu', 'Chennai', 'Tamil Nadu', 'India', 'anvi.naidu@gmail.com', '9840012365'),
(483, 'Reyansh', 'Raj', 'Coimbatore', 'Tamil Nadu', 'India', 'reyansh.raj@gmail.com', '9843212365'),
(484, 'Ayushi', 'Rane', 'Panaji', 'Goa', 'India', 'ayushi.rane@gmail.com', '9823212365'),
(485, 'Ishaan', 'Deshpande', 'Nagpur', 'Maharashtra', 'India', 'ishaan.deshpande@gmail.com', '9867912365'),
(486, 'Kiara', 'Singh', 'Noida', 'Uttar Pradesh', 'India', 'kiara.singh@gmail.com', '9783212365'),
(487, 'Rohit', 'Dey', 'Kolkata', 'West Bengal', 'India', 'rohit.dey@gmail.com', '9831812365'),
(488, 'Muskan', 'Jaiswal', 'Gaya', 'Bihar', 'India', 'muskan.jaiswal@gmail.com', '9700612365'),
(489, 'Siddhi', 'Joshi', 'Vadodara', 'Gujarat', 'India', 'siddhi.joshi@gmail.com', '9876912365'),
(490, 'Atharv', 'Pandey', 'Kanpur', 'Uttar Pradesh', 'India', 'atharv.pandey@gmail.com', '9799212365'),
(491, 'Madhav', 'Sarkar', 'Durgapur', 'West Bengal', 'India', 'madhav.sarkar@gmail.com', '9831912365'),
(492, 'Ira', 'Saxena', 'Lucknow', 'Uttar Pradesh', 'India', 'ira.saxena@gmail.com', '9799312365'),
(493, 'Vihaan', 'Rathi', 'Patiala', 'Punjab', 'India', 'vihaan.rathi@gmail.com', '9812912365'),
(494, 'Samaira', 'Gupta', 'Amritsar', 'Punjab', 'India', 'samaira.gupta@gmail.com', '9813012365'),
(495, 'Krish', 'Chowdhury', 'Kolkata', 'West Bengal', 'India', 'krish.chowdhury@gmail.com', '9832012365'),
(496, 'Naisha', 'Malik', 'Ghaziabad', 'Uttar Pradesh', 'India', 'naisha.malik@gmail.com', '9799412365'),
(497, 'Shaurya', 'Garg', 'Faridabad', 'Haryana', 'India', 'shaurya.garg@gmail.com', '9812712365'),
(498, 'Myra', 'Bajpai', 'Gorakhpur', 'Uttar Pradesh', 'India', 'myra.bajpai@gmail.com', '9799512365'),
(499, 'Aarav', 'Chadha', 'Bikaner', 'Rajasthan', 'India', 'aarav.chadha@gmail.com', '9783312365'),
(500, 'Diya', 'Kapoor', 'Delhi', 'Delhi', 'India', 'diya.kapoor@gmail.com', '9818912385');
GO


INSERT INTO DateDim (DateID, ActualDate, Month, Quarter, Year)
VALUES
(1, '2023-01-01', 'January', 'Q1', 2023),
(2, '2023-01-02', 'January', 'Q1', 2023),
(3, '2023-01-03', 'January', 'Q1', 2023),
(4, '2023-01-04', 'January', 'Q1', 2023),
(5, '2023-01-05', 'January', 'Q1', 2023),
(6, '2023-01-06', 'January', 'Q1', 2023),
(7, '2023-01-07', 'January', 'Q1', 2023),
(8, '2023-01-08', 'January', 'Q1', 2023),
(9, '2023-01-09', 'January', 'Q1', 2023),
(10, '2023-01-10', 'January', 'Q1', 2023),
(11, '2023-01-11', 'January', 'Q1', 2023),
(12, '2023-01-12', 'January', 'Q1', 2023),
(13, '2023-01-13', 'January', 'Q1', 2023),
(14, '2023-01-14', 'January', 'Q1', 2023),
(15, '2023-01-15', 'January', 'Q1', 2023),
(16, '2023-01-16', 'January', 'Q1', 2023),
(17, '2023-01-17', 'January', 'Q1', 2023),
(18, '2023-01-18', 'January', 'Q1', 2023),
(19, '2023-01-19', 'January', 'Q1', 2023),
(20, '2023-01-20', 'January', 'Q1', 2023),
(21, '2023-01-21', 'January', 'Q1', 2023),
(22, '2023-01-22', 'January', 'Q1', 2023),
(23, '2023-01-23', 'January', 'Q1', 2023),
(24, '2023-01-24', 'January', 'Q1', 2023),
(25, '2023-01-25', 'January', 'Q1', 2023),
(26, '2023-01-26', 'January', 'Q1', 2023),
(27, '2023-01-27', 'January', 'Q1', 2023),
(28, '2023-01-28', 'January', 'Q1', 2023),
(29, '2023-01-29', 'January', 'Q1', 2023),
(30, '2023-01-30', 'January', 'Q1', 2023),
(31, '2023-01-31', 'January', 'Q1', 2023),
(32, '2023-02-01', 'February', 'Q1', 2023),
(33, '2023-02-02', 'February', 'Q1', 2023),
(34, '2023-02-03', 'February', 'Q1', 2023),
(35, '2023-02-04', 'February', 'Q1', 2023),
(36, '2023-02-05', 'February', 'Q1', 2023),
(37, '2023-02-06', 'February', 'Q1', 2023),
(38, '2023-02-07', 'February', 'Q1', 2023),
(39, '2023-02-08', 'February', 'Q1', 2023),
(40, '2023-02-09', 'February', 'Q1', 2023),
(41, '2023-02-10', 'February', 'Q1', 2023),
(42, '2023-02-11', 'February', 'Q1', 2023),
(43, '2023-02-12', 'February', 'Q1', 2023),
(44, '2023-02-13', 'February', 'Q1', 2023),
(45, '2023-02-14', 'February', 'Q1', 2023),
(46, '2023-02-15', 'February', 'Q1', 2023),
(47, '2023-02-16', 'February', 'Q1', 2023),
(48, '2023-02-17', 'February', 'Q1', 2023),
(49, '2023-02-18', 'February', 'Q1', 2023),
(50, '2023-02-19', 'February', 'Q1', 2023),
(51, '2023-02-20', 'February', 'Q1', 2023),
(52, '2023-02-21', 'February', 'Q1', 2023),
(53, '2023-02-22', 'February', 'Q1', 2023),
(54, '2023-02-23', 'February', 'Q1', 2023),
(55, '2023-02-24', 'February', 'Q1', 2023),
(56, '2023-02-25', 'February', 'Q1', 2023),
(57, '2023-02-26', 'February', 'Q1', 2023),
(58, '2023-02-27', 'February', 'Q1', 2023),
(59, '2023-02-28', 'February', 'Q1', 2023),
(60, '2023-03-01', 'March', 'Q1', 2023),
(61, '2023-03-02', 'March', 'Q1', 2023),
(62, '2023-03-03', 'March', 'Q1', 2023),
(63, '2023-03-04', 'March', 'Q1', 2023),
(64, '2023-03-05', 'March', 'Q1', 2023),
(65, '2023-03-06', 'March', 'Q1', 2023),
(66, '2023-03-07', 'March', 'Q1', 2023),
(67, '2023-03-08', 'March', 'Q1', 2023),
(68, '2023-03-09', 'March', 'Q1', 2023),
(69, '2023-03-10', 'March', 'Q1', 2023),
(70, '2023-03-11', 'March', 'Q1', 2023),
(71, '2023-03-12', 'March', 'Q1', 2023),
(72, '2023-03-13', 'March', 'Q1', 2023),
(73, '2023-03-14', 'March', 'Q1', 2023),
(74, '2023-03-15', 'March', 'Q1', 2023),
(75, '2023-03-16', 'March', 'Q1', 2023),
(76, '2023-03-17', 'March', 'Q1', 2023),
(77, '2023-03-18', 'March', 'Q1', 2023),
(78, '2023-03-19', 'March', 'Q1', 2023),
(79, '2023-03-20', 'March', 'Q1', 2023),
(80, '2023-03-21', 'March', 'Q1', 2023),
(81, '2023-03-22', 'March', 'Q1', 2023),
(82, '2023-03-23', 'March', 'Q1', 2023),
(83, '2023-03-24', 'March', 'Q1', 2023),
(84, '2023-03-25', 'March', 'Q1', 2023),
(85, '2023-03-26', 'March', 'Q1', 2023),
(86, '2023-03-27', 'March', 'Q1', 2023),
(87, '2023-03-28', 'March', 'Q1', 2023),
(88, '2023-03-29', 'March', 'Q1', 2023),
(89, '2023-03-30', 'March', 'Q1', 2023),
(90, '2023-03-31', 'March', 'Q1', 2023),
(91, '2023-04-01', 'April', 'Q2', 2023),
(92, '2023-04-02', 'April', 'Q2', 2023),
(93, '2023-04-03', 'April', 'Q2', 2023),
(94, '2023-04-04', 'April', 'Q2', 2023),
(95, '2023-04-05', 'April', 'Q2', 2023),
(96, '2023-04-06', 'April', 'Q2', 2023),
(97, '2023-04-07', 'April', 'Q2', 2023),
(98, '2023-04-08', 'April', 'Q2', 2023),
(99, '2023-04-09', 'April', 'Q2', 2023),
(100, '2023-04-10', 'April', 'Q2', 2023);
GO
INSERT INTO DateDim (DateID, ActualDate, Month, Quarter, Year)
VALUES
(101, '2023-04-11', 'April', 'Q2', 2023),
(102, '2023-04-12', 'April', 'Q2', 2023),
(103, '2023-04-13', 'April', 'Q2', 2023),
(104, '2023-04-14', 'April', 'Q2', 2023),
(105, '2023-04-15', 'April', 'Q2', 2023),
(106, '2023-04-16', 'April', 'Q2', 2023),
(107, '2023-04-17', 'April', 'Q2', 2023),
(108, '2023-04-18', 'April', 'Q2', 2023),
(109, '2023-04-19', 'April', 'Q2', 2023),
(110, '2023-04-20', 'April', 'Q2', 2023),
(111, '2023-04-21', 'April', 'Q2', 2023),
(112, '2023-04-22', 'April', 'Q2', 2023),
(113, '2023-04-23', 'April', 'Q2', 2023),
(114, '2023-04-24', 'April', 'Q2', 2023),
(115, '2023-04-25', 'April', 'Q2', 2023),
(116, '2023-04-26', 'April', 'Q2', 2023),
(117, '2023-04-27', 'April', 'Q2', 2023),
(118, '2023-04-28', 'April', 'Q2', 2023),
(119, '2023-04-29', 'April', 'Q2', 2023),
(120, '2023-04-30', 'April', 'Q2', 2023),
(121, '2023-05-01', 'May', 'Q2', 2023),
(122, '2023-05-02', 'May', 'Q2', 2023),
(123, '2023-05-03', 'May', 'Q2', 2023),
(124, '2023-05-04', 'May', 'Q2', 2023),
(125, '2023-05-05', 'May', 'Q2', 2023),
(126, '2023-05-06', 'May', 'Q2', 2023),
(127, '2023-05-07', 'May', 'Q2', 2023),
(128, '2023-05-08', 'May', 'Q2', 2023),
(129, '2023-05-09', 'May', 'Q2', 2023),
(130, '2023-05-10', 'May', 'Q2', 2023),
(131, '2023-05-11', 'May', 'Q2', 2023),
(132, '2023-05-12', 'May', 'Q2', 2023),
(133, '2023-05-13', 'May', 'Q2', 2023),
(134, '2023-05-14', 'May', 'Q2', 2023),
(135, '2023-05-15', 'May', 'Q2', 2023),
(136, '2023-05-16', 'May', 'Q2', 2023),
(137, '2023-05-17', 'May', 'Q2', 2023),
(138, '2023-05-18', 'May', 'Q2', 2023),
(139, '2023-05-19', 'May', 'Q2', 2023),
(140, '2023-05-20', 'May', 'Q2', 2023),
(141, '2023-05-21', 'May', 'Q2', 2023),
(142, '2023-05-22', 'May', 'Q2', 2023),
(143, '2023-05-23', 'May', 'Q2', 2023),
(144, '2023-05-24', 'May', 'Q2', 2023),
(145, '2023-05-25', 'May', 'Q2', 2023),
(146, '2023-05-26', 'May', 'Q2', 2023),
(147, '2023-05-27', 'May', 'Q2', 2023),
(148, '2023-05-28', 'May', 'Q2', 2023),
(149, '2023-05-29', 'May', 'Q2', 2023),
(150, '2023-05-30', 'May', 'Q2', 2023),
(151, '2023-05-31', 'May', 'Q2', 2023),
(152, '2023-06-01', 'June', 'Q2', 2023),
(153, '2023-06-02', 'June', 'Q2', 2023),
(154, '2023-06-03', 'June', 'Q2', 2023),
(155, '2023-06-04', 'June', 'Q2', 2023),
(156, '2023-06-05', 'June', 'Q2', 2023),
(157, '2023-06-06', 'June', 'Q2', 2023),
(158, '2023-06-07', 'June', 'Q2', 2023),
(159, '2023-06-08', 'June', 'Q2', 2023),
(160, '2023-06-09', 'June', 'Q2', 2023),
(161, '2023-06-10', 'June', 'Q2', 2023),
(162, '2023-06-11', 'June', 'Q2', 2023),
(163, '2023-06-12', 'June', 'Q2', 2023),
(164, '2023-06-13', 'June', 'Q2', 2023),
(165, '2023-06-14', 'June', 'Q2', 2023),
(166, '2023-06-15', 'June', 'Q2', 2023),
(167, '2023-06-16', 'June', 'Q2', 2023),
(168, '2023-06-17', 'June', 'Q2', 2023),
(169, '2023-06-18', 'June', 'Q2', 2023),
(170, '2023-06-19', 'June', 'Q2', 2023),
(171, '2023-06-20', 'June', 'Q2', 2023),
(172, '2023-06-21', 'June', 'Q2', 2023),
(173, '2023-06-22', 'June', 'Q2', 2023),
(174, '2023-06-23', 'June', 'Q2', 2023),
(175, '2023-06-24', 'June', 'Q2', 2023),
(176, '2023-06-25', 'June', 'Q2', 2023),
(177, '2023-06-26', 'June', 'Q2', 2023),
(178, '2023-06-27', 'June', 'Q2', 2023),
(179, '2023-06-28', 'June', 'Q2', 2023),
(180, '2023-06-29', 'June', 'Q2', 2023),
(181, '2023-06-30', 'June', 'Q2', 2023),
(182, '2023-07-01', 'July', 'Q3', 2023),
(183, '2023-07-02', 'July', 'Q3', 2023),
(184, '2023-07-03', 'July', 'Q3', 2023),
(185, '2023-07-04', 'July', 'Q3', 2023),
(186, '2023-07-05', 'July', 'Q3', 2023),
(187, '2023-07-06', 'July', 'Q3', 2023),
(188, '2023-07-07', 'July', 'Q3', 2023),
(189, '2023-07-08', 'July', 'Q3', 2023),
(190, '2023-07-09', 'July', 'Q3', 2023),
(191, '2023-07-10', 'July', 'Q3', 2023),
(192, '2023-07-11', 'July', 'Q3', 2023),
(193, '2023-07-12', 'July', 'Q3', 2023),
(194, '2023-07-13', 'July', 'Q3', 2023),
(195, '2023-07-14', 'July', 'Q3', 2023),
(196, '2023-07-15', 'July', 'Q3', 2023),
(197, '2023-07-16', 'July', 'Q3', 2023),
(198, '2023-07-17', 'July', 'Q3', 2023),
(199, '2023-07-18', 'July', 'Q3', 2023),
(200, '2023-07-19', 'July', 'Q3', 2023);
GO
INSERT INTO DateDim (DateID, ActualDate, Month, Quarter, Year)
VALUES
(201, '2023-07-20', 'July', 'Q3', 2023),
(202, '2023-07-21', 'July', 'Q3', 2023),
(203, '2023-07-22', 'July', 'Q3', 2023),
(204, '2023-07-23', 'July', 'Q3', 2023),
(205, '2023-07-24', 'July', 'Q3', 2023),
(206, '2023-07-25', 'July', 'Q3', 2023),
(207, '2023-07-26', 'July', 'Q3', 2023),
(208, '2023-07-27', 'July', 'Q3', 2023),
(209, '2023-07-28', 'July', 'Q3', 2023),
(210, '2023-07-29', 'July', 'Q3', 2023),
(211, '2023-07-30', 'July', 'Q3', 2023),
(212, '2023-07-31', 'July', 'Q3', 2023),
(213, '2023-08-01', 'August', 'Q3', 2023),
(214, '2023-08-02', 'August', 'Q3', 2023),
(215, '2023-08-03', 'August', 'Q3', 2023),
(216, '2023-08-04', 'August', 'Q3', 2023),
(217, '2023-08-05', 'August', 'Q3', 2023),
(218, '2023-08-06', 'August', 'Q3', 2023),
(219, '2023-08-07', 'August', 'Q3', 2023),
(220, '2023-08-08', 'August', 'Q3', 2023),
(221, '2023-08-09', 'August', 'Q3', 2023),
(222, '2023-08-10', 'August', 'Q3', 2023),
(223, '2023-08-11', 'August', 'Q3', 2023),
(224, '2023-08-12', 'August', 'Q3', 2023),
(225, '2023-08-13', 'August', 'Q3', 2023),
(226, '2023-08-14', 'August', 'Q3', 2023),
(227, '2023-08-15', 'August', 'Q3', 2023),
(228, '2023-08-16', 'August', 'Q3', 2023),
(229, '2023-08-17', 'August', 'Q3', 2023),
(230, '2023-08-18', 'August', 'Q3', 2023),
(231, '2023-08-19', 'August', 'Q3', 2023),
(232, '2023-08-20', 'August', 'Q3', 2023),
(233, '2023-08-21', 'August', 'Q3', 2023),
(234, '2023-08-22', 'August', 'Q3', 2023),
(235, '2023-08-23', 'August', 'Q3', 2023),
(236, '2023-08-24', 'August', 'Q3', 2023),
(237, '2023-08-25', 'August', 'Q3', 2023),
(238, '2023-08-26', 'August', 'Q3', 2023),
(239, '2023-08-27', 'August', 'Q3', 2023),
(240, '2023-08-28', 'August', 'Q3', 2023),
(241, '2023-08-29', 'August', 'Q3', 2023),
(242, '2023-08-30', 'August', 'Q3', 2023),
(243, '2023-08-31', 'August', 'Q3', 2023),
(244, '2023-09-01', 'September', 'Q3', 2023),
(245, '2023-09-02', 'September', 'Q3', 2023),
(246, '2023-09-03', 'September', 'Q3', 2023),
(247, '2023-09-04', 'September', 'Q3', 2023),
(248, '2023-09-05', 'September', 'Q3', 2023),
(249, '2023-09-06', 'September', 'Q3', 2023),
(250, '2023-09-07', 'September', 'Q3', 2023),
(251, '2023-09-08', 'September', 'Q3', 2023),
(252, '2023-09-09', 'September', 'Q3', 2023),
(253, '2023-09-10', 'September', 'Q3', 2023),
(254, '2023-09-11', 'September', 'Q3', 2023),
(255, '2023-09-12', 'September', 'Q3', 2023),
(256, '2023-09-13', 'September', 'Q3', 2023),
(257, '2023-09-14', 'September', 'Q3', 2023),
(258, '2023-09-15', 'September', 'Q3', 2023),
(259, '2023-09-16', 'September', 'Q3', 2023),
(260, '2023-09-17', 'September', 'Q3', 2023),
(261, '2023-09-18', 'September', 'Q3', 2023),
(262, '2023-09-19', 'September', 'Q3', 2023),
(263, '2023-09-20', 'September', 'Q3', 2023),
(264, '2023-09-21', 'September', 'Q3', 2023),
(265, '2023-09-22', 'September', 'Q3', 2023),
(266, '2023-09-23', 'September', 'Q3', 2023),
(267, '2023-09-24', 'September', 'Q3', 2023),
(268, '2023-09-25', 'September', 'Q3', 2023),
(269, '2023-09-26', 'September', 'Q3', 2023),
(270, '2023-09-27', 'September', 'Q3', 2023),
(271, '2023-09-28', 'September', 'Q3', 2023),
(272, '2023-09-29', 'September', 'Q3', 2023),
(273, '2023-09-30', 'September', 'Q3', 2023),
(274, '2023-10-01', 'October', 'Q4', 2023),
(275, '2023-10-02', 'October', 'Q4', 2023),
(276, '2023-10-03', 'October', 'Q4', 2023),
(277, '2023-10-04', 'October', 'Q4', 2023),
(278, '2023-10-05', 'October', 'Q4', 2023),
(279, '2023-10-06', 'October', 'Q4', 2023),
(280, '2023-10-07', 'October', 'Q4', 2023),
(281, '2023-10-08', 'October', 'Q4', 2023),
(282, '2023-10-09', 'October', 'Q4', 2023),
(283, '2023-10-10', 'October', 'Q4', 2023),
(284, '2023-10-11', 'October', 'Q4', 2023),
(285, '2023-10-12', 'October', 'Q4', 2023),
(286, '2023-10-13', 'October', 'Q4', 2023),
(287, '2023-10-14', 'October', 'Q4', 2023),
(288, '2023-10-15', 'October', 'Q4', 2023),
(289, '2023-10-16', 'October', 'Q4', 2023),
(290, '2023-10-17', 'October', 'Q4', 2023),
(291, '2023-10-18', 'October', 'Q4', 2023),
(292, '2023-10-19', 'October', 'Q4', 2023),
(293, '2023-10-20', 'October', 'Q4', 2023),
(294, '2023-10-21', 'October', 'Q4', 2023),
(295, '2023-10-22', 'October', 'Q4', 2023),
(296, '2023-10-23', 'October', 'Q4', 2023),
(297, '2023-10-24', 'October', 'Q4', 2023),
(298, '2023-10-25', 'October', 'Q4', 2023),
(299, '2023-10-26', 'October', 'Q4', 2023),
(300, '2023-10-27', 'October', 'Q4', 2023);
GO



INSERT INTO DateDim (DateID, ActualDate, Month, Quarter, Year)
VALUES
(301, '2023-10-28', 'October', 'Q4', 2023),
(302, '2023-10-29', 'October', 'Q4', 2023),
(303, '2023-10-30', 'October', 'Q4', 2023),
(304, '2023-10-31', 'October', 'Q4', 2023),
(305, '2023-11-01', 'November', 'Q4', 2023),
(306, '2023-11-02', 'November', 'Q4', 2023),
(307, '2023-11-03', 'November', 'Q4', 2023),
(308, '2023-11-04', 'November', 'Q4', 2023),
(309, '2023-11-05', 'November', 'Q4', 2023),
(310, '2023-11-06', 'November', 'Q4', 2023),
(311, '2023-11-07', 'November', 'Q4', 2023),
(312, '2023-11-08', 'November', 'Q4', 2023),
(313, '2023-11-09', 'November', 'Q4', 2023),
(314, '2023-11-10', 'November', 'Q4', 2023),
(315, '2023-11-11', 'November', 'Q4', 2023),
(316, '2023-11-12', 'November', 'Q4', 2023),
(317, '2023-11-13', 'November', 'Q4', 2023),
(318, '2023-11-14', 'November', 'Q4', 2023),
(319, '2023-11-15', 'November', 'Q4', 2023),
(320, '2023-11-16', 'November', 'Q4', 2023),
(321, '2023-11-17', 'November', 'Q4', 2023),
(322, '2023-11-18', 'November', 'Q4', 2023),
(323, '2023-11-19', 'November', 'Q4', 2023),
(324, '2023-11-20', 'November', 'Q4', 2023),
(325, '2023-11-21', 'November', 'Q4', 2023),
(326, '2023-11-22', 'November', 'Q4', 2023),
(327, '2023-11-23', 'November', 'Q4', 2023),
(328, '2023-11-24', 'November', 'Q4', 2023),
(329, '2023-11-25', 'November', 'Q4', 2023),
(330, '2023-11-26', 'November', 'Q4', 2023),
(331, '2023-11-27', 'November', 'Q4', 2023),
(332, '2023-11-28', 'November', 'Q4', 2023),
(333, '2023-11-29', 'November', 'Q4', 2023),
(334, '2023-11-30', 'November', 'Q4', 2023),
(335, '2023-12-01', 'December', 'Q4', 2023),
(336, '2023-12-02', 'December', 'Q4', 2023),
(337, '2023-12-03', 'December', 'Q4', 2023),
(338, '2023-12-04', 'December', 'Q4', 2023),
(339, '2023-12-05', 'December', 'Q4', 2023),
(340, '2023-12-06', 'December', 'Q4', 2023),
(341, '2023-12-07', 'December', 'Q4', 2023),
(342, '2023-12-08', 'December', 'Q4', 2023),
(343, '2023-12-09', 'December', 'Q4', 2023),
(344, '2023-12-10', 'December', 'Q4', 2023),
(345, '2023-12-11', 'December', 'Q4', 2023),
(346, '2023-12-12', 'December', 'Q4', 2023),
(347, '2023-12-13', 'December', 'Q4', 2023),
(348, '2023-12-14', 'December', 'Q4', 2023),
(349, '2023-12-15', 'December', 'Q4', 2023),
(350, '2023-12-16', 'December', 'Q4', 2023),
(351, '2023-12-17', 'December', 'Q4', 2023),
(352, '2023-12-18', 'December', 'Q4', 2023),
(353, '2023-12-19', 'December', 'Q4', 2023),
(354, '2023-12-20', 'December', 'Q4', 2023),
(355, '2023-12-21', 'December', 'Q4', 2023),
(356, '2023-12-22', 'December', 'Q4', 2023),
(357, '2023-12-23', 'December', 'Q4', 2023),
(358, '2023-12-24', 'December', 'Q4', 2023),
(359, '2023-12-25', 'December', 'Q4', 2023),
(360, '2023-12-26', 'December', 'Q4', 2023),
(361, '2023-12-27', 'December', 'Q4', 2023),
(362, '2023-12-28', 'December', 'Q4', 2023),
(363, '2023-12-29', 'December', 'Q4', 2023),
(364, '2023-12-30', 'December', 'Q4', 2023),
(365, '2023-12-31', 'December', 'Q4', 2023),
(366, '2024-01-01', 'January', 'Q1', 2024),
(367, '2024-01-02', 'January', 'Q1', 2024),
(368, '2024-01-03', 'January', 'Q1', 2024),
(369, '2024-01-04', 'January', 'Q1', 2024),
(370, '2024-01-05', 'January', 'Q1', 2024),
(371, '2024-01-06', 'January', 'Q1', 2024),
(372, '2024-01-07', 'January', 'Q1', 2024),
(373, '2024-01-08', 'January', 'Q1', 2024),
(374, '2024-01-09', 'January', 'Q1', 2024),
(375, '2024-01-10', 'January', 'Q1', 2024),
(376, '2024-01-11', 'January', 'Q1', 2024),
(377, '2024-01-12', 'January', 'Q1', 2024),
(378, '2024-01-13', 'January', 'Q1', 2024),
(379, '2024-01-14', 'January', 'Q1', 2024),
(380, '2024-01-15', 'January', 'Q1', 2024),
(381, '2024-01-16', 'January', 'Q1', 2024),
(382, '2024-01-17', 'January', 'Q1', 2024),
(383, '2024-01-18', 'January', 'Q1', 2024),
(384, '2024-01-19', 'January', 'Q1', 2024),
(385, '2024-01-20', 'January', 'Q1', 2024),
(386, '2024-01-21', 'January', 'Q1', 2024),
(387, '2024-01-22', 'January', 'Q1', 2024),
(388, '2024-01-23', 'January', 'Q1', 2024),
(389, '2024-01-24', 'January', 'Q1', 2024),
(390, '2024-01-25', 'January', 'Q1', 2024),
(391, '2024-01-26', 'January', 'Q1', 2024),
(392, '2024-01-27', 'January', 'Q1', 2024),
(393, '2024-01-28', 'January', 'Q1', 2024),
(394, '2024-01-29', 'January', 'Q1', 2024),
(395, '2024-01-30', 'January', 'Q1', 2024),
(396, '2024-01-31', 'January', 'Q1', 2024),
(397, '2024-02-01', 'February', 'Q1', 2024),
(398, '2024-02-02', 'February', 'Q1', 2024),
(399, '2024-02-03', 'February', 'Q1', 2024),
(400, '2024-02-04', 'February', 'Q1', 2024);
GO



INSERT INTO DateDim (DateID, ActualDate, Month, Quarter, Year)
VALUES
(401, '2024-02-05', 'February', 'Q1', 2024),
(402, '2024-02-06', 'February', 'Q1', 2024),
(403, '2024-02-07', 'February', 'Q1', 2024),
(404, '2024-02-08', 'February', 'Q1', 2024),
(405, '2024-02-09', 'February', 'Q1', 2024),
(406, '2024-02-10', 'February', 'Q1', 2024),
(407, '2024-02-11', 'February', 'Q1', 2024),
(408, '2024-02-12', 'February', 'Q1', 2024),
(409, '2024-02-13', 'February', 'Q1', 2024),
(410, '2024-02-14', 'February', 'Q1', 2024),
(411, '2024-02-15', 'February', 'Q1', 2024),
(412, '2024-02-16', 'February', 'Q1', 2024),
(413, '2024-02-17', 'February', 'Q1', 2024),
(414, '2024-02-18', 'February', 'Q1', 2024),
(415, '2024-02-19', 'February', 'Q1', 2024),
(416, '2024-02-20', 'February', 'Q1', 2024),
(417, '2024-02-21', 'February', 'Q1', 2024),
(418, '2024-02-22', 'February', 'Q1', 2024),
(419, '2024-02-23', 'February', 'Q1', 2024),
(420, '2024-02-24', 'February', 'Q1', 2024),
(421, '2024-02-25', 'February', 'Q1', 2024),
(422, '2024-02-26', 'February', 'Q1', 2024),
(423, '2024-02-27', 'February', 'Q1', 2024),
(424, '2024-02-28', 'February', 'Q1', 2024),
(425, '2024-02-29', 'February', 'Q1', 2024), -- Leap year!
(426, '2024-03-01', 'March', 'Q1', 2024),
(427, '2024-03-02', 'March', 'Q1', 2024),
(428, '2024-03-03', 'March', 'Q1', 2024),
(429, '2024-03-04', 'March', 'Q1', 2024),
(430, '2024-03-05', 'March', 'Q1', 2024),
(431, '2024-03-06', 'March', 'Q1', 2024),
(432, '2024-03-07', 'March', 'Q1', 2024),
(433, '2024-03-08', 'March', 'Q1', 2024),
(434, '2024-03-09', 'March', 'Q1', 2024),
(435, '2024-03-10', 'March', 'Q1', 2024),
(436, '2024-03-11', 'March', 'Q1', 2024),
(437, '2024-03-12', 'March', 'Q1', 2024),
(438, '2024-03-13', 'March', 'Q1', 2024),
(439, '2024-03-14', 'March', 'Q1', 2024),
(440, '2024-03-15', 'March', 'Q1', 2024),
(441, '2024-03-16', 'March', 'Q1', 2024),
(442, '2024-03-17', 'March', 'Q1', 2024),
(443, '2024-03-18', 'March', 'Q1', 2024),
(444, '2024-03-19', 'March', 'Q1', 2024),
(445, '2024-03-20', 'March', 'Q1', 2024),
(446, '2024-03-21', 'March', 'Q1', 2024),
(447, '2024-03-22', 'March', 'Q1', 2024),
(448, '2024-03-23', 'March', 'Q1', 2024),
(449, '2024-03-24', 'March', 'Q1', 2024),
(450, '2024-03-25', 'March', 'Q1', 2024),
(451, '2024-03-26', 'March', 'Q1', 2024),
(452, '2024-03-27', 'March', 'Q1', 2024),
(453, '2024-03-28', 'March', 'Q1', 2024),
(454, '2024-03-29', 'March', 'Q1', 2024),
(455, '2024-03-30', 'March', 'Q1', 2024),
(456, '2024-03-31', 'March', 'Q1', 2024),
(457, '2024-04-01', 'April', 'Q2', 2024),
(458, '2024-04-02', 'April', 'Q2', 2024),
(459, '2024-04-03', 'April', 'Q2', 2024),
(460, '2024-04-04', 'April', 'Q2', 2024),
(461, '2024-04-05', 'April', 'Q2', 2024),
(462, '2024-04-06', 'April', 'Q2', 2024),
(463, '2024-04-07', 'April', 'Q2', 2024),
(464, '2024-04-08', 'April', 'Q2', 2024),
(465, '2024-04-09', 'April', 'Q2', 2024),
(466, '2024-04-10', 'April', 'Q2', 2024),
(467, '2024-04-11', 'April', 'Q2', 2024),
(468, '2024-04-12', 'April', 'Q2', 2024),
(469, '2024-04-13', 'April', 'Q2', 2024),
(470, '2024-04-14', 'April', 'Q2', 2024),
(471, '2024-04-15', 'April', 'Q2', 2024),
(472, '2024-04-16', 'April', 'Q2', 2024),
(473, '2024-04-17', 'April', 'Q2', 2024),
(474, '2024-04-18', 'April', 'Q2', 2024),
(475, '2024-04-19', 'April', 'Q2', 2024),
(476, '2024-04-20', 'April', 'Q2', 2024),
(477, '2024-04-21', 'April', 'Q2', 2024),
(478, '2024-04-22', 'April', 'Q2', 2024),
(479, '2024-04-23', 'April', 'Q2', 2024),
(480, '2024-04-24', 'April', 'Q2', 2024),
(481, '2024-04-25', 'April', 'Q2', 2024),
(482, '2024-04-26', 'April', 'Q2', 2024),
(483, '2024-04-27', 'April', 'Q2', 2024),
(484, '2024-04-28', 'April', 'Q2', 2024),
(485, '2024-04-29', 'April', 'Q2', 2024),
(486, '2024-04-30', 'April', 'Q2', 2024),
(487, '2024-05-01', 'May', 'Q2', 2024),
(488, '2024-05-02', 'May', 'Q2', 2024),
(489, '2024-05-03', 'May', 'Q2', 2024),
(490, '2024-05-04', 'May', 'Q2', 2024),
(491, '2024-05-05', 'May', 'Q2', 2024),
(492, '2024-05-06', 'May', 'Q2', 2024),
(493, '2024-05-07', 'May', 'Q2', 2024),
(494, '2024-05-08', 'May', 'Q2', 2024),
(495, '2024-05-09', 'May', 'Q2', 2024),
(496, '2024-05-10', 'May', 'Q2', 2024),
(497, '2024-05-11', 'May', 'Q2', 2024),
(498, '2024-05-12', 'May', 'Q2', 2024),
(499, '2024-05-13', 'May', 'Q2', 2024),
(500, '2024-05-14', 'May', 'Q2', 2024);
GO



INSERT INTO DateDim (DateID, ActualDate, Month, Quarter, Year)
VALUES
(501, '2024-05-15', 'May', 'Q2', 2024),
(502, '2024-05-16', 'May', 'Q2', 2024),
(503, '2024-05-17', 'May', 'Q2', 2024),
(504, '2024-05-18', 'May', 'Q2', 2024),
(505, '2024-05-19', 'May', 'Q2', 2024),
(506, '2024-05-20', 'May', 'Q2', 2024),
(507, '2024-05-21', 'May', 'Q2', 2024),
(508, '2024-05-22', 'May', 'Q2', 2024),
(509, '2024-05-23', 'May', 'Q2', 2024),
(510, '2024-05-24', 'May', 'Q2', 2024),
(511, '2024-05-25', 'May', 'Q2', 2024),
(512, '2024-05-26', 'May', 'Q2', 2024),
(513, '2024-05-27', 'May', 'Q2', 2024),
(514, '2024-05-28', 'May', 'Q2', 2024),
(515, '2024-05-29', 'May', 'Q2', 2024),
(516, '2024-05-30', 'May', 'Q2', 2024),
(517, '2024-05-31', 'May', 'Q2', 2024),
(518, '2024-06-01', 'June', 'Q2', 2024),
(519, '2024-06-02', 'June', 'Q2', 2024),
(520, '2024-06-03', 'June', 'Q2', 2024),
(521, '2024-06-04', 'June', 'Q2', 2024),
(522, '2024-06-05', 'June', 'Q2', 2024),
(523, '2024-06-06', 'June', 'Q2', 2024),
(524, '2024-06-07', 'June', 'Q2', 2024),
(525, '2024-06-08', 'June', 'Q2', 2024),
(526, '2024-06-09', 'June', 'Q2', 2024),
(527, '2024-06-10', 'June', 'Q2', 2024),
(528, '2024-06-11', 'June', 'Q2', 2024),
(529, '2024-06-12', 'June', 'Q2', 2024),
(530, '2024-06-13', 'June', 'Q2', 2024),
(531, '2024-06-14', 'June', 'Q2', 2024),
(532, '2024-06-15', 'June', 'Q2', 2024),
(533, '2024-06-16', 'June', 'Q2', 2024),
(534, '2024-06-17', 'June', 'Q2', 2024),
(535, '2024-06-18', 'June', 'Q2', 2024),
(536, '2024-06-19', 'June', 'Q2', 2024),
(537, '2024-06-20', 'June', 'Q2', 2024),
(538, '2024-06-21', 'June', 'Q2', 2024),
(539, '2024-06-22', 'June', 'Q2', 2024),
(540, '2024-06-23', 'June', 'Q2', 2024),
(541, '2024-06-24', 'June', 'Q2', 2024),
(542, '2024-06-25', 'June', 'Q2', 2024),
(543, '2024-06-26', 'June', 'Q2', 2024),
(544, '2024-06-27', 'June', 'Q2', 2024),
(545, '2024-06-28', 'June', 'Q2', 2024),
(546, '2024-06-29', 'June', 'Q2', 2024),
(547, '2024-06-30', 'June', 'Q2', 2024),
(548, '2024-07-01', 'July', 'Q3', 2024),
(549, '2024-07-02', 'July', 'Q3', 2024),
(550, '2024-07-03', 'July', 'Q3', 2024),
(551, '2024-07-04', 'July', 'Q3', 2024),
(552, '2024-07-05', 'July', 'Q3', 2024),
(553, '2024-07-06', 'July', 'Q3', 2024),
(554, '2024-07-07', 'July', 'Q3', 2024),
(555, '2024-07-08', 'July', 'Q3', 2024),
(556, '2024-07-09', 'July', 'Q3', 2024),
(557, '2024-07-10', 'July', 'Q3', 2024),
(558, '2024-07-11', 'July', 'Q3', 2024),
(559, '2024-07-12', 'July', 'Q3', 2024),
(560, '2024-07-13', 'July', 'Q3', 2024),
(561, '2024-07-14', 'July', 'Q3', 2024),
(562, '2024-07-15', 'July', 'Q3', 2024),
(563, '2024-07-16', 'July', 'Q3', 2024),
(564, '2024-07-17', 'July', 'Q3', 2024),
(565, '2024-07-18', 'July', 'Q3', 2024),
(566, '2024-07-19', 'July', 'Q3', 2024),
(567, '2024-07-20', 'July', 'Q3', 2024),
(568, '2024-07-21', 'July', 'Q3', 2024),
(569, '2024-07-22', 'July', 'Q3', 2024),
(570, '2024-07-23', 'July', 'Q3', 2024),
(571, '2024-07-24', 'July', 'Q3', 2024),
(572, '2024-07-25', 'July', 'Q3', 2024),
(573, '2024-07-26', 'July', 'Q3', 2024),
(574, '2024-07-27', 'July', 'Q3', 2024),
(575, '2024-07-28', 'July', 'Q3', 2024),
(576, '2024-07-29', 'July', 'Q3', 2024),
(577, '2024-07-30', 'July', 'Q3', 2024),
(578, '2024-07-31', 'July', 'Q3', 2024),
(579, '2024-08-01', 'August', 'Q3', 2024),
(580, '2024-08-02', 'August', 'Q3', 2024),
(581, '2024-08-03', 'August', 'Q3', 2024),
(582, '2024-08-04', 'August', 'Q3', 2024),
(583, '2024-08-05', 'August', 'Q3', 2024),
(584, '2024-08-06', 'August', 'Q3', 2024),
(585, '2024-08-07', 'August', 'Q3', 2024),
(586, '2024-08-08', 'August', 'Q3', 2024),
(587, '2024-08-09', 'August', 'Q3', 2024),
(588, '2024-08-10', 'August', 'Q3', 2024),
(589, '2024-08-11', 'August', 'Q3', 2024),
(590, '2024-08-12', 'August', 'Q3', 2024),
(591, '2024-08-13', 'August', 'Q3', 2024),
(592, '2024-08-14', 'August', 'Q3', 2024),
(593, '2024-08-15', 'August', 'Q3', 2024),
(594, '2024-08-16', 'August', 'Q3', 2024),
(595, '2024-08-17', 'August', 'Q3', 2024),
(596, '2024-08-18', 'August', 'Q3', 2024),
(597, '2024-08-19', 'August', 'Q3', 2024),
(598, '2024-08-20', 'August', 'Q3', 2024),
(599, '2024-08-21', 'August', 'Q3', 2024),
(600, '2024-08-22', 'August', 'Q3', 2024);
GO



INSERT INTO DateDim (DateID, ActualDate, Month, Quarter, Year)
VALUES
(601, '2024-08-23', 'August', 'Q3', 2024),
(602, '2024-08-24', 'August', 'Q3', 2024),
(603, '2024-08-25', 'August', 'Q3', 2024),
(604, '2024-08-26', 'August', 'Q3', 2024),
(605, '2024-08-27', 'August', 'Q3', 2024),
(606, '2024-08-28', 'August', 'Q3', 2024),
(607, '2024-08-29', 'August', 'Q3', 2024),
(608, '2024-08-30', 'August', 'Q3', 2024),
(609, '2024-08-31', 'August', 'Q3', 2024),
(610, '2024-09-01', 'September', 'Q3', 2024),
(611, '2024-09-02', 'September', 'Q3', 2024),
(612, '2024-09-03', 'September', 'Q3', 2024),
(613, '2024-09-04', 'September', 'Q3', 2024),
(614, '2024-09-05', 'September', 'Q3', 2024),
(615, '2024-09-06', 'September', 'Q3', 2024),
(616, '2024-09-07', 'September', 'Q3', 2024),
(617, '2024-09-08', 'September', 'Q3', 2024),
(618, '2024-09-09', 'September', 'Q3', 2024),
(619, '2024-09-10', 'September', 'Q3', 2024),
(620, '2024-09-11', 'September', 'Q3', 2024),
(621, '2024-09-12', 'September', 'Q3', 2024),
(622, '2024-09-13', 'September', 'Q3', 2024),
(623, '2024-09-14', 'September', 'Q3', 2024),
(624, '2024-09-15', 'September', 'Q3', 2024),
(625, '2024-09-16', 'September', 'Q3', 2024),
(626, '2024-09-17', 'September', 'Q3', 2024),
(627, '2024-09-18', 'September', 'Q3', 2024),
(628, '2024-09-19', 'September', 'Q3', 2024),
(629, '2024-09-20', 'September', 'Q3', 2024),
(630, '2024-09-21', 'September', 'Q3', 2024),
(631, '2024-09-22', 'September', 'Q3', 2024),
(632, '2024-09-23', 'September', 'Q3', 2024),
(633, '2024-09-24', 'September', 'Q3', 2024),
(634, '2024-09-25', 'September', 'Q3', 2024),
(635, '2024-09-26', 'September', 'Q3', 2024),
(636, '2024-09-27', 'September', 'Q3', 2024),
(637, '2024-09-28', 'September', 'Q3', 2024),
(638, '2024-09-29', 'September', 'Q3', 2024),
(639, '2024-09-30', 'September', 'Q3', 2024),
(640, '2024-10-01', 'October', 'Q4', 2024),
(641, '2024-10-02', 'October', 'Q4', 2024),
(642, '2024-10-03', 'October', 'Q4', 2024),
(643, '2024-10-04', 'October', 'Q4', 2024),
(644, '2024-10-05', 'October', 'Q4', 2024),
(645, '2024-10-06', 'October', 'Q4', 2024),
(646, '2024-10-07', 'October', 'Q4', 2024),
(647, '2024-10-08', 'October', 'Q4', 2024),
(648, '2024-10-09', 'October', 'Q4', 2024),
(649, '2024-10-10', 'October', 'Q4', 2024),
(650, '2024-10-11', 'October', 'Q4', 2024),
(651, '2024-10-12', 'October', 'Q4', 2024),
(652, '2024-10-13', 'October', 'Q4', 2024),
(653, '2024-10-14', 'October', 'Q4', 2024),
(654, '2024-10-15', 'October', 'Q4', 2024),
(655, '2024-10-16', 'October', 'Q4', 2024),
(656, '2024-10-17', 'October', 'Q4', 2024),
(657, '2024-10-18', 'October', 'Q4', 2024),
(658, '2024-10-19', 'October', 'Q4', 2024),
(659, '2024-10-20', 'October', 'Q4', 2024),
(660, '2024-10-21', 'October', 'Q4', 2024),
(661, '2024-10-22', 'October', 'Q4', 2024),
(662, '2024-10-23', 'October', 'Q4', 2024),
(663, '2024-10-24', 'October', 'Q4', 2024),
(664, '2024-10-25', 'October', 'Q4', 2024),
(665, '2024-10-26', 'October', 'Q4', 2024),
(666, '2024-10-27', 'October', 'Q4', 2024),
(667, '2024-10-28', 'October', 'Q4', 2024),
(668, '2024-10-29', 'October', 'Q4', 2024),
(669, '2024-10-30', 'October', 'Q4', 2024),
(670, '2024-10-31', 'October', 'Q4', 2024),
(671, '2024-11-01', 'November', 'Q4', 2024),
(672, '2024-11-02', 'November', 'Q4', 2024),
(673, '2024-11-03', 'November', 'Q4', 2024),
(674, '2024-11-04', 'November', 'Q4', 2024),
(675, '2024-11-05', 'November', 'Q4', 2024),
(676, '2024-11-06', 'November', 'Q4', 2024),
(677, '2024-11-07', 'November', 'Q4', 2024),
(678, '2024-11-08', 'November', 'Q4', 2024),
(679, '2024-11-09', 'November', 'Q4', 2024),
(680, '2024-11-10', 'November', 'Q4', 2024),
(681, '2024-11-11', 'November', 'Q4', 2024),
(682, '2024-11-12', 'November', 'Q4', 2024),
(683, '2024-11-13', 'November', 'Q4', 2024),
(684, '2024-11-14', 'November', 'Q4', 2024),
(685, '2024-11-15', 'November', 'Q4', 2024),
(686, '2024-11-16', 'November', 'Q4', 2024),
(687, '2024-11-17', 'November', 'Q4', 2024),
(688, '2024-11-18', 'November', 'Q4', 2024),
(689, '2024-11-19', 'November', 'Q4', 2024),
(690, '2024-11-20', 'November', 'Q4', 2024),
(691, '2024-11-21', 'November', 'Q4', 2024),
(692, '2024-11-22', 'November', 'Q4', 2024),
(693, '2024-11-23', 'November', 'Q4', 2024),
(694, '2024-11-24', 'November', 'Q4', 2024),
(695, '2024-11-25', 'November', 'Q4', 2024),
(696, '2024-11-26', 'November', 'Q4', 2024),
(697, '2024-11-27', 'November', 'Q4', 2024),
(698, '2024-11-28', 'November', 'Q4', 2024),
(699, '2024-11-29', 'November', 'Q4', 2024),
(700, '2024-11-30', 'November', 'Q4', 2024);
GO




INSERT INTO DateDim (DateID, ActualDate, Month, Quarter, Year)
VALUES
(701, '2024-12-01', 'December', 'Q4', 2024),
(702, '2024-12-02', 'December', 'Q4', 2024),
(703, '2024-12-03', 'December', 'Q4', 2024),
(704, '2024-12-04', 'December', 'Q4', 2024),
(705, '2024-12-05', 'December', 'Q4', 2024),
(706, '2024-12-06', 'December', 'Q4', 2024),
(707, '2024-12-07', 'December', 'Q4', 2024),
(708, '2024-12-08', 'December', 'Q4', 2024),
(709, '2024-12-09', 'December', 'Q4', 2024),
(710, '2024-12-10', 'December', 'Q4', 2024),
(711, '2024-12-11', 'December', 'Q4', 2024),
(712, '2024-12-12', 'December', 'Q4', 2024),
(713, '2024-12-13', 'December', 'Q4', 2024),
(714, '2024-12-14', 'December', 'Q4', 2024),
(715, '2024-12-15', 'December', 'Q4', 2024),
(716, '2024-12-16', 'December', 'Q4', 2024),
(717, '2024-12-17', 'December', 'Q4', 2024),
(718, '2024-12-18', 'December', 'Q4', 2024),
(719, '2024-12-19', 'December', 'Q4', 2024),
(720, '2024-12-20', 'December', 'Q4', 2024),
(721, '2024-12-21', 'December', 'Q4', 2024),
(722, '2024-12-22', 'December', 'Q4', 2024),
(723, '2024-12-23', 'December', 'Q4', 2024),
(724, '2024-12-24', 'December', 'Q4', 2024),
(725, '2024-12-25', 'December', 'Q4', 2024),
(726, '2024-12-26', 'December', 'Q4', 2024),
(727, '2024-12-27', 'December', 'Q4', 2024),
(728, '2024-12-28', 'December', 'Q4', 2024),
(729, '2024-12-29', 'December', 'Q4', 2024),
(730, '2024-12-30', 'December', 'Q4', 2024);
GO



SET IDENTITY_INSERT StoreLicenseDim ON;
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (1, 'Retail License', '2022-01-02', '2025-01-02', '2022-01-02', '2025-01-02', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (2, 'Wholesale License', '2022-01-03', '2025-01-03', '2022-01-03', '2025-01-03', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (3, 'Retail License', '2022-01-04', '2025-01-04', '2022-01-04', '2025-01-04', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (4, 'Wholesale License', '2022-01-05', '2025-01-05', '2022-01-05', '2025-01-05', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (5, 'Retail License', '2022-01-06', '2025-01-06', '2022-01-06', '2025-01-06', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (6, 'Wholesale License', '2022-01-07', '2025-01-07', '2022-01-07', '2025-01-07', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (7, 'Retail License', '2022-01-08', '2025-01-08', '2022-01-08', '2025-01-08', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (8, 'Wholesale License', '2022-01-09', '2025-01-09', '2022-01-09', '2025-01-09', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (9, 'Retail License', '2022-01-10', '2025-01-10', '2022-01-10', '2025-01-10', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (10, 'Wholesale License', '2022-01-11', '2025-01-11', '2022-01-11', '2025-01-11', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (11, 'Retail License', '2022-01-12', '2025-01-12', '2022-01-12', '2025-01-12', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (12, 'Wholesale License', '2022-01-13', '2025-01-13', '2022-01-13', '2025-01-13', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (13, 'Retail License', '2022-01-14', '2025-01-14', '2022-01-14', '2025-01-14', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (14, 'Wholesale License', '2022-01-15', '2025-01-15', '2022-01-15', '2025-01-15', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (15, 'Retail License', '2022-01-16', '2025-01-16', '2022-01-16', '2025-01-16', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (16, 'Wholesale License', '2022-01-17', '2025-01-17', '2022-01-17', '2025-01-17', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (17, 'Retail License', '2022-01-18', '2025-01-18', '2022-01-18', '2025-01-18', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (18, 'Wholesale License', '2022-01-19', '2025-01-19', '2022-01-19', '2025-01-19', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (19, 'Retail License', '2022-01-20', '2025-01-20', '2022-01-20', '2025-01-20', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (20, 'Wholesale License', '2022-01-21', '2025-01-21', '2022-01-21', '2025-01-21', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (21, 'Retail License', '2022-01-22', '2025-01-22', '2022-01-22', '2025-01-22', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (22, 'Wholesale License', '2022-01-23', '2025-01-23', '2022-01-23', '2025-01-23', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (23, 'Retail License', '2022-01-24', '2025-01-24', '2022-01-24', '2025-01-24', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (24, 'Wholesale License', '2022-01-25', '2025-01-25', '2022-01-25', '2025-01-25', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (25, 'Retail License', '2022-01-26', '2025-01-26', '2022-01-26', '2025-01-26', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (26, 'Wholesale License', '2022-01-27', '2025-01-27', '2022-01-27', '2025-01-27', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (27, 'Retail License', '2022-01-28', '2025-01-28', '2022-01-28', '2025-01-28', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (28, 'Wholesale License', '2022-01-29', '2025-01-29', '2022-01-29', '2025-01-29', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (29, 'Retail License', '2022-01-30', '2025-01-30', '2022-01-30', '2025-01-30', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (30, 'Wholesale License', '2022-01-31', '2025-01-31', '2022-01-31', '2025-01-31', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (31, 'Retail License', '2022-02-01', '2025-02-01', '2022-02-01', '2025-02-01', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (32, 'Wholesale License', '2022-02-02', '2025-02-02', '2022-02-02', '2025-02-02', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (33, 'Retail License', '2022-02-03', '2025-02-03', '2022-02-03', '2025-02-03', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (34, 'Wholesale License', '2022-02-04', '2025-02-04', '2022-02-04', '2025-02-04', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (35, 'Retail License', '2022-02-05', '2025-02-05', '2022-02-05', '2025-02-05', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (36, 'Wholesale License', '2022-02-06', '2025-02-06', '2022-02-06', '2025-02-06', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (37, 'Retail License', '2022-02-07', '2025-02-07', '2022-02-07', '2025-02-07', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (38, 'Wholesale License', '2022-02-08', '2025-02-08', '2022-02-08', '2025-02-08', 1, 0, 1);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (39, 'Retail License', '2022-02-09', '2025-02-09', '2022-02-09', '2025-02-09', 1, 1, 0);
INSERT INTO StoreLicenseDim (StoreLicenseSK, LicenseType, LicenseIssued, LicenseExpiry, ValidFrom, ValidTo, CurrentFlag, IsRetailStore, IsWholesaleStore) VALUES (40, 'Wholesale License', '2022-02-10', '2025-02-10', '2022-02-10', '2025-02-10', 1, 0, 1);
SET IDENTITY_INSERT StoreLicenseDim OFF;
GO

INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (1, 'Amul Store 1', 'Delhi', 'State2', 'India', 1);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (2, 'Amul Store 2', 'Mumbai', 'State3', 'India', 2);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (3, 'Amul Store 3', 'Surat', 'State4', 'India', 3);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (4, 'Amul Store 4', 'Ahmedabad', 'State5', 'India', 4);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (5, 'Amul Store 5', 'Ahmedabad', 'State6', 'India', 5);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (6, 'Amul Store 6', 'Pune', 'State7', 'India', 6);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (7, 'Amul Store 7', 'Delhi', 'State8', 'India', 7);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (8, 'Amul Store 8', 'Delhi', 'State9', 'India', 8);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (9, 'Amul Store 9', 'Hyderabad', 'State10', 'India', 9);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (10, 'Amul Store 10', 'Mumbai', 'State1', 'India', 10);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (11, 'Amul Store 11', 'Mumbai', 'State2', 'India', 11);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (12, 'Amul Store 12', 'Delhi', 'State3', 'India', 12);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (13, 'Amul Store 13', 'Ahmedabad', 'State4', 'India', 13);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (14, 'Amul Store 14', 'Ahmedabad', 'State5', 'India', 14);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (15, 'Amul Store 15', 'Mumbai', 'State6', 'India', 15);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (16, 'Amul Store 16', 'Ahmedabad', 'State7', 'India', 16);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (17, 'Amul Store 17', 'Hyderabad', 'State8', 'India', 17);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (18, 'Amul Store 18', 'Ahmedabad', 'State9', 'India', 18);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (19, 'Amul Store 19', 'Chennai', 'State10', 'India', 19);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (20, 'Amul Store 20', 'Surat', 'State1', 'India', 20);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (21, 'Amul Store 21', 'Mumbai', 'State2', 'India', 21);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (22, 'Amul Store 22', 'Pune', 'State3', 'India', 22);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (23, 'Amul Store 23', 'Hyderabad', 'State4', 'India', 23);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (24, 'Amul Store 24', 'Bangalore', 'State5', 'India', 24);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (25, 'Amul Store 25', 'Surat', 'State6', 'India', 25);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (26, 'Amul Store 26', 'Pune', 'State7', 'India', 26);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (27, 'Amul Store 27', 'Ahmedabad', 'State8', 'India', 27);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (28, 'Amul Store 28', 'Bangalore', 'State9', 'India', 28);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (29, 'Amul Store 29', 'Delhi', 'State10', 'India', 29);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (30, 'Amul Store 30', 'Delhi', 'State1', 'India', 30);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (31, 'Amul Store 31', 'Hyderabad', 'State2', 'India', 31);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (32, 'Amul Store 32', 'Delhi', 'State3', 'India', 32);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (33, 'Amul Store 33', 'Bangalore', 'State4', 'India', 33);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (34, 'Amul Store 34', 'Bangalore', 'State5', 'India', 34);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (35, 'Amul Store 35', 'Surat', 'State6', 'India', 35);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (36, 'Amul Store 36', 'Mumbai', 'State7', 'India', 36);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (37, 'Amul Store 37', 'Chennai', 'State8', 'India', 37);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (38, 'Amul Store 38', 'Delhi', 'State9', 'India', 38);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (39, 'Amul Store 39', 'Hyderabad', 'State10', 'India', 39);
INSERT INTO StoreDim (StoreID, StoreName, City, State, Country, StoreLicenseSK) VALUES (40, 'Amul Store 40', 'Delhi', 'State1', 'India', 40);
GO

INSERT INTO WarehouseDim (WarehouseID, WarehouseName, City, State, Country, StorageCapacity) VALUES (1, 'Warehouse 1', 'Surat', 'State2', 'India', 4488.21);
INSERT INTO WarehouseDim (WarehouseID, WarehouseName, City, State, Country, StorageCapacity) VALUES (2, 'Warehouse 2', 'Bangalore', 'State3', 'India', 3732.06);
INSERT INTO WarehouseDim (WarehouseID, WarehouseName, City, State, Country, StorageCapacity) VALUES (3, 'Warehouse 3', 'Delhi', 'State4', 'India', 2137.47);
INSERT INTO WarehouseDim (WarehouseID, WarehouseName, City, State, Country, StorageCapacity) VALUES (4, 'Warehouse 4', 'Ahmedabad', 'State5', 'India', 4319.21);
INSERT INTO WarehouseDim (WarehouseID, WarehouseName, City, State, Country, StorageCapacity) VALUES (5, 'Warehouse 5', 'Delhi', 'State6', 'India', 4565.95);
INSERT INTO WarehouseDim (WarehouseID, WarehouseName, City, State, Country, StorageCapacity) VALUES (6, 'Warehouse 6', 'Delhi', 'State7', 'India', 3140.38);
INSERT INTO WarehouseDim (WarehouseID, WarehouseName, City, State, Country, StorageCapacity) VALUES (7, 'Warehouse 7', 'Chennai', 'State8', 'India', 3907.05);
INSERT INTO WarehouseDim (WarehouseID, WarehouseName, City, State, Country, StorageCapacity) VALUES (8, 'Warehouse 8', 'Bangalore', 'State9', 'India', 2487.96);
INSERT INTO WarehouseDim (WarehouseID, WarehouseName, City, State, Country, StorageCapacity) VALUES (9, 'Warehouse 9', 'Bangalore', 'State10', 'India', 2628.52);
INSERT INTO WarehouseDim (WarehouseID, WarehouseName, City, State, Country, StorageCapacity) VALUES (10, 'Warehouse 10', 'Surat', 'State1', 'India', 4105.46);
GO

SET IDENTITY_INSERT JunkDim ON;
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (1, 0, 0, 0, 0);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (2, 1, 1, 1, 0);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (3, 1, 0, 0, 0);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (4, 1, 1, 1, 0);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (5, 0, 1, 0, 1);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (6, 1, 1, 0, 1);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (7, 0, 0, 1, 1);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (8, 1, 1, 0, 0);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (9, 1, 0, 0, 0);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (10, 0, 0, 1, 0);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (11, 1, 1, 1, 1);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (12, 0, 0, 1, 1);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (13, 0, 1, 1, 0);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (14, 1, 0, 1, 0);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (15, 0, 1, 0, 0);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (16, 1, 0, 0, 1);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (17, 1, 0, 0, 1);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (18, 1, 0, 0, 0);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (19, 0, 0, 1, 0);
INSERT INTO JunkDim (JunkID, IsPromotional, IsOnline, IsReturnable, IsClearance) VALUES (20, 0, 0, 1, 0);
SET IDENTITY_INSERT JunkDim OFF;
GO

INSERT INTO PaymentDim (PaymentID, PaymentMethod) VALUES (1, 'Cash');
INSERT INTO PaymentDim (PaymentID, PaymentMethod) VALUES (2, 'Credit');
INSERT INTO PaymentDim (PaymentID, PaymentMethod) VALUES (3, 'UPI');
INSERT INTO PaymentDim (PaymentID, PaymentMethod) VALUES (4, 'Net Banking');
INSERT INTO PaymentDim (PaymentID, PaymentMethod) VALUES (5, 'Card');
GO

INSERT INTO ReasonDim (ReasonID, Reason) VALUES (1, 'Damaged Packaging');
INSERT INTO ReasonDim (ReasonID, Reason) VALUES (2, 'Spoiled Product');
INSERT INTO ReasonDim (ReasonID, Reason) VALUES (3, 'Expired');
INSERT INTO ReasonDim (ReasonID, Reason) VALUES (4, 'Wrong Item');
INSERT INTO ReasonDim (ReasonID, Reason) VALUES (5, 'Customer Complaint');
INSERT INTO ReasonDim (ReasonID, Reason) VALUES (6, 'Defective');
INSERT INTO ReasonDim (ReasonID, Reason) VALUES (7, 'Leaked');
INSERT INTO ReasonDim (ReasonID, Reason) VALUES (8, 'Unsealed');
INSERT INTO ReasonDim (ReasonID, Reason) VALUES (9, 'Mismatch');
INSERT INTO ReasonDim (ReasonID, Reason) VALUES (10, 'Others');
GO











INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (1, 'Supplier 1', 'Surat', 'State2', 'India', '9666585408');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (2, 'Supplier 2', 'Hyderabad', 'State3', 'India', '9327416584');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (3, 'Supplier 3', 'Ahmedabad', 'State4', 'India', '9865523129');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (4, 'Supplier 4', 'Surat', 'State5', 'India', '9528414718');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (5, 'Supplier 5', 'Bangalore', 'State6', 'India', '9570406376');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (6, 'Supplier 6', 'Chennai', 'State7', 'India', '9229927269');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (7, 'Supplier 7', 'Ahmedabad', 'State8', 'India', '9341266931');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (8, 'Supplier 8', 'Delhi', 'State9', 'India', '9463016614');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (9, 'Supplier 9', 'Mumbai', 'State10', 'India', '9731691672');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (10, 'Supplier 10', 'Ahmedabad', 'State1', 'India', '9731832764');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (11, 'Supplier 11', 'Ahmedabad', 'State2', 'India', '9107721109');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (12, 'Supplier 12', 'Delhi', 'State3', 'India', '9860038427');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (13, 'Supplier 13', 'Mumbai', 'State4', 'India', '9345824373');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (14, 'Supplier 14', 'Delhi', 'State5', 'India', '9133729406');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (15, 'Supplier 15', 'Bangalore', 'State6', 'India', '9176082500');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (16, 'Supplier 16', 'Ahmedabad', 'State7', 'India', '9399012686');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (17, 'Supplier 17', 'Chennai', 'State8', 'India', '9330035022');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (18, 'Supplier 18', 'Pune', 'State9', 'India', '9876693898');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (19, 'Supplier 19', 'Chennai', 'State10', 'India', '9360916298');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (20, 'Supplier 20', 'Chennai', 'State1', 'India', '9967043303');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (21, 'Supplier 21', 'Hyderabad', 'State2', 'India', '9304451095');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (22, 'Supplier 22', 'Delhi', 'State3', 'India', '9204078666');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (23, 'Supplier 23', 'Hyderabad', 'State4', 'India', '9480424119');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (24, 'Supplier 24', 'Hyderabad', 'State5', 'India', '9541417711');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (25, 'Supplier 25', 'Chennai', 'State6', 'India', '9882839238');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (26, 'Supplier 26', 'Mumbai', 'State7', 'India', '9823019672');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (27, 'Supplier 27', 'Delhi', 'State8', 'India', '9165082363');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (28, 'Supplier 28', 'Hyderabad', 'State9', 'India', '9881913386');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (29, 'Supplier 29', 'Bangalore', 'State10', 'India', '9959629660');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (30, 'Supplier 30', 'Delhi', 'State1', 'India', '9366992705');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (31, 'Supplier 31', 'Ahmedabad', 'State2', 'India', '9304235259');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (32, 'Supplier 32', 'Chennai', 'State3', 'India', '9250519597');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (33, 'Supplier 33', 'Hyderabad', 'State4', 'India', '9297018781');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (34, 'Supplier 34', 'Surat', 'State5', 'India', '9596743109');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (35, 'Supplier 35', 'Ahmedabad', 'State6', 'India', '9180943908');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (36, 'Supplier 36', 'Chennai', 'State7', 'India', '9967607278');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (37, 'Supplier 37', 'Delhi', 'State8', 'India', '9154318806');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (38, 'Supplier 38', 'Mumbai', 'State9', 'India', '9200140141');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (39, 'Supplier 39', 'Ahmedabad', 'State10', 'India', '9278575192');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (40, 'Supplier 40', 'Hyderabad', 'State1', 'India', '9621453189');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (41, 'Supplier 41', 'Chennai', 'State2', 'India', '9329509408');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (42, 'Supplier 42', 'Hyderabad', 'State3', 'India', '9162959284');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (43, 'Supplier 43', 'Pune', 'State4', 'India', '9506919288');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (44, 'Supplier 44', 'Mumbai', 'State5', 'India', '9519212169');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (45, 'Supplier 45', 'Surat', 'State6', 'India', '9941889393');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (46, 'Supplier 46', 'Chennai', 'State7', 'India', '9406284028');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (47, 'Supplier 47', 'Hyderabad', 'State8', 'India', '9847959430');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (48, 'Supplier 48', 'Chennai', 'State9', 'India', '9266211829');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (49, 'Supplier 49', 'Ahmedabad', 'State10', 'India', '9418587604');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (50, 'Supplier 50', 'Ahmedabad', 'State1', 'India', '9162795957');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (51, 'Supplier 51', 'Mumbai', 'State2', 'India', '9903132646');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (52, 'Supplier 52', 'Bangalore', 'State3', 'India', '9161380746');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (53, 'Supplier 53', 'Mumbai', 'State4', 'India', '9727255918');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (54, 'Supplier 54', 'Chennai', 'State5', 'India', '9639931481');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (55, 'Supplier 55', 'Pune', 'State6', 'India', '9161073976');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (56, 'Supplier 56', 'Delhi', 'State7', 'India', '9299528037');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (57, 'Supplier 57', 'Delhi', 'State8', 'India', '9738914080');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (58, 'Supplier 58', 'Delhi', 'State9', 'India', '9825003955');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (59, 'Supplier 59', 'Ahmedabad', 'State10', 'India', '9533550699');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (60, 'Supplier 60', 'Delhi', 'State1', 'India', '9711684318');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (61, 'Supplier 61', 'Ahmedabad', 'State2', 'India', '9721609600');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (62, 'Supplier 62', 'Mumbai', 'State3', 'India', '9765055833');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (63, 'Supplier 63', 'Delhi', 'State4', 'India', '9550139320');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (64, 'Supplier 64', 'Bangalore', 'State5', 'India', '9379995032');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (65, 'Supplier 65', 'Ahmedabad', 'State6', 'India', '9819112790');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (66, 'Supplier 66', 'Bangalore', 'State7', 'India', '9356287095');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (67, 'Supplier 67', 'Surat', 'State8', 'India', '9524971817');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (68, 'Supplier 68', 'Pune', 'State9', 'India', '9821221887');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (69, 'Supplier 69', 'Surat', 'State10', 'India', '9590941149');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (70, 'Supplier 70', 'Bangalore', 'State1', 'India', '9907308348');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (71, 'Supplier 71', 'Delhi', 'State2', 'India', '9110002396');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (72, 'Supplier 72', 'Chennai', 'State3', 'India', '9766964667');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (73, 'Supplier 73', 'Delhi', 'State4', 'India', '9178663096');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (74, 'Supplier 74', 'Ahmedabad', 'State5', 'India', '9643189555');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (75, 'Supplier 75', 'Surat', 'State6', 'India', '9242224154');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (76, 'Supplier 76', 'Bangalore', 'State7', 'India', '9173864104');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (77, 'Supplier 77', 'Ahmedabad', 'State8', 'India', '9496776692');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (78, 'Supplier 78', 'Surat', 'State9', 'India', '9269379374');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (79, 'Supplier 79', 'Chennai', 'State10', 'India', '9995226828');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (80, 'Supplier 80', 'Surat', 'State1', 'India', '9756783995');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (81, 'Supplier 81', 'Mumbai', 'State2', 'India', '9817112652');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (82, 'Supplier 82', 'Surat', 'State3', 'India', '9812308209');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (83, 'Supplier 83', 'Delhi', 'State4', 'India', '9244193987');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (84, 'Supplier 84', 'Surat', 'State5', 'India', '9223940587');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (85, 'Supplier 85', 'Delhi', 'State6', 'India', '9897163846');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (86, 'Supplier 86', 'Pune', 'State7', 'India', '9392431670');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (87, 'Supplier 87', 'Surat', 'State8', 'India', '9749431082');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (88, 'Supplier 88', 'Ahmedabad', 'State9', 'India', '9870530217');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (89, 'Supplier 89', 'Bangalore', 'State10', 'India', '9318610946');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (90, 'Supplier 90', 'Surat', 'State1', 'India', '9642678844');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (91, 'Supplier 91', 'Chennai', 'State2', 'India', '9369639388');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (92, 'Supplier 92', 'Mumbai', 'State3', 'India', '9199104722');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (93, 'Supplier 93', 'Hyderabad', 'State4', 'India', '9990505735');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (94, 'Supplier 94', 'Surat', 'State5', 'India', '9147337803');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (95, 'Supplier 95', 'Mumbai', 'State6', 'India', '9458153605');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (96, 'Supplier 96', 'Pune', 'State7', 'India', '9784095277');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (97, 'Supplier 97', 'Surat', 'State8', 'India', '9273497327');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (98, 'Supplier 98', 'Chennai', 'State9', 'India', '9692362342');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (99, 'Supplier 99', 'Hyderabad', 'State10', 'India', '9702269164');
INSERT INTO SupplierDim (SupplierID, SupplierName, City, State, Country, ContactNumber) VALUES (100, 'Supplier 100', 'Mumbai', 'State1', 'India', '9220123666');
GO

INSERT INTO FactoryDim (FactoryID, FactoryName, City, State, Country) VALUES (1, 'Factory 1', 'Delhi', 'State2', 'India');
INSERT INTO FactoryDim (FactoryID, FactoryName, City, State, Country) VALUES (2, 'Factory 2', 'Pune', 'State3', 'India');
INSERT INTO FactoryDim (FactoryID, FactoryName, City, State, Country) VALUES (3, 'Factory 3', 'Mumbai', 'State4', 'India');
INSERT INTO FactoryDim (FactoryID, FactoryName, City, State, Country) VALUES (4, 'Factory 4', 'Bangalore', 'State5', 'India');
INSERT INTO FactoryDim (FactoryID, FactoryName, City, State, Country) VALUES (5, 'Factory 5', 'Pune', 'State6', 'India');
INSERT INTO FactoryDim (FactoryID, FactoryName, City, State, Country) VALUES (6, 'Factory 6', 'Hyderabad', 'State7', 'India');
INSERT INTO FactoryDim (FactoryID, FactoryName, City, State, Country) VALUES (7, 'Factory 7', 'Pune', 'State8', 'India');
INSERT INTO FactoryDim (FactoryID, FactoryName, City, State, Country) VALUES (8, 'Factory 8', 'Mumbai', 'State9', 'India');
INSERT INTO FactoryDim (FactoryID, FactoryName, City, State, Country) VALUES (9, 'Factory 9', 'Surat', 'State10', 'India');
INSERT INTO FactoryDim (FactoryID, FactoryName, City, State, Country) VALUES (10, 'Factory 10', 'Bangalore', 'State1', 'India');
GO

SET IDENTITY_INSERT PromoDim ON;
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (1, 'Promo Offer 1');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (2, 'Promo Offer 2');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (3, 'Promo Offer 3');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (4, 'Promo Offer 4');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (5, 'Promo Offer 5');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (6, 'Promo Offer 6');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (7, 'Promo Offer 7');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (8, 'Promo Offer 8');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (9, 'Promo Offer 9');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (10, 'Promo Offer 10');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (11, 'Promo Offer 11');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (12, 'Promo Offer 12');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (13, 'Promo Offer 13');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (14, 'Promo Offer 14');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (15, 'Promo Offer 15');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (16, 'Promo Offer 16');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (17, 'Promo Offer 17');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (18, 'Promo Offer 18');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (19, 'Promo Offer 19');
INSERT INTO PromoDim (PromotionID, PromotionName) VALUES (20, 'Promo Offer 20');
SET IDENTITY_INSERT PromoDim OFF;
GO

INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (101, 2);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (102, 12);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (103, 7);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (104, 8);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (105, 4);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (106, 12);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (107, 18);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (108, 14);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (109, 20);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (110, 5);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (111, 8);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (112, 6);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (113, 6);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (114, 14);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (115, 1);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (116, 6);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (117, 11);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (118, 14);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (119, 8);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (120, 9);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (121, 6);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (122, 4);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (123, 13);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (124, 2);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (125, 16);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (126, 8);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (127, 7);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (128, 15);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (129, 12);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (130, 10);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (131, 8);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (132, 8);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (133, 1);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (134, 7);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (135, 13);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (136, 11);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (137, 9);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (138, 3);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (139, 9);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (140, 12);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (141, 17);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (142, 13);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (143, 18);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (144, 11);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (145, 1);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (146, 4);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (147, 9);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (148, 6);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (149, 19);
INSERT INTO ProductPromoBridge (ProductID, PromotionID) VALUES (150, 9);
GO


SET IDENTITY_INSERT OrderDim ON;
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (1, 'RETURN', 414, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (2, 'BUY', 330, 'CUSTOMER', 338, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (3, 'BUY', 701, 'RETAIL_STORE', NULL, 4);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (4, 'RETURN', 602, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (5, 'BUY', 49, 'CUSTOMER', 156, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (6, 'RETURN', 701, 'CUSTOMER', 498, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (7, 'BUY', 220, 'CUSTOMER', 51, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (8, 'BUY', 209, 'CUSTOMER', 304, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (9, 'BUY', 47, 'CUSTOMER', 196, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (10, 'RETURN', 247, 'CUSTOMER', 388, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (11, 'RETURN', 412, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (12, 'BUY', 433, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (13, 'BUY', 426, 'CUSTOMER', 472, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (14, 'RETURN', 500, 'CUSTOMER', 130, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (15, 'BUY', 132, 'RETAIL_STORE', NULL, 15);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (16, 'BUY', 69, 'RETAIL_STORE', NULL, 12);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (17, 'RETURN', 292, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (18, 'BUY', 405, 'CUSTOMER', 472, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (19, 'BUY', 206, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (20, 'BUY', 235, 'CUSTOMER', 20, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (21, 'BUY', 248, 'CUSTOMER', 224, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (22, 'BUY', 679, 'CUSTOMER', 308, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (23, 'BUY', 583, 'CUSTOMER', 8, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (24, 'RETURN', 180, 'RETAIL_STORE', NULL, 23);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (25, 'BUY', 299, 'CUSTOMER', 309, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (26, 'BUY', 344, 'CUSTOMER', 387, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (27, 'BUY', 617, 'CUSTOMER', 321, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (28, 'BUY', 59, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (29, 'BUY', 634, 'CUSTOMER', 419, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (30, 'BUY', 107, 'CUSTOMER', 401, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (31, 'BUY', 397, 'CUSTOMER', 444, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (32, 'BUY', 578, 'CUSTOMER', 330, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (33, 'BUY', 586, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (34, 'BUY', 700, 'CUSTOMER', 302, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (35, 'BUY', 466, 'CUSTOMER', 325, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (36, 'BUY', 398, 'CUSTOMER', 132, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (37, 'BUY', 308, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (38, 'BUY', 412, 'CUSTOMER', 65, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (39, 'BUY', 472, 'RETAIL_STORE', NULL, 29);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (40, 'BUY', 682, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (41, 'BUY', 730, 'CUSTOMER', 98, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (42, 'BUY', 562, 'RETAIL_STORE', NULL, 27);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (43, 'BUY', 112, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (44, 'BUY', 346, 'CUSTOMER', 333, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (45, 'RETURN', 185, 'RETAIL_STORE', NULL, 29);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (46, 'BUY', 280, 'CUSTOMER', 432, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (47, 'BUY', 155, 'CUSTOMER', 211, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (48, 'RETURN', 499, 'CUSTOMER', 162, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (49, 'BUY', 22, 'CUSTOMER', 5, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (50, 'RETURN', 366, 'RETAIL_STORE', NULL, 13);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (51, 'BUY', 372, 'CUSTOMER', 370, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (52, 'BUY', 297, 'CUSTOMER', 156, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (53, 'BUY', 168, 'CUSTOMER', 213, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (54, 'RETURN', 163, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (55, 'RETURN', 456, 'CUSTOMER', 50, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (56, 'RETURN', 389, 'RETAIL_STORE', NULL, 31);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (57, 'BUY', 452, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (58, 'RETURN', 688, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (59, 'RETURN', 182, 'CUSTOMER', 70, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (60, 'BUY', 650, 'CUSTOMER', 165, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (61, 'BUY', 17, 'RETAIL_STORE', NULL, 40);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (62, 'RETURN', 526, 'CUSTOMER', 144, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (63, 'BUY', 54, 'CUSTOMER', 383, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (64, 'BUY', 346, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (65, 'BUY', 134, 'CUSTOMER', 497, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (66, 'BUY', 205, 'RETAIL_STORE', NULL, 31);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (67, 'BUY', 714, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (68, 'BUY', 136, 'RETAIL_STORE', NULL, 23);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (69, 'BUY', 86, 'RETAIL_STORE', NULL, 29);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (70, 'RETURN', 24, 'CUSTOMER', 466, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (71, 'BUY', 383, 'CUSTOMER', 34, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (72, 'RETURN', 78, 'CUSTOMER', 5, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (73, 'RETURN', 160, 'CUSTOMER', 349, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (74, 'BUY', 722, 'CUSTOMER', 72, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (75, 'BUY', 4, 'CUSTOMER', 222, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (76, 'BUY', 397, 'CUSTOMER', 165, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (77, 'RETURN', 620, 'RETAIL_STORE', NULL, 12);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (78, 'BUY', 82, 'CUSTOMER', 91, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (79, 'BUY', 717, 'CUSTOMER', 64, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (80, 'BUY', 234, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (81, 'BUY', 224, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (82, 'BUY', 289, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (83, 'BUY', 62, 'RETAIL_STORE', NULL, 40);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (84, 'BUY', 327, 'CUSTOMER', 352, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (85, 'BUY', 462, 'RETAIL_STORE', NULL, 23);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (86, 'BUY', 321, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (87, 'BUY', 708, 'CUSTOMER', 181, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (88, 'BUY', 475, 'RETAIL_STORE', NULL, 30);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (89, 'BUY', 430, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (90, 'BUY', 410, 'CUSTOMER', 188, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (91, 'BUY', 155, 'CUSTOMER', 354, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (92, 'BUY', 484, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (93, 'BUY', 163, 'RETAIL_STORE', NULL, 20);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (94, 'BUY', 444, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (95, 'RETURN', 362, 'CUSTOMER', 55, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (96, 'BUY', 145, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (97, 'BUY', 647, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (98, 'BUY', 543, 'CUSTOMER', 145, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (99, 'BUY', 65, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (100, 'BUY', 705, 'RETAIL_STORE', NULL, 15);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (101, 'BUY', 716, 'RETAIL_STORE', NULL, 13);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (102, 'BUY', 726, 'CUSTOMER', 354, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (103, 'BUY', 20, 'RETAIL_STORE', NULL, 21);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (104, 'BUY', 84, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (105, 'BUY', 198, 'RETAIL_STORE', NULL, 18);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (106, 'RETURN', 486, 'CUSTOMER', 127, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (107, 'BUY', 576, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (108, 'RETURN', 662, 'CUSTOMER', 97, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (109, 'BUY', 537, 'CUSTOMER', 460, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (110, 'BUY', 306, 'CUSTOMER', 134, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (111, 'BUY', 668, 'CUSTOMER', 380, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (112, 'BUY', 458, 'CUSTOMER', 371, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (113, 'BUY', 111, 'RETAIL_STORE', NULL, 18);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (114, 'BUY', 292, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (115, 'RETURN', 54, 'CUSTOMER', 495, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (116, 'BUY', 385, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (117, 'BUY', 183, 'RETAIL_STORE', NULL, 21);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (118, 'BUY', 524, 'CUSTOMER', 29, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (119, 'BUY', 144, 'CUSTOMER', 78, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (120, 'BUY', 95, 'CUSTOMER', 437, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (121, 'BUY', 72, 'RETAIL_STORE', NULL, 32);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (122, 'BUY', 712, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (123, 'BUY', 268, 'CUSTOMER', 117, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (124, 'BUY', 54, 'CUSTOMER', 380, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (125, 'BUY', 239, 'CUSTOMER', 79, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (126, 'BUY', 650, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (127, 'BUY', 25, 'RETAIL_STORE', NULL, 27);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (128, 'BUY', 214, 'CUSTOMER', 118, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (129, 'BUY', 522, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (130, 'BUY', 273, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (131, 'BUY', 623, 'CUSTOMER', 132, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (132, 'RETURN', 123, 'RETAIL_STORE', NULL, 19);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (133, 'BUY', 210, 'RETAIL_STORE', NULL, 12);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (134, 'BUY', 211, 'CUSTOMER', 103, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (135, 'BUY', 664, 'CUSTOMER', 371, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (136, 'RETURN', 223, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (137, 'BUY', 342, 'CUSTOMER', 106, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (138, 'BUY', 617, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (139, 'BUY', 80, 'CUSTOMER', 366, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (140, 'RETURN', 12, 'CUSTOMER', 141, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (141, 'BUY', 100, 'CUSTOMER', 28, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (142, 'RETURN', 78, 'RETAIL_STORE', NULL, 18);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (143, 'BUY', 310, 'CUSTOMER', 73, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (144, 'BUY', 488, 'CUSTOMER', 90, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (145, 'BUY', 467, 'CUSTOMER', 496, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (146, 'BUY', 65, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (147, 'BUY', 31, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (148, 'BUY', 591, 'CUSTOMER', 23, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (149, 'BUY', 208, 'RETAIL_STORE', NULL, 18);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (150, 'RETURN', 241, 'CUSTOMER', 404, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (151, 'RETURN', 573, 'RETAIL_STORE', NULL, 32);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (152, 'BUY', 613, 'CUSTOMER', 189, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (153, 'BUY', 565, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (154, 'BUY', 417, 'RETAIL_STORE', NULL, 12);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (155, 'RETURN', 152, 'RETAIL_STORE', NULL, 32);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (156, 'BUY', 141, 'RETAIL_STORE', NULL, 22);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (157, 'BUY', 44, 'CUSTOMER', 176, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (158, 'BUY', 588, 'CUSTOMER', 72, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (159, 'BUY', 115, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (160, 'BUY', 261, 'CUSTOMER', 332, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (161, 'BUY', 501, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (162, 'BUY', 225, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (163, 'BUY', 160, 'RETAIL_STORE', NULL, 13);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (164, 'BUY', 148, 'RETAIL_STORE', NULL, 5);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (165, 'BUY', 555, 'CUSTOMER', 377, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (166, 'BUY', 303, 'CUSTOMER', 62, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (167, 'RETURN', 69, 'CUSTOMER', 130, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (168, 'RETURN', 11, 'RETAIL_STORE', NULL, 39);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (169, 'BUY', 439, 'RETAIL_STORE', NULL, 40);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (170, 'BUY', 512, 'CUSTOMER', 164, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (171, 'BUY', 552, 'RETAIL_STORE', NULL, 7);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (172, 'RETURN', 28, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (173, 'BUY', 487, 'CUSTOMER', 130, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (174, 'BUY', 466, 'CUSTOMER', 195, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (175, 'BUY', 566, 'RETAIL_STORE', NULL, 29);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (176, 'BUY', 701, 'CUSTOMER', 66, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (177, 'BUY', 475, 'CUSTOMER', 141, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (178, 'BUY', 715, 'CUSTOMER', 315, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (179, 'BUY', 41, 'CUSTOMER', 149, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (180, 'BUY', 204, 'CUSTOMER', 247, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (181, 'BUY', 386, 'CUSTOMER', 23, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (182, 'BUY', 235, 'RETAIL_STORE', NULL, 29);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (183, 'BUY', 620, 'CUSTOMER', 339, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (184, 'BUY', 22, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (185, 'BUY', 286, 'CUSTOMER', 224, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (186, 'BUY', 487, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (187, 'BUY', 89, 'CUSTOMER', 343, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (188, 'BUY', 571, 'RETAIL_STORE', NULL, 17);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (189, 'BUY', 574, 'CUSTOMER', 21, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (190, 'BUY', 719, 'CUSTOMER', 201, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (191, 'BUY', 116, 'CUSTOMER', 319, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (192, 'BUY', 328, 'CUSTOMER', 125, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (193, 'BUY', 491, 'RETAIL_STORE', NULL, 14);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (194, 'BUY', 150, 'CUSTOMER', 392, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (195, 'BUY', 490, 'CUSTOMER', 313, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (196, 'BUY', 641, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (197, 'BUY', 44, 'RETAIL_STORE', NULL, 21);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (198, 'BUY', 401, 'RETAIL_STORE', NULL, 29);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (199, 'BUY', 662, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (200, 'BUY', 77, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (201, 'BUY', 722, 'CUSTOMER', 448, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (202, 'BUY', 288, 'RETAIL_STORE', NULL, 30);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (203, 'RETURN', 524, 'RETAIL_STORE', NULL, 32);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (204, 'BUY', 709, 'CUSTOMER', 301, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (205, 'BUY', 278, 'RETAIL_STORE', NULL, 19);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (206, 'RETURN', 246, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (207, 'RETURN', 344, 'CUSTOMER', 316, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (208, 'BUY', 628, 'CUSTOMER', 453, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (209, 'BUY', 730, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (210, 'BUY', 121, 'CUSTOMER', 421, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (211, 'BUY', 188, 'RETAIL_STORE', NULL, 32);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (212, 'BUY', 582, 'RETAIL_STORE', NULL, 30);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (213, 'BUY', 128, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (214, 'BUY', 507, 'RETAIL_STORE', NULL, 30);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (215, 'BUY', 438, 'CUSTOMER', 372, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (216, 'BUY', 321, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (217, 'BUY', 43, 'CUSTOMER', 484, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (218, 'BUY', 131, 'RETAIL_STORE', NULL, 7);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (219, 'RETURN', 11, 'CUSTOMER', 58, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (220, 'BUY', 237, 'CUSTOMER', 113, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (221, 'RETURN', 24, 'CUSTOMER', 334, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (222, 'RETURN', 209, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (223, 'BUY', 498, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (224, 'RETURN', 248, 'CUSTOMER', 236, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (225, 'RETURN', 110, 'RETAIL_STORE', NULL, 1);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (226, 'BUY', 457, 'RETAIL_STORE', NULL, 14);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (227, 'RETURN', 730, 'RETAIL_STORE', NULL, 29);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (228, 'RETURN', 24, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (229, 'BUY', 330, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (230, 'RETURN', 382, 'CUSTOMER', 74, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (231, 'RETURN', 173, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (232, 'BUY', 281, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (233, 'BUY', 25, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (234, 'BUY', 399, 'CUSTOMER', 343, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (235, 'BUY', 457, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (236, 'BUY', 276, 'CUSTOMER', 188, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (237, 'BUY', 38, 'CUSTOMER', 196, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (238, 'BUY', 95, 'CUSTOMER', 366, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (239, 'BUY', 464, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (240, 'BUY', 235, 'CUSTOMER', 210, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (241, 'BUY', 636, 'CUSTOMER', 27, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (242, 'BUY', 172, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (243, 'BUY', 69, 'CUSTOMER', 446, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (244, 'RETURN', 547, 'CUSTOMER', 64, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (245, 'BUY', 547, 'CUSTOMER', 96, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (246, 'BUY', 279, 'CUSTOMER', 313, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (247, 'BUY', 404, 'CUSTOMER', 70, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (248, 'BUY', 248, 'CUSTOMER', 492, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (249, 'BUY', 180, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (250, 'BUY', 69, 'CUSTOMER', 194, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (251, 'BUY', 694, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (252, 'RETURN', 621, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (253, 'BUY', 130, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (254, 'BUY', 306, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (255, 'BUY', 323, 'CUSTOMER', 250, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (256, 'BUY', 461, 'CUSTOMER', 493, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (257, 'BUY', 17, 'CUSTOMER', 117, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (258, 'BUY', 381, 'RETAIL_STORE', NULL, 14);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (259, 'RETURN', 150, 'CUSTOMER', 378, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (260, 'BUY', 477, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (261, 'BUY', 42, 'RETAIL_STORE', NULL, 31);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (262, 'BUY', 519, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (263, 'BUY', 62, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (264, 'BUY', 414, 'RETAIL_STORE', NULL, 22);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (265, 'BUY', 530, 'CUSTOMER', 350, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (266, 'BUY', 527, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (267, 'RETURN', 339, 'RETAIL_STORE', NULL, 29);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (268, 'BUY', 96, 'CUSTOMER', 366, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (269, 'BUY', 311, 'CUSTOMER', 7, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (270, 'BUY', 428, 'CUSTOMER', 460, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (271, 'BUY', 216, 'RETAIL_STORE', NULL, 1);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (272, 'RETURN', 495, 'RETAIL_STORE', NULL, 5);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (273, 'RETURN', 689, 'CUSTOMER', 303, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (274, 'BUY', 632, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (275, 'BUY', 540, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (276, 'BUY', 445, 'CUSTOMER', 248, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (277, 'BUY', 53, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (278, 'RETURN', 225, 'CUSTOMER', 128, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (279, 'BUY', 423, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (280, 'BUY', 167, 'CUSTOMER', 370, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (281, 'RETURN', 447, 'CUSTOMER', 208, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (282, 'BUY', 342, 'CUSTOMER', 190, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (283, 'BUY', 406, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (284, 'BUY', 294, 'CUSTOMER', 125, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (285, 'BUY', 608, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (286, 'BUY', 154, 'CUSTOMER', 327, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (287, 'RETURN', 53, 'CUSTOMER', 2, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (288, 'BUY', 696, 'RETAIL_STORE', NULL, 23);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (289, 'BUY', 339, 'RETAIL_STORE', NULL, 7);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (290, 'BUY', 630, 'CUSTOMER', 1, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (291, 'RETURN', 111, 'RETAIL_STORE', NULL, 18);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (292, 'RETURN', 142, 'RETAIL_STORE', NULL, 5);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (293, 'BUY', 509, 'CUSTOMER', 361, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (294, 'BUY', 681, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (295, 'RETURN', 301, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (296, 'BUY', 247, 'CUSTOMER', 237, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (297, 'BUY', 602, 'CUSTOMER', 499, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (298, 'BUY', 130, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (299, 'BUY', 594, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (300, 'BUY', 727, 'RETAIL_STORE', NULL, 14);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (301, 'BUY', 354, 'CUSTOMER', 34, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (302, 'RETURN', 399, 'RETAIL_STORE', NULL, 12);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (303, 'BUY', 461, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (304, 'RETURN', 8, 'CUSTOMER', 496, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (305, 'BUY', 343, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (306, 'BUY', 285, 'RETAIL_STORE', NULL, 13);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (307, 'BUY', 647, 'CUSTOMER', 185, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (308, 'BUY', 495, 'CUSTOMER', 446, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (309, 'BUY', 544, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (310, 'BUY', 466, 'CUSTOMER', 419, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (311, 'BUY', 19, 'RETAIL_STORE', NULL, 27);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (312, 'RETURN', 475, 'RETAIL_STORE', NULL, 39);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (313, 'RETURN', 461, 'CUSTOMER', 136, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (314, 'BUY', 405, 'RETAIL_STORE', NULL, 17);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (315, 'BUY', 461, 'CUSTOMER', 123, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (316, 'BUY', 281, 'CUSTOMER', 325, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (317, 'BUY', 509, 'CUSTOMER', 348, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (318, 'BUY', 119, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (319, 'BUY', 15, 'CUSTOMER', 401, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (320, 'BUY', 22, 'RETAIL_STORE', NULL, 7);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (321, 'BUY', 688, 'RETAIL_STORE', NULL, 17);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (322, 'BUY', 371, 'CUSTOMER', 50, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (323, 'BUY', 125, 'CUSTOMER', 487, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (324, 'BUY', 184, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (325, 'BUY', 524, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (326, 'BUY', 95, 'RETAIL_STORE', NULL, 23);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (327, 'RETURN', 19, 'RETAIL_STORE', NULL, 40);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (328, 'BUY', 165, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (329, 'RETURN', 31, 'RETAIL_STORE', NULL, 22);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (330, 'RETURN', 218, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (331, 'BUY', 233, 'CUSTOMER', 478, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (332, 'BUY', 204, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (333, 'BUY', 18, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (334, 'RETURN', 88, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (335, 'BUY', 608, 'CUSTOMER', 70, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (336, 'BUY', 654, 'CUSTOMER', 163, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (337, 'BUY', 301, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (338, 'RETURN', 713, 'CUSTOMER', 133, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (339, 'BUY', 77, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (340, 'BUY', 417, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (341, 'BUY', 141, 'CUSTOMER', 319, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (342, 'BUY', 342, 'RETAIL_STORE', NULL, 21);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (343, 'BUY', 238, 'CUSTOMER', 26, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (344, 'RETURN', 566, 'RETAIL_STORE', NULL, 20);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (345, 'BUY', 320, 'CUSTOMER', 500, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (346, 'BUY', 141, 'CUSTOMER', 36, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (347, 'BUY', 44, 'RETAIL_STORE', NULL, 31);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (348, 'BUY', 84, 'CUSTOMER', 172, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (349, 'BUY', 646, 'CUSTOMER', 466, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (350, 'BUY', 174, 'CUSTOMER', 428, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (351, 'BUY', 591, 'RETAIL_STORE', NULL, 13);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (352, 'BUY', 628, 'CUSTOMER', 392, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (353, 'BUY', 605, 'RETAIL_STORE', NULL, 27);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (354, 'BUY', 724, 'CUSTOMER', 216, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (355, 'BUY', 416, 'CUSTOMER', 353, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (356, 'BUY', 657, 'CUSTOMER', 348, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (357, 'BUY', 237, 'CUSTOMER', 128, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (358, 'BUY', 224, 'CUSTOMER', 142, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (359, 'BUY', 114, 'CUSTOMER', 475, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (360, 'BUY', 458, 'CUSTOMER', 74, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (361, 'RETURN', 421, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (362, 'RETURN', 212, 'CUSTOMER', 200, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (363, 'BUY', 448, 'RETAIL_STORE', NULL, 4);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (364, 'BUY', 62, 'CUSTOMER', 434, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (365, 'BUY', 295, 'CUSTOMER', 73, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (366, 'BUY', 485, 'CUSTOMER', 453, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (367, 'BUY', 660, 'RETAIL_STORE', NULL, 15);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (368, 'RETURN', 277, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (369, 'RETURN', 241, 'CUSTOMER', 381, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (370, 'RETURN', 113, 'CUSTOMER', 138, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (371, 'BUY', 675, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (372, 'BUY', 248, 'CUSTOMER', 145, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (373, 'BUY', 153, 'CUSTOMER', 11, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (374, 'BUY', 493, 'CUSTOMER', 100, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (375, 'BUY', 258, 'RETAIL_STORE', NULL, 18);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (376, 'BUY', 99, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (377, 'RETURN', 47, 'RETAIL_STORE', NULL, 22);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (378, 'BUY', 234, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (379, 'BUY', 237, 'CUSTOMER', 211, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (380, 'BUY', 106, 'CUSTOMER', 399, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (381, 'BUY', 380, 'CUSTOMER', 50, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (382, 'BUY', 124, 'RETAIL_STORE', NULL, 18);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (383, 'BUY', 627, 'CUSTOMER', 61, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (384, 'BUY', 46, 'CUSTOMER', 244, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (385, 'BUY', 502, 'CUSTOMER', 469, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (386, 'RETURN', 91, 'CUSTOMER', 308, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (387, 'BUY', 714, 'RETAIL_STORE', NULL, 23);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (388, 'BUY', 643, 'CUSTOMER', 343, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (389, 'BUY', 240, 'CUSTOMER', 428, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (390, 'BUY', 203, 'CUSTOMER', 68, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (391, 'BUY', 634, 'CUSTOMER', 69, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (392, 'BUY', 376, 'CUSTOMER', 372, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (393, 'BUY', 486, 'CUSTOMER', 194, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (394, 'BUY', 701, 'CUSTOMER', 482, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (395, 'BUY', 75, 'CUSTOMER', 79, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (396, 'BUY', 273, 'CUSTOMER', 416, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (397, 'RETURN', 460, 'CUSTOMER', 218, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (398, 'RETURN', 286, 'RETAIL_STORE', NULL, 21);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (399, 'RETURN', 201, 'CUSTOMER', 208, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (400, 'RETURN', 712, 'CUSTOMER', 65, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (401, 'BUY', 574, 'CUSTOMER', 246, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (402, 'BUY', 552, 'CUSTOMER', 499, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (403, 'BUY', 521, 'CUSTOMER', 490, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (404, 'BUY', 348, 'CUSTOMER', 319, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (405, 'BUY', 183, 'CUSTOMER', 23, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (406, 'BUY', 716, 'CUSTOMER', 376, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (407, 'BUY', 74, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (408, 'BUY', 346, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (409, 'BUY', 32, 'CUSTOMER', 43, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (410, 'BUY', 493, 'CUSTOMER', 463, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (411, 'BUY', 59, 'RETAIL_STORE', NULL, 39);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (412, 'RETURN', 389, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (413, 'BUY', 615, 'CUSTOMER', 393, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (414, 'BUY', 155, 'CUSTOMER', 90, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (415, 'BUY', 42, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (416, 'BUY', 3, 'CUSTOMER', 389, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (417, 'BUY', 91, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (418, 'BUY', 242, 'CUSTOMER', 212, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (419, 'BUY', 379, 'RETAIL_STORE', NULL, 4);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (420, 'BUY', 43, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (421, 'BUY', 247, 'CUSTOMER', 211, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (422, 'BUY', 640, 'CUSTOMER', 449, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (423, 'BUY', 49, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (424, 'RETURN', 268, 'CUSTOMER', 371, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (425, 'BUY', 529, 'CUSTOMER', 100, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (426, 'BUY', 159, 'CUSTOMER', 395, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (427, 'BUY', 175, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (428, 'BUY', 430, 'CUSTOMER', 438, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (429, 'BUY', 220, 'RETAIL_STORE', NULL, 7);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (430, 'BUY', 400, 'CUSTOMER', 150, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (431, 'RETURN', 298, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (432, 'BUY', 349, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (433, 'BUY', 685, 'CUSTOMER', 44, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (434, 'BUY', 298, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (435, 'BUY', 248, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (436, 'BUY', 477, 'CUSTOMER', 363, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (437, 'BUY', 299, 'CUSTOMER', 123, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (438, 'BUY', 199, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (439, 'RETURN', 405, 'CUSTOMER', 423, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (440, 'RETURN', 97, 'CUSTOMER', 415, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (441, 'BUY', 558, 'CUSTOMER', 25, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (442, 'BUY', 505, 'CUSTOMER', 111, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (443, 'BUY', 41, 'CUSTOMER', 209, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (444, 'RETURN', 336, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (445, 'RETURN', 566, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (446, 'RETURN', 28, 'CUSTOMER', 466, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (447, 'BUY', 115, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (448, 'BUY', 251, 'CUSTOMER', 403, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (449, 'BUY', 271, 'RETAIL_STORE', NULL, 19);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (450, 'RETURN', 402, 'CUSTOMER', 189, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (451, 'BUY', 127, 'CUSTOMER', 496, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (452, 'BUY', 543, 'RETAIL_STORE', NULL, 31);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (453, 'BUY', 200, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (454, 'BUY', 76, 'CUSTOMER', 123, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (455, 'BUY', 95, 'CUSTOMER', 131, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (456, 'BUY', 44, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (457, 'BUY', 439, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (458, 'BUY', 132, 'CUSTOMER', 219, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (459, 'RETURN', 533, 'CUSTOMER', 105, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (460, 'RETURN', 28, 'CUSTOMER', 198, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (461, 'BUY', 103, 'CUSTOMER', 90, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (462, 'RETURN', 54, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (463, 'BUY', 642, 'RETAIL_STORE', NULL, 32);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (464, 'BUY', 298, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (465, 'BUY', 541, 'CUSTOMER', 230, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (466, 'BUY', 684, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (467, 'BUY', 661, 'CUSTOMER', 192, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (468, 'BUY', 463, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (469, 'BUY', 297, 'CUSTOMER', 147, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (470, 'BUY', 262, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (471, 'BUY', 640, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (472, 'BUY', 149, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (473, 'BUY', 151, 'CUSTOMER', 170, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (474, 'BUY', 584, 'RETAIL_STORE', NULL, 40);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (475, 'RETURN', 190, 'CUSTOMER', 480, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (476, 'BUY', 414, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (477, 'BUY', 572, 'CUSTOMER', 243, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (478, 'BUY', 428, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (479, 'BUY', 533, 'CUSTOMER', 361, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (480, 'BUY', 666, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (481, 'BUY', 4, 'RETAIL_STORE', NULL, 23);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (482, 'RETURN', 350, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (483, 'BUY', 558, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (484, 'BUY', 587, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (485, 'RETURN', 16, 'CUSTOMER', 338, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (486, 'BUY', 195, 'CUSTOMER', 464, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (487, 'RETURN', 258, 'CUSTOMER', 482, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (488, 'BUY', 247, 'CUSTOMER', 351, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (489, 'BUY', 31, 'CUSTOMER', 477, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (490, 'BUY', 7, 'CUSTOMER', 392, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (491, 'RETURN', 65, 'RETAIL_STORE', NULL, 4);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (492, 'BUY', 84, 'CUSTOMER', 393, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (493, 'BUY', 50, 'CUSTOMER', 34, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (494, 'BUY', 83, 'RETAIL_STORE', NULL, 19);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (495, 'BUY', 182, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (496, 'RETURN', 643, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (497, 'BUY', 277, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (498, 'BUY', 167, 'RETAIL_STORE', NULL, 4);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (499, 'BUY', 688, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (500, 'BUY', 504, 'CUSTOMER', 422, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (501, 'RETURN', 270, 'CUSTOMER', 12, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (502, 'BUY', 204, 'CUSTOMER', 104, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (503, 'RETURN', 367, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (504, 'RETURN', 112, 'RETAIL_STORE', NULL, 30);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (505, 'BUY', 695, 'CUSTOMER', 53, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (506, 'BUY', 116, 'RETAIL_STORE', NULL, 15);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (507, 'BUY', 560, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (508, 'BUY', 77, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (509, 'BUY', 593, 'CUSTOMER', 166, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (510, 'RETURN', 523, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (511, 'BUY', 243, 'CUSTOMER', 232, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (512, 'RETURN', 482, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (513, 'RETURN', 684, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (514, 'BUY', 655, 'CUSTOMER', 48, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (515, 'BUY', 268, 'CUSTOMER', 316, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (516, 'BUY', 704, 'RETAIL_STORE', NULL, 39);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (517, 'RETURN', 553, 'CUSTOMER', 125, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (518, 'BUY', 419, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (519, 'RETURN', 505, 'CUSTOMER', 453, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (520, 'BUY', 413, 'CUSTOMER', 491, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (521, 'BUY', 16, 'CUSTOMER', 187, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (522, 'BUY', 675, 'CUSTOMER', 481, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (523, 'BUY', 336, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (524, 'BUY', 16, 'RETAIL_STORE', NULL, 22);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (525, 'BUY', 75, 'CUSTOMER', 318, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (526, 'RETURN', 336, 'CUSTOMER', 341, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (527, 'BUY', 241, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (528, 'RETURN', 39, 'CUSTOMER', 486, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (529, 'BUY', 613, 'RETAIL_STORE', NULL, 17);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (530, 'RETURN', 625, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (531, 'BUY', 642, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (532, 'BUY', 241, 'CUSTOMER', 329, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (533, 'BUY', 27, 'CUSTOMER', 366, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (534, 'BUY', 643, 'CUSTOMER', 390, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (535, 'BUY', 639, 'CUSTOMER', 345, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (536, 'BUY', 133, 'CUSTOMER', 164, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (537, 'RETURN', 659, 'CUSTOMER', 323, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (538, 'BUY', 699, 'CUSTOMER', 371, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (539, 'BUY', 31, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (540, 'BUY', 32, 'CUSTOMER', 395, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (541, 'BUY', 351, 'CUSTOMER', 487, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (542, 'BUY', 472, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (543, 'BUY', 191, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (544, 'BUY', 401, 'RETAIL_STORE', NULL, 15);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (545, 'RETURN', 349, 'CUSTOMER', 208, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (546, 'BUY', 192, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (547, 'RETURN', 399, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (548, 'RETURN', 712, 'CUSTOMER', 114, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (549, 'BUY', 574, 'CUSTOMER', 414, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (550, 'BUY', 532, 'RETAIL_STORE', NULL, 17);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (551, 'BUY', 500, 'RETAIL_STORE', NULL, 19);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (552, 'BUY', 692, 'CUSTOMER', 313, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (553, 'RETURN', 169, 'RETAIL_STORE', NULL, 4);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (554, 'RETURN', 596, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (555, 'RETURN', 404, 'CUSTOMER', 158, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (556, 'BUY', 335, 'CUSTOMER', 474, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (557, 'BUY', 375, 'CUSTOMER', 368, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (558, 'BUY', 244, 'CUSTOMER', 459, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (559, 'BUY', 154, 'RETAIL_STORE', NULL, 7);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (560, 'BUY', 468, 'CUSTOMER', 197, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (561, 'BUY', 620, 'CUSTOMER', 426, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (562, 'BUY', 133, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (563, 'RETURN', 571, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (564, 'RETURN', 461, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (565, 'RETURN', 505, 'CUSTOMER', 412, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (566, 'RETURN', 555, 'RETAIL_STORE', NULL, 22);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (567, 'BUY', 183, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (568, 'RETURN', 85, 'CUSTOMER', 466, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (569, 'BUY', 41, 'CUSTOMER', 22, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (570, 'BUY', 601, 'CUSTOMER', 382, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (571, 'RETURN', 659, 'CUSTOMER', 500, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (572, 'RETURN', 214, 'CUSTOMER', 3, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (573, 'BUY', 649, 'CUSTOMER', 375, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (574, 'BUY', 311, 'RETAIL_STORE', NULL, 19);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (575, 'BUY', 434, 'CUSTOMER', 230, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (576, 'BUY', 133, 'CUSTOMER', 188, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (577, 'BUY', 539, 'CUSTOMER', 112, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (578, 'RETURN', 137, 'CUSTOMER', 98, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (579, 'BUY', 661, 'CUSTOMER', 4, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (580, 'BUY', 93, 'CUSTOMER', 317, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (581, 'BUY', 209, 'CUSTOMER', 418, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (582, 'BUY', 414, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (583, 'BUY', 359, 'CUSTOMER', 246, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (584, 'BUY', 576, 'RETAIL_STORE', NULL, 18);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (585, 'BUY', 334, 'CUSTOMER', 73, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (586, 'RETURN', 392, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (587, 'BUY', 451, 'CUSTOMER', 62, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (588, 'BUY', 204, 'CUSTOMER', 227, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (589, 'BUY', 30, 'CUSTOMER', 167, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (590, 'BUY', 422, 'CUSTOMER', 88, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (591, 'BUY', 656, 'CUSTOMER', 156, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (592, 'BUY', 171, 'CUSTOMER', 167, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (593, 'BUY', 274, 'RETAIL_STORE', NULL, 27);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (594, 'BUY', 505, 'RETAIL_STORE', NULL, 15);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (595, 'BUY', 585, 'CUSTOMER', 171, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (596, 'BUY', 185, 'CUSTOMER', 229, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (597, 'BUY', 72, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (598, 'BUY', 540, 'RETAIL_STORE', NULL, 32);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (599, 'BUY', 142, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (600, 'BUY', 138, 'CUSTOMER', 457, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (601, 'BUY', 39, 'CUSTOMER', 23, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (602, 'BUY', 532, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (603, 'BUY', 684, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (604, 'BUY', 63, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (605, 'BUY', 242, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (606, 'RETURN', 113, 'RETAIL_STORE', NULL, 30);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (607, 'RETURN', 216, 'CUSTOMER', 497, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (608, 'BUY', 601, 'CUSTOMER', 434, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (609, 'BUY', 284, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (610, 'BUY', 6, 'CUSTOMER', 346, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (611, 'BUY', 96, 'RETAIL_STORE', NULL, 39);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (612, 'BUY', 156, 'CUSTOMER', 60, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (613, 'BUY', 420, 'RETAIL_STORE', NULL, 30);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (614, 'BUY', 119, 'CUSTOMER', 58, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (615, 'BUY', 43, 'CUSTOMER', 62, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (616, 'BUY', 678, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (617, 'RETURN', 38, 'CUSTOMER', 151, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (618, 'BUY', 550, 'CUSTOMER', 7, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (619, 'BUY', 534, 'RETAIL_STORE', NULL, 7);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (620, 'BUY', 292, 'CUSTOMER', 12, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (621, 'RETURN', 591, 'CUSTOMER', 391, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (622, 'BUY', 132, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (623, 'RETURN', 390, 'RETAIL_STORE', NULL, 5);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (624, 'BUY', 132, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (625, 'BUY', 122, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (626, 'RETURN', 553, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (627, 'BUY', 266, 'CUSTOMER', 39, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (628, 'BUY', 56, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (629, 'BUY', 237, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (630, 'BUY', 454, 'CUSTOMER', 419, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (631, 'BUY', 423, 'CUSTOMER', 117, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (632, 'RETURN', 351, 'CUSTOMER', 164, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (633, 'BUY', 34, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (634, 'BUY', 416, 'RETAIL_STORE', NULL, 32);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (635, 'RETURN', 638, 'RETAIL_STORE', NULL, 5);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (636, 'BUY', 177, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (637, 'BUY', 473, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (638, 'BUY', 122, 'CUSTOMER', 459, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (639, 'BUY', 568, 'RETAIL_STORE', NULL, 15);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (640, 'BUY', 501, 'CUSTOMER', 83, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (641, 'BUY', 687, 'CUSTOMER', 188, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (642, 'BUY', 351, 'CUSTOMER', 411, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (643, 'BUY', 419, 'CUSTOMER', 232, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (644, 'BUY', 341, 'CUSTOMER', 41, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (645, 'BUY', 504, 'RETAIL_STORE', NULL, 20);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (646, 'BUY', 26, 'CUSTOMER', 9, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (647, 'BUY', 458, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (648, 'BUY', 124, 'CUSTOMER', 338, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (649, 'BUY', 622, 'CUSTOMER', 207, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (650, 'RETURN', 404, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (651, 'BUY', 538, 'CUSTOMER', 124, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (652, 'BUY', 273, 'CUSTOMER', 207, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (653, 'BUY', 642, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (654, 'BUY', 458, 'CUSTOMER', 352, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (655, 'RETURN', 21, 'CUSTOMER', 434, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (656, 'BUY', 577, 'CUSTOMER', 438, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (657, 'BUY', 325, 'CUSTOMER', 452, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (658, 'BUY', 604, 'CUSTOMER', 153, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (659, 'BUY', 204, 'CUSTOMER', 238, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (660, 'BUY', 105, 'RETAIL_STORE', NULL, 27);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (661, 'BUY', 51, 'RETAIL_STORE', NULL, 32);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (662, 'BUY', 331, 'CUSTOMER', 224, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (663, 'BUY', 597, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (664, 'BUY', 69, 'CUSTOMER', 415, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (665, 'RETURN', 27, 'CUSTOMER', 110, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (666, 'RETURN', 109, 'CUSTOMER', 46, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (667, 'BUY', 646, 'CUSTOMER', 462, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (668, 'BUY', 151, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (669, 'RETURN', 678, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (670, 'RETURN', 267, 'RETAIL_STORE', NULL, 20);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (671, 'BUY', 365, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (672, 'RETURN', 449, 'RETAIL_STORE', NULL, 1);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (673, 'RETURN', 554, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (674, 'BUY', 185, 'CUSTOMER', 482, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (675, 'BUY', 610, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (676, 'RETURN', 691, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (677, 'BUY', 475, 'CUSTOMER', 422, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (678, 'BUY', 274, 'CUSTOMER', 23, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (679, 'BUY', 595, 'CUSTOMER', 217, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (680, 'BUY', 566, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (681, 'BUY', 342, 'CUSTOMER', 421, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (682, 'BUY', 595, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (683, 'BUY', 719, 'RETAIL_STORE', NULL, 19);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (684, 'BUY', 27, 'RETAIL_STORE', NULL, 18);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (685, 'BUY', 12, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (686, 'BUY', 594, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (687, 'BUY', 273, 'CUSTOMER', 324, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (688, 'BUY', 141, 'RETAIL_STORE', NULL, 17);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (689, 'RETURN', 617, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (690, 'BUY', 92, 'CUSTOMER', 154, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (691, 'RETURN', 601, 'CUSTOMER', 438, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (692, 'BUY', 210, 'CUSTOMER', 416, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (693, 'BUY', 1, 'RETAIL_STORE', NULL, 22);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (694, 'BUY', 329, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (695, 'BUY', 170, 'CUSTOMER', 185, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (696, 'BUY', 632, 'CUSTOMER', 50, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (697, 'RETURN', 281, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (698, 'BUY', 67, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (699, 'BUY', 560, 'CUSTOMER', 328, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (700, 'BUY', 100, 'CUSTOMER', 140, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (701, 'BUY', 232, 'CUSTOMER', 480, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (702, 'RETURN', 272, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (703, 'BUY', 714, 'RETAIL_STORE', NULL, 40);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (704, 'BUY', 336, 'CUSTOMER', 175, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (705, 'BUY', 614, 'CUSTOMER', 398, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (706, 'RETURN', 370, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (707, 'BUY', 81, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (708, 'RETURN', 213, 'RETAIL_STORE', NULL, 27);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (709, 'RETURN', 103, 'CUSTOMER', 314, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (710, 'BUY', 498, 'RETAIL_STORE', NULL, 1);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (711, 'BUY', 140, 'RETAIL_STORE', NULL, 20);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (712, 'BUY', 385, 'RETAIL_STORE', NULL, 18);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (713, 'BUY', 447, 'RETAIL_STORE', NULL, 17);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (714, 'RETURN', 323, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (715, 'BUY', 585, 'CUSTOMER', 231, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (716, 'BUY', 436, 'CUSTOMER', 67, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (717, 'BUY', 391, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (718, 'BUY', 56, 'RETAIL_STORE', NULL, 7);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (719, 'BUY', 10, 'CUSTOMER', 406, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (720, 'BUY', 302, 'CUSTOMER', 93, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (721, 'BUY', 319, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (722, 'BUY', 29, 'RETAIL_STORE', NULL, 7);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (723, 'BUY', 95, 'CUSTOMER', 191, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (724, 'RETURN', 550, 'CUSTOMER', 8, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (725, 'BUY', 493, 'RETAIL_STORE', NULL, 32);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (726, 'RETURN', 592, 'CUSTOMER', 355, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (727, 'RETURN', 457, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (728, 'BUY', 78, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (729, 'BUY', 235, 'RETAIL_STORE', NULL, 31);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (730, 'BUY', 546, 'RETAIL_STORE', NULL, 4);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (731, 'RETURN', 378, 'CUSTOMER', 136, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (732, 'BUY', 516, 'CUSTOMER', 167, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (733, 'BUY', 261, 'RETAIL_STORE', NULL, 20);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (734, 'BUY', 202, 'CUSTOMER', 483, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (735, 'BUY', 158, 'CUSTOMER', 416, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (736, 'BUY', 462, 'CUSTOMER', 225, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (737, 'BUY', 502, 'CUSTOMER', 87, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (738, 'RETURN', 702, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (739, 'BUY', 671, 'CUSTOMER', 328, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (740, 'BUY', 253, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (741, 'BUY', 333, 'CUSTOMER', 419, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (742, 'BUY', 339, 'CUSTOMER', 485, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (743, 'BUY', 528, 'CUSTOMER', 36, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (744, 'BUY', 436, 'CUSTOMER', 177, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (745, 'BUY', 268, 'RETAIL_STORE', NULL, 17);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (746, 'RETURN', 705, 'RETAIL_STORE', NULL, 5);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (747, 'BUY', 16, 'CUSTOMER', 379, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (748, 'BUY', 515, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (749, 'RETURN', 601, 'RETAIL_STORE', NULL, 34);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (750, 'BUY', 493, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (751, 'BUY', 698, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (752, 'BUY', 613, 'CUSTOMER', 327, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (753, 'BUY', 571, 'CUSTOMER', 383, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (754, 'BUY', 244, 'CUSTOMER', 341, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (755, 'RETURN', 31, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (756, 'BUY', 530, 'CUSTOMER', 494, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (757, 'BUY', 172, 'CUSTOMER', 75, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (758, 'RETURN', 190, 'CUSTOMER', 118, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (759, 'BUY', 473, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (760, 'RETURN', 396, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (761, 'BUY', 194, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (762, 'BUY', 567, 'CUSTOMER', 149, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (763, 'BUY', 495, 'CUSTOMER', 142, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (764, 'BUY', 419, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (765, 'BUY', 469, 'CUSTOMER', 478, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (766, 'BUY', 338, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (767, 'BUY', 447, 'CUSTOMER', 222, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (768, 'BUY', 663, 'CUSTOMER', 202, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (769, 'BUY', 289, 'CUSTOMER', 1, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (770, 'BUY', 634, 'RETAIL_STORE', NULL, 31);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (771, 'BUY', 576, 'RETAIL_STORE', NULL, 13);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (772, 'BUY', 387, 'CUSTOMER', 324, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (773, 'BUY', 541, 'CUSTOMER', 120, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (774, 'BUY', 630, 'RETAIL_STORE', NULL, 5);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (775, 'RETURN', 185, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (776, 'RETURN', 710, 'CUSTOMER', 355, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (777, 'BUY', 136, 'CUSTOMER', 221, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (778, 'BUY', 81, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (779, 'BUY', 75, 'CUSTOMER', 452, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (780, 'BUY', 472, 'CUSTOMER', 250, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (781, 'BUY', 500, 'CUSTOMER', 152, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (782, 'BUY', 555, 'CUSTOMER', 395, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (783, 'BUY', 142, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (784, 'BUY', 343, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (785, 'BUY', 376, 'RETAIL_STORE', NULL, 18);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (786, 'RETURN', 698, 'RETAIL_STORE', NULL, 19);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (787, 'BUY', 3, 'CUSTOMER', 483, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (788, 'RETURN', 509, 'RETAIL_STORE', NULL, 1);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (789, 'BUY', 225, 'RETAIL_STORE', NULL, 22);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (790, 'BUY', 140, 'CUSTOMER', 143, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (791, 'RETURN', 287, 'RETAIL_STORE', NULL, 1);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (792, 'BUY', 165, 'CUSTOMER', 403, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (793, 'BUY', 75, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (794, 'BUY', 576, 'RETAIL_STORE', NULL, 4);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (795, 'BUY', 626, 'CUSTOMER', 92, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (796, 'BUY', 83, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (797, 'BUY', 205, 'CUSTOMER', 23, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (798, 'BUY', 608, 'RETAIL_STORE', NULL, 21);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (799, 'RETURN', 718, 'RETAIL_STORE', NULL, 6);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (800, 'BUY', 662, 'CUSTOMER', 73, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (801, 'RETURN', 353, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (802, 'BUY', 91, 'RETAIL_STORE', NULL, 40);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (803, 'BUY', 552, 'RETAIL_STORE', NULL, 6);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (804, 'BUY', 47, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (805, 'BUY', 71, 'CUSTOMER', 240, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (806, 'BUY', 346, 'CUSTOMER', 497, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (807, 'BUY', 280, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (808, 'BUY', 258, 'CUSTOMER', 154, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (809, 'BUY', 326, 'CUSTOMER', 460, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (810, 'RETURN', 416, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (811, 'BUY', 455, 'RETAIL_STORE', NULL, 18);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (812, 'BUY', 361, 'RETAIL_STORE', NULL, 6);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (813, 'BUY', 10, 'CUSTOMER', 355, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (814, 'RETURN', 110, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (815, 'BUY', 240, 'CUSTOMER', 52, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (816, 'BUY', 98, 'RETAIL_STORE', NULL, 39);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (817, 'BUY', 722, 'RETAIL_STORE', NULL, 29);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (818, 'BUY', 416, 'CUSTOMER', 418, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (819, 'RETURN', 716, 'RETAIL_STORE', NULL, 6);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (820, 'RETURN', 187, 'CUSTOMER', 225, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (821, 'RETURN', 11, 'CUSTOMER', 81, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (822, 'BUY', 220, 'RETAIL_STORE', NULL, 12);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (823, 'BUY', 33, 'RETAIL_STORE', NULL, 29);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (824, 'BUY', 722, 'RETAIL_STORE', NULL, 13);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (825, 'BUY', 363, 'CUSTOMER', 413, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (826, 'BUY', 50, 'CUSTOMER', 5, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (827, 'RETURN', 209, 'CUSTOMER', 404, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (828, 'BUY', 33, 'CUSTOMER', 500, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (829, 'BUY', 66, 'RETAIL_STORE', NULL, 5);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (830, 'RETURN', 631, 'RETAIL_STORE', NULL, 40);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (831, 'BUY', 383, 'CUSTOMER', 402, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (832, 'BUY', 35, 'CUSTOMER', 31, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (833, 'BUY', 585, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (834, 'BUY', 489, 'RETAIL_STORE', NULL, 17);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (835, 'RETURN', 712, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (836, 'BUY', 315, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (837, 'BUY', 470, 'RETAIL_STORE', NULL, 25);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (838, 'BUY', 165, 'CUSTOMER', 375, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (839, 'BUY', 321, 'RETAIL_STORE', NULL, 17);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (840, 'BUY', 471, 'CUSTOMER', 326, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (841, 'BUY', 225, 'CUSTOMER', 455, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (842, 'BUY', 72, 'CUSTOMER', 8, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (843, 'BUY', 694, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (844, 'BUY', 523, 'RETAIL_STORE', NULL, 17);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (845, 'BUY', 91, 'CUSTOMER', 197, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (846, 'BUY', 289, 'CUSTOMER', 398, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (847, 'BUY', 332, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (848, 'BUY', 320, 'RETAIL_STORE', NULL, 11);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (849, 'RETURN', 430, 'CUSTOMER', 394, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (850, 'RETURN', 469, 'CUSTOMER', 190, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (851, 'BUY', 475, 'RETAIL_STORE', NULL, 2);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (852, 'RETURN', 94, 'CUSTOMER', 461, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (853, 'BUY', 186, 'CUSTOMER', 97, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (854, 'BUY', 70, 'CUSTOMER', 181, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (855, 'BUY', 5, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (856, 'BUY', 516, 'CUSTOMER', 224, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (857, 'BUY', 603, 'CUSTOMER', 161, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (858, 'BUY', 391, 'CUSTOMER', 335, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (859, 'BUY', 243, 'RETAIL_STORE', NULL, 31);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (860, 'BUY', 624, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (861, 'BUY', 55, 'RETAIL_STORE', NULL, 7);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (862, 'BUY', 167, 'RETAIL_STORE', NULL, 1);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (863, 'BUY', 550, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (864, 'BUY', 61, 'CUSTOMER', 130, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (865, 'BUY', 671, 'RETAIL_STORE', NULL, 14);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (866, 'BUY', 432, 'CUSTOMER', 185, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (867, 'BUY', 131, 'CUSTOMER', 19, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (868, 'BUY', 225, 'CUSTOMER', 487, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (869, 'BUY', 368, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (870, 'BUY', 43, 'CUSTOMER', 448, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (871, 'BUY', 49, 'RETAIL_STORE', NULL, 27);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (872, 'BUY', 353, 'CUSTOMER', 417, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (873, 'BUY', 408, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (874, 'BUY', 73, 'CUSTOMER', 401, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (875, 'RETURN', 426, 'CUSTOMER', 400, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (876, 'BUY', 163, 'CUSTOMER', 349, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (877, 'RETURN', 270, 'CUSTOMER', 127, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (878, 'BUY', 582, 'CUSTOMER', 42, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (879, 'BUY', 514, 'CUSTOMER', 29, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (880, 'RETURN', 403, 'RETAIL_STORE', NULL, 30);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (881, 'BUY', 157, 'RETAIL_STORE', NULL, 6);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (882, 'BUY', 261, 'RETAIL_STORE', NULL, 20);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (883, 'RETURN', 202, 'RETAIL_STORE', NULL, 20);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (884, 'BUY', 9, 'RETAIL_STORE', NULL, 20);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (885, 'BUY', 395, 'CUSTOMER', 69, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (886, 'BUY', 262, 'CUSTOMER', 111, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (887, 'RETURN', 273, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (888, 'RETURN', 547, 'CUSTOMER', 427, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (889, 'BUY', 152, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (890, 'BUY', 574, 'CUSTOMER', 174, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (891, 'BUY', 472, 'RETAIL_STORE', NULL, 12);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (892, 'BUY', 252, 'CUSTOMER', 134, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (893, 'RETURN', 80, 'CUSTOMER', 41, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (894, 'BUY', 274, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (895, 'BUY', 412, 'RETAIL_STORE', NULL, 38);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (896, 'BUY', 448, 'CUSTOMER', 190, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (897, 'BUY', 66, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (898, 'BUY', 352, 'CUSTOMER', 147, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (899, 'BUY', 521, 'RETAIL_STORE', NULL, 6);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (900, 'BUY', 381, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (901, 'RETURN', 116, 'CUSTOMER', 487, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (902, 'BUY', 140, 'RETAIL_STORE', NULL, 16);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (903, 'BUY', 126, 'RETAIL_STORE', NULL, 19);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (904, 'BUY', 254, 'CUSTOMER', 456, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (905, 'RETURN', 325, 'RETAIL_STORE', NULL, 20);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (906, 'BUY', 226, 'RETAIL_STORE', NULL, 30);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (907, 'RETURN', 31, 'CUSTOMER', 324, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (908, 'RETURN', 172, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (909, 'BUY', 95, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (910, 'BUY', 181, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (911, 'RETURN', 50, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (912, 'RETURN', 709, 'CUSTOMER', 321, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (913, 'BUY', 474, 'RETAIL_STORE', NULL, 29);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (914, 'BUY', 417, 'RETAIL_STORE', NULL, 13);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (915, 'BUY', 64, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (916, 'RETURN', 26, 'CUSTOMER', 189, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (917, 'BUY', 496, 'CUSTOMER', 489, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (918, 'BUY', 328, 'CUSTOMER', 238, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (919, 'BUY', 233, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (920, 'BUY', 507, 'CUSTOMER', 85, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (921, 'BUY', 638, 'RETAIL_STORE', NULL, 23);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (922, 'BUY', 616, 'CUSTOMER', 381, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (923, 'BUY', 253, 'RETAIL_STORE', NULL, 23);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (924, 'RETURN', 676, 'RETAIL_STORE', NULL, 14);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (925, 'BUY', 233, 'RETAIL_STORE', NULL, 40);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (926, 'BUY', 2, 'CUSTOMER', 148, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (927, 'BUY', 133, 'CUSTOMER', 117, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (928, 'BUY', 481, 'CUSTOMER', 204, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (929, 'BUY', 47, 'RETAIL_STORE', NULL, 33);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (930, 'BUY', 518, 'CUSTOMER', 464, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (931, 'BUY', 15, 'CUSTOMER', 302, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (932, 'BUY', 661, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (933, 'BUY', 724, 'CUSTOMER', 46, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (934, 'BUY', 413, 'RETAIL_STORE', NULL, 31);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (935, 'BUY', 135, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (936, 'RETURN', 146, 'CUSTOMER', 83, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (937, 'BUY', 260, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (938, 'BUY', 183, 'CUSTOMER', 426, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (939, 'BUY', 217, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (940, 'BUY', 251, 'RETAIL_STORE', NULL, 5);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (941, 'BUY', 701, 'RETAIL_STORE', NULL, 32);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (942, 'BUY', 235, 'RETAIL_STORE', NULL, 36);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (943, 'BUY', 226, 'CUSTOMER', 447, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (944, 'BUY', 680, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (945, 'RETURN', 673, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (946, 'BUY', 47, 'RETAIL_STORE', NULL, 24);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (947, 'BUY', 378, 'CUSTOMER', 45, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (948, 'BUY', 338, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (949, 'BUY', 607, 'RETAIL_STORE', NULL, 14);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (950, 'BUY', 62, 'CUSTOMER', 245, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (951, 'BUY', 446, 'CUSTOMER', 82, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (952, 'BUY', 99, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (953, 'BUY', 586, 'CUSTOMER', 125, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (954, 'BUY', 416, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (955, 'BUY', 496, 'RETAIL_STORE', NULL, 15);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (956, 'RETURN', 136, 'CUSTOMER', 225, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (957, 'RETURN', 665, 'RETAIL_STORE', NULL, 35);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (958, 'RETURN', 647, 'CUSTOMER', 401, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (959, 'BUY', 337, 'RETAIL_STORE', NULL, 20);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (960, 'RETURN', 187, 'RETAIL_STORE', NULL, 15);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (961, 'BUY', 601, 'CUSTOMER', 36, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (962, 'BUY', 279, 'RETAIL_STORE', NULL, 19);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (963, 'BUY', 2, 'CUSTOMER', 72, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (964, 'BUY', 558, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (965, 'BUY', 317, 'RETAIL_STORE', NULL, 6);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (966, 'RETURN', 708, 'RETAIL_STORE', NULL, 3);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (967, 'BUY', 362, 'CUSTOMER', 162, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (968, 'BUY', 279, 'RETAIL_STORE', NULL, 37);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (969, 'RETURN', 81, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (970, 'BUY', 51, 'CUSTOMER', 406, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (971, 'BUY', 377, 'CUSTOMER', 180, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (972, 'BUY', 424, 'RETAIL_STORE', NULL, 14);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (973, 'RETURN', 629, 'RETAIL_STORE', NULL, 19);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (974, 'BUY', 424, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (975, 'RETURN', 300, 'RETAIL_STORE', NULL, 15);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (976, 'BUY', 627, 'RETAIL_STORE', NULL, 8);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (977, 'BUY', 723, 'CUSTOMER', 490, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (978, 'BUY', 420, 'RETAIL_STORE', NULL, 17);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (979, 'BUY', 150, 'CUSTOMER', 115, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (980, 'BUY', 132, 'RETAIL_STORE', NULL, 39);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (981, 'BUY', 107, 'CUSTOMER', 5, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (982, 'BUY', 491, 'CUSTOMER', 440, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (983, 'BUY', 198, 'RETAIL_STORE', NULL, 19);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (984, 'BUY', 129, 'CUSTOMER', 20, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (985, 'BUY', 581, 'RETAIL_STORE', NULL, 28);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (986, 'BUY', 581, 'CUSTOMER', 28, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (987, 'RETURN', 110, 'RETAIL_STORE', NULL, 9);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (988, 'BUY', 342, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (989, 'BUY', 644, 'RETAIL_STORE', NULL, 31);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (990, 'RETURN', 588, 'CUSTOMER', 363, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (991, 'BUY', 566, 'RETAIL_STORE', NULL, 20);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (992, 'BUY', 398, 'RETAIL_STORE', NULL, 15);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (993, 'BUY', 50, 'RETAIL_STORE', NULL, 14);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (994, 'RETURN', 687, 'CUSTOMER', 430, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (995, 'RETURN', 318, 'CUSTOMER', 235, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (996, 'BUY', 20, 'CUSTOMER', 155, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (997, 'BUY', 517, 'RETAIL_STORE', NULL, 26);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (998, 'BUY', 728, 'RETAIL_STORE', NULL, 10);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (999, 'BUY', 663, 'CUSTOMER', 390, NULL);
INSERT INTO OrderDim (OrderDimID, OrderType, OrderDateID, OrderSource, CustomerID, StoreID) VALUES (1000, 'BUY', 193, 'RETAIL_STORE', NULL, 3);
SET IDENTITY_INSERT OrderDim OFF;
GO

INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (1, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (1, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (2, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (2, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (3, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (4, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (5, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (5, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (6, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (6, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (7, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (7, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (8, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (9, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (10, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (10, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (11, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (12, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (12, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (13, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (13, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (14, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (15, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (16, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (16, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (17, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (17, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (18, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (19, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (20, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (20, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (21, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (21, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (22, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (23, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (24, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (24, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (25, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (26, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (26, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (27, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (27, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (28, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (29, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (30, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (31, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (32, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (33, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (33, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (34, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (34, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (35, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (35, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (36, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (37, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (38, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (38, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (39, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (39, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (40, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (41, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (42, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (42, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (43, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (43, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (44, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (45, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (46, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (47, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (47, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (48, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (49, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (50, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (51, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (51, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (52, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (53, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (54, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (54, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (55, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (56, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (57, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (58, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (58, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (59, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (59, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (60, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (60, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (61, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (61, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (62, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (63, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (64, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (64, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (65, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (66, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (66, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (67, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (67, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (68, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (68, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (69, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (70, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (71, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (72, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (73, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (73, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (74, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (75, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (76, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (77, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (77, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (78, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (79, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (80, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (80, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (81, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (81, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (82, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (83, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (83, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (84, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (84, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (85, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (85, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (86, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (87, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (87, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (88, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (88, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (89, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (90, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (91, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (92, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (92, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (93, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (93, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (94, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (95, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (96, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (96, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (97, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (97, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (98, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (98, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (99, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (99, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (100, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (100, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (101, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (102, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (103, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (104, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (104, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (105, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (106, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (107, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (107, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (108, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (109, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (109, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (110, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (111, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (111, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (112, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (112, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (113, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (113, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (114, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (115, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (115, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (116, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (117, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (118, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (119, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (120, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (120, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (121, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (121, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (122, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (123, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (124, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (125, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (126, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (127, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (128, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (128, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (129, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (129, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (130, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (130, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (131, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (131, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (132, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (132, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (133, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (134, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (134, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (135, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (136, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (137, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (137, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (138, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (138, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (139, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (140, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (141, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (141, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (142, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (142, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (143, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (143, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (144, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (145, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (145, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (146, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (147, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (147, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (148, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (149, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (150, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (150, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (151, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (152, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (152, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (153, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (154, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (154, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (155, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (155, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (156, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (156, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (157, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (158, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (159, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (160, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (161, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (161, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (162, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (162, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (163, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (164, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (164, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (165, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (166, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (167, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (167, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (168, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (168, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (169, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (169, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (170, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (170, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (171, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (171, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (172, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (173, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (174, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (174, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (175, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (176, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (177, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (177, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (178, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (178, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (179, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (179, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (180, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (180, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (181, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (181, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (182, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (183, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (184, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (184, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (185, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (185, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (186, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (187, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (188, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (188, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (189, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (190, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (191, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (191, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (192, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (192, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (193, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (194, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (195, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (196, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (197, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (197, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (198, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (199, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (200, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (201, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (202, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (202, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (203, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (203, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (204, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (204, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (205, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (206, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (207, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (207, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (208, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (209, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (209, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (210, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (210, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (211, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (211, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (212, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (212, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (213, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (213, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (214, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (214, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (215, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (215, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (216, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (217, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (218, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (218, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (219, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (219, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (220, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (220, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (221, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (221, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (222, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (223, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (224, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (225, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (226, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (227, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (227, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (228, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (228, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (229, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (229, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (230, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (231, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (232, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (232, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (233, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (234, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (234, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (235, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (236, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (236, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (237, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (237, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (238, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (239, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (239, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (240, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (240, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (241, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (242, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (243, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (244, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (244, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (245, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (246, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (247, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (248, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (248, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (249, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (250, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (251, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (251, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (252, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (252, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (253, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (254, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (254, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (255, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (256, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (257, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (257, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (258, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (258, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (259, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (260, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (260, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (261, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (262, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (263, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (264, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (264, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (265, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (266, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (267, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (267, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (268, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (268, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (269, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (270, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (271, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (272, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (273, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (274, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (274, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (275, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (275, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (276, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (276, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (277, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (277, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (278, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (278, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (279, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (279, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (280, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (280, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (281, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (281, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (282, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (283, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (284, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (285, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (286, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (286, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (287, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (287, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (288, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (289, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (290, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (291, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (291, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (292, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (292, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (293, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (294, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (294, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (295, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (295, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (296, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (297, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (298, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (299, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (299, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (300, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (300, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (301, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (302, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (302, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (303, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (303, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (304, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (305, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (306, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (307, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (307, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (308, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (309, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (310, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (310, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (311, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (312, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (313, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (313, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (314, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (315, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (315, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (316, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (316, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (317, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (318, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (318, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (319, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (319, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (320, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (321, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (321, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (322, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (322, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (323, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (324, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (324, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (325, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (325, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (326, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (327, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (328, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (329, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (329, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (330, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (331, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (331, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (332, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (333, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (333, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (334, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (335, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (335, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (336, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (337, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (338, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (338, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (339, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (339, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (340, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (341, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (342, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (343, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (343, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (344, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (345, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (345, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (346, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (347, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (347, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (348, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (349, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (350, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (351, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (351, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (352, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (352, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (353, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (353, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (354, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (354, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (355, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (356, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (357, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (358, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (359, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (360, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (361, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (361, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (362, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (362, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (363, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (363, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (364, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (364, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (365, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (365, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (366, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (367, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (367, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (368, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (368, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (369, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (369, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (370, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (370, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (371, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (371, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (372, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (372, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (373, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (373, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (374, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (375, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (376, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (376, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (377, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (377, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (378, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (379, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (380, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (380, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (381, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (382, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (382, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (383, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (384, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (384, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (385, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (386, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (387, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (387, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (388, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (389, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (390, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (390, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (391, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (392, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (392, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (393, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (394, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (394, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (395, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (395, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (396, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (396, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (397, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (398, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (398, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (399, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (399, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (400, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (401, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (401, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (402, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (403, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (404, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (405, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (405, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (406, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (407, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (408, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (409, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (409, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (410, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (411, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (412, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (412, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (413, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (413, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (414, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (414, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (415, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (415, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (416, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (416, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (417, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (417, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (418, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (419, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (419, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (420, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (421, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (421, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (422, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (423, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (423, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (424, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (424, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (425, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (425, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (426, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (427, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (427, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (428, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (429, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (429, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (430, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (430, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (431, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (432, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (433, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (433, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (434, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (435, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (436, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (437, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (438, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (438, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (439, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (440, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (440, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (441, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (442, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (443, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (444, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (445, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (446, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (447, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (448, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (448, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (449, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (450, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (450, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (451, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (451, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (452, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (452, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (453, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (454, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (454, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (455, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (456, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (457, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (458, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (459, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (459, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (460, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (461, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (462, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (463, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (463, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (464, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (465, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (466, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (467, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (468, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (469, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (470, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (471, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (471, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (472, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (472, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (473, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (474, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (475, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (476, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (477, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (478, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (478, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (479, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (480, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (481, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (481, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (482, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (483, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (483, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (484, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (484, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (485, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (485, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (486, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (486, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (487, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (488, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (488, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (489, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (490, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (490, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (491, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (492, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (493, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (493, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (494, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (495, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (496, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (497, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (497, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (498, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (498, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (499, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (500, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (500, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (501, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (501, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (502, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (502, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (503, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (504, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (505, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (506, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (506, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (507, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (507, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (508, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (508, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (509, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (510, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (511, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (512, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (513, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (514, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (514, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (515, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (515, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (516, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (516, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (517, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (518, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (518, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (519, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (519, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (520, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (520, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (521, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (522, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (523, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (524, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (524, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (525, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (526, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (526, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (527, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (527, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (528, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (528, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (529, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (529, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (530, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (531, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (531, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (532, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (532, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (533, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (533, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (534, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (534, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (535, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (535, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (536, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (537, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (537, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (538, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (539, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (539, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (540, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (541, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (541, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (542, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (542, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (543, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (544, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (545, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (546, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (546, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (547, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (548, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (548, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (549, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (549, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (550, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (550, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (551, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (551, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (552, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (553, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (554, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (554, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (555, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (556, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (556, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (557, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (558, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (558, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (559, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (559, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (560, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (561, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (562, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (562, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (563, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (563, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (564, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (564, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (565, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (565, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (566, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (566, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (567, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (568, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (568, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (569, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (570, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (571, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (572, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (572, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (573, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (573, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (574, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (574, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (575, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (575, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (576, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (577, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (578, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (579, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (579, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (580, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (581, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (581, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (582, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (583, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (583, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (584, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (584, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (585, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (586, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (587, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (587, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (588, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (589, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (590, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (591, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (592, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (592, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (593, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (594, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (595, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (595, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (596, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (596, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (597, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (598, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (599, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (600, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (600, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (601, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (601, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (602, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (602, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (603, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (603, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (604, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (605, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (606, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (607, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (608, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (608, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (609, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (610, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (610, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (611, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (612, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (613, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (614, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (614, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (615, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (616, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (616, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (617, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (618, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (619, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (620, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (620, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (621, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (621, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (622, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (623, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (624, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (624, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (625, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (625, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (626, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (626, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (627, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (628, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (629, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (629, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (630, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (631, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (632, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (632, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (633, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (634, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (634, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (635, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (635, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (636, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (636, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (637, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (638, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (639, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (640, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (640, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (641, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (641, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (642, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (643, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (644, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (645, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (646, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (646, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (647, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (647, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (648, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (649, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (650, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (651, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (652, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (652, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (653, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (654, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (654, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (655, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (655, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (656, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (656, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (657, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (658, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (658, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (659, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (659, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (660, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (660, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (661, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (661, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (662, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (663, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (664, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (664, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (665, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (665, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (666, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (666, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (667, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (667, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (668, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (669, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (670, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (671, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (672, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (673, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (673, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (674, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (675, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (676, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (676, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (677, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (677, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (678, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (678, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (679, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (680, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (681, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (681, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (682, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (683, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (683, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (684, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (684, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (685, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (685, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (686, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (686, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (687, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (687, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (688, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (688, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (689, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (690, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (691, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (692, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (692, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (693, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (694, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (695, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (695, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (696, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (696, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (697, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (697, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (698, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (699, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (700, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (701, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (701, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (702, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (702, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (703, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (703, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (704, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (704, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (705, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (706, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (706, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (707, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (708, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (708, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (709, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (709, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (710, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (711, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (711, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (712, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (712, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (713, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (714, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (714, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (715, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (715, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (716, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (717, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (718, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (718, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (719, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (719, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (720, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (720, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (721, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (722, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (723, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (723, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (724, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (725, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (726, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (726, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (727, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (727, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (728, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (729, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (729, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (730, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (730, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (731, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (732, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (732, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (733, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (733, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (734, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (735, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (735, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (736, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (736, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (737, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (738, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (739, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (740, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (740, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (741, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (742, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (743, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (743, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (744, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (745, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (745, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (746, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (746, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (747, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (747, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (748, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (748, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (749, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (750, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (751, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (751, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (752, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (752, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (753, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (754, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (755, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (756, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (757, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (758, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (759, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (759, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (760, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (761, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (761, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (762, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (762, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (763, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (763, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (764, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (764, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (765, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (765, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (766, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (766, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (767, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (767, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (768, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (768, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (769, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (769, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (770, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (771, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (771, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (772, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (772, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (773, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (773, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (774, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (774, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (775, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (775, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (776, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (777, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (777, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (778, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (779, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (779, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (780, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (780, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (781, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (781, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (782, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (783, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (783, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (784, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (785, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (786, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (786, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (787, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (788, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (789, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (789, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (790, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (790, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (791, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (792, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (792, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (793, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (793, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (794, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (795, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (795, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (796, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (796, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (797, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (798, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (799, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (799, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (800, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (800, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (801, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (801, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (802, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (803, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (804, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (804, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (805, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (805, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (806, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (807, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (807, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (808, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (809, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (810, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (811, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (812, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (812, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (813, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (814, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (814, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (815, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (816, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (817, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (817, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (818, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (818, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (819, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (820, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (820, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (821, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (821, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (822, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (822, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (823, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (823, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (824, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (825, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (825, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (826, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (826, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (827, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (828, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (829, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (829, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (830, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (831, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (831, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (832, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (832, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (833, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (834, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (835, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (836, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (836, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (837, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (838, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (838, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (839, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (840, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (840, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (841, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (842, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (843, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (843, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (844, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (845, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (845, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (846, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (846, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (847, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (848, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (848, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (849, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (850, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (850, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (851, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (852, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (852, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (853, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (853, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (854, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (855, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (856, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (857, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (857, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (858, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (859, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (860, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (860, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (861, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (862, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (863, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (864, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (865, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (866, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (867, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (868, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (869, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (870, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (871, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (871, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (872, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (873, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (874, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (875, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (876, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (877, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (877, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (878, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (879, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (879, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (880, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (881, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (881, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (882, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (883, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (884, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (884, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (885, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (885, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (886, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (886, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (887, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (888, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (888, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (889, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (889, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (890, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (891, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (891, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (892, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (893, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (893, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (894, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (894, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (895, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (895, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (896, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (896, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (897, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (898, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (898, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (899, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (899, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (900, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (900, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (901, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (902, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (902, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (903, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (904, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (905, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (906, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (907, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (908, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (909, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (909, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (910, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (910, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (911, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (911, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (912, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (912, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (913, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (914, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (915, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (915, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (916, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (916, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (917, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (918, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (919, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (920, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (921, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (921, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (922, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (923, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (924, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (925, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (926, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (926, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (927, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (927, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (928, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (929, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (930, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (931, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (932, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (933, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (933, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (934, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (935, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (936, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (937, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (937, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (938, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (938, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (939, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (940, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (941, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (941, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (942, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (942, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (943, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (943, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (944, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (945, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (945, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (946, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (946, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (947, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (947, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (948, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (948, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (949, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (949, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (950, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (951, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (952, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (953, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (953, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (954, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (954, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (955, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (956, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (956, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (957, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (957, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (958, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (958, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (959, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (960, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (961, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (961, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (962, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (962, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (963, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (963, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (964, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (964, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (965, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (965, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (966, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (966, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (967, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (968, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (968, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (969, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (969, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (970, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (970, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (971, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (972, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (972, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (973, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (973, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (974, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (975, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (975, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (976, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (976, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (977, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (977, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (978, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (979, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (980, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (980, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (981, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (981, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (982, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (983, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (983, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (984, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (985, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (985, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (986, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (987, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (988, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (988, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (989, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (990, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (991, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (992, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (993, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (993, 5);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (994, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (995, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (995, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (996, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (997, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (998, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (998, 1);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (999, 4);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (999, 3);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (1000, 2);
INSERT INTO OrderPaymentBridge (OrderDimID, PaymentID) VALUES (1000, 3);
GO



-- Base Dimension Tables
SELECT * FROM CategoryDim;
SELECT * FROM BrandDim;
SELECT * FROM ProductDim;
SELECT * FROM CustomerDim;
SELECT * FROM DateDim;
SELECT * FROM StoreLicenseDim;
SELECT * FROM StoreDim;
SELECT * FROM WarehouseDim;
SELECT * FROM JunkDim;
SELECT * FROM PaymentDim;
SELECT * FROM ReasonDim;
SELECT * FROM SupplierDim;
SELECT * FROM FactoryDim;
SELECT * FROM PromoDim;



SET IDENTITY_INSERT SalesFact ON;
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (1, 667, 376, 9, 670.65, 'BILL0001', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (2, 647, 342, 2, 634.64, 'BILL0002', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (3, 522, 29, 8, 669.4, 'BILL0003', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (4, 874, 445, 5, 110.44, 'BILL0004', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (5, 15, 174, 2, 162.72, 'BILL0005', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (6, 742, 322, 9, 101.45, 'BILL0006', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (7, 531, 39, 8, 426.03, 'BILL0007', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (8, 540, 368, 10, 489.46, 'BILL0008', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (9, 627, 18, 5, 455.04, 'BILL0009', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (10, 435, 499, 7, 959.78, 'BILL0010', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (11, 395, 206, 6, 943.45, 'BILL0011', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (12, 599, 370, 3, 575.58, 'BILL0012', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (13, 208, 340, 1, 600.2, 'BILL0013', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (14, 822, 128, 8, 696.94, 'BILL0014', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (15, 782, 389, 7, 569.85, 'BILL0015', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (16, 283, 455, 6, 302.94, 'BILL0016', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (17, 280, 126, 10, 393.43, 'BILL0017', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (18, 61, 317, 6, 964.45, 'BILL0018', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (19, 410, 325, 8, 808.95, 'BILL0019', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (20, 522, 189, 4, 418.78, 'BILL0020', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (21, 492, 47, 7, 280.31, 'BILL0021', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (22, 204, 272, 7, 676.6, 'BILL0022', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (23, 161, 471, 5, 174.0, 'BILL0023', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (24, 590, 190, 3, 962.68, 'BILL0024', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (25, 438, 291, 2, 996.96, 'BILL0025', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (26, 271, 42, 8, 977.91, 'BILL0026', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (27, 996, 346, 2, 589.16, 'BILL0027', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (28, 320, 19, 1, 761.0, 'BILL0028', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (29, 800, 94, 10, 203.76, 'BILL0029', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (30, 977, 290, 3, 939.61, 'BILL0030', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (31, 937, 138, 3, 249.67, 'BILL0031', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (32, 209, 230, 5, 296.04, 'BILL0032', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (33, 111, 139, 9, 373.46, 'BILL0033', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (34, 299, 425, 7, 477.54, 'BILL0034', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (35, 604, 480, 10, 440.15, 'BILL0035', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (36, 838, 190, 2, 724.52, 'BILL0036', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (37, 536, 26, 10, 848.16, 'BILL0037', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (38, 91, 20, 6, 125.14, 'BILL0038', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (39, 342, 185, 8, 344.59, 'BILL0039', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (40, 474, 370, 6, 787.31, 'BILL0040', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (41, 479, 396, 7, 433.53, 'BILL0041', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (42, 63, 124, 3, 184.12, 'BILL0042', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (43, 828, 404, 9, 528.55, 'BILL0043', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (44, 774, 148, 2, 615.45, 'BILL0044', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (45, 23, 380, 2, 575.43, 'BILL0045', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (46, 963, 211, 5, 965.99, 'BILL0046', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (47, 164, 411, 4, 855.55, 'BILL0047', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (48, 521, 389, 4, 730.53, 'BILL0048', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (49, 336, 489, 7, 726.15, 'BILL0049', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (50, 733, 355, 2, 521.17, 'BILL0050', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (51, 906, 232, 9, 266.34, 'BILL0051', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (52, 851, 223, 3, 827.73, 'BILL0052', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (53, 146, 148, 5, 143.11, 'BILL0053', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (54, 204, 232, 5, 528.56, 'BILL0054', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (55, 340, 345, 10, 372.86, 'BILL0055', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (56, 214, 329, 9, 105.31, 'BILL0056', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (57, 153, 354, 2, 376.9, 'BILL0057', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (58, 422, 182, 3, 846.68, 'BILL0058', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (59, 198, 310, 2, 654.45, 'BILL0059', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (60, 124, 316, 9, 881.79, 'BILL0060', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (61, 478, 79, 3, 708.64, 'BILL0061', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (62, 732, 308, 5, 143.37, 'BILL0062', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (63, 283, 469, 10, 344.5, 'BILL0063', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (64, 52, 415, 6, 242.03, 'BILL0064', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (65, 868, 491, 2, 707.02, 'BILL0065', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (66, 469, 162, 2, 129.7, 'BILL0066', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (67, 218, 342, 9, 795.16, 'BILL0067', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (68, 182, 111, 1, 725.27, 'BILL0068', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (69, 913, 442, 2, 690.54, 'BILL0069', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (70, 772, 441, 9, 821.5, 'BILL0070', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (71, 720, 57, 3, 688.24, 'BILL0071', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (72, 199, 75, 3, 173.1, 'BILL0072', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (73, 340, 148, 6, 599.94, 'BILL0073', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (74, 357, 58, 2, 442.88, 'BILL0074', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (75, 904, 302, 5, 966.02, 'BILL0075', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (76, 805, 104, 7, 408.15, 'BILL0076', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (77, 699, 160, 6, 144.18, 'BILL0077', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (78, 684, 278, 8, 477.86, 'BILL0078', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (79, 604, 414, 5, 872.4, 'BILL0079', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (80, 61, 384, 10, 176.69, 'BILL0080', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (81, 380, 279, 5, 830.51, 'BILL0081', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (82, 479, 227, 2, 878.65, 'BILL0082', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (83, 534, 424, 7, 269.48, 'BILL0083', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (84, 681, 132, 7, 405.36, 'BILL0084', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (85, 448, 238, 5, 151.44, 'BILL0085', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (86, 411, 87, 3, 953.0, 'BILL0086', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (87, 184, 105, 8, 625.96, 'BILL0087', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (88, 717, 451, 3, 591.88, 'BILL0088', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (89, 229, 31, 5, 885.53, 'BILL0089', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (90, 81, 89, 3, 700.22, 'BILL0090', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (91, 640, 295, 10, 766.2, 'BILL0091', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (92, 843, 491, 3, 410.92, 'BILL0092', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (93, 729, 44, 1, 456.07, 'BILL0093', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (94, 970, 256, 7, 869.38, 'BILL0094', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (95, 428, 359, 9, 437.67, 'BILL0095', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (96, 248, 172, 10, 443.77, 'BILL0096', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (97, 476, 123, 3, 624.5, 'BILL0097', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (98, 314, 495, 2, 847.45, 'BILL0098', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (99, 371, 70, 5, 543.31, 'BILL0099', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (100, 49, 382, 5, 132.48, 'BILL0100', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (101, 630, 216, 6, 132.26, 'BILL0101', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (102, 253, 46, 1, 343.56, 'BILL0102', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (103, 752, 405, 1, 381.61, 'BILL0103', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (104, 610, 1, 4, 318.99, 'BILL0104', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (105, 315, 357, 1, 594.59, 'BILL0105', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (106, 730, 317, 6, 894.43, 'BILL0106', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (107, 420, 491, 1, 343.36, 'BILL0107', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (108, 923, 161, 1, 310.81, 'BILL0108', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (109, 864, 167, 2, 408.31, 'BILL0109', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (110, 374, 261, 4, 455.38, 'BILL0110', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (111, 147, 258, 7, 237.38, 'BILL0111', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (112, 531, 17, 3, 474.07, 'BILL0112', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (113, 886, 433, 5, 378.73, 'BILL0113', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (114, 340, 19, 10, 377.38, 'BILL0114', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (115, 652, 499, 8, 463.71, 'BILL0115', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (116, 382, 462, 10, 313.79, 'BILL0116', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (117, 803, 5, 9, 720.84, 'BILL0117', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (118, 337, 383, 3, 659.32, 'BILL0118', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (119, 320, 393, 1, 149.33, 'BILL0119', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (120, 773, 21, 3, 905.96, 'BILL0120', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (121, 639, 336, 6, 427.84, 'BILL0121', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (122, 818, 451, 6, 808.59, 'BILL0122', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (123, 529, 266, 7, 927.63, 'BILL0123', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (124, 613, 186, 3, 444.34, 'BILL0124', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (125, 180, 308, 5, 204.15, 'BILL0125', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (126, 324, 349, 7, 320.19, 'BILL0126', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (127, 992, 344, 9, 165.9, 'BILL0127', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (128, 265, 299, 2, 693.25, 'BILL0128', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (129, 12, 457, 10, 485.92, 'BILL0129', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (130, 558, 105, 2, 565.11, 'BILL0130', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (131, 684, 127, 7, 258.11, 'BILL0131', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (132, 739, 272, 8, 753.02, 'BILL0132', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (133, 688, 405, 10, 721.42, 'BILL0133', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (134, 351, 329, 10, 458.81, 'BILL0134', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (135, 832, 84, 1, 135.06, 'BILL0135', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (136, 759, 228, 9, 895.38, 'BILL0136', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (137, 461, 466, 2, 207.69, 'BILL0137', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (138, 831, 258, 9, 300.3, 'BILL0138', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (139, 648, 142, 10, 704.0, 'BILL0139', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (140, 846, 154, 10, 499.92, 'BILL0140', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (141, 518, 313, 6, 326.54, 'BILL0141', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (142, 910, 463, 1, 781.67, 'BILL0142', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (143, 269, 496, 9, 921.58, 'BILL0143', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (144, 584, 126, 1, 609.21, 'BILL0144', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (145, 685, 86, 2, 229.54, 'BILL0145', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (146, 66, 154, 6, 161.75, 'BILL0146', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (147, 961, 218, 3, 638.4, 'BILL0147', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (148, 651, 306, 1, 973.12, 'BILL0148', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (149, 711, 282, 7, 134.09, 'BILL0149', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (150, 135, 137, 9, 241.56, 'BILL0150', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (151, 298, 434, 10, 957.05, 'BILL0151', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (152, 997, 323, 4, 404.9, 'BILL0152', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (153, 637, 249, 6, 902.05, 'BILL0153', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (154, 254, 222, 1, 191.6, 'BILL0154', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (155, 232, 65, 9, 650.59, 'BILL0155', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (156, 143, 438, 6, 997.16, 'BILL0156', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (157, 74, 264, 6, 870.9, 'BILL0157', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (158, 705, 251, 8, 323.35, 'BILL0158', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (159, 759, 400, 8, 857.83, 'BILL0159', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (160, 624, 349, 8, 670.08, 'BILL0160', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (161, 152, 109, 6, 517.43, 'BILL0161', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (162, 171, 266, 4, 707.45, 'BILL0162', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (163, 280, 305, 3, 409.78, 'BILL0163', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (164, 558, 4, 8, 890.45, 'BILL0164', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (165, 317, 500, 5, 105.66, 'BILL0165', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (166, 722, 498, 10, 359.85, 'BILL0166', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (167, 371, 215, 1, 809.92, 'BILL0167', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (168, 659, 319, 1, 426.28, 'BILL0168', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (169, 316, 343, 1, 171.64, 'BILL0169', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (170, 591, 36, 4, 733.82, 'BILL0170', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (171, 615, 137, 4, 731.66, 'BILL0171', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (172, 253, 323, 2, 533.89, 'BILL0172', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (173, 473, 132, 9, 144.76, 'BILL0173', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (174, 514, 213, 9, 630.81, 'BILL0174', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (175, 113, 170, 1, 839.93, 'BILL0175', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (176, 884, 204, 4, 867.0, 'BILL0176', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (177, 620, 72, 8, 542.0, 'BILL0177', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (178, 892, 411, 3, 302.49, 'BILL0178', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (179, 925, 414, 10, 856.56, 'BILL0179', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (180, 488, 370, 1, 589.58, 'BILL0180', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (181, 249, 337, 2, 324.2, 'BILL0181', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (182, 641, 366, 4, 478.46, 'BILL0182', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (183, 592, 112, 5, 220.24, 'BILL0183', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (184, 540, 259, 1, 395.09, 'BILL0184', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (185, 976, 302, 6, 837.63, 'BILL0185', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (186, 211, 38, 8, 955.12, 'BILL0186', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (187, 728, 384, 3, 545.73, 'BILL0187', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (188, 372, 395, 7, 777.59, 'BILL0188', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (189, 845, 423, 1, 127.75, 'BILL0189', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (190, 656, 260, 2, 411.46, 'BILL0190', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (191, 21, 40, 2, 329.97, 'BILL0191', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (192, 804, 445, 5, 888.24, 'BILL0192', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (193, 394, 493, 1, 651.09, 'BILL0193', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (194, 577, 120, 9, 385.81, 'BILL0194', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (195, 47, 292, 4, 409.8, 'BILL0195', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (196, 212, 169, 3, 715.96, 'BILL0196', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (197, 111, 221, 3, 292.67, 'BILL0197', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (198, 777, 186, 1, 658.52, 'BILL0198', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (199, 719, 497, 5, 132.59, 'BILL0199', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (200, 804, 231, 4, 382.8, 'BILL0200', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (201, 599, 266, 3, 757.17, 'BILL0201', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (202, 147, 46, 10, 905.39, 'BILL0202', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (203, 280, 444, 9, 462.73, 'BILL0203', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (204, 585, 136, 2, 954.68, 'BILL0204', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (205, 948, 106, 6, 544.43, 'BILL0205', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (206, 977, 177, 9, 653.26, 'BILL0206', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (207, 116, 453, 8, 925.98, 'BILL0207', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (208, 26, 77, 4, 305.47, 'BILL0208', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (209, 792, 411, 3, 960.16, 'BILL0209', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (210, 645, 99, 4, 647.93, 'BILL0210', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (211, 951, 118, 1, 100.64, 'BILL0211', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (212, 544, 448, 8, 105.16, 'BILL0212', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (213, 156, 201, 1, 851.12, 'BILL0213', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (214, 834, 464, 3, 884.07, 'BILL0214', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (215, 939, 52, 1, 744.11, 'BILL0215', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (216, 692, 475, 7, 678.67, 'BILL0216', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (217, 443, 185, 3, 924.28, 'BILL0217', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (218, 191, 191, 4, 637.6, 'BILL0218', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (219, 383, 132, 6, 503.36, 'BILL0219', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (220, 781, 382, 6, 860.44, 'BILL0220', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (221, 808, 353, 10, 725.2, 'BILL0221', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (222, 674, 191, 2, 411.2, 'BILL0222', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (223, 109, 385, 4, 290.77, 'BILL0223', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (224, 712, 284, 1, 508.06, 'BILL0224', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (225, 442, 416, 9, 166.53, 'BILL0225', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (226, 506, 416, 4, 999.31, 'BILL0226', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (227, 87, 358, 4, 238.54, 'BILL0227', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (228, 134, 15, 8, 980.79, 'BILL0228', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (229, 573, 43, 1, 492.89, 'BILL0229', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (230, 866, 282, 2, 134.79, 'BILL0230', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (231, 299, 206, 1, 279.87, 'BILL0231', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (232, 149, 181, 9, 231.16, 'BILL0232', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (233, 815, 154, 9, 783.77, 'BILL0233', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (234, 122, 93, 5, 563.38, 'BILL0234', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (235, 201, 38, 5, 134.24, 'BILL0235', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (236, 157, 180, 4, 834.22, 'BILL0236', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (237, 152, 89, 4, 923.74, 'BILL0237', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (238, 721, 317, 8, 694.53, 'BILL0238', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (239, 812, 306, 7, 966.23, 'BILL0239', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (240, 175, 133, 8, 473.14, 'BILL0240', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (241, 319, 160, 5, 133.85, 'BILL0241', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (242, 392, 147, 7, 114.08, 'BILL0242', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (243, 133, 33, 4, 751.56, 'BILL0243', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (244, 868, 229, 5, 482.21, 'BILL0244', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (245, 216, 467, 8, 587.69, 'BILL0245', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (246, 255, 472, 10, 373.81, 'BILL0246', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (247, 979, 428, 2, 815.68, 'BILL0247', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (248, 178, 137, 9, 535.43, 'BILL0248', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (249, 195, 184, 3, 925.23, 'BILL0249', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (250, 51, 106, 1, 976.81, 'BILL0250', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (251, 596, 176, 9, 559.37, 'BILL0251', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (252, 357, 304, 9, 489.91, 'BILL0252', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (253, 766, 488, 8, 626.18, 'BILL0253', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (254, 410, 357, 10, 987.89, 'BILL0254', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (255, 308, 174, 2, 527.28, 'BILL0255', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (256, 326, 495, 4, 264.87, 'BILL0256', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (257, 752, 380, 5, 944.56, 'BILL0257', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (258, 401, 485, 3, 780.06, 'BILL0258', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (259, 649, 175, 5, 224.71, 'BILL0259', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (260, 705, 312, 3, 756.46, 'BILL0260', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (261, 337, 393, 6, 573.98, 'BILL0261', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (262, 308, 168, 3, 717.18, 'BILL0262', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (263, 282, 424, 8, 726.02, 'BILL0263', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (264, 7, 150, 10, 832.56, 'BILL0264', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (265, 480, 242, 7, 401.01, 'BILL0265', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (266, 337, 252, 9, 751.15, 'BILL0266', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (267, 701, 341, 7, 203.4, 'BILL0267', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (268, 795, 321, 2, 132.02, 'BILL0268', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (269, 569, 392, 4, 793.93, 'BILL0269', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (270, 339, 141, 4, 559.77, 'BILL0270', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (271, 66, 490, 6, 685.28, 'BILL0271', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (272, 411, 189, 6, 343.59, 'BILL0272', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (273, 952, 356, 6, 383.89, 'BILL0273', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (274, 637, 220, 2, 964.5, 'BILL0274', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (275, 144, 51, 10, 312.45, 'BILL0275', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (276, 843, 52, 4, 763.75, 'BILL0276', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (277, 114, 252, 6, 904.53, 'BILL0277', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (278, 303, 498, 5, 803.55, 'BILL0278', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (279, 442, 429, 9, 449.2, 'BILL0279', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (280, 441, 250, 8, 588.01, 'BILL0280', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (281, 652, 481, 10, 212.75, 'BILL0281', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (282, 684, 192, 10, 293.1, 'BILL0282', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (283, 817, 402, 3, 179.2, 'BILL0283', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (284, 806, 346, 8, 722.99, 'BILL0284', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (285, 284, 477, 5, 121.3, 'BILL0285', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (286, 61, 375, 10, 153.25, 'BILL0286', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (287, 380, 210, 1, 399.68, 'BILL0287', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (288, 174, 189, 4, 859.64, 'BILL0288', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (289, 300, 396, 5, 365.67, 'BILL0289', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (290, 569, 222, 3, 151.94, 'BILL0290', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (291, 81, 134, 7, 117.52, 'BILL0291', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (292, 154, 100, 9, 848.09, 'BILL0292', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (293, 25, 394, 2, 680.34, 'BILL0293', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (294, 455, 143, 7, 620.82, 'BILL0294', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (295, 615, 68, 1, 625.73, 'BILL0295', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (296, 159, 440, 2, 826.6, 'BILL0296', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (297, 387, 125, 8, 592.47, 'BILL0297', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (298, 355, 249, 9, 808.68, 'BILL0298', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (299, 35, 399, 10, 191.53, 'BILL0299', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (300, 396, 139, 6, 386.49, 'BILL0300', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (301, 754, 478, 10, 954.93, 'BILL0301', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (302, 91, 239, 3, 184.95, 'BILL0302', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (303, 756, 168, 5, 641.62, 'BILL0303', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (304, 605, 114, 2, 912.35, 'BILL0304', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (305, 720, 4, 8, 889.93, 'BILL0305', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (306, 943, 50, 3, 499.3, 'BILL0306', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (307, 573, 70, 9, 961.53, 'BILL0307', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (308, 913, 490, 2, 685.97, 'BILL0308', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (309, 688, 15, 5, 607.73, 'BILL0309', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (310, 602, 223, 5, 832.52, 'BILL0310', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (311, 178, 235, 7, 786.93, 'BILL0311', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (312, 736, 144, 3, 489.3, 'BILL0312', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (313, 584, 185, 2, 385.7, 'BILL0313', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (314, 867, 328, 2, 726.28, 'BILL0314', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (315, 354, 187, 7, 590.06, 'BILL0315', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (316, 84, 454, 8, 769.71, 'BILL0316', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (317, 418, 236, 1, 494.98, 'BILL0317', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (318, 408, 365, 8, 249.99, 'BILL0318', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (319, 719, 55, 9, 957.61, 'BILL0319', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (320, 854, 365, 2, 982.95, 'BILL0320', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (321, 500, 213, 10, 380.72, 'BILL0321', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (322, 162, 117, 8, 965.9, 'BILL0322', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (323, 932, 456, 5, 113.87, 'BILL0323', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (324, 240, 263, 5, 187.94, 'BILL0324', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (325, 323, 33, 8, 700.81, 'BILL0325', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (326, 371, 337, 10, 180.39, 'BILL0326', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (327, 917, 115, 4, 546.0, 'BILL0327', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (328, 438, 344, 10, 147.78, 'BILL0328', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (329, 486, 464, 6, 149.26, 'BILL0329', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (330, 687, 195, 4, 766.58, 'BILL0330', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (331, 428, 488, 4, 368.03, 'BILL0331', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (332, 580, 244, 1, 596.0, 'BILL0332', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (333, 88, 233, 10, 901.67, 'BILL0333', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (334, 279, 115, 4, 388.03, 'BILL0334', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (335, 22, 23, 10, 605.7, 'BILL0335', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (336, 652, 470, 9, 838.15, 'BILL0336', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (337, 948, 216, 4, 217.7, 'BILL0337', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (338, 601, 208, 8, 952.58, 'BILL0338', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (339, 531, 333, 6, 440.18, 'BILL0339', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (340, 251, 425, 1, 708.65, 'BILL0340', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (341, 350, 268, 6, 767.0, 'BILL0341', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (342, 111, 85, 5, 672.88, 'BILL0342', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (343, 166, 471, 7, 904.98, 'BILL0343', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (344, 728, 481, 9, 409.09, 'BILL0344', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (345, 253, 77, 2, 615.53, 'BILL0345', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (346, 840, 433, 4, 336.38, 'BILL0346', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (347, 283, 38, 1, 417.96, 'BILL0347', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (348, 889, 187, 10, 440.44, 'BILL0348', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (349, 561, 500, 4, 240.11, 'BILL0349', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (350, 441, 88, 3, 698.24, 'BILL0350', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (351, 872, 132, 1, 491.73, 'BILL0351', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (352, 145, 358, 5, 648.47, 'BILL0352', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (353, 253, 391, 8, 338.64, 'BILL0353', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (354, 619, 424, 10, 749.46, 'BILL0354', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (355, 254, 319, 6, 609.37, 'BILL0355', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (356, 940, 311, 1, 930.2, 'BILL0356', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (357, 176, 292, 5, 613.32, 'BILL0357', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (358, 637, 106, 3, 107.13, 'BILL0358', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (359, 789, 429, 8, 168.19, 'BILL0359', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (360, 804, 14, 6, 675.19, 'BILL0360', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (361, 40, 302, 6, 822.7, 'BILL0361', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (362, 453, 237, 1, 198.87, 'BILL0362', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (363, 27, 262, 3, 672.66, 'BILL0363', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (364, 521, 287, 2, 337.3, 'BILL0364', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (365, 91, 2, 3, 692.88, 'BILL0365', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (366, 74, 199, 6, 940.82, 'BILL0366', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (367, 299, 318, 5, 155.99, 'BILL0367', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (368, 927, 406, 3, 246.82, 'BILL0368', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (369, 536, 483, 9, 753.27, 'BILL0369', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (370, 111, 99, 6, 226.43, 'BILL0370', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (371, 298, 431, 3, 930.88, 'BILL0371', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (372, 35, 455, 7, 450.39, 'BILL0372', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (373, 976, 69, 2, 382.61, 'BILL0373', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (374, 615, 75, 6, 437.63, 'BILL0374', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (375, 560, 386, 8, 115.31, 'BILL0375', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (376, 173, 39, 9, 342.84, 'BILL0376', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (377, 488, 105, 10, 132.16, 'BILL0377', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (378, 645, 280, 9, 120.63, 'BILL0378', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (379, 634, 149, 5, 568.98, 'BILL0379', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (380, 628, 94, 2, 436.81, 'BILL0380', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (381, 729, 357, 8, 513.69, 'BILL0381', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (382, 325, 131, 5, 260.41, 'BILL0382', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (383, 894, 274, 4, 521.57, 'BILL0383', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (384, 280, 40, 2, 328.48, 'BILL0384', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (385, 111, 264, 6, 314.55, 'BILL0385', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (386, 700, 304, 6, 869.96, 'BILL0386', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (387, 769, 267, 6, 569.79, 'BILL0387', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (388, 971, 445, 8, 777.43, 'BILL0388', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (389, 515, 312, 2, 328.82, 'BILL0389', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (390, 433, 175, 9, 475.08, 'BILL0390', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (391, 950, 372, 10, 976.15, 'BILL0391', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (392, 539, 374, 8, 479.87, 'BILL0392', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (393, 663, 348, 4, 398.91, 'BILL0393', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (394, 44, 171, 1, 677.31, 'BILL0394', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (395, 637, 437, 9, 931.04, 'BILL0395', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (396, 645, 232, 8, 189.48, 'BILL0396', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (397, 387, 408, 9, 277.75, 'BILL0397', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (398, 813, 441, 8, 257.48, 'BILL0398', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (399, 392, 489, 1, 280.21, 'BILL0399', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (400, 358, 380, 1, 922.02, 'BILL0400', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (401, 52, 225, 1, 130.64, 'BILL0401', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (402, 133, 79, 10, 288.68, 'BILL0402', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (403, 860, 397, 4, 220.1, 'BILL0403', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (404, 968, 169, 1, 302.13, 'BILL0404', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (405, 160, 366, 4, 476.24, 'BILL0405', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (406, 470, 71, 2, 559.94, 'BILL0406', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (407, 579, 169, 6, 351.66, 'BILL0407', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (408, 246, 202, 6, 751.02, 'BILL0408', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (409, 126, 338, 8, 535.03, 'BILL0409', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (410, 144, 220, 2, 612.19, 'BILL0410', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (411, 842, 44, 7, 416.52, 'BILL0411', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (412, 767, 113, 7, 877.14, 'BILL0412', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (413, 188, 380, 8, 645.16, 'BILL0413', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (414, 163, 425, 8, 742.3, 'BILL0414', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (415, 96, 335, 8, 531.0, 'BILL0415', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (416, 162, 224, 1, 296.33, 'BILL0416', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (417, 511, 196, 1, 189.57, 'BILL0417', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (418, 848, 290, 10, 891.25, 'BILL0418', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (419, 886, 381, 4, 230.89, 'BILL0419', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (420, 245, 50, 8, 225.61, 'BILL0420', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (421, 363, 359, 2, 134.72, 'BILL0421', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (422, 264, 166, 8, 918.26, 'BILL0422', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (423, 836, 416, 4, 840.22, 'BILL0423', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (424, 739, 491, 2, 910.97, 'BILL0424', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (425, 177, 75, 4, 113.56, 'BILL0425', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (426, 190, 104, 10, 416.23, 'BILL0426', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (427, 494, 415, 2, 316.86, 'BILL0427', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (428, 664, 58, 4, 874.58, 'BILL0428', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (429, 818, 414, 5, 826.96, 'BILL0429', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (430, 451, 415, 1, 576.25, 'BILL0430', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (431, 229, 77, 4, 723.41, 'BILL0431', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (432, 395, 229, 5, 988.98, 'BILL0432', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (433, 467, 439, 4, 457.01, 'BILL0433', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (434, 813, 212, 1, 444.98, 'BILL0434', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (435, 217, 270, 5, 530.77, 'BILL0435', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (436, 985, 142, 5, 181.94, 'BILL0436', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (437, 320, 328, 6, 167.62, 'BILL0437', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (438, 879, 324, 6, 559.59, 'BILL0438', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (439, 488, 384, 3, 259.22, 'BILL0439', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (440, 305, 401, 5, 164.13, 'BILL0440', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (441, 125, 219, 2, 434.32, 'BILL0441', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (442, 959, 458, 6, 912.95, 'BILL0442', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (443, 124, 220, 7, 973.13, 'BILL0443', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (444, 701, 389, 10, 100.78, 'BILL0444', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (445, 484, 476, 3, 642.31, 'BILL0445', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (446, 389, 151, 6, 985.72, 'BILL0446', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (447, 488, 234, 6, 977.31, 'BILL0447', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (448, 410, 226, 9, 176.23, 'BILL0448', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (449, 508, 301, 6, 398.27, 'BILL0449', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (450, 390, 209, 2, 999.46, 'BILL0450', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (451, 624, 61, 6, 555.1, 'BILL0451', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (452, 699, 434, 1, 934.06, 'BILL0452', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (453, 385, 101, 7, 675.1, 'BILL0453', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (454, 622, 53, 4, 704.15, 'BILL0454', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (455, 416, 135, 8, 614.79, 'BILL0455', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (456, 779, 39, 4, 401.33, 'BILL0456', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (457, 178, 271, 2, 785.19, 'BILL0457', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (458, 251, 100, 5, 557.33, 'BILL0458', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (459, 675, 68, 10, 776.83, 'BILL0459', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (460, 171, 119, 6, 109.04, 'BILL0460', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (461, 481, 252, 5, 897.83, 'BILL0461', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (462, 878, 152, 9, 240.83, 'BILL0462', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (463, 750, 199, 4, 903.69, 'BILL0463', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (464, 540, 307, 10, 538.78, 'BILL0464', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (465, 61, 354, 6, 830.76, 'BILL0465', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (466, 682, 217, 4, 813.55, 'BILL0466', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (467, 668, 206, 10, 465.21, 'BILL0467', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (468, 974, 225, 3, 810.12, 'BILL0468', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (469, 269, 477, 7, 201.46, 'BILL0469', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (470, 685, 289, 6, 937.28, 'BILL0470', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (471, 294, 75, 3, 617.77, 'BILL0471', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (472, 213, 364, 8, 243.4, 'BILL0472', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (473, 741, 80, 8, 709.99, 'BILL0473', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (474, 823, 289, 1, 704.27, 'BILL0474', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (475, 593, 217, 7, 278.44, 'BILL0475', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (476, 920, 388, 6, 224.61, 'BILL0476', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (477, 237, 72, 4, 646.75, 'BILL0477', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (478, 156, 18, 10, 950.59, 'BILL0478', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (479, 583, 46, 5, 354.57, 'BILL0479', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (480, 577, 272, 5, 854.39, 'BILL0480', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (481, 9, 238, 2, 429.05, 'BILL0481', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (482, 233, 81, 5, 969.94, 'BILL0482', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (483, 113, 292, 3, 225.48, 'BILL0483', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (484, 595, 484, 2, 720.11, 'BILL0484', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (485, 802, 461, 4, 278.78, 'BILL0485', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (486, 949, 128, 4, 795.81, 'BILL0486', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (487, 502, 406, 3, 159.42, 'BILL0487', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (488, 363, 176, 4, 421.17, 'BILL0488', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (489, 662, 206, 1, 104.45, 'BILL0489', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (490, 980, 389, 5, 454.89, 'BILL0490', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (491, 620, 248, 8, 384.61, 'BILL0491', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (492, 828, 272, 5, 389.74, 'BILL0492', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (493, 552, 284, 3, 784.12, 'BILL0493', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (494, 802, 357, 7, 635.19, 'BILL0494', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (495, 415, 454, 1, 536.99, 'BILL0495', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (496, 283, 124, 8, 542.51, 'BILL0496', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (497, 298, 479, 3, 981.5, 'BILL0497', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (498, 593, 146, 10, 998.03, 'BILL0498', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (499, 772, 441, 10, 652.78, 'BILL0499', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (500, 149, 121, 2, 700.07, 'BILL0500', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (501, 769, 466, 4, 942.56, 'BILL0501', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (502, 169, 372, 6, 577.96, 'BILL0502', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (503, 842, 113, 3, 217.34, 'BILL0503', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (504, 488, 239, 2, 461.82, 'BILL0504', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (505, 152, 322, 10, 499.26, 'BILL0505', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (506, 51, 145, 5, 237.26, 'BILL0506', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (507, 659, 425, 6, 339.63, 'BILL0507', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (508, 215, 178, 10, 350.21, 'BILL0508', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (509, 579, 159, 1, 845.38, 'BILL0509', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (510, 847, 20, 10, 585.77, 'BILL0510', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (511, 181, 338, 4, 140.21, 'BILL0511', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (512, 782, 436, 9, 299.58, 'BILL0512', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (513, 474, 112, 4, 763.03, 'BILL0513', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (514, 392, 221, 3, 999.07, 'BILL0514', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (515, 946, 267, 7, 748.23, 'BILL0515', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (516, 255, 403, 3, 618.56, 'BILL0516', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (517, 651, 95, 10, 506.64, 'BILL0517', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (518, 451, 470, 1, 965.51, 'BILL0518', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (519, 463, 42, 2, 320.09, 'BILL0519', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (520, 100, 485, 1, 636.21, 'BILL0520', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (521, 394, 124, 3, 133.31, 'BILL0521', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (522, 365, 100, 7, 914.78, 'BILL0522', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (523, 910, 95, 8, 123.58, 'BILL0523', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (524, 242, 406, 9, 274.86, 'BILL0524', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (525, 419, 123, 4, 436.11, 'BILL0525', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (526, 772, 140, 4, 689.05, 'BILL0526', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (527, 345, 328, 8, 343.57, 'BILL0527', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (528, 99, 479, 1, 460.44, 'BILL0528', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (529, 598, 22, 10, 498.38, 'BILL0529', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (530, 785, 411, 2, 373.16, 'BILL0530', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (531, 535, 40, 8, 477.54, 'BILL0531', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (532, 3, 317, 9, 383.9, 'BILL0532', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (533, 808, 229, 7, 990.56, 'BILL0533', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (534, 842, 452, 9, 564.39, 'BILL0534', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (535, 576, 239, 2, 434.23, 'BILL0535', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (536, 388, 360, 1, 483.27, 'BILL0536', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (537, 915, 169, 3, 981.58, 'BILL0537', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (538, 175, 338, 9, 970.86, 'BILL0538', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (539, 573, 117, 7, 990.76, 'BILL0539', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (540, 80, 416, 5, 937.58, 'BILL0540', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (541, 20, 27, 9, 993.0, 'BILL0541', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (542, 378, 472, 8, 687.32, 'BILL0542', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (543, 209, 302, 7, 105.14, 'BILL0543', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (544, 971, 175, 5, 328.66, 'BILL0544', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (545, 534, 170, 8, 558.02, 'BILL0545', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (546, 890, 455, 6, 288.97, 'BILL0546', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (547, 261, 38, 2, 940.58, 'BILL0547', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (548, 954, 100, 8, 266.1, 'BILL0548', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (549, 260, 288, 4, 449.33, 'BILL0549', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (550, 925, 319, 7, 869.33, 'BILL0550', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (551, 390, 207, 2, 445.14, 'BILL0551', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (552, 989, 70, 2, 839.51, 'BILL0552', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (553, 381, 66, 5, 996.48, 'BILL0553', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (554, 182, 400, 3, 939.4, 'BILL0554', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (555, 137, 180, 7, 913.98, 'BILL0555', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (556, 149, 311, 8, 306.56, 'BILL0556', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (557, 348, 403, 8, 194.0, 'BILL0557', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (558, 303, 312, 7, 432.48, 'BILL0558', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (559, 187, 148, 10, 154.45, 'BILL0559', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (560, 8, 254, 3, 858.59, 'BILL0560', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (561, 236, 59, 9, 646.95, 'BILL0561', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (562, 683, 41, 7, 347.6, 'BILL0562', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (563, 803, 405, 9, 773.93, 'BILL0563', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (564, 861, 70, 4, 453.15, 'BILL0564', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (565, 190, 38, 10, 468.89, 'BILL0565', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (566, 894, 96, 3, 601.77, 'BILL0566', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (567, 834, 440, 6, 471.16, 'BILL0567', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (568, 31, 219, 1, 522.22, 'BILL0568', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (569, 490, 288, 4, 239.67, 'BILL0569', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (570, 428, 468, 4, 174.44, 'BILL0570', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (571, 845, 40, 2, 404.18, 'BILL0571', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (572, 574, 451, 7, 766.27, 'BILL0572', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (573, 160, 314, 9, 426.64, 'BILL0573', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (574, 2, 445, 10, 669.75, 'BILL0574', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (575, 193, 117, 8, 118.82, 'BILL0575', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (576, 105, 50, 5, 393.51, 'BILL0576', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (577, 453, 239, 10, 867.01, 'BILL0577', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (578, 276, 478, 1, 383.42, 'BILL0578', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (579, 216, 426, 9, 810.24, 'BILL0579', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (580, 332, 331, 9, 408.26, 'BILL0580', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (581, 480, 201, 9, 183.08, 'BILL0581', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (582, 587, 72, 10, 359.54, 'BILL0582', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (583, 187, 265, 9, 136.27, 'BILL0583', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (584, 199, 399, 7, 976.65, 'BILL0584', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (585, 324, 30, 8, 877.42, 'BILL0585', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (586, 246, 205, 10, 839.28, 'BILL0586', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (587, 57, 36, 5, 980.21, 'BILL0587', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (588, 871, 303, 9, 816.98, 'BILL0588', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (589, 811, 431, 5, 233.93, 'BILL0589', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (590, 15, 37, 3, 184.61, 'BILL0590', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (591, 536, 296, 8, 560.75, 'BILL0591', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (592, 613, 82, 3, 644.8, 'BILL0592', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (593, 634, 361, 1, 687.92, 'BILL0593', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (594, 882, 198, 7, 229.91, 'BILL0594', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (595, 141, 68, 5, 843.55, 'BILL0595', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (596, 238, 391, 6, 516.83, 'BILL0596', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (597, 21, 123, 4, 760.18, 'BILL0597', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (598, 744, 482, 9, 834.24, 'BILL0598', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (599, 931, 231, 4, 474.69, 'BILL0599', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (600, 165, 133, 4, 591.96, 'BILL0600', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (601, 290, 398, 7, 617.34, 'BILL0601', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (602, 585, 199, 1, 318.43, 'BILL0602', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (603, 863, 465, 10, 830.72, 'BILL0603', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (604, 300, 197, 10, 401.33, 'BILL0604', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (605, 196, 91, 7, 676.91, 'BILL0605', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (606, 848, 130, 4, 905.54, 'BILL0606', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (607, 858, 423, 5, 744.37, 'BILL0607', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (608, 88, 30, 3, 266.58, 'BILL0608', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (609, 220, 112, 9, 298.9, 'BILL0609', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (610, 857, 339, 6, 863.36, 'BILL0610', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (611, 660, 382, 2, 606.15, 'BILL0611', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (612, 544, 325, 7, 506.65, 'BILL0612', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (613, 381, 296, 5, 321.52, 'BILL0613', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (614, 16, 124, 4, 862.66, 'BILL0614', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (615, 681, 214, 5, 756.18, 'BILL0615', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (616, 472, 136, 3, 176.95, 'BILL0616', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (617, 18, 213, 6, 177.88, 'BILL0617', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (618, 874, 23, 3, 245.28, 'BILL0618', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (619, 30, 418, 1, 934.45, 'BILL0619', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (620, 438, 467, 6, 293.93, 'BILL0620', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (621, 406, 355, 6, 735.94, 'BILL0621', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (622, 559, 158, 2, 755.97, 'BILL0622', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (623, 152, 255, 9, 647.45, 'BILL0623', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (624, 677, 449, 4, 192.52, 'BILL0624', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (625, 210, 110, 2, 683.87, 'BILL0625', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (626, 899, 153, 8, 115.45, 'BILL0626', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (627, 303, 315, 7, 573.68, 'BILL0627', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (628, 407, 5, 5, 717.98, 'BILL0628', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (629, 542, 447, 4, 207.45, 'BILL0629', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (630, 109, 245, 6, 926.85, 'BILL0630', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (631, 983, 178, 6, 824.8, 'BILL0631', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (632, 96, 461, 2, 415.74, 'BILL0632', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (633, 191, 346, 7, 785.3, 'BILL0633', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (634, 516, 219, 8, 309.51, 'BILL0634', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (635, 757, 195, 7, 899.14, 'BILL0635', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (636, 536, 48, 8, 399.21, 'BILL0636', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (637, 39, 86, 6, 704.01, 'BILL0637', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (638, 30, 225, 8, 445.55, 'BILL0638', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (639, 856, 3, 6, 989.65, 'BILL0639', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (640, 598, 267, 6, 653.7, 'BILL0640', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (641, 863, 201, 4, 966.97, 'BILL0641', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (642, 421, 409, 3, 547.31, 'BILL0642', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (643, 770, 496, 6, 218.6, 'BILL0643', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (644, 581, 28, 2, 121.79, 'BILL0644', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (645, 176, 177, 6, 149.44, 'BILL0645', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (646, 871, 443, 6, 924.38, 'BILL0646', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (647, 633, 430, 4, 614.99, 'BILL0647', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (648, 868, 414, 3, 472.29, 'BILL0648', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (649, 807, 92, 6, 146.72, 'BILL0649', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (650, 996, 312, 1, 677.6, 'BILL0650', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (651, 414, 330, 4, 159.19, 'BILL0651', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (652, 152, 130, 4, 958.4, 'BILL0652', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (653, 253, 135, 1, 223.51, 'BILL0653', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (654, 145, 400, 8, 877.64, 'BILL0654', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (655, 473, 239, 1, 389.34, 'BILL0655', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (656, 205, 173, 5, 903.73, 'BILL0656', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (657, 768, 285, 5, 682.34, 'BILL0657', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (658, 474, 353, 9, 457.46, 'BILL0658', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (659, 843, 365, 3, 470.95, 'BILL0659', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (660, 170, 337, 4, 605.1, 'BILL0660', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (661, 237, 53, 8, 961.1, 'BILL0661', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (662, 946, 320, 2, 561.94, 'BILL0662', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (663, 7, 212, 4, 441.34, 'BILL0663', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (664, 761, 133, 9, 609.25, 'BILL0664', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (665, 953, 408, 5, 496.55, 'BILL0665', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (666, 668, 71, 4, 253.47, 'BILL0666', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (667, 407, 51, 5, 670.19, 'BILL0667', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (668, 935, 197, 4, 662.36, 'BILL0668', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (669, 532, 415, 9, 902.96, 'BILL0669', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (670, 629, 300, 8, 339.8, 'BILL0670', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (671, 759, 254, 6, 461.36, 'BILL0671', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (672, 861, 76, 4, 288.6, 'BILL0672', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (673, 311, 130, 2, 472.78, 'BILL0673', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (674, 16, 378, 4, 786.24, 'BILL0674', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (675, 735, 21, 3, 171.37, 'BILL0675', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (676, 454, 136, 8, 583.02, 'BILL0676', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (677, 729, 377, 9, 796.09, 'BILL0677', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (678, 229, 237, 3, 229.69, 'BILL0678', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (679, 280, 143, 9, 469.46, 'BILL0679', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (680, 121, 275, 5, 437.78, 'BILL0680', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (681, 848, 462, 10, 990.07, 'BILL0681', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (682, 226, 433, 3, 786.36, 'BILL0682', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (683, 335, 50, 9, 772.44, 'BILL0683', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (684, 759, 481, 4, 264.66, 'BILL0684', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (685, 346, 130, 2, 614.66, 'BILL0685', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (686, 678, 93, 1, 390.43, 'BILL0686', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (687, 365, 202, 10, 782.79, 'BILL0687', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (688, 851, 477, 3, 891.87, 'BILL0688', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (689, 197, 361, 4, 607.04, 'BILL0689', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (690, 633, 151, 6, 499.73, 'BILL0690', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (691, 825, 391, 9, 843.15, 'BILL0691', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (692, 245, 126, 1, 972.24, 'BILL0692', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (693, 885, 320, 3, 641.08, 'BILL0693', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (694, 138, 71, 1, 578.51, 'BILL0694', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (695, 683, 62, 8, 801.48, 'BILL0695', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (696, 354, 160, 3, 208.55, 'BILL0696', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (697, 567, 102, 1, 550.5, 'BILL0697', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (698, 656, 275, 1, 630.17, 'BILL0698', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (699, 41, 105, 4, 834.07, 'BILL0699', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (700, 266, 126, 2, 548.4, 'BILL0700', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (701, 595, 346, 6, 384.33, 'BILL0701', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (702, 497, 395, 6, 717.96, 'BILL0702', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (703, 457, 373, 1, 895.03, 'BILL0703', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (704, 716, 237, 5, 102.32, 'BILL0704', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (705, 532, 171, 10, 253.44, 'BILL0705', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (706, 309, 451, 8, 256.0, 'BILL0706', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (707, 796, 292, 3, 500.88, 'BILL0707', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (708, 633, 183, 4, 810.0, 'BILL0708', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (709, 541, 157, 6, 360.07, 'BILL0709', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (710, 977, 388, 5, 305.42, 'BILL0710', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (711, 722, 388, 9, 753.64, 'BILL0711', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (712, 831, 379, 7, 838.3, 'BILL0712', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (713, 358, 222, 9, 592.57, 'BILL0713', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (714, 846, 255, 9, 802.85, 'BILL0714', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (715, 493, 333, 6, 813.33, 'BILL0715', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (716, 240, 307, 9, 873.56, 'BILL0716', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (717, 288, 477, 2, 756.16, 'BILL0717', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (718, 845, 225, 5, 608.5, 'BILL0718', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (719, 937, 12, 1, 276.45, 'BILL0719', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (720, 805, 287, 8, 519.85, 'BILL0720', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (721, 407, 51, 9, 725.7, 'BILL0721', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (722, 26, 230, 6, 790.36, 'BILL0722', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (723, 625, 80, 7, 427.71, 'BILL0723', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (724, 355, 69, 4, 627.92, 'BILL0724', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (725, 149, 15, 10, 556.62, 'BILL0725', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (726, 202, 124, 4, 901.92, 'BILL0726', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (727, 699, 472, 3, 366.9, 'BILL0727', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (728, 389, 159, 5, 797.55, 'BILL0728', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (729, 185, 306, 1, 578.37, 'BILL0729', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (730, 139, 480, 5, 184.79, 'BILL0730', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (731, 373, 290, 9, 456.51, 'BILL0731', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (732, 974, 285, 5, 159.15, 'BILL0732', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (733, 435, 22, 6, 700.88, 'BILL0733', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (734, 121, 47, 1, 571.52, 'BILL0734', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (735, 633, 141, 3, 873.02, 'BILL0735', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (736, 996, 160, 1, 416.96, 'BILL0736', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (737, 143, 363, 2, 829.52, 'BILL0737', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (738, 656, 359, 2, 867.3, 'BILL0738', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (739, 472, 71, 8, 451.4, 'BILL0739', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (740, 795, 247, 4, 426.35, 'BILL0740', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (741, 800, 488, 8, 497.13, 'BILL0741', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (742, 380, 338, 8, 685.81, 'BILL0742', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (743, 592, 354, 2, 251.75, 'BILL0743', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (744, 844, 27, 4, 110.33, 'BILL0744', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (745, 76, 34, 2, 916.36, 'BILL0745', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (746, 395, 48, 2, 596.72, 'BILL0746', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (747, 421, 106, 8, 104.99, 'BILL0747', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (748, 242, 414, 2, 594.3, 'BILL0748', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (749, 781, 483, 3, 849.02, 'BILL0749', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (750, 590, 71, 8, 935.06, 'BILL0750', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (751, 111, 217, 5, 505.1, 'BILL0751', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (752, 49, 3, 2, 802.42, 'BILL0752', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (753, 522, 243, 5, 883.55, 'BILL0753', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (754, 29, 209, 4, 811.57, 'BILL0754', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (755, 733, 170, 6, 637.2, 'BILL0755', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (756, 164, 202, 3, 232.76, 'BILL0756', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (757, 181, 493, 5, 305.26, 'BILL0757', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (758, 658, 359, 8, 264.39, 'BILL0758', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (759, 36, 193, 5, 692.08, 'BILL0759', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (760, 855, 273, 6, 742.73, 'BILL0760', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (761, 413, 65, 5, 163.06, 'BILL0761', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (762, 372, 399, 5, 633.97, 'BILL0762', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (763, 719, 176, 3, 639.22, 'BILL0763', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (764, 385, 467, 10, 698.39, 'BILL0764', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (765, 947, 20, 4, 822.7, 'BILL0765', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (766, 451, 206, 9, 934.46, 'BILL0766', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (767, 331, 244, 9, 242.15, 'BILL0767', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (768, 781, 164, 8, 558.74, 'BILL0768', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (769, 395, 150, 9, 620.92, 'BILL0769', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (770, 465, 411, 5, 630.9, 'BILL0770', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (771, 721, 47, 8, 292.91, 'BILL0771', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (772, 339, 268, 9, 731.44, 'BILL0772', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (773, 218, 268, 10, 615.79, 'BILL0773', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (774, 413, 167, 5, 962.49, 'BILL0774', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (775, 992, 314, 4, 967.31, 'BILL0775', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (776, 499, 117, 2, 958.43, 'BILL0776', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (777, 546, 259, 8, 721.87, 'BILL0777', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (778, 191, 496, 7, 390.55, 'BILL0778', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (779, 743, 381, 7, 217.79, 'BILL0779', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (780, 597, 453, 1, 104.32, 'BILL0780', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (781, 700, 53, 4, 328.08, 'BILL0781', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (782, 592, 185, 9, 429.73, 'BILL0782', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (783, 473, 336, 7, 535.75, 'BILL0783', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (784, 596, 397, 7, 574.02, 'BILL0784', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (785, 569, 348, 1, 570.15, 'BILL0785', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (786, 733, 193, 1, 579.16, 'BILL0786', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (787, 549, 31, 1, 727.76, 'BILL0787', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (788, 992, 226, 4, 539.65, 'BILL0788', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (789, 305, 209, 8, 320.43, 'BILL0789', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (790, 884, 251, 4, 802.17, 'BILL0790', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (791, 628, 139, 2, 265.94, 'BILL0791', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (792, 605, 421, 4, 968.07, 'BILL0792', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (793, 671, 422, 1, 241.91, 'BILL0793', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (794, 307, 438, 8, 728.37, 'BILL0794', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (795, 620, 185, 6, 558.69, 'BILL0795', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (796, 836, 243, 2, 361.13, 'BILL0796', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (797, 483, 127, 8, 495.44, 'BILL0797', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (798, 992, 492, 7, 868.65, 'BILL0798', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (799, 270, 354, 8, 376.66, 'BILL0799', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (800, 778, 263, 3, 358.18, 'BILL0800', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (801, 15, 196, 1, 748.69, 'BILL0801', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (802, 594, 235, 3, 449.69, 'BILL0802', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (803, 532, 167, 1, 934.93, 'BILL0803', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (804, 612, 404, 6, 715.98, 'BILL0804', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (805, 752, 303, 6, 872.17, 'BILL0805', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (806, 146, 204, 3, 678.15, 'BILL0806', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (807, 778, 480, 9, 746.81, 'BILL0807', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (808, 511, 358, 6, 768.83, 'BILL0808', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (809, 385, 305, 10, 641.63, 'BILL0809', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (810, 535, 25, 3, 280.81, 'BILL0810', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (811, 311, 334, 6, 648.8, 'BILL0811', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (812, 276, 213, 9, 406.62, 'BILL0812', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (813, 164, 217, 3, 819.31, 'BILL0813', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (814, 671, 109, 7, 108.74, 'BILL0814', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (815, 817, 302, 5, 135.0, 'BILL0815', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (816, 610, 484, 5, 126.45, 'BILL0816', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (817, 93, 49, 1, 694.85, 'BILL0817', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (818, 87, 442, 9, 942.47, 'BILL0818', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (819, 929, 374, 7, 864.32, 'BILL0819', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (820, 582, 414, 8, 255.48, 'BILL0820', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (821, 31, 485, 6, 622.32, 'BILL0821', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (822, 406, 382, 7, 624.9, 'BILL0822', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (823, 575, 179, 2, 981.98, 'BILL0823', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (824, 642, 486, 9, 630.09, 'BILL0824', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (825, 198, 59, 3, 261.83, 'BILL0825', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (826, 483, 445, 3, 676.33, 'BILL0826', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (827, 968, 200, 6, 641.85, 'BILL0827', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (828, 582, 158, 10, 820.0, 'BILL0828', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (829, 100, 360, 5, 100.63, 'BILL0829', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (830, 794, 190, 4, 344.47, 'BILL0830', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (831, 506, 489, 8, 105.16, 'BILL0831', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (832, 443, 298, 9, 528.36, 'BILL0832', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (833, 772, 35, 6, 533.42, 'BILL0833', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (834, 182, 428, 10, 468.12, 'BILL0834', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (835, 204, 42, 3, 954.71, 'BILL0835', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (836, 983, 363, 8, 468.89, 'BILL0836', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (837, 402, 325, 1, 688.09, 'BILL0837', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (838, 867, 265, 4, 726.14, 'BILL0838', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (839, 664, 461, 8, 486.02, 'BILL0839', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (840, 763, 440, 9, 933.02, 'BILL0840', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (841, 913, 151, 3, 649.25, 'BILL0841', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (842, 21, 425, 3, 474.04, 'BILL0842', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (843, 283, 143, 10, 102.66, 'BILL0843', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (844, 235, 326, 1, 311.37, 'BILL0844', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (845, 688, 441, 1, 920.52, 'BILL0845', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (846, 806, 248, 5, 101.2, 'BILL0846', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (847, 107, 416, 2, 344.03, 'BILL0847', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (848, 868, 101, 8, 950.73, 'BILL0848', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (849, 904, 403, 5, 271.51, 'BILL0849', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (850, 205, 160, 9, 259.05, 'BILL0850', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (851, 818, 119, 5, 348.72, 'BILL0851', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (852, 479, 222, 6, 249.94, 'BILL0852', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (853, 157, 68, 6, 145.91, 'BILL0853', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (854, 751, 291, 6, 978.48, 'BILL0854', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (855, 144, 173, 2, 140.86, 'BILL0855', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (856, 711, 127, 2, 964.97, 'BILL0856', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (857, 939, 87, 2, 471.82, 'BILL0857', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (858, 845, 231, 4, 300.96, 'BILL0858', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (859, 534, 448, 6, 121.65, 'BILL0859', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (860, 226, 412, 6, 902.08, 'BILL0860', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (861, 543, 6, 9, 458.83, 'BILL0861', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (862, 25, 1, 10, 642.27, 'BILL0862', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (863, 353, 127, 8, 395.32, 'BILL0863', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (864, 425, 281, 1, 223.84, 'BILL0864', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (865, 128, 18, 10, 965.31, 'BILL0865', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (866, 438, 27, 10, 478.34, 'BILL0866', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (867, 943, 369, 6, 167.05, 'BILL0867', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (868, 634, 473, 4, 500.72, 'BILL0868', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (869, 322, 190, 5, 891.76, 'BILL0869', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (870, 536, 359, 5, 888.7, 'BILL0870', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (871, 28, 275, 7, 478.86, 'BILL0871', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (872, 649, 407, 5, 101.84, 'BILL0872', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (873, 756, 286, 9, 103.12, 'BILL0873', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (874, 839, 404, 10, 427.84, 'BILL0874', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (875, 394, 482, 5, 959.31, 'BILL0875', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (876, 261, 110, 4, 636.07, 'BILL0876', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (877, 426, 485, 7, 829.27, 'BILL0877', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (878, 34, 122, 9, 455.82, 'BILL0878', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (879, 198, 154, 6, 917.66, 'BILL0879', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (880, 262, 280, 3, 592.3, 'BILL0880', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (881, 390, 384, 7, 338.46, 'BILL0881', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (882, 211, 285, 5, 458.45, 'BILL0882', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (883, 388, 213, 6, 531.59, 'BILL0883', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (884, 212, 340, 3, 301.85, 'BILL0884', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (885, 628, 409, 9, 507.31, 'BILL0885', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (886, 447, 357, 10, 344.32, 'BILL0886', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (887, 44, 416, 3, 440.34, 'BILL0887', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (888, 96, 409, 9, 565.34, 'BILL0888', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (889, 276, 402, 4, 823.65, 'BILL0889', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (890, 741, 395, 4, 516.2, 'BILL0890', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (891, 837, 277, 10, 812.28, 'BILL0891', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (892, 97, 55, 9, 885.2, 'BILL0892', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (893, 867, 188, 2, 399.15, 'BILL0893', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (894, 713, 210, 8, 782.62, 'BILL0894', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (895, 42, 101, 8, 174.23, 'BILL0895', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (896, 954, 453, 8, 388.8, 'BILL0896', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (897, 223, 345, 5, 764.7, 'BILL0897', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (898, 931, 364, 5, 902.56, 'BILL0898', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (899, 178, 15, 4, 113.36, 'BILL0899', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (900, 826, 348, 4, 371.97, 'BILL0900', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (901, 542, 467, 6, 126.42, 'BILL0901', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (902, 954, 484, 5, 988.81, 'BILL0902', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (903, 408, 6, 6, 322.77, 'BILL0903', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (904, 274, 158, 2, 734.94, 'BILL0904', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (905, 696, 222, 7, 889.8, 'BILL0905', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (906, 169, 400, 4, 388.13, 'BILL0906', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (907, 174, 302, 6, 323.45, 'BILL0907', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (908, 356, 439, 8, 918.09, 'BILL0908', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (909, 181, 462, 5, 711.06, 'BILL0909', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (910, 704, 118, 6, 144.43, 'BILL0910', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (911, 347, 145, 6, 115.09, 'BILL0911', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (912, 597, 295, 9, 492.52, 'BILL0912', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (913, 163, 249, 1, 641.46, 'BILL0913', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (914, 359, 42, 10, 756.59, 'BILL0914', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (915, 456, 185, 3, 700.78, 'BILL0915', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (916, 944, 15, 6, 708.45, 'BILL0916', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (917, 116, 30, 5, 404.76, 'BILL0917', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (918, 298, 175, 3, 504.61, 'BILL0918', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (919, 188, 237, 4, 831.43, 'BILL0919', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (920, 524, 246, 3, 467.21, 'BILL0920', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (921, 806, 63, 3, 514.52, 'BILL0921', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (922, 177, 55, 4, 158.31, 'BILL0922', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (923, 538, 451, 1, 354.9, 'BILL0923', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (924, 156, 371, 6, 675.1, 'BILL0924', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (925, 374, 468, 9, 550.97, 'BILL0925', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (926, 46, 457, 4, 955.09, 'BILL0926', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (927, 550, 74, 9, 925.27, 'BILL0927', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (928, 256, 11, 4, 491.73, 'BILL0928', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (929, 306, 282, 10, 887.16, 'BILL0929', 6);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (930, 716, 236, 7, 197.71, 'BILL0930', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (931, 862, 362, 3, 696.88, 'BILL0931', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (932, 710, 145, 1, 760.68, 'BILL0932', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (933, 348, 184, 5, 380.4, 'BILL0933', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (934, 663, 370, 9, 428.37, 'BILL0934', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (935, 471, 372, 7, 614.95, 'BILL0935', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (936, 350, 452, 5, 709.32, 'BILL0936', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (937, 698, 273, 6, 246.59, 'BILL0937', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (938, 176, 61, 5, 920.46, 'BILL0938', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (939, 525, 232, 1, 107.26, 'BILL0939', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (940, 585, 476, 8, 566.5, 'BILL0940', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (941, 480, 281, 6, 300.32, 'BILL0941', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (942, 744, 160, 9, 268.43, 'BILL0942', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (943, 493, 392, 10, 611.89, 'BILL0943', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (944, 648, 101, 9, 330.0, 'BILL0944', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (945, 927, 429, 9, 112.24, 'BILL0945', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (946, 447, 245, 4, 823.87, 'BILL0946', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (947, 305, 376, 7, 264.26, 'BILL0947', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (948, 522, 211, 5, 382.36, 'BILL0948', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (949, 872, 253, 7, 880.36, 'BILL0949', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (950, 5, 51, 2, 943.68, 'BILL0950', 13);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (951, 720, 35, 2, 537.84, 'BILL0951', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (952, 511, 417, 10, 693.44, 'BILL0952', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (953, 763, 431, 5, 641.55, 'BILL0953', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (954, 594, 486, 4, 761.5, 'BILL0954', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (955, 74, 149, 7, 594.05, 'BILL0955', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (956, 257, 256, 3, 428.33, 'BILL0956', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (957, 734, 82, 3, 636.71, 'BILL0957', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (958, 722, 267, 2, 956.58, 'BILL0958', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (959, 733, 23, 4, 220.17, 'BILL0959', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (960, 197, 370, 6, 460.81, 'BILL0960', 20);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (961, 997, 169, 7, 143.76, 'BILL0961', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (962, 692, 382, 9, 724.79, 'BILL0962', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (963, 647, 419, 7, 597.09, 'BILL0963', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (964, 229, 269, 4, 220.48, 'BILL0964', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (965, 19, 431, 10, 878.4, 'BILL0965', 18);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (966, 873, 279, 5, 594.95, 'BILL0966', 4);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (967, 52, 260, 6, 432.98, 'BILL0967', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (968, 864, 409, 9, 988.93, 'BILL0968', 17);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (969, 656, 137, 8, 158.32, 'BILL0969', 5);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (970, 162, 447, 10, 849.61, 'BILL0970', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (971, 802, 95, 2, 216.41, 'BILL0971', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (972, 223, 371, 4, 163.92, 'BILL0972', 15);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (973, 534, 226, 6, 623.84, 'BILL0973', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (974, 324, 119, 4, 137.19, 'BILL0974', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (975, 348, 260, 6, 621.8, 'BILL0975', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (976, 420, 160, 10, 959.84, 'BILL0976', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (977, 698, 438, 2, 721.34, 'BILL0977', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (978, 602, 406, 6, 992.02, 'BILL0978', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (979, 529, 421, 5, 549.16, 'BILL0979', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (980, 493, 131, 2, 531.59, 'BILL0980', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (981, 595, 476, 5, 292.43, 'BILL0981', 14);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (982, 169, 91, 5, 728.64, 'BILL0982', 11);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (983, 387, 7, 8, 612.52, 'BILL0983', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (984, 853, 11, 1, 908.42, 'BILL0984', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (985, 298, 295, 1, 869.26, 'BILL0985', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (986, 600, 13, 9, 670.51, 'BILL0986', 9);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (987, 715, 31, 3, 411.65, 'BILL0987', 8);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (988, 226, 3, 1, 640.37, 'BILL0988', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (989, 454, 12, 6, 465.88, 'BILL0989', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (990, 696, 112, 3, 861.44, 'BILL0990', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (991, 64, 453, 2, 660.89, 'BILL0991', 3);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (992, 926, 437, 10, 121.88, 'BILL0992', 7);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (993, 613, 299, 1, 627.11, 'BILL0993', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (994, 453, 195, 5, 506.57, 'BILL0994', 16);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (995, 119, 348, 6, 660.58, 'BILL0995', 10);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (996, 390, 370, 2, 106.53, 'BILL0996', 19);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (997, 19, 485, 4, 190.26, 'BILL0997', 12);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (998, 406, 449, 2, 135.75, 'BILL0998', 1);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (999, 420, 344, 2, 477.93, 'BILL0999', 2);
INSERT INTO SalesFact (SalesFactID, OrderDimID, ProductID, QuantitySold, SalesAmount, BillNumber, JunkID) VALUES (1000, 861, 113, 2, 682.07, 'BILL1000', 12);
SET IDENTITY_INSERT SalesFact OFF;
GO

SET IDENTITY_INSERT ReturnsFact ON;
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (1, 911, 170, 'Spoiled', 5, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (2, 278, 232, 'Late Delivery', 3, 10);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (3, 893, 368, 'Spoiled', 1, 4);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (4, 512, 136, 'Damaged Item', 4, 20);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (5, 45, 186, 'Mismatch in SKU', 5, 18);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (6, 676, 392, 'Wrong Product', 1, 11);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (7, 115, 198, 'Damaged Item', 4, 1);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (8, 911, 299, 'Damaged Item', 3, 17);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (9, 361, 326, 'Unsealed', 5, 20);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (10, 377, 78, 'Mismatch in SKU', 3, 1);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (11, 545, 397, 'Other', 4, 6);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (12, 956, 214, 'Customer Changed Mind', 3, 2);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (13, 439, 166, 'Other', 4, 14);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (14, 362, 11, 'Wrong Product', 5, 4);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (15, 731, 264, 'Wrong Product', 1, 6);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (16, 475, 198, 'Leaked Packaging', 5, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (17, 905, 82, 'Spoiled', 1, 11);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (18, 966, 80, 'Wrong Product', 3, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (19, 960, 156, 'Mismatch in SKU', 5, 4);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (20, 362, 430, 'Customer Changed Mind', 4, 2);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (21, 386, 50, 'Customer Changed Mind', 1, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (22, 225, 194, 'Late Delivery', 3, 14);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (23, 329, 462, 'Late Delivery', 4, 19);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (24, 850, 319, 'Late Delivery', 3, 12);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (25, 55, 120, 'Leaked Packaging', 4, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (26, 291, 473, 'Other', 4, 10);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (27, 244, 251, 'Wrong Product', 4, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (28, 994, 85, 'Late Delivery', 2, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (29, 827, 39, 'Damaged Item', 4, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (30, 504, 456, 'Mismatch in SKU', 5, 2);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (31, 400, 440, 'Expired', 2, 1);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (32, 377, 415, 'Mismatch in SKU', 2, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (33, 791, 243, 'Unsealed', 3, 14);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (34, 966, 155, 'Late Delivery', 4, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (35, 399, 201, 'Late Delivery', 1, 6);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (36, 225, 312, 'Spoiled', 3, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (37, 676, 260, 'Mismatch in SKU', 4, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (38, 142, 486, 'Wrong Product', 2, 11);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (39, 330, 37, 'Wrong Product', 1, 16);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (40, 727, 279, 'Late Delivery', 4, 6);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (41, 912, 472, 'Wrong Product', 5, 17);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (42, 230, 238, 'Damaged Item', 1, 14);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (43, 77, 15, 'Leaked Packaging', 2, 4);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (44, 820, 405, 'Unsealed', 2, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (45, 553, 430, 'Wrong Product', 4, 20);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (46, 517, 370, 'Damaged Item', 1, 1);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (47, 572, 217, 'Leaked Packaging', 1, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (48, 48, 478, 'Damaged Item', 5, 12);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (49, 485, 192, 'Leaked Packaging', 3, 20);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (50, 231, 441, 'Unsealed', 1, 17);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (51, 397, 132, 'Spoiled', 4, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (52, 231, 106, 'Other', 4, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (53, 799, 129, 'Wrong Product', 3, 11);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (54, 786, 432, 'Mismatch in SKU', 5, 4);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (55, 676, 256, 'Customer Changed Mind', 2, 17);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (56, 607, 61, 'Wrong Product', 1, 18);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (57, 115, 462, 'Customer Changed Mind', 5, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (58, 547, 349, 'Expired', 4, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (59, 672, 251, 'Expired', 1, 17);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (60, 801, 385, 'Other', 4, 14);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (61, 849, 438, 'Leaked Packaging', 5, 20);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (62, 901, 114, 'Unsealed', 5, 16);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (63, 136, 373, 'Wrong Product', 5, 13);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (64, 554, 39, 'Damaged Item', 5, 18);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (65, 626, 360, 'Customer Changed Mind', 2, 6);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (66, 62, 152, 'Damaged Item', 2, 6);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (67, 252, 449, 'Expired', 3, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (68, 956, 343, 'Leaked Packaging', 4, 16);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (69, 911, 221, 'Unsealed', 4, 14);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (70, 724, 404, 'Mismatch in SKU', 2, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (71, 709, 258, 'Mismatch in SKU', 1, 17);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (72, 852, 14, 'Wrong Product', 1, 2);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (73, 397, 426, 'Late Delivery', 5, 17);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (74, 548, 492, 'Spoiled', 1, 16);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (75, 45, 417, 'Spoiled', 1, 5);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (76, 62, 114, 'Other', 5, 19);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (77, 252, 115, 'Expired', 4, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (78, 377, 450, 'Spoiled', 3, 16);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (79, 142, 375, 'Expired', 4, 4);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (80, 446, 436, 'Mismatch in SKU', 5, 4);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (81, 106, 134, 'Customer Changed Mind', 4, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (82, 957, 145, 'Spoiled', 3, 15);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (83, 673, 269, 'Unsealed', 2, 18);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (84, 960, 266, 'Spoiled', 2, 11);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (85, 334, 426, 'Unsealed', 1, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (86, 273, 20, 'Unsealed', 4, 10);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (87, 726, 13, 'Mismatch in SKU', 4, 15);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (88, 1, 478, 'Damaged Item', 5, 12);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (89, 621, 47, 'Leaked Packaging', 5, 2);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (90, 252, 137, 'Damaged Item', 2, 14);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (91, 975, 251, 'Damaged Item', 2, 5);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (92, 334, 59, 'Unsealed', 5, 16);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (93, 400, 400, 'Wrong Product', 2, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (94, 14, 493, 'Spoiled', 1, 10);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (95, 108, 104, 'Spoiled', 5, 12);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (96, 821, 121, 'Damaged Item', 1, 1);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (97, 706, 351, 'Mismatch in SKU', 2, 5);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (98, 512, 239, 'Unsealed', 5, 2);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (99, 887, 396, 'Expired', 3, 10);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (100, 431, 165, 'Damaged Item', 3, 10);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (101, 272, 389, 'Damaged Item', 4, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (102, 56, 454, 'Spoiled', 3, 12);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (103, 936, 216, 'Expired', 2, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (104, 482, 289, 'Damaged Item', 4, 10);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (105, 496, 473, 'Other', 4, 15);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (106, 503, 179, 'Damaged Item', 2, 5);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (107, 370, 302, 'Expired', 5, 12);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (108, 206, 82, 'Expired', 3, 4);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (109, 399, 414, 'Late Delivery', 5, 19);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (110, 875, 493, 'Late Delivery', 4, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (111, 140, 284, 'Wrong Product', 3, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (112, 578, 318, 'Other', 2, 14);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (113, 775, 408, 'Unsealed', 3, 4);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (114, 17, 210, 'Mismatch in SKU', 5, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (115, 911, 242, 'Other', 4, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (116, 912, 113, 'Damaged Item', 4, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (117, 302, 62, 'Unsealed', 2, 4);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (118, 58, 287, 'Late Delivery', 3, 13);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (119, 714, 307, 'Late Delivery', 4, 12);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (120, 17, 19, 'Wrong Product', 2, 20);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (121, 911, 117, 'Spoiled', 1, 5);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (122, 48, 416, 'Spoiled', 5, 14);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (123, 140, 114, 'Expired', 1, 1);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (124, 849, 476, 'Expired', 1, 16);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (125, 655, 103, 'Expired', 1, 1);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (126, 945, 34, 'Expired', 5, 19);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (127, 776, 33, 'Expired', 5, 10);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (128, 496, 41, 'Leaked Packaging', 3, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (129, 623, 344, 'Expired', 3, 18);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (130, 313, 113, 'Late Delivery', 1, 2);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (131, 760, 261, 'Wrong Product', 4, 19);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (132, 219, 315, 'Customer Changed Mind', 5, 11);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (133, 893, 406, 'Other', 1, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (134, 62, 220, 'Customer Changed Mind', 1, 13);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (135, 445, 255, 'Unsealed', 3, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (136, 912, 471, 'Damaged Item', 2, 5);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (137, 877, 401, 'Mismatch in SKU', 4, 12);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (138, 791, 232, 'Unsealed', 1, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (139, 222, 353, 'Leaked Packaging', 1, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (140, 669, 338, 'Other', 2, 4);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (141, 377, 206, 'Mismatch in SKU', 3, 6);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (142, 912, 151, 'Other', 4, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (143, 400, 280, 'Spoiled', 5, 19);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (144, 689, 311, 'Spoiled', 2, 18);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (145, 14, 233, 'Damaged Item', 1, 1);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (146, 167, 222, 'Late Delivery', 5, 18);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (147, 219, 44, 'Late Delivery', 3, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (148, 219, 30, 'Late Delivery', 1, 6);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (149, 219, 114, 'Late Delivery', 2, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (150, 724, 351, 'Customer Changed Mind', 4, 11);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (151, 291, 76, 'Customer Changed Mind', 4, 12);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (152, 626, 490, 'Spoiled', 2, 1);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (153, 901, 408, 'Expired', 4, 15);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (154, 513, 227, 'Unsealed', 2, 1);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (155, 810, 441, 'Late Delivery', 2, 15);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (156, 503, 364, 'Customer Changed Mind', 3, 2);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (157, 259, 118, 'Late Delivery', 1, 13);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (158, 327, 186, 'Unsealed', 2, 1);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (159, 485, 444, 'Mismatch in SKU', 4, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (160, 568, 444, 'Damaged Item', 1, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (161, 746, 190, 'Other', 4, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (162, 607, 70, 'Late Delivery', 3, 16);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (163, 510, 167, 'Unsealed', 5, 11);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (164, 888, 124, 'Leaked Packaging', 1, 6);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (165, 252, 88, 'Expired', 1, 6);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (166, 830, 197, 'Other', 4, 19);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (167, 547, 302, 'Leaked Packaging', 1, 13);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (168, 225, 91, 'Wrong Product', 4, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (169, 259, 376, 'Late Delivery', 5, 10);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (170, 990, 35, 'Leaked Packaging', 3, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (171, 830, 22, 'Other', 2, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (172, 883, 62, 'Leaked Packaging', 2, 10);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (173, 136, 482, 'Damaged Item', 3, 16);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (174, 485, 279, 'Damaged Item', 2, 3);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (175, 875, 367, 'Mismatch in SKU', 5, 6);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (176, 827, 63, 'Expired', 3, 9);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (177, 555, 31, 'Spoiled', 2, 15);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (178, 155, 415, 'Other', 2, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (179, 776, 110, 'Spoiled', 3, 16);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (180, 969, 66, 'Late Delivery', 2, 11);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (181, 975, 2, 'Customer Changed Mind', 2, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (182, 267, 125, 'Wrong Product', 5, 12);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (183, 632, 342, 'Wrong Product', 4, 5);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (184, 72, 340, 'Damaged Item', 2, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (185, 462, 324, 'Late Delivery', 3, 17);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (186, 398, 425, 'Mismatch in SKU', 5, 14);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (187, 571, 6, 'Unsealed', 2, 16);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (188, 230, 414, 'Spoiled', 5, 16);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (189, 312, 360, 'Expired', 2, 19);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (190, 994, 465, 'Unsealed', 5, 6);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (191, 672, 334, 'Unsealed', 4, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (192, 496, 490, 'Mismatch in SKU', 3, 4);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (193, 398, 112, 'Damaged Item', 3, 2);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (194, 228, 241, 'Other', 3, 8);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (195, 960, 74, 'Leaked Packaging', 1, 5);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (196, 230, 278, 'Unsealed', 3, 7);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (197, 203, 473, 'Other', 3, 13);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (198, 632, 365, 'Other', 3, 14);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (199, 571, 281, 'Leaked Packaging', 1, 5);
INSERT INTO ReturnsFact (ReturnsFactID, OrderDimID, ProductID, ReturnReason, QuantityReturned, JunkID) VALUES (200, 292, 265, 'Mismatch in SKU', 2, 20);
SET IDENTITY_INSERT ReturnsFact OFF;
GO





SET IDENTITY_INSERT CustomerFeedbackFact ON;
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (1, 384, 212, 1, 'Excellent product', 487);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (2, 855, 104, 4, 'Bad taste', 429);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (3, 610, 337, 4, 'Just okay', 64);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (4, 966, 37, 1, 'Just okay', 285);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (5, 317, 204, 2, 'Too costly', 600);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (6, 393, 223, 2, 'Very satisfied', 531);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (7, 205, 80, 4, 'Excellent product', 362);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (8, 593, 298, 4, 'Very fresh', 231);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (9, 314, 126, 4, 'Just okay', 712);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (10, 966, 365, 1, 'Too costly', 461);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (11, 284, 168, 4, 'Poor packaging', 620);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (12, 952, 178, 3, 'Excellent product', 637);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (13, 737, 46, 1, 'Average experience', 533);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (14, 178, 103, 4, 'Just okay', 56);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (15, 507, 441, 3, 'Just okay', 730);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (16, 152, 32, 4, 'Very satisfied', 55);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (17, 174, 216, 4, 'Poor packaging', 206);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (18, 867, 349, 4, 'Excellent product', 487);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (19, 678, 384, 3, 'Average experience', 268);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (20, 867, 274, 2, 'Very fresh', 485);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (21, 823, 159, 2, 'Bad taste', 483);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (22, 761, 15, 1, 'Very satisfied', 334);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (23, 395, 57, 2, 'Average experience', 305);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (24, 487, 45, 5, 'Good quality', 642);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (25, 835, 122, 1, 'Very satisfied', 715);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (26, 626, 83, 4, 'Bad taste', 476);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (27, 193, 64, 2, 'Good quality', 417);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (28, 297, 366, 1, 'Good quality', 351);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (29, 328, 285, 4, 'Very satisfied', 158);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (30, 733, 109, 4, 'Poor packaging', 127);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (31, 448, 203, 3, 'Poor packaging', 690);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (32, 211, 35, 3, 'Good quality', 336);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (33, 394, 114, 1, 'Bad taste', 700);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (34, 779, 326, 5, 'Excellent product', 331);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (35, 826, 272, 1, 'Excellent product', 28);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (36, 330, 50, 3, 'Excellent product', 192);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (37, 742, 88, 2, 'Bad taste', 38);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (38, 653, 354, 2, 'Very fresh', 112);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (39, 934, 292, 1, 'Very satisfied', 456);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (40, 523, 269, 4, 'Poor packaging', 411);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (41, 351, 152, 4, 'Very satisfied', 451);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (42, 762, 475, 4, 'Bad taste', 333);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (43, 32, 403, 2, 'Bad taste', 222);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (44, 172, 356, 5, 'Bad taste', 196);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (45, 360, 102, 4, 'Good quality', 493);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (46, 482, 159, 3, 'Will buy again', 653);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (47, 830, 192, 2, 'Average experience', 416);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (48, 215, 53, 2, 'Good quality', 323);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (49, 8, 363, 1, 'Poor packaging', 445);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (50, 94, 492, 1, 'Very satisfied', 664);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (51, 786, 495, 2, 'Good quality', 206);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (52, 922, 8, 2, 'Very fresh', 438);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (53, 439, 398, 4, 'Bad taste', 510);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (54, 822, 390, 4, 'Good quality', 25);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (55, 403, 254, 1, 'Poor packaging', 97);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (56, 978, 90, 5, 'Just okay', 683);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (57, 936, 377, 2, 'Bad taste', 261);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (58, 946, 225, 5, 'Very satisfied', 660);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (59, 714, 498, 3, 'Excellent product', 513);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (60, 756, 9, 5, 'Excellent product', 286);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (61, 738, 378, 1, 'Good quality', 28);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (62, 137, 497, 5, 'Poor packaging', 101);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (63, 602, 56, 3, 'Good quality', 440);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (64, 260, 500, 5, 'Poor packaging', 77);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (65, 156, 226, 3, 'Good quality', 702);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (66, 402, 65, 5, 'Just okay', 677);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (67, 309, 456, 1, 'Average experience', 183);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (68, 993, 441, 2, 'Very satisfied', 604);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (69, 62, 422, 4, 'Just okay', 191);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (70, 260, 269, 1, 'Poor packaging', 7);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (71, 487, 165, 4, 'Good quality', 513);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (72, 77, 341, 3, 'Excellent product', 165);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (73, 819, 254, 2, 'Very satisfied', 491);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (74, 8, 131, 5, 'Good quality', 610);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (75, 798, 386, 3, 'Very fresh', 61);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (76, 14, 270, 3, 'Very fresh', 345);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (77, 890, 73, 4, 'Bad taste', 83);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (78, 660, 145, 1, 'Bad taste', 621);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (79, 132, 157, 1, 'Very satisfied', 64);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (80, 296, 182, 1, 'Just okay', 202);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (81, 473, 439, 3, 'Bad taste', 17);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (82, 689, 354, 3, 'Poor packaging', 158);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (83, 321, 315, 2, 'Good quality', 584);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (84, 192, 228, 3, 'Very fresh', 263);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (85, 621, 464, 1, 'Just okay', 331);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (86, 978, 474, 1, 'Average experience', 508);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (87, 629, 337, 2, 'Too costly', 639);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (88, 486, 346, 4, 'Excellent product', 728);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (89, 921, 89, 2, 'Average experience', 349);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (90, 947, 92, 5, 'Good quality', 551);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (91, 684, 19, 1, 'Bad taste', 697);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (92, 60, 72, 3, 'Very satisfied', 71);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (93, 263, 446, 4, 'Excellent product', 600);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (94, 338, 222, 4, 'Average experience', 679);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (95, 903, 361, 4, 'Poor packaging', 624);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (96, 888, 289, 3, 'Very fresh', 449);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (97, 937, 355, 2, 'Just okay', 59);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (98, 848, 73, 3, 'Bad taste', 274);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (99, 233, 214, 1, 'Excellent product', 726);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (100, 91, 430, 5, 'Bad taste', 717);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (101, 604, 86, 4, 'Very satisfied', 534);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (102, 77, 222, 3, 'Very fresh', 125);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (103, 679, 395, 4, 'Very fresh', 95);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (104, 269, 245, 1, 'Excellent product', 503);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (105, 824, 387, 4, 'Excellent product', 117);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (106, 504, 474, 2, 'Average experience', 133);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (107, 841, 430, 5, 'Average experience', 604);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (108, 51, 255, 1, 'Bad taste', 621);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (109, 957, 482, 2, 'Excellent product', 646);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (110, 619, 109, 3, 'Too costly', 111);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (111, 202, 433, 2, 'Just okay', 367);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (112, 306, 368, 4, 'Very fresh', 284);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (113, 783, 141, 3, 'Excellent product', 142);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (114, 273, 497, 5, 'Average experience', 64);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (115, 568, 144, 2, 'Will buy again', 298);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (116, 947, 490, 1, 'Too costly', 672);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (117, 10, 56, 1, 'Bad taste', 311);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (118, 35, 500, 2, 'Excellent product', 170);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (119, 923, 52, 3, 'Average experience', 687);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (120, 117, 143, 3, 'Very fresh', 451);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (121, 920, 246, 4, 'Very satisfied', 468);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (122, 33, 329, 4, 'Excellent product', 645);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (123, 436, 143, 3, 'Good quality', 163);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (124, 175, 446, 2, 'Will buy again', 523);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (125, 511, 410, 5, 'Too costly', 443);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (126, 547, 240, 1, 'Excellent product', 682);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (127, 659, 95, 4, 'Excellent product', 590);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (128, 892, 494, 5, 'Good quality', 459);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (129, 294, 369, 3, 'Just okay', 219);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (130, 188, 132, 5, 'Will buy again', 661);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (131, 128, 204, 4, 'Bad taste', 551);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (132, 641, 120, 3, 'Very satisfied', 315);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (133, 607, 20, 2, 'Excellent product', 152);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (134, 103, 159, 4, 'Good quality', 545);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (135, 86, 430, 4, 'Very fresh', 618);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (136, 44, 231, 2, 'Good quality', 48);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (137, 696, 92, 3, 'Bad taste', 315);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (138, 924, 418, 1, 'Bad taste', 385);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (139, 366, 81, 4, 'Too costly', 423);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (140, 241, 134, 1, 'Too costly', 715);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (141, 219, 215, 1, 'Just okay', 447);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (142, 121, 23, 2, 'Very fresh', 700);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (143, 430, 336, 4, 'Will buy again', 346);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (144, 232, 498, 4, 'Just okay', 223);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (145, 850, 196, 3, 'Average experience', 198);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (146, 149, 308, 4, 'Very satisfied', 95);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (147, 469, 224, 2, 'Good quality', 350);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (148, 588, 129, 1, 'Average experience', 434);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (149, 118, 88, 2, 'Average experience', 442);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (150, 418, 369, 2, 'Average experience', 354);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (151, 156, 231, 5, 'Very satisfied', 106);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (152, 390, 465, 3, 'Poor packaging', 511);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (153, 620, 181, 5, 'Poor packaging', 529);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (154, 854, 99, 3, 'Just okay', 42);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (155, 626, 354, 2, 'Will buy again', 332);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (156, 208, 252, 4, 'Just okay', 212);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (157, 312, 46, 4, 'Good quality', 352);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (158, 883, 337, 1, 'Very satisfied', 583);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (159, 41, 291, 4, 'Will buy again', 180);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (160, 613, 186, 2, 'Bad taste', 12);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (161, 985, 41, 2, 'Very satisfied', 448);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (162, 704, 41, 3, 'Will buy again', 307);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (163, 619, 259, 3, 'Will buy again', 633);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (164, 542, 210, 2, 'Poor packaging', 98);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (165, 355, 125, 2, 'Bad taste', 724);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (166, 885, 209, 3, 'Poor packaging', 303);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (167, 104, 91, 4, 'Bad taste', 83);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (168, 904, 238, 1, 'Very fresh', 677);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (169, 197, 279, 2, 'Just okay', 711);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (170, 146, 170, 1, 'Very fresh', 641);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (171, 150, 85, 5, 'Too costly', 108);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (172, 757, 10, 5, 'Very fresh', 728);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (173, 809, 54, 1, 'Too costly', 256);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (174, 787, 311, 3, 'Too costly', 215);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (175, 51, 129, 2, 'Too costly', 319);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (176, 744, 441, 5, 'Will buy again', 528);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (177, 930, 427, 5, 'Bad taste', 195);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (178, 195, 427, 3, 'Good quality', 591);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (179, 521, 476, 4, 'Too costly', 667);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (180, 695, 467, 2, 'Very fresh', 292);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (181, 558, 467, 4, 'Good quality', 181);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (182, 1, 106, 3, 'Bad taste', 618);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (183, 777, 161, 2, 'Very fresh', 203);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (184, 641, 106, 1, 'Poor packaging', 14);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (185, 730, 300, 1, 'Very fresh', 616);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (186, 813, 243, 2, 'Very fresh', 98);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (187, 501, 208, 5, 'Just okay', 316);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (188, 837, 486, 3, 'Very fresh', 653);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (189, 136, 132, 5, 'Very fresh', 459);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (190, 423, 233, 5, 'Will buy again', 349);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (191, 633, 368, 2, 'Too costly', 183);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (192, 106, 211, 5, 'Very satisfied', 83);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (193, 918, 152, 5, 'Bad taste', 196);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (194, 96, 256, 4, 'Good quality', 287);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (195, 8, 302, 5, 'Average experience', 31);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (196, 795, 12, 5, 'Bad taste', 232);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (197, 141, 104, 3, 'Good quality', 213);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (198, 889, 270, 3, 'Very satisfied', 335);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (199, 711, 406, 1, 'Very satisfied', 441);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (200, 567, 205, 1, 'Bad taste', 10);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (201, 888, 127, 3, 'Will buy again', 27);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (202, 437, 460, 2, 'Good quality', 498);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (203, 521, 434, 2, 'Excellent product', 356);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (204, 339, 336, 4, 'Very fresh', 385);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (205, 554, 389, 2, 'Just okay', 173);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (206, 838, 221, 3, 'Average experience', 354);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (207, 109, 398, 1, 'Excellent product', 587);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (208, 564, 98, 3, 'Will buy again', 172);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (209, 14, 134, 3, 'Very satisfied', 337);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (210, 209, 67, 3, 'Excellent product', 712);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (211, 133, 194, 1, 'Good quality', 154);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (212, 71, 362, 2, 'Just okay', 252);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (213, 691, 323, 1, 'Good quality', 113);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (214, 614, 149, 1, 'Bad taste', 656);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (215, 661, 214, 5, 'Too costly', 650);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (216, 324, 48, 1, 'Poor packaging', 332);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (217, 21, 30, 5, 'Will buy again', 618);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (218, 107, 373, 5, 'Bad taste', 670);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (219, 414, 184, 4, 'Average experience', 431);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (220, 320, 403, 2, 'Average experience', 698);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (221, 234, 79, 3, 'Average experience', 74);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (222, 571, 151, 4, 'Poor packaging', 95);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (223, 900, 142, 2, 'Good quality', 300);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (224, 176, 428, 5, 'Excellent product', 575);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (225, 287, 244, 5, 'Excellent product', 626);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (226, 69, 209, 2, 'Bad taste', 121);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (227, 650, 149, 3, 'Just okay', 664);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (228, 302, 36, 5, 'Excellent product', 712);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (229, 176, 156, 2, 'Very fresh', 709);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (230, 357, 274, 1, 'Just okay', 512);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (231, 799, 429, 4, 'Good quality', 92);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (232, 345, 297, 2, 'Too costly', 662);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (233, 25, 402, 2, 'Too costly', 31);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (234, 191, 127, 4, 'Bad taste', 597);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (235, 705, 105, 1, 'Just okay', 210);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (236, 288, 301, 5, 'Too costly', 142);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (237, 779, 391, 1, 'Excellent product', 57);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (238, 746, 88, 2, 'Average experience', 679);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (239, 239, 35, 2, 'Too costly', 10);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (240, 88, 222, 5, 'Average experience', 488);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (241, 984, 142, 3, 'Too costly', 650);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (242, 348, 454, 2, 'Poor packaging', 535);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (243, 170, 55, 1, 'Bad taste', 635);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (244, 40, 18, 3, 'Good quality', 181);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (245, 757, 418, 5, 'Very fresh', 99);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (246, 616, 36, 5, 'Too costly', 349);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (247, 415, 245, 5, 'Average experience', 15);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (248, 402, 116, 1, 'Bad taste', 106);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (249, 142, 337, 4, 'Poor packaging', 386);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (250, 825, 149, 5, 'Average experience', 346);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (251, 575, 436, 1, 'Poor packaging', 237);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (252, 699, 116, 1, 'Poor packaging', 80);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (253, 837, 53, 1, 'Poor packaging', 644);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (254, 920, 244, 2, 'Will buy again', 133);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (255, 57, 439, 2, 'Just okay', 350);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (256, 113, 117, 1, 'Bad taste', 345);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (257, 724, 158, 4, 'Good quality', 651);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (258, 999, 377, 1, 'Average experience', 693);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (259, 948, 386, 3, 'Too costly', 55);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (260, 106, 469, 1, 'Too costly', 595);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (261, 235, 57, 1, 'Average experience', 555);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (262, 704, 139, 3, 'Will buy again', 391);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (263, 808, 193, 1, 'Poor packaging', 121);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (264, 283, 9, 3, 'Average experience', 442);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (265, 217, 32, 4, 'Very satisfied', 334);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (266, 269, 145, 4, 'Very satisfied', 587);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (267, 417, 438, 5, 'Will buy again', 333);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (268, 593, 197, 1, 'Average experience', 124);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (269, 594, 77, 3, 'Average experience', 341);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (270, 772, 30, 4, 'Very fresh', 205);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (271, 418, 306, 2, 'Bad taste', 377);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (272, 325, 454, 3, 'Very fresh', 401);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (273, 314, 66, 3, 'Will buy again', 696);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (274, 9, 300, 5, 'Average experience', 120);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (275, 469, 143, 1, 'Good quality', 383);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (276, 355, 276, 2, 'Very satisfied', 117);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (277, 284, 374, 5, 'Good quality', 646);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (278, 53, 402, 2, 'Poor packaging', 96);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (279, 145, 257, 1, 'Very satisfied', 562);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (280, 192, 149, 2, 'Good quality', 313);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (281, 166, 410, 1, 'Will buy again', 681);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (282, 582, 180, 3, 'Bad taste', 19);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (283, 194, 161, 3, 'Too costly', 34);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (284, 595, 212, 2, 'Good quality', 158);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (285, 57, 258, 1, 'Very satisfied', 326);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (286, 813, 282, 4, 'Very fresh', 309);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (287, 361, 375, 5, 'Poor packaging', 512);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (288, 179, 50, 5, 'Very satisfied', 171);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (289, 391, 336, 2, 'Just okay', 309);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (290, 398, 442, 2, 'Very fresh', 65);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (291, 328, 73, 4, 'Just okay', 236);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (292, 253, 317, 5, 'Excellent product', 436);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (293, 190, 439, 2, 'Poor packaging', 32);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (294, 261, 15, 1, 'Poor packaging', 703);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (295, 616, 468, 4, 'Poor packaging', 470);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (296, 947, 14, 1, 'Average experience', 257);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (297, 802, 34, 1, 'Just okay', 169);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (298, 860, 64, 4, 'Just okay', 562);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (299, 388, 346, 5, 'Very satisfied', 382);
INSERT INTO CustomerFeedbackFact (FeedbackFactID, OrderDimID, ProductID, Rating, FeedbackComment, FeedbackDateID) VALUES (300, 856, 455, 5, 'Too costly', 135);
SET IDENTITY_INSERT CustomerFeedbackFact OFF;
GO







SET IDENTITY_INSERT SupplierSupplyFact ON;
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (1, 80, 460, 93, 249, 1697.62);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (2, 35, 136, 39, 403, 1084.46);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (3, 81, 283, 272, 390, 612.05);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (4, 12, 252, 628, 240, 1070.32);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (5, 83, 325, 472, 289, 4930.07);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (6, 40, 347, 124, 169, 4757.17);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (7, 30, 392, 91, 481, 944.58);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (8, 43, 43, 213, 375, 2325.52);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (9, 55, 248, 262, 220, 1116.34);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (10, 93, 319, 332, 478, 4437.28);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (11, 17, 125, 224, 274, 2644.72);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (12, 12, 144, 293, 458, 1659.81);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (13, 21, 246, 438, 361, 1042.08);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (14, 72, 369, 113, 165, 1605.97);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (15, 5, 167, 696, 483, 716.3);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (16, 38, 370, 703, 299, 3232.14);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (17, 85, 27, 685, 50, 4406.02);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (18, 63, 89, 267, 126, 4850.98);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (19, 80, 263, 646, 411, 3293.2);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (20, 15, 118, 555, 241, 1931.76);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (21, 41, 359, 317, 245, 2538.95);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (22, 83, 146, 183, 335, 1784.44);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (23, 84, 76, 226, 458, 1434.31);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (24, 34, 32, 641, 147, 2746.8);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (25, 45, 420, 394, 248, 3417.92);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (26, 70, 259, 405, 241, 3870.45);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (27, 30, 384, 103, 169, 3276.37);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (28, 86, 1, 417, 229, 3403.7);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (29, 53, 71, 603, 242, 2166.12);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (30, 55, 457, 552, 475, 2652.93);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (31, 88, 168, 154, 301, 4475.59);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (32, 92, 416, 137, 397, 3486.33);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (33, 2, 86, 153, 149, 3076.94);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (34, 27, 296, 565, 161, 885.47);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (35, 21, 302, 601, 233, 1899.24);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (36, 90, 475, 724, 476, 2897.97);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (37, 52, 147, 374, 379, 1673.03);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (38, 8, 331, 219, 95, 1129.65);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (39, 75, 80, 498, 220, 4546.92);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (40, 43, 312, 349, 169, 652.71);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (41, 7, 446, 340, 472, 1347.9);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (42, 79, 180, 263, 101, 694.39);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (43, 58, 263, 336, 224, 4010.78);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (44, 69, 416, 469, 278, 788.6);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (45, 36, 388, 385, 170, 4062.02);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (46, 81, 354, 158, 304, 2641.62);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (47, 33, 232, 667, 58, 3118.34);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (48, 53, 458, 293, 416, 3520.56);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (49, 74, 89, 301, 455, 1944.7);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (50, 75, 430, 42, 213, 1978.33);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (51, 97, 315, 615, 143, 1322.24);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (52, 15, 141, 527, 277, 4470.87);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (53, 35, 261, 521, 413, 1542.45);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (54, 7, 45, 445, 366, 1430.17);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (55, 90, 443, 298, 445, 4209.84);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (56, 12, 74, 244, 67, 1554.79);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (57, 55, 467, 343, 483, 693.24);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (58, 93, 454, 491, 108, 4164.23);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (59, 45, 258, 380, 343, 1163.32);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (60, 10, 368, 402, 388, 2193.19);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (61, 50, 205, 621, 221, 3031.19);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (62, 18, 233, 456, 113, 2932.82);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (63, 32, 77, 616, 499, 2986.94);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (64, 15, 46, 190, 360, 4810.25);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (65, 65, 255, 62, 71, 4439.05);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (66, 89, 250, 80, 169, 1698.89);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (67, 76, 426, 554, 407, 4787.8);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (68, 17, 73, 315, 314, 2976.03);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (69, 1, 112, 724, 256, 3005.72);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (70, 95, 225, 67, 368, 820.04);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (71, 76, 153, 364, 236, 1096.24);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (72, 69, 290, 150, 224, 3495.06);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (73, 45, 208, 194, 198, 3129.04);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (74, 90, 340, 501, 174, 1591.55);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (75, 2, 438, 173, 60, 3320.11);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (76, 68, 230, 399, 350, 2974.51);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (77, 65, 428, 417, 271, 2876.84);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (78, 16, 451, 396, 410, 4946.7);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (79, 75, 445, 725, 93, 4584.75);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (80, 96, 427, 342, 212, 1068.24);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (81, 82, 229, 230, 252, 1784.59);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (82, 89, 109, 570, 79, 2741.81);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (83, 21, 360, 340, 484, 1348.39);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (84, 56, 42, 707, 480, 4428.3);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (85, 41, 269, 173, 154, 4056.37);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (86, 80, 449, 444, 124, 4345.03);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (87, 11, 126, 357, 275, 2623.71);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (88, 6, 269, 649, 143, 749.89);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (89, 45, 365, 535, 199, 2513.94);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (90, 8, 363, 179, 117, 4210.85);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (91, 42, 209, 408, 126, 1099.75);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (92, 16, 181, 644, 276, 2337.82);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (93, 66, 365, 665, 381, 1101.95);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (94, 83, 22, 607, 473, 3992.87);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (95, 6, 407, 85, 155, 2409.81);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (96, 21, 413, 723, 284, 1748.88);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (97, 39, 17, 323, 407, 2554.94);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (98, 14, 342, 219, 132, 2595.1);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (99, 9, 138, 346, 431, 2689.05);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (100, 21, 325, 666, 215, 2996.44);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (101, 37, 98, 449, 235, 4650.75);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (102, 68, 378, 300, 455, 2261.27);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (103, 100, 15, 360, 71, 1689.56);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (104, 15, 271, 218, 433, 3477.65);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (105, 64, 177, 719, 425, 2930.09);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (106, 27, 192, 657, 396, 3754.64);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (107, 58, 192, 364, 234, 2365.2);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (108, 95, 384, 590, 494, 2182.85);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (109, 62, 68, 91, 410, 1710.53);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (110, 19, 277, 292, 499, 4998.39);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (111, 9, 389, 147, 407, 4973.64);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (112, 46, 322, 406, 165, 4346.77);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (113, 82, 443, 686, 326, 2275.84);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (114, 86, 204, 461, 266, 4081.19);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (115, 61, 364, 300, 192, 665.08);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (116, 96, 25, 164, 103, 592.12);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (117, 99, 54, 324, 224, 1716.51);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (118, 100, 2, 365, 436, 4670.83);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (119, 36, 480, 628, 491, 2895.77);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (120, 11, 49, 610, 448, 2182.36);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (121, 70, 308, 460, 450, 2767.44);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (122, 75, 367, 139, 259, 4867.15);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (123, 78, 317, 599, 73, 3460.17);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (124, 73, 388, 657, 267, 2408.03);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (125, 33, 289, 323, 406, 2036.06);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (126, 78, 383, 487, 447, 4752.96);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (127, 54, 91, 333, 260, 1111.78);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (128, 29, 1, 42, 209, 4398.19);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (129, 49, 497, 516, 366, 1953.15);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (130, 50, 413, 646, 456, 1377.73);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (131, 21, 230, 101, 300, 2955.79);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (132, 69, 395, 128, 193, 4341.09);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (133, 5, 224, 187, 447, 1753.23);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (134, 72, 50, 318, 124, 4841.79);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (135, 55, 343, 77, 247, 4540.64);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (136, 47, 23, 270, 389, 2629.75);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (137, 7, 292, 472, 481, 3814.33);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (138, 47, 345, 449, 278, 4405.66);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (139, 91, 13, 372, 278, 3756.01);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (140, 67, 479, 468, 431, 2921.24);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (141, 75, 67, 22, 466, 1522.44);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (142, 8, 260, 366, 377, 1847.72);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (143, 20, 154, 468, 59, 902.06);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (144, 19, 240, 569, 148, 3005.95);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (145, 31, 69, 91, 356, 623.46);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (146, 85, 243, 27, 289, 1005.73);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (147, 14, 152, 243, 360, 1227.76);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (148, 18, 31, 666, 475, 2562.94);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (149, 22, 118, 242, 151, 1128.95);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (150, 53, 229, 240, 252, 2356.23);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (151, 37, 164, 205, 72, 1317.97);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (152, 100, 327, 23, 139, 2205.51);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (153, 52, 386, 635, 166, 4551.46);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (154, 43, 400, 516, 63, 3664.85);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (155, 3, 437, 709, 322, 3050.37);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (156, 17, 245, 104, 394, 3608.47);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (157, 62, 460, 526, 217, 4103.63);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (158, 34, 178, 534, 487, 3282.19);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (159, 61, 403, 73, 313, 4736.23);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (160, 55, 232, 681, 205, 4247.19);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (161, 80, 132, 647, 65, 680.51);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (162, 32, 125, 86, 473, 3619.63);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (163, 58, 155, 671, 187, 604.44);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (164, 25, 325, 308, 110, 3889.76);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (165, 13, 164, 686, 377, 2387.3);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (166, 98, 26, 664, 297, 3251.9);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (167, 64, 388, 40, 418, 2085.87);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (168, 32, 427, 56, 392, 3642.78);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (169, 60, 180, 644, 394, 2548.73);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (170, 36, 131, 642, 335, 2226.92);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (171, 28, 323, 111, 184, 2105.79);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (172, 50, 27, 139, 129, 4074.49);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (173, 36, 349, 576, 163, 1480.82);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (174, 65, 246, 337, 173, 3393.92);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (175, 7, 462, 447, 102, 4209.75);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (176, 100, 152, 681, 81, 3582.4);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (177, 87, 122, 436, 386, 3687.23);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (178, 93, 181, 493, 143, 3185.87);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (179, 21, 102, 479, 148, 4886.11);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (180, 62, 430, 538, 427, 1932.79);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (181, 94, 130, 640, 459, 1913.1);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (182, 89, 93, 457, 233, 1461.82);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (183, 95, 83, 130, 386, 2090.35);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (184, 20, 226, 446, 224, 4277.55);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (185, 34, 356, 282, 154, 3129.46);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (186, 90, 123, 232, 431, 3243.56);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (187, 98, 5, 358, 469, 760.68);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (188, 96, 238, 65, 419, 2991.86);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (189, 3, 227, 216, 358, 4818.73);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (190, 12, 282, 678, 168, 2618.01);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (191, 87, 59, 176, 223, 2719.36);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (192, 4, 220, 676, 422, 4806.51);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (193, 62, 150, 454, 95, 4434.17);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (194, 22, 231, 631, 257, 1995.63);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (195, 77, 491, 582, 446, 1381.35);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (196, 35, 422, 46, 273, 2594.4);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (197, 17, 113, 190, 442, 4287.73);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (198, 40, 386, 375, 328, 2898.72);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (199, 57, 73, 354, 317, 1986.88);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (200, 69, 299, 456, 82, 1588.54);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (201, 78, 462, 76, 275, 4177.29);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (202, 94, 250, 163, 424, 3905.39);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (203, 53, 280, 349, 75, 1398.63);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (204, 56, 177, 37, 239, 1558.12);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (205, 48, 486, 346, 333, 1091.6);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (206, 85, 142, 691, 160, 4418.8);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (207, 63, 102, 643, 388, 1639.05);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (208, 93, 334, 331, 127, 659.66);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (209, 37, 215, 663, 371, 2657.73);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (210, 52, 315, 729, 298, 3095.82);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (211, 44, 365, 261, 203, 1013.32);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (212, 27, 396, 661, 402, 4787.28);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (213, 32, 313, 31, 237, 4884.39);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (214, 37, 194, 338, 163, 4938.66);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (215, 53, 51, 78, 397, 2064.27);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (216, 83, 249, 394, 146, 3682.52);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (217, 6, 243, 95, 317, 1446.48);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (218, 71, 196, 420, 278, 2009.54);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (219, 73, 204, 447, 475, 1104.24);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (220, 43, 159, 230, 500, 2506.49);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (221, 54, 73, 357, 59, 1299.45);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (222, 31, 152, 63, 315, 4276.68);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (223, 34, 470, 39, 278, 556.49);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (224, 76, 56, 729, 315, 3250.18);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (225, 25, 439, 409, 413, 4183.95);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (226, 45, 270, 50, 313, 4332.64);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (227, 84, 447, 523, 427, 4020.29);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (228, 56, 240, 394, 450, 3976.73);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (229, 17, 360, 151, 134, 1542.15);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (230, 20, 148, 365, 118, 3757.51);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (231, 37, 430, 226, 253, 2578.39);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (232, 78, 22, 39, 357, 2145.09);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (233, 11, 449, 90, 256, 1253.44);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (234, 45, 307, 712, 482, 4586.99);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (235, 42, 343, 156, 368, 4628.62);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (236, 52, 477, 497, 438, 2245.95);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (237, 13, 437, 555, 458, 1933.17);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (238, 95, 414, 206, 488, 3618.29);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (239, 36, 293, 305, 322, 852.71);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (240, 63, 484, 490, 468, 709.36);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (241, 65, 260, 108, 287, 995.17);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (242, 85, 273, 538, 115, 849.75);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (243, 75, 19, 445, 401, 1699.59);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (244, 53, 273, 343, 195, 1925.49);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (245, 28, 91, 518, 232, 3907.47);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (246, 31, 280, 602, 203, 1674.76);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (247, 26, 422, 16, 281, 4327.22);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (248, 18, 315, 676, 395, 2394.56);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (249, 37, 217, 140, 357, 3046.09);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (250, 91, 58, 297, 408, 2395.98);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (251, 81, 422, 693, 118, 4122.49);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (252, 61, 331, 443, 339, 1650.99);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (253, 39, 52, 51, 356, 4040.29);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (254, 8, 47, 196, 349, 1379.03);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (255, 99, 234, 296, 412, 656.41);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (256, 39, 116, 334, 402, 777.86);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (257, 22, 489, 150, 479, 753.82);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (258, 46, 6, 643, 140, 612.87);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (259, 72, 171, 506, 399, 2360.38);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (260, 93, 354, 305, 64, 2624.5);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (261, 83, 251, 663, 250, 2593.24);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (262, 80, 31, 438, 457, 4529.77);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (263, 73, 299, 585, 304, 4430.76);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (264, 49, 259, 91, 124, 1030.88);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (265, 27, 481, 235, 231, 613.47);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (266, 85, 123, 3, 359, 513.53);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (267, 48, 70, 186, 99, 4602.0);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (268, 87, 20, 44, 136, 4468.0);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (269, 72, 316, 116, 53, 1219.98);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (270, 73, 296, 475, 305, 2902.88);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (271, 73, 176, 314, 379, 4938.03);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (272, 74, 199, 399, 431, 3948.45);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (273, 16, 154, 642, 278, 2669.56);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (274, 34, 174, 376, 194, 2554.97);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (275, 59, 260, 377, 93, 853.11);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (276, 73, 51, 33, 145, 4858.23);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (277, 87, 488, 61, 164, 3200.11);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (278, 87, 463, 627, 115, 3867.31);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (279, 9, 456, 225, 491, 4231.7);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (280, 100, 264, 335, 413, 3328.18);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (281, 54, 329, 462, 342, 2882.56);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (282, 71, 249, 625, 106, 4083.95);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (283, 52, 388, 325, 477, 2081.21);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (284, 75, 305, 667, 62, 2611.1);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (285, 85, 246, 545, 241, 1814.43);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (286, 8, 66, 265, 183, 4055.92);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (287, 45, 2, 169, 255, 3653.16);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (288, 70, 441, 196, 499, 4139.71);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (289, 91, 277, 36, 68, 2643.18);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (290, 71, 421, 341, 180, 2631.71);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (291, 99, 193, 403, 126, 1494.94);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (292, 94, 247, 345, 286, 2371.81);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (293, 97, 255, 473, 469, 1965.54);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (294, 62, 249, 565, 338, 4188.71);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (295, 28, 417, 502, 367, 3242.46);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (296, 30, 38, 446, 162, 1283.44);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (297, 68, 192, 140, 79, 2999.86);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (298, 24, 19, 106, 270, 524.31);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (299, 98, 166, 321, 297, 805.36);
INSERT INTO SupplierSupplyFact (SupplyID, SupplierID, ProductID, SupplyDateID, QuantitySupplied, SupplyCost) VALUES (300, 35, 410, 689, 71, 861.1);
SET IDENTITY_INSERT SupplierSupplyFact OFF;
GO


SET IDENTITY_INSERT ProductionFact ON;
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (1, 308, 3, 156, 972, 156.51);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (2, 228, 2, 103, 790, 240.99);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (3, 172, 6, 183, 947, 20.55);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (4, 427, 5, 28, 852, 231.86);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (5, 357, 10, 249, 330, 158.54);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (6, 349, 1, 663, 819, 237.09);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (7, 469, 2, 187, 757, 239.48);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (8, 95, 9, 331, 288, 151.24);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (9, 173, 3, 345, 103, 235.89);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (10, 299, 5, 31, 907, 164.14);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (11, 499, 4, 597, 345, 215.36);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (12, 260, 10, 395, 674, 90.5);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (13, 432, 10, 636, 731, 197.07);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (14, 331, 6, 55, 103, 127.21);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (15, 1, 5, 211, 950, 111.67);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (16, 255, 8, 4, 167, 75.77);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (17, 411, 10, 362, 413, 52.3);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (18, 310, 7, 679, 654, 161.8);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (19, 240, 6, 607, 616, 10.74);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (20, 168, 4, 256, 617, 49.64);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (21, 442, 8, 196, 370, 221.67);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (22, 9, 6, 182, 156, 176.05);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (23, 5, 1, 459, 597, 241.38);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (24, 109, 10, 161, 527, 212.99);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (25, 176, 6, 259, 762, 136.97);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (26, 217, 2, 7, 877, 166.58);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (27, 85, 2, 528, 302, 47.68);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (28, 161, 2, 290, 215, 238.21);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (29, 230, 4, 9, 453, 116.16);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (30, 14, 8, 59, 402, 192.94);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (31, 447, 10, 194, 757, 247.66);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (32, 413, 7, 98, 355, 157.96);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (33, 16, 4, 644, 593, 148.93);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (34, 336, 8, 178, 578, 128.13);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (35, 144, 1, 135, 639, 58.13);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (36, 299, 8, 646, 850, 140.32);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (37, 469, 7, 694, 980, 158.12);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (38, 292, 1, 623, 575, 136.6);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (39, 251, 9, 253, 297, 19.43);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (40, 120, 3, 387, 775, 90.07);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (41, 408, 3, 246, 882, 48.22);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (42, 154, 8, 341, 846, 13.75);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (43, 265, 8, 662, 189, 148.76);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (44, 307, 5, 633, 201, 229.09);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (45, 481, 5, 566, 376, 48.01);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (46, 480, 4, 419, 559, 139.89);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (47, 107, 7, 33, 327, 235.23);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (48, 415, 8, 432, 451, 234.16);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (49, 380, 7, 177, 961, 57.47);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (50, 142, 9, 615, 993, 194.58);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (51, 400, 2, 180, 720, 104.18);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (52, 253, 4, 239, 695, 128.45);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (53, 26, 9, 471, 215, 247.02);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (54, 74, 5, 189, 162, 173.06);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (55, 432, 1, 651, 898, 35.74);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (56, 209, 1, 234, 648, 195.72);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (57, 500, 9, 305, 294, 119.19);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (58, 313, 7, 516, 806, 19.28);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (59, 452, 4, 82, 208, 95.87);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (60, 165, 9, 587, 280, 155.61);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (61, 402, 5, 320, 318, 185.9);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (62, 283, 3, 727, 179, 234.25);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (63, 420, 7, 184, 513, 161.34);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (64, 318, 10, 386, 757, 219.55);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (65, 65, 7, 211, 963, 62.63);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (66, 78, 2, 224, 377, 149.59);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (67, 410, 2, 461, 372, 143.38);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (68, 50, 4, 261, 779, 188.17);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (69, 497, 10, 513, 173, 129.46);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (70, 280, 10, 154, 793, 204.63);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (71, 284, 8, 679, 824, 219.65);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (72, 406, 10, 143, 421, 66.12);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (73, 216, 6, 500, 949, 233.51);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (74, 268, 10, 265, 948, 83.43);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (75, 106, 9, 634, 388, 69.49);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (76, 288, 9, 482, 369, 28.63);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (77, 149, 4, 413, 424, 44.67);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (78, 261, 10, 186, 997, 113.77);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (79, 143, 3, 8, 567, 140.5);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (80, 258, 3, 284, 387, 166.95);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (81, 422, 1, 114, 603, 65.86);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (82, 419, 8, 462, 533, 105.73);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (83, 457, 10, 53, 138, 49.88);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (84, 445, 1, 132, 706, 65.67);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (85, 196, 10, 679, 699, 24.24);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (86, 114, 10, 229, 644, 238.83);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (87, 325, 9, 595, 979, 100.09);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (88, 22, 3, 600, 999, 28.74);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (89, 401, 3, 409, 784, 190.28);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (90, 324, 5, 425, 759, 29.65);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (91, 371, 3, 58, 824, 25.02);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (92, 220, 5, 222, 923, 148.61);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (93, 117, 7, 464, 875, 131.48);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (94, 387, 2, 663, 841, 132.26);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (95, 46, 1, 636, 252, 176.82);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (96, 168, 6, 457, 189, 217.5);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (97, 218, 4, 526, 312, 101.5);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (98, 148, 8, 648, 232, 42.96);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (99, 360, 5, 170, 241, 83.82);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (100, 390, 5, 299, 960, 60.43);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (101, 339, 9, 602, 867, 208.05);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (102, 380, 7, 565, 397, 13.95);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (103, 122, 6, 508, 253, 50.76);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (104, 467, 10, 564, 750, 73.96);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (105, 450, 1, 647, 533, 98.81);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (106, 127, 6, 150, 821, 26.14);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (107, 340, 5, 320, 224, 112.58);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (108, 473, 5, 286, 138, 215.71);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (109, 115, 1, 23, 446, 184.43);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (110, 55, 10, 701, 680, 193.95);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (111, 178, 10, 279, 572, 37.81);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (112, 290, 2, 584, 401, 80.3);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (113, 427, 5, 260, 429, 126.83);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (114, 256, 7, 483, 828, 195.01);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (115, 442, 4, 682, 666, 234.37);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (116, 135, 10, 33, 683, 238.52);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (117, 490, 10, 34, 863, 156.54);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (118, 339, 4, 557, 982, 223.11);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (119, 59, 2, 19, 127, 178.29);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (120, 486, 3, 80, 908, 72.31);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (121, 55, 7, 420, 670, 210.46);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (122, 229, 10, 171, 553, 41.93);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (123, 393, 8, 24, 434, 148.46);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (124, 335, 6, 632, 795, 174.71);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (125, 140, 1, 544, 489, 195.7);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (126, 495, 4, 309, 133, 203.58);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (127, 235, 5, 616, 269, 209.36);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (128, 143, 10, 59, 907, 61.86);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (129, 259, 2, 684, 166, 101.69);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (130, 422, 9, 18, 445, 111.76);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (131, 333, 2, 10, 185, 66.97);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (132, 388, 6, 565, 211, 178.15);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (133, 177, 5, 391, 487, 82.16);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (134, 279, 3, 609, 220, 155.07);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (135, 66, 4, 166, 321, 199.38);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (136, 269, 7, 430, 296, 152.73);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (137, 484, 9, 119, 718, 74.59);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (138, 27, 4, 164, 603, 119.5);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (139, 461, 10, 263, 1000, 246.68);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (140, 186, 7, 521, 881, 219.46);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (141, 113, 8, 83, 214, 79.98);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (142, 131, 1, 322, 859, 95.97);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (143, 375, 2, 176, 680, 172.57);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (144, 28, 9, 440, 557, 31.03);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (145, 284, 4, 720, 114, 149.44);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (146, 365, 8, 48, 812, 198.5);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (147, 194, 6, 171, 655, 146.79);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (148, 57, 3, 642, 360, 200.97);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (149, 183, 6, 285, 359, 61.84);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (150, 371, 5, 8, 243, 44.47);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (151, 369, 8, 201, 784, 48.35);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (152, 28, 3, 268, 191, 196.18);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (153, 58, 10, 33, 847, 216.3);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (154, 379, 8, 492, 654, 19.46);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (155, 430, 4, 17, 584, 175.49);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (156, 333, 2, 207, 482, 159.79);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (157, 117, 5, 140, 949, 91.51);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (158, 102, 10, 664, 883, 154.09);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (159, 98, 2, 98, 712, 219.36);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (160, 241, 8, 676, 487, 156.61);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (161, 205, 7, 607, 998, 133.64);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (162, 230, 6, 506, 262, 191.83);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (163, 497, 3, 146, 140, 174.66);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (164, 367, 5, 614, 371, 166.64);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (165, 5, 1, 382, 892, 148.32);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (166, 245, 6, 630, 281, 41.84);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (167, 375, 7, 688, 132, 113.07);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (168, 402, 3, 597, 711, 45.78);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (169, 257, 5, 5, 190, 115.38);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (170, 262, 3, 23, 163, 139.69);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (171, 367, 1, 189, 969, 65.66);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (172, 140, 4, 60, 699, 127.48);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (173, 359, 9, 721, 701, 36.32);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (174, 396, 1, 158, 187, 183.2);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (175, 264, 2, 652, 879, 219.51);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (176, 24, 2, 512, 419, 237.13);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (177, 152, 2, 640, 817, 198.77);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (178, 10, 5, 402, 517, 74.1);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (179, 490, 3, 431, 872, 180.14);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (180, 191, 3, 677, 892, 103.59);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (181, 338, 10, 467, 157, 144.95);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (182, 255, 6, 616, 741, 112.12);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (183, 302, 2, 697, 882, 35.76);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (184, 79, 6, 165, 404, 66.94);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (185, 467, 6, 377, 794, 115.98);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (186, 190, 10, 455, 595, 134.21);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (187, 18, 5, 670, 498, 179.15);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (188, 195, 10, 511, 336, 152.39);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (189, 83, 9, 378, 745, 121.6);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (190, 102, 6, 271, 966, 61.98);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (191, 55, 3, 483, 536, 249.53);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (192, 192, 10, 536, 138, 63.37);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (193, 432, 8, 254, 546, 204.5);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (194, 99, 3, 210, 711, 131.89);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (195, 482, 1, 490, 510, 242.88);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (196, 312, 8, 116, 366, 118.96);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (197, 455, 10, 624, 879, 201.92);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (198, 265, 8, 110, 719, 88.68);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (199, 167, 5, 566, 992, 162.05);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (200, 340, 5, 321, 754, 71.73);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (201, 435, 5, 648, 595, 139.25);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (202, 42, 8, 671, 906, 64.2);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (203, 84, 9, 371, 259, 75.27);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (204, 500, 5, 37, 426, 205.53);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (205, 55, 9, 609, 387, 87.8);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (206, 61, 9, 327, 953, 231.82);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (207, 275, 9, 209, 489, 159.62);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (208, 195, 10, 500, 875, 70.4);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (209, 420, 7, 391, 780, 239.02);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (210, 213, 2, 580, 210, 18.87);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (211, 336, 8, 529, 743, 80.43);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (212, 146, 7, 598, 226, 138.63);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (213, 287, 3, 28, 753, 140.96);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (214, 62, 2, 693, 907, 178.83);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (215, 364, 3, 91, 366, 199.74);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (216, 361, 10, 171, 850, 18.9);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (217, 245, 10, 52, 162, 143.39);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (218, 285, 5, 472, 118, 33.49);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (219, 423, 1, 339, 344, 202.86);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (220, 377, 10, 19, 568, 187.04);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (221, 209, 7, 204, 805, 145.94);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (222, 312, 2, 397, 274, 21.69);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (223, 320, 7, 615, 229, 13.53);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (224, 256, 2, 463, 289, 57.26);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (225, 118, 5, 649, 147, 181.25);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (226, 292, 4, 662, 948, 182.14);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (227, 305, 4, 581, 282, 127.36);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (228, 442, 7, 399, 932, 142.49);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (229, 321, 10, 701, 809, 152.16);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (230, 474, 10, 406, 204, 120.45);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (231, 224, 1, 463, 693, 89.78);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (232, 383, 3, 296, 603, 54.85);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (233, 139, 10, 337, 229, 68.19);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (234, 292, 4, 108, 258, 120.69);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (235, 49, 3, 630, 739, 180.94);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (236, 21, 3, 201, 882, 79.74);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (237, 176, 3, 658, 892, 55.38);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (238, 304, 6, 193, 211, 141.93);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (239, 69, 10, 133, 596, 237.45);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (240, 20, 5, 514, 402, 42.98);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (241, 126, 3, 449, 938, 92.89);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (242, 216, 5, 685, 287, 202.7);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (243, 93, 1, 446, 451, 232.68);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (244, 33, 1, 142, 420, 118.75);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (245, 111, 2, 206, 185, 54.99);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (246, 103, 1, 630, 418, 57.22);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (247, 404, 4, 657, 140, 200.61);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (248, 9, 1, 202, 912, 209.26);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (249, 353, 10, 46, 243, 103.16);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (250, 127, 9, 294, 343, 205.77);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (251, 172, 5, 724, 827, 221.4);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (252, 192, 9, 321, 747, 49.47);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (253, 42, 3, 516, 162, 197.12);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (254, 45, 3, 597, 251, 150.68);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (255, 314, 3, 376, 299, 11.77);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (256, 34, 8, 560, 403, 227.22);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (257, 389, 3, 384, 231, 48.73);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (258, 433, 4, 113, 114, 214.54);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (259, 101, 3, 223, 369, 180.85);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (260, 361, 7, 702, 207, 65.64);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (261, 487, 4, 138, 558, 28.44);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (262, 226, 8, 517, 559, 38.99);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (263, 272, 6, 279, 527, 231.07);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (264, 437, 2, 193, 741, 246.41);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (265, 155, 9, 725, 780, 93.64);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (266, 130, 2, 425, 775, 94.13);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (267, 288, 1, 99, 557, 241.77);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (268, 460, 1, 74, 394, 16.05);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (269, 479, 6, 136, 996, 221.26);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (270, 282, 3, 117, 764, 23.04);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (271, 476, 8, 434, 783, 84.6);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (272, 479, 1, 441, 505, 218.48);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (273, 178, 10, 65, 555, 245.66);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (274, 49, 6, 549, 311, 18.15);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (275, 11, 8, 531, 124, 37.89);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (276, 303, 6, 14, 966, 220.64);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (277, 444, 8, 411, 827, 203.35);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (278, 160, 10, 657, 229, 44.53);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (279, 140, 8, 633, 517, 120.23);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (280, 260, 3, 484, 221, 82.26);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (281, 162, 5, 61, 865, 60.17);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (282, 334, 10, 419, 343, 171.72);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (283, 345, 7, 665, 184, 200.61);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (284, 79, 8, 244, 705, 27.36);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (285, 467, 1, 445, 494, 70.16);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (286, 183, 8, 136, 207, 223.88);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (287, 124, 2, 79, 350, 192.66);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (288, 488, 2, 127, 640, 30.19);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (289, 357, 4, 431, 552, 58.14);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (290, 31, 6, 312, 910, 177.69);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (291, 451, 10, 427, 320, 132.08);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (292, 48, 1, 102, 482, 116.83);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (293, 482, 3, 606, 209, 84.72);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (294, 312, 2, 504, 556, 76.03);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (295, 355, 7, 623, 796, 223.07);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (296, 89, 10, 454, 247, 241.08);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (297, 88, 2, 387, 683, 154.56);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (298, 364, 5, 387, 921, 199.28);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (299, 377, 1, 197, 393, 101.3);
INSERT INTO ProductionFact (ProductionID, ProductID, FactoryID, ProductionDateID, QuantityProduced, ProductCost) VALUES (300, 407, 6, 285, 970, 84.45);
SET IDENTITY_INSERT ProductionFact OFF;
GO


SET IDENTITY_INSERT InventoryFact ON;
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (1, 220, 2, 23, 336);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (2, 255, 2, 79, 948);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (3, 414, 6, 107, 461);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (4, 289, 10, 393, 896);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (5, 500, 2, 619, 943);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (6, 125, 3, 416, 481);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (7, 410, 8, 483, 195);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (8, 462, 8, 42, 332);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (9, 359, 1, 448, 672);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (10, 14, 6, 596, 881);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (11, 209, 8, 441, 526);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (12, 470, 9, 348, 818);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (13, 398, 7, 713, 344);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (14, 236, 10, 701, 435);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (15, 241, 8, 426, 971);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (16, 417, 10, 680, 571);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (17, 409, 7, 622, 179);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (18, 450, 8, 536, 611);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (19, 141, 9, 438, 708);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (20, 475, 1, 290, 979);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (21, 141, 1, 80, 427);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (22, 100, 4, 494, 951);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (23, 493, 1, 153, 853);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (24, 192, 4, 674, 250);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (25, 194, 6, 614, 140);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (26, 17, 6, 285, 547);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (27, 343, 5, 360, 876);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (28, 398, 8, 611, 552);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (29, 188, 8, 722, 983);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (30, 215, 5, 333, 910);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (31, 454, 9, 299, 471);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (32, 104, 4, 9, 554);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (33, 21, 3, 644, 705);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (34, 65, 5, 567, 889);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (35, 477, 1, 2, 561);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (36, 212, 7, 388, 835);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (37, 124, 7, 229, 75);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (38, 194, 6, 527, 883);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (39, 455, 4, 319, 637);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (40, 291, 7, 584, 701);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (41, 447, 2, 77, 246);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (42, 190, 7, 84, 296);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (43, 102, 3, 27, 725);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (44, 137, 8, 715, 322);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (45, 172, 4, 137, 366);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (46, 54, 2, 24, 426);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (47, 34, 3, 248, 296);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (48, 26, 2, 675, 634);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (49, 22, 5, 151, 455);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (50, 333, 2, 394, 279);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (51, 131, 3, 15, 807);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (52, 244, 10, 599, 68);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (53, 491, 10, 126, 929);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (54, 27, 2, 280, 716);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (55, 336, 5, 120, 729);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (56, 439, 1, 652, 640);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (57, 220, 5, 383, 909);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (58, 417, 8, 58, 607);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (59, 91, 4, 17, 81);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (60, 177, 4, 240, 290);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (61, 63, 5, 503, 966);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (62, 478, 1, 520, 712);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (63, 135, 3, 54, 319);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (64, 92, 2, 375, 195);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (65, 327, 10, 566, 735);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (66, 466, 10, 108, 213);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (67, 104, 3, 725, 868);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (68, 272, 10, 239, 155);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (69, 223, 5, 549, 769);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (70, 450, 8, 553, 840);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (71, 87, 9, 26, 522);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (72, 263, 7, 248, 795);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (73, 171, 3, 288, 353);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (74, 432, 3, 399, 259);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (75, 418, 10, 640, 450);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (76, 467, 9, 50, 92);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (77, 399, 4, 396, 817);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (78, 486, 3, 261, 825);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (79, 65, 8, 25, 879);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (80, 324, 2, 458, 170);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (81, 205, 5, 459, 635);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (82, 199, 7, 649, 275);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (83, 161, 8, 711, 390);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (84, 337, 7, 452, 203);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (85, 181, 9, 601, 779);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (86, 182, 6, 513, 597);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (87, 17, 3, 42, 813);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (88, 308, 6, 471, 145);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (89, 80, 2, 600, 778);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (90, 62, 7, 265, 781);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (91, 136, 10, 505, 512);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (92, 25, 4, 389, 435);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (93, 328, 7, 274, 868);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (94, 414, 2, 161, 613);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (95, 152, 5, 543, 488);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (96, 274, 2, 356, 383);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (97, 120, 1, 562, 193);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (98, 45, 5, 283, 517);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (99, 198, 7, 338, 274);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (100, 23, 1, 433, 420);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (101, 227, 5, 563, 808);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (102, 153, 2, 500, 292);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (103, 35, 4, 302, 301);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (104, 474, 7, 84, 986);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (105, 451, 7, 289, 752);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (106, 12, 4, 720, 55);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (107, 21, 4, 243, 452);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (108, 199, 6, 403, 169);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (109, 233, 5, 677, 236);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (110, 284, 9, 251, 133);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (111, 360, 8, 650, 308);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (112, 409, 1, 53, 637);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (113, 471, 3, 197, 510);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (114, 233, 8, 445, 663);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (115, 346, 8, 376, 527);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (116, 228, 9, 480, 587);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (117, 391, 7, 150, 350);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (118, 295, 5, 131, 144);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (119, 141, 10, 65, 450);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (120, 215, 7, 214, 662);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (121, 453, 9, 629, 793);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (122, 432, 2, 298, 550);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (123, 496, 1, 429, 558);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (124, 316, 3, 23, 198);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (125, 293, 1, 706, 290);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (126, 153, 5, 703, 714);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (127, 448, 8, 137, 336);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (128, 19, 1, 181, 852);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (129, 395, 9, 112, 787);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (130, 445, 1, 93, 775);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (131, 258, 5, 196, 740);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (132, 256, 8, 469, 935);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (133, 73, 7, 668, 834);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (134, 466, 7, 258, 635);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (135, 242, 5, 65, 417);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (136, 328, 10, 242, 359);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (137, 444, 9, 131, 901);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (138, 438, 9, 671, 150);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (139, 496, 2, 305, 866);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (140, 42, 5, 121, 244);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (141, 133, 7, 388, 364);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (142, 145, 2, 210, 321);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (143, 186, 8, 116, 453);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (144, 45, 7, 631, 95);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (145, 264, 4, 683, 783);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (146, 62, 6, 105, 477);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (147, 363, 8, 135, 51);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (148, 409, 4, 173, 916);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (149, 156, 4, 401, 463);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (150, 85, 10, 222, 406);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (151, 252, 5, 131, 72);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (152, 293, 10, 480, 625);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (153, 305, 2, 640, 628);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (154, 300, 5, 325, 522);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (155, 449, 5, 14, 229);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (156, 446, 8, 76, 635);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (157, 171, 10, 699, 229);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (158, 167, 10, 415, 117);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (159, 427, 6, 487, 960);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (160, 384, 4, 479, 69);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (161, 444, 6, 312, 624);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (162, 392, 9, 7, 567);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (163, 210, 9, 466, 643);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (164, 231, 7, 178, 90);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (165, 108, 3, 150, 643);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (166, 38, 6, 419, 83);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (167, 114, 4, 168, 528);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (168, 500, 1, 260, 734);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (169, 102, 2, 213, 190);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (170, 260, 2, 399, 805);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (171, 109, 5, 93, 782);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (172, 317, 2, 471, 419);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (173, 42, 1, 421, 358);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (174, 376, 1, 521, 245);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (175, 283, 9, 663, 763);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (176, 177, 8, 672, 463);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (177, 482, 1, 348, 95);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (178, 222, 2, 169, 629);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (179, 80, 6, 141, 777);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (180, 119, 8, 670, 415);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (181, 466, 6, 661, 57);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (182, 166, 8, 540, 949);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (183, 377, 8, 486, 362);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (184, 62, 3, 379, 343);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (185, 155, 8, 268, 76);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (186, 214, 8, 283, 106);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (187, 383, 5, 707, 626);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (188, 104, 10, 718, 817);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (189, 400, 1, 279, 370);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (190, 215, 4, 513, 628);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (191, 9, 4, 121, 828);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (192, 95, 10, 368, 314);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (193, 473, 5, 281, 907);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (194, 181, 7, 208, 806);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (195, 405, 6, 380, 764);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (196, 169, 3, 429, 145);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (197, 264, 4, 123, 290);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (198, 100, 3, 10, 511);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (199, 357, 3, 568, 165);
INSERT INTO InventoryFact (InventoryID, ProductID, WarehouseID, SnapshotDateID, QuantityOnHand) VALUES (200, 274, 6, 17, 241);
SET IDENTITY_INSERT InventoryFact OFF;
GO

SET IDENTITY_INSERT DistributionFact ON;
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (1, 117, 32, 39, 663, 53);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (2, 383, 24, 13, 199, 158);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (3, 494, 30, 35, 707, 68);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (4, 255, 24, 9, 725, 107);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (5, 177, 18, 33, 57, 130);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (6, 323, 34, 11, 85, 185);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (7, 395, 38, 3, 590, 117);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (8, 288, 32, 25, 494, 103);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (9, 376, 24, 1, 594, 137);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (10, 248, 24, 3, 148, 189);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (11, 413, 30, 15, 659, 177);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (12, 7, 38, 1, 316, 51);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (13, 62, 4, 17, 205, 44);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (14, 331, 26, 15, 647, 27);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (15, 153, 36, 9, 282, 77);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (16, 117, 32, 7, 680, 74);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (17, 494, 4, 27, 527, 162);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (18, 249, 34, 13, 305, 60);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (19, 254, 36, 25, 534, 189);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (20, 372, 16, 27, 207, 200);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (21, 345, 32, 31, 243, 80);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (22, 278, 4, 35, 643, 99);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (23, 235, 12, 1, 116, 42);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (24, 365, 22, 1, 452, 87);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (25, 30, 20, 29, 319, 51);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (26, 455, 12, 1, 607, 199);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (27, 284, 32, 5, 237, 120);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (28, 154, 28, 37, 354, 177);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (29, 430, 38, 3, 630, 103);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (30, 163, 22, 39, 14, 32);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (31, 47, 26, 37, 416, 66);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (32, 204, 14, 3, 640, 43);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (33, 367, 14, 21, 674, 165);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (34, 19, 28, 1, 375, 113);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (35, 273, 22, 13, 144, 50);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (36, 159, 8, 39, 55, 139);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (37, 146, 26, 11, 373, 105);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (38, 79, 2, 11, 374, 82);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (39, 425, 28, 33, 37, 174);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (40, 230, 2, 19, 339, 111);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (41, 142, 20, 5, 730, 107);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (42, 219, 2, 25, 421, 40);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (43, 103, 16, 3, 92, 70);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (44, 364, 34, 1, 284, 91);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (45, 166, 16, 23, 176, 107);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (46, 97, 26, 1, 502, 55);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (47, 335, 20, 13, 708, 112);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (48, 390, 24, 29, 620, 33);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (49, 282, 14, 1, 449, 74);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (50, 113, 6, 27, 335, 114);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (51, 415, 28, 17, 268, 156);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (52, 440, 14, 3, 210, 104);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (53, 65, 20, 3, 466, 111);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (54, 460, 28, 15, 557, 76);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (55, 345, 20, 37, 598, 157);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (56, 360, 22, 33, 302, 114);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (57, 423, 10, 37, 527, 130);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (58, 380, 2, 1, 62, 171);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (59, 278, 10, 37, 528, 148);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (60, 442, 28, 39, 291, 84);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (61, 327, 14, 25, 383, 147);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (62, 435, 38, 27, 146, 95);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (63, 111, 6, 37, 4, 148);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (64, 179, 18, 11, 267, 102);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (65, 292, 30, 13, 88, 126);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (66, 37, 12, 13, 57, 89);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (67, 487, 16, 35, 85, 111);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (68, 230, 12, 25, 279, 183);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (69, 314, 34, 23, 236, 198);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (70, 321, 26, 21, 715, 181);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (71, 389, 38, 27, 313, 90);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (72, 263, 18, 15, 358, 37);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (73, 474, 4, 37, 55, 156);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (74, 105, 34, 13, 333, 190);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (75, 262, 24, 33, 680, 126);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (76, 27, 20, 33, 656, 168);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (77, 431, 12, 35, 90, 162);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (78, 433, 16, 15, 17, 171);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (79, 313, 2, 37, 465, 181);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (80, 438, 8, 39, 543, 194);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (81, 431, 38, 5, 45, 148);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (82, 462, 36, 23, 570, 132);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (83, 339, 16, 19, 531, 45);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (84, 109, 40, 15, 390, 28);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (85, 320, 30, 39, 710, 158);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (86, 368, 26, 25, 206, 75);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (87, 266, 8, 29, 323, 32);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (88, 82, 32, 23, 319, 64);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (89, 144, 12, 27, 372, 157);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (90, 458, 28, 9, 449, 41);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (91, 402, 28, 1, 39, 107);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (92, 155, 32, 13, 693, 151);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (93, 282, 12, 13, 317, 134);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (94, 179, 22, 11, 72, 49);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (95, 105, 30, 37, 718, 71);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (96, 367, 30, 27, 442, 85);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (97, 27, 40, 25, 33, 106);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (98, 351, 20, 7, 422, 191);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (99, 50, 28, 37, 45, 22);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (100, 465, 18, 3, 476, 102);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (101, 389, 26, 21, 206, 120);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (102, 347, 30, 33, 548, 140);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (103, 454, 6, 1, 156, 119);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (104, 409, 36, 17, 528, 51);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (105, 165, 22, 1, 685, 137);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (106, 57, 38, 5, 417, 122);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (107, 448, 22, 21, 538, 83);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (108, 231, 12, 3, 384, 81);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (109, 256, 14, 17, 601, 23);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (110, 213, 36, 13, 121, 74);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (111, 375, 38, 39, 375, 159);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (112, 398, 24, 25, 699, 126);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (113, 81, 2, 31, 557, 22);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (114, 394, 18, 33, 605, 97);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (115, 305, 24, 21, 714, 86);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (116, 243, 10, 19, 42, 200);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (117, 409, 6, 19, 49, 70);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (118, 449, 8, 17, 7, 147);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (119, 72, 6, 33, 399, 122);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (120, 330, 40, 17, 303, 24);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (121, 372, 12, 31, 675, 161);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (122, 409, 28, 25, 181, 100);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (123, 286, 26, 1, 93, 170);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (124, 356, 16, 19, 236, 53);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (125, 252, 24, 39, 698, 83);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (126, 275, 34, 9, 409, 22);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (127, 287, 4, 23, 123, 110);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (128, 170, 2, 37, 419, 129);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (129, 172, 18, 9, 370, 66);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (130, 141, 32, 35, 45, 175);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (131, 429, 32, 13, 390, 149);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (132, 457, 34, 27, 504, 142);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (133, 250, 10, 17, 191, 185);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (134, 436, 28, 11, 360, 136);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (135, 14, 36, 29, 137, 160);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (136, 351, 6, 19, 505, 107);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (137, 223, 24, 15, 412, 88);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (138, 6, 12, 19, 553, 188);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (139, 264, 14, 1, 389, 59);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (140, 3, 40, 21, 226, 62);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (141, 13, 10, 15, 616, 153);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (142, 472, 30, 3, 538, 148);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (143, 383, 36, 9, 221, 77);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (144, 339, 2, 31, 238, 87);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (145, 82, 16, 19, 686, 147);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (146, 281, 2, 7, 241, 38);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (147, 41, 28, 37, 352, 109);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (148, 104, 36, 15, 129, 28);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (149, 284, 8, 5, 187, 182);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (150, 144, 30, 39, 345, 83);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (151, 352, 26, 3, 79, 81);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (152, 339, 20, 17, 642, 113);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (153, 11, 28, 1, 499, 145);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (154, 62, 28, 27, 419, 43);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (155, 395, 8, 23, 47, 125);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (156, 465, 12, 33, 389, 199);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (157, 151, 28, 25, 328, 157);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (158, 316, 4, 37, 514, 143);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (159, 441, 8, 29, 31, 123);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (160, 495, 30, 5, 465, 75);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (161, 404, 4, 13, 207, 185);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (162, 168, 24, 39, 98, 85);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (163, 202, 40, 25, 288, 93);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (164, 472, 28, 35, 240, 123);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (165, 373, 32, 27, 287, 71);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (166, 442, 2, 19, 214, 50);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (167, 292, 18, 13, 402, 192);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (168, 435, 40, 5, 278, 87);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (169, 253, 26, 15, 153, 132);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (170, 333, 36, 1, 696, 184);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (171, 255, 18, 11, 485, 77);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (172, 79, 8, 5, 654, 73);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (173, 360, 8, 9, 501, 148);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (174, 163, 32, 27, 196, 183);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (175, 127, 6, 11, 267, 86);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (176, 479, 34, 27, 459, 184);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (177, 102, 6, 17, 249, 173);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (178, 28, 8, 19, 310, 24);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (179, 247, 16, 9, 669, 159);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (180, 66, 12, 11, 408, 176);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (181, 19, 18, 33, 668, 142);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (182, 271, 16, 17, 423, 114);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (183, 424, 8, 7, 56, 99);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (184, 240, 14, 11, 618, 152);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (185, 281, 24, 11, 357, 109);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (186, 94, 8, 23, 645, 109);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (187, 18, 10, 19, 175, 173);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (188, 397, 10, 19, 628, 110);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (189, 59, 32, 31, 297, 24);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (190, 183, 20, 35, 244, 61);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (191, 184, 18, 23, 182, 24);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (192, 50, 4, 15, 233, 147);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (193, 353, 24, 3, 79, 78);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (194, 480, 32, 9, 172, 75);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (195, 108, 40, 17, 384, 127);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (196, 107, 20, 39, 104, 62);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (197, 22, 6, 31, 324, 145);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (198, 475, 40, 9, 492, 49);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (199, 309, 8, 35, 281, 85);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (200, 49, 12, 13, 309, 23);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (201, 16, 26, 29, 360, 83);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (202, 203, 18, 7, 215, 199);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (203, 308, 34, 37, 682, 88);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (204, 130, 32, 13, 78, 30);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (205, 283, 8, 15, 82, 73);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (206, 34, 28, 33, 283, 154);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (207, 358, 2, 23, 388, 112);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (208, 204, 38, 7, 403, 116);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (209, 405, 26, 27, 99, 36);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (210, 370, 36, 25, 354, 44);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (211, 336, 10, 11, 223, 105);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (212, 156, 34, 35, 214, 70);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (213, 310, 24, 1, 43, 102);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (214, 492, 12, 3, 56, 46);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (215, 176, 20, 17, 485, 32);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (216, 65, 4, 25, 638, 66);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (217, 5, 38, 33, 196, 149);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (218, 251, 16, 27, 274, 68);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (219, 140, 38, 15, 130, 49);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (220, 376, 8, 13, 498, 122);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (221, 270, 12, 9, 41, 91);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (222, 240, 30, 29, 294, 101);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (223, 468, 12, 19, 522, 27);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (224, 179, 22, 31, 330, 177);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (225, 212, 18, 17, 525, 143);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (226, 258, 24, 29, 57, 128);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (227, 56, 4, 21, 106, 23);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (228, 409, 28, 19, 729, 115);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (229, 299, 12, 1, 404, 65);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (230, 370, 36, 5, 342, 71);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (231, 40, 16, 31, 294, 155);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (232, 222, 8, 27, 83, 128);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (233, 252, 36, 35, 536, 30);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (234, 495, 22, 3, 531, 102);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (235, 242, 38, 35, 633, 199);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (236, 169, 20, 9, 578, 187);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (237, 437, 20, 19, 55, 151);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (238, 71, 38, 5, 193, 128);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (239, 11, 12, 3, 159, 174);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (240, 430, 24, 25, 111, 182);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (241, 269, 12, 11, 96, 187);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (242, 457, 36, 35, 259, 200);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (243, 193, 14, 9, 403, 115);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (244, 304, 24, 37, 630, 186);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (245, 425, 14, 7, 262, 195);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (246, 497, 2, 11, 210, 157);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (247, 353, 16, 21, 654, 198);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (248, 374, 2, 7, 705, 182);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (249, 19, 8, 15, 711, 32);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (250, 96, 32, 11, 49, 182);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (251, 438, 20, 9, 5, 104);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (252, 38, 14, 17, 468, 188);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (253, 397, 40, 23, 69, 27);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (254, 59, 26, 3, 690, 79);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (255, 98, 6, 19, 122, 142);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (256, 274, 20, 15, 246, 171);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (257, 440, 40, 29, 146, 137);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (258, 318, 28, 13, 268, 49);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (259, 50, 34, 15, 477, 30);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (260, 289, 4, 13, 469, 144);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (261, 90, 36, 11, 549, 181);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (262, 33, 28, 19, 105, 66);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (263, 212, 20, 1, 633, 170);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (264, 374, 18, 37, 50, 21);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (265, 113, 40, 17, 326, 65);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (266, 128, 30, 9, 628, 100);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (267, 353, 22, 37, 122, 124);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (268, 139, 10, 5, 645, 184);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (269, 267, 28, 37, 170, 83);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (270, 367, 2, 9, 661, 61);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (271, 4, 30, 25, 363, 33);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (272, 311, 18, 31, 398, 174);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (273, 323, 20, 5, 262, 199);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (274, 479, 6, 21, 148, 177);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (275, 486, 34, 25, 641, 20);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (276, 162, 8, 37, 673, 154);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (277, 399, 4, 13, 282, 27);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (278, 172, 36, 31, 334, 134);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (279, 405, 34, 1, 292, 179);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (280, 475, 4, 17, 26, 44);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (281, 272, 14, 11, 84, 147);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (282, 29, 36, 11, 113, 123);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (283, 140, 24, 9, 210, 115);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (284, 473, 22, 21, 104, 120);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (285, 224, 20, 1, 203, 45);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (286, 107, 2, 13, 498, 40);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (287, 48, 16, 13, 398, 122);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (288, 108, 10, 15, 199, 182);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (289, 269, 8, 33, 453, 82);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (290, 136, 36, 3, 480, 27);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (291, 299, 6, 29, 6, 134);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (292, 125, 20, 9, 705, 160);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (293, 473, 4, 13, 723, 152);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (294, 431, 38, 3, 473, 121);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (295, 350, 30, 5, 531, 65);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (296, 96, 2, 27, 263, 27);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (297, 335, 30, 17, 341, 44);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (298, 305, 18, 33, 567, 193);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (299, 430, 14, 13, 369, 28);
INSERT INTO DistributionFact (DistributionID, ProductID, WholesaleStoreID, RetailStoreID, DateID, Quantity) VALUES (300, 339, 34, 25, 367, 124);
SET IDENTITY_INSERT DistributionFact OFF;
GO

SET IDENTITY_INSERT FailedFact ON;
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (1, 470, 'Expired', 1, 8);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (2, 216, 'Expired', 3, 17);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (3, 18, 'Broken Seal', 1, 8);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (4, 133, 'Damaged', 5, 7);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (5, 332, 'Broken Seal', 4, 4);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (6, 464, 'Damaged', 10, 2);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (7, 394, 'Expired', 8, 11);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (8, 72, 'Expired', 3, 7);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (9, 65, 'Broken Seal', 4, 19);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (10, 40, 'Expired', 1, 1);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (11, 271, 'Damaged', 1, 18);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (12, 67, 'Spoiled', 1, 9);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (13, 336, 'Spoiled', 1, 10);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (14, 40, 'Broken Seal', 6, 17);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (15, 412, 'Spoiled', 6, 16);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (16, 73, 'Expired', 9, 15);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (17, 95, 'Broken Seal', 5, 20);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (18, 415, 'Damaged', 10, 15);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (19, 80, 'Broken Seal', 5, 7);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (20, 342, 'Broken Seal', 3, 11);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (21, 40, 'Broken Seal', 1, 14);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (22, 444, 'Damaged', 3, 11);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (23, 386, 'Spoiled', 10, 13);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (24, 440, 'Expired', 6, 20);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (25, 77, 'Expired', 5, 10);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (26, 265, 'Expired', 2, 10);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (27, 32, 'Expired', 7, 15);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (28, 32, 'Mislabelled', 3, 9);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (29, 15, 'Returned', 3, 1);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (30, 262, 'Mislabelled', 2, 18);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (31, 477, 'Damaged', 3, 6);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (32, 209, 'Damaged', 6, 7);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (33, 120, 'Returned', 5, 4);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (34, 10, 'Returned', 5, 6);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (35, 427, 'Returned', 3, 12);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (36, 43, 'Spoiled', 8, 11);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (37, 450, 'Spoiled', 5, 6);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (38, 115, 'Damaged', 4, 9);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (39, 95, 'Expired', 3, 20);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (40, 150, 'Damaged', 2, 5);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (41, 5, 'Damaged', 5, 19);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (42, 499, 'Damaged', 2, 12);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (43, 375, 'Expired', 8, 9);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (44, 109, 'Expired', 7, 10);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (45, 443, 'Mislabelled', 4, 12);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (46, 232, 'Returned', 5, 11);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (47, 114, 'Broken Seal', 8, 8);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (48, 82, 'Returned', 6, 2);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (49, 305, 'Damaged', 5, 9);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (50, 45, 'Expired', 6, 1);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (51, 33, 'Returned', 5, 1);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (52, 174, 'Spoiled', 5, 7);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (53, 151, 'Expired', 10, 17);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (54, 314, 'Expired', 5, 15);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (55, 183, 'Damaged', 10, 17);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (56, 40, 'Expired', 10, 14);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (57, 217, 'Damaged', 1, 16);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (58, 11, 'Mislabelled', 9, 10);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (59, 3, 'Spoiled', 1, 8);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (60, 121, 'Spoiled', 7, 16);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (61, 312, 'Broken Seal', 6, 12);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (62, 245, 'Spoiled', 4, 15);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (63, 90, 'Returned', 5, 18);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (64, 368, 'Broken Seal', 7, 13);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (65, 437, 'Mislabelled', 9, 9);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (66, 260, 'Spoiled', 9, 15);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (67, 465, 'Expired', 9, 18);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (68, 86, 'Damaged', 7, 12);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (69, 334, 'Spoiled', 9, 13);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (70, 399, 'Returned', 6, 12);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (71, 228, 'Spoiled', 9, 15);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (72, 457, 'Spoiled', 8, 13);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (73, 382, 'Returned', 4, 10);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (74, 53, 'Returned', 5, 8);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (75, 50, 'Mislabelled', 4, 19);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (76, 314, 'Mislabelled', 8, 2);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (77, 340, 'Spoiled', 3, 13);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (78, 52, 'Damaged', 1, 19);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (79, 334, 'Spoiled', 7, 2);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (80, 167, 'Mislabelled', 8, 14);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (81, 71, 'Broken Seal', 6, 5);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (82, 224, 'Broken Seal', 7, 9);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (83, 194, 'Mislabelled', 3, 14);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (84, 287, 'Mislabelled', 4, 4);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (85, 326, 'Damaged', 1, 10);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (86, 64, 'Spoiled', 4, 16);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (87, 317, 'Spoiled', 10, 10);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (88, 194, 'Spoiled', 3, 20);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (89, 239, 'Returned', 4, 3);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (90, 32, 'Damaged', 2, 20);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (91, 249, 'Returned', 3, 11);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (92, 38, 'Spoiled', 3, 19);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (93, 238, 'Spoiled', 5, 16);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (94, 23, 'Broken Seal', 3, 3);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (95, 349, 'Returned', 10, 11);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (96, 264, 'Mislabelled', 2, 6);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (97, 342, 'Spoiled', 5, 8);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (98, 316, 'Returned', 1, 3);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (99, 389, 'Damaged', 3, 12);
INSERT INTO FailedFact (FailedID, ProductID, Status, ReasonID, FailedQuantity) VALUES (100, 173, 'Spoiled', 7, 11);
SET IDENTITY_INSERT FailedFact OFF;
GO




INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (350, 110, 326);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (361, 54, 499);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (51, 403, 15);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (324, 338, 620);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (474, 159, 98);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (116, 159, 2);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (217, 96, 355);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (220, 71, 430);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (224, 242, 625);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (146, 172, 678);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (24, 362, 259);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (213, 250, 310);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (498, 67, 429);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (78, 106, 82);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (138, 191, 135);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (187, 166, 703);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (123, 309, 293);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (365, 108, 478);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (350, 163, 233);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (95, 32, 431);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (376, 44, 492);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (383, 133, 452);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (236, 308, 210);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (77, 444, 160);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (306, 379, 703);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (124, 36, 119);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (402, 320, 335);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (188, 171, 609);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (78, 62, 327);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (65, 342, 377);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (454, 49, 153);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (251, 151, 375);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (125, 95, 401);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (82, 389, 492);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (358, 142, 490);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (303, 197, 697);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (96, 345, 633);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (256, 196, 528);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (170, 4, 149);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (305, 98, 260);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (104, 173, 450);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (1, 431, 629);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (415, 436, 305);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (494, 58, 711);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (462, 497, 401);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (356, 425, 483);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (23, 320, 135);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (10, 319, 652);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (133, 451, 114);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (486, 170, 117);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (84, 56, 488);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (73, 478, 356);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (297, 394, 37);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (104, 471, 500);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (122, 312, 41);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (410, 109, 107);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (212, 378, 517);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (67, 161, 205);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (119, 84, 417);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (39, 187, 105);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (30, 448, 608);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (351, 44, 537);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (441, 241, 725);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (82, 439, 255);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (144, 311, 106);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (320, 440, 54);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (428, 51, 382);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (429, 13, 175);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (41, 14, 35);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (241, 405, 440);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (287, 144, 685);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (466, 348, 3);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (161, 362, 495);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (164, 215, 97);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (462, 10, 340);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (230, 15, 639);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (135, 430, 668);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (484, 302, 22);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (246, 164, 708);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (218, 55, 124);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (325, 159, 155);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (357, 374, 694);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (101, 401, 239);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (103, 201, 575);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (491, 45, 489);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (475, 103, 289);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (497, 327, 225);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (423, 47, 127);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (286, 230, 297);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (21, 91, 65);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (313, 51, 682);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (311, 403, 215);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (361, 75, 542);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (62, 142, 373);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (311, 367, 288);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (82, 235, 113);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (269, 118, 556);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (143, 124, 70);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (425, 421, 268);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (366, 8, 639);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (368, 374, 380);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (238, 362, 474);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (492, 230, 726);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (161, 410, 582);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (103, 131, 365);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (369, 4, 44);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (413, 225, 394);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (344, 466, 515);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (328, 351, 210);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (217, 304, 443);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (373, 193, 500);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (490, 141, 492);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (276, 483, 310);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (161, 68, 492);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (262, 203, 642);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (259, 303, 297);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (99, 14, 335);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (32, 363, 451);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (166, 162, 183);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (309, 160, 265);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (106, 384, 228);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (393, 140, 422);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (256, 91, 54);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (152, 432, 525);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (5, 142, 626);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (141, 425, 141);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (292, 81, 643);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (267, 202, 293);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (44, 450, 532);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (318, 57, 441);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (442, 423, 468);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (395, 428, 183);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (355, 470, 217);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (471, 478, 713);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (164, 239, 198);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (476, 499, 139);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (134, 322, 14);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (402, 335, 486);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (222, 340, 712);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (187, 330, 378);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (6, 374, 418);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (321, 39, 191);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (202, 106, 61);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (432, 77, 143);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (420, 362, 673);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (79, 470, 105);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (5, 482, 587);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (454, 125, 340);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (214, 160, 589);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (447, 144, 365);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (295, 95, 396);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (221, 48, 208);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (119, 387, 370);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (150, 77, 706);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (81, 165, 172);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (6, 77, 410);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (365, 350, 244);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (414, 360, 489);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (13, 146, 39);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (354, 19, 9);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (358, 470, 381);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (166, 458, 608);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (221, 442, 359);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (355, 141, 246);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (258, 498, 167);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (192, 307, 544);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (329, 320, 606);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (389, 232, 204);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (153, 69, 547);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (7, 347, 223);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (107, 91, 179);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (3, 99, 48);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (228, 446, 72);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (281, 203, 265);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (334, 91, 687);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (176, 248, 576);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (244, 69, 590);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (86, 384, 9);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (242, 231, 648);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (232, 112, 325);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (215, 35, 109);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (340, 67, 673);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (195, 408, 346);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (488, 198, 606);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (65, 86, 326);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (308, 360, 180);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (18, 109, 568);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (157, 373, 520);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (373, 230, 342);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (74, 212, 638);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (209, 15, 713);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (288, 247, 170);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (43, 146, 576);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (486, 76, 321);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (295, 250, 549);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (449, 37, 480);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (42, 229, 158);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (276, 63, 195);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (459, 111, 288);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (451, 406, 708);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (132, 113, 201);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (386, 331, 514);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (261, 180, 69);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (152, 244, 456);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (34, 221, 165);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (300, 204, 227);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (26, 171, 324);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (171, 474, 442);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (275, 204, 352);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (105, 177, 459);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (64, 366, 73);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (196, 453, 576);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (320, 435, 704);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (454, 36, 77);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (388, 325, 287);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (320, 418, 465);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (127, 109, 424);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (476, 337, 357);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (396, 424, 146);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (380, 120, 79);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (455, 57, 721);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (204, 320, 559);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (235, 63, 82);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (306, 335, 643);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (474, 145, 729);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (113, 52, 546);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (281, 432, 685);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (250, 330, 302);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (435, 185, 194);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (251, 171, 275);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (290, 149, 440);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (141, 493, 238);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (77, 421, 328);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (256, 461, 309);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (312, 398, 215);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (479, 121, 468);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (8, 221, 327);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (475, 362, 333);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (111, 487, 703);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (467, 88, 145);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (424, 78, 550);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (117, 364, 51);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (257, 306, 709);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (105, 439, 728);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (234, 106, 501);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (436, 177, 4);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (280, 92, 688);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (421, 44, 62);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (329, 307, 347);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (210, 376, 219);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (61, 448, 577);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (489, 133, 478);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (463, 89, 26);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (290, 154, 642);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (452, 225, 201);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (4, 367, 394);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (83, 35, 164);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (465, 347, 194);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (480, 363, 163);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (154, 113, 280);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (198, 131, 268);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (489, 92, 548);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (70, 381, 387);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (253, 29, 20);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (191, 31, 434);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (373, 483, 140);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (251, 485, 360);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (199, 227, 527);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (223, 11, 607);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (345, 68, 649);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (222, 466, 630);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (465, 142, 656);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (182, 249, 145);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (3, 325, 274);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (489, 456, 690);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (196, 490, 257);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (26, 7, 514);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (84, 71, 350);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (16, 39, 343);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (371, 484, 205);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (337, 118, 697);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (397, 47, 353);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (485, 464, 8);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (155, 304, 546);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (356, 24, 52);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (273, 10, 472);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (158, 427, 340);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (51, 341, 132);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (462, 417, 652);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (10, 488, 551);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (390, 238, 336);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (42, 215, 433);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (340, 105, 542);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (303, 464, 49);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (139, 424, 393);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (293, 203, 103);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (112, 110, 254);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (240, 170, 138);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (461, 192, 182);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (345, 7, 36);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (145, 37, 331);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (449, 240, 281);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (311, 451, 8);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (376, 110, 309);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (104, 490, 299);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (209, 149, 334);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (52, 116, 606);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (247, 424, 264);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (137, 164, 254);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (309, 423, 698);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (241, 164, 538);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (271, 232, 427);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (382, 229, 626);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (190, 319, 718);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (168, 17, 100);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (339, 160, 95);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (396, 169, 500);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (246, 416, 399);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (297, 129, 9);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (236, 313, 206);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (308, 497, 157);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (473, 426, 481);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (272, 220, 413);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (108, 193, 339);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (261, 48, 425);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (368, 33, 579);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (88, 440, 88);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (96, 129, 332);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (480, 137, 701);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (466, 134, 237);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (232, 99, 227);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (477, 30, 250);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (379, 219, 72);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (452, 474, 151);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (216, 47, 199);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (232, 151, 215);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (383, 421, 248);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (306, 441, 678);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (331, 35, 604);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (419, 500, 314);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (95, 328, 549);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (450, 443, 548);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (151, 34, 247);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (450, 104, 36);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (282, 27, 209);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (336, 120, 250);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (337, 321, 721);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (425, 61, 321);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (330, 128, 568);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (77, 185, 519);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (160, 16, 599);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (384, 101, 557);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (271, 222, 416);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (256, 202, 330);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (273, 222, 628);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (122, 31, 566);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (100, 434, 242);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (176, 29, 578);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (195, 122, 7);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (400, 102, 142);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (467, 396, 462);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (23, 145, 522);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (186, 177, 167);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (422, 48, 245);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (499, 366, 55);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (491, 354, 219);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (241, 195, 348);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (238, 417, 116);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (53, 489, 189);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (361, 115, 443);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (28, 382, 233);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (106, 368, 588);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (40, 71, 33);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (368, 438, 51);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (493, 56, 384);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (76, 301, 203);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (365, 213, 122);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (204, 148, 184);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (226, 72, 603);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (393, 178, 707);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (153, 146, 64);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (41, 215, 311);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (315, 43, 679);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (262, 58, 615);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (422, 199, 488);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (241, 380, 582);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (91, 46, 490);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (378, 106, 586);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (378, 361, 604);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (188, 7, 249);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (367, 448, 153);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (220, 81, 41);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (466, 207, 684);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (319, 218, 575);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (276, 191, 370);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (150, 6, 402);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (60, 455, 302);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (377, 235, 386);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (398, 393, 407);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (444, 154, 24);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (385, 72, 451);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (76, 303, 314);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (136, 178, 281);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (225, 5, 680);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (300, 392, 695);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (426, 399, 145);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (420, 234, 15);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (24, 219, 647);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (282, 315, 17);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (427, 226, 646);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (78, 234, 226);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (141, 453, 371);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (417, 411, 95);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (45, 475, 244);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (368, 52, 22);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (142, 166, 348);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (293, 64, 575);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (471, 66, 103);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (350, 86, 222);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (151, 440, 158);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (288, 234, 392);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (152, 206, 39);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (11, 309, 44);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (460, 402, 314);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (3, 213, 524);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (188, 233, 678);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (433, 346, 480);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (175, 129, 213);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (80, 215, 127);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (143, 79, 635);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (213, 186, 362);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (240, 219, 343);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (174, 410, 409);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (284, 225, 520);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (252, 498, 688);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (280, 381, 309);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (245, 334, 692);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (234, 477, 630);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (427, 339, 107);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (347, 161, 401);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (227, 232, 532);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (305, 336, 545);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (389, 217, 721);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (370, 451, 333);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (443, 198, 697);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (382, 5, 95);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (88, 224, 338);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (160, 55, 556);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (321, 482, 542);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (403, 418, 462);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (306, 137, 713);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (138, 174, 308);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (473, 89, 66);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (387, 331, 586);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (129, 334, 402);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (98, 307, 180);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (202, 189, 723);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (419, 195, 64);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (287, 436, 77);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (282, 445, 126);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (89, 248, 498);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (347, 491, 242);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (299, 184, 665);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (151, 170, 342);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (76, 315, 538);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (372, 346, 214);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (457, 361, 97);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (8, 112, 241);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (384, 202, 548);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (257, 100, 445);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (119, 176, 324);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (244, 7, 337);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (438, 465, 610);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (384, 169, 535);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (338, 33, 685);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (325, 422, 665);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (182, 113, 450);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (329, 414, 150);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (392, 417, 709);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (251, 340, 42);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (190, 59, 51);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (150, 207, 252);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (1, 359, 38);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (45, 441, 709);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (436, 218, 373);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (80, 189, 483);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (349, 236, 584);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (359, 336, 329);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (63, 153, 540);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (214, 413, 251);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (429, 232, 132);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (296, 383, 616);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (332, 94, 323);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (216, 65, 286);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (424, 371, 35);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (56, 191, 137);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (298, 220, 523);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (350, 349, 224);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (191, 150, 656);
INSERT INTO ProductViewFact (ProductID, CustomerID, ViewDateID) VALUES (286, 396, 47);
GO


-- a) Populate CategorySales_Aggregate
INSERT INTO CategorySales_Aggregate (
    CategoryID, CategoryName, CustomerID, StoreID, StoreName, DateID, ActualDate, SalesAmount
)
SELECT 
    c.CategoryID,
    c.CategoryName,
    o.CustomerID,
    o.StoreID,
    s.StoreName,
    d.DateID,
    d.ActualDate,
    SUM(sf.SalesAmount)
FROM SalesFact sf
JOIN OrderDim o ON sf.OrderDimID = o.OrderDimID
JOIN ProductDim p ON sf.ProductID = p.ProductID
JOIN BrandDim b ON p.BrandID = b.BrandID
JOIN CategoryDim c ON b.CategoryID = c.CategoryID
JOIN StoreDim s ON o.StoreID = s.StoreID
JOIN DateDim d ON o.OrderDateID = d.DateID
WHERE o.StoreID IS NOT NULL
GROUP BY 
    c.CategoryID, c.CategoryName,
    o.CustomerID,
    o.StoreID, s.StoreName,
    d.DateID, d.ActualDate;
GO


-- b) Populate StoreSales_Aggregate
INSERT INTO StoreSales_Aggregate (
    StoreID, StoreName, DateID, ActualDate, TotalSales, TotalQuantitySold
)
SELECT 
    o.StoreID,
    s.StoreName,
    o.OrderDateID,
    d.ActualDate,
    SUM(sf.SalesAmount),
    SUM(sf.QuantitySold)
FROM SalesFact sf
JOIN OrderDim o ON sf.OrderDimID = o.OrderDimID
JOIN StoreDim s ON o.StoreID = s.StoreID
JOIN DateDim d ON o.OrderDateID = d.DateID
WHERE o.StoreID IS NOT NULL
GROUP BY 
    o.StoreID, s.StoreName,
    o.OrderDateID, d.ActualDate;
GO


-- c) Populate ProductPerformance_Aggregate
INSERT INTO ProductPerformance_Aggregate (
    ProductID, ProductName, DateID, ActualDate, TotalSales, TotalQuantitySold
)
SELECT 
    sf.ProductID,
    p.ProductName,
    o.OrderDateID,
    d.ActualDate,
    SUM(sf.SalesAmount),
    SUM(sf.QuantitySold)
FROM SalesFact sf
JOIN ProductDim p ON sf.ProductID = p.ProductID
JOIN OrderDim o ON sf.OrderDimID = o.OrderDimID
JOIN DateDim d ON o.OrderDateID = d.DateID
GROUP BY 
    sf.ProductID, p.ProductName,
    o.OrderDateID, d.ActualDate;
GO




-- 1. Total Sales by Store
SELECT s.StoreName, SUM(sf.SalesAmount) AS TotalSales
FROM SalesFact sf
JOIN OrderDim o ON sf.OrderDimID = o.OrderDimID
JOIN StoreDim s ON o.StoreID = s.StoreID
GROUP BY s.StoreName;

-- 2. Monthly Sales Trend
SELECT d.Year, d.Month, SUM(sf.SalesAmount) AS MonthlySales
FROM SalesFact sf
JOIN OrderDim o ON sf.OrderDimID = o.OrderDimID
JOIN OrderDateDim d ON o.OrderDateID = d.DateID
GROUP BY d.Year, d.Month
ORDER BY d.Year, 
    CASE d.Month
        WHEN 'January' THEN 1 WHEN 'February' THEN 2 WHEN 'March' THEN 3
        WHEN 'April' THEN 4 WHEN 'May' THEN 5 WHEN 'June' THEN 6
        WHEN 'July' THEN 7 WHEN 'August' THEN 8 WHEN 'September' THEN 9
        WHEN 'October' THEN 10 WHEN 'November' THEN 11 WHEN 'December' THEN 12
    END;

-- 3. Top 5 Products by Sales
SELECT TOP 5 p.ProductName, SUM(sf.SalesAmount) AS TotalSales
FROM SalesFact sf
JOIN ProductDim p ON sf.ProductID = p.ProductID
GROUP BY p.ProductName
ORDER BY TotalSales DESC;

-- 4. Average Sales Amount per Customer
SELECT c.FirstName, c.LastName, AVG(sf.SalesAmount) AS AvgSales
FROM SalesFact sf
JOIN OrderDim o ON sf.OrderDimID = o.OrderDimID
JOIN CustomerDim c ON o.CustomerID = c.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName;

-- 5. Inventory Levels by Warehouse
SELECT w.WarehouseName, SUM(ifact.QuantityOnHand) AS TotalInventory
FROM InventoryFact ifact
JOIN WarehouseDim w ON ifact.WarehouseID = w.WarehouseID
GROUP BY w.WarehouseName;

-- 6. Production Cost by Factory
SELECT f.FactoryName, SUM(pf.ProductCost) AS TotalProductionCost
FROM ProductionFact pf
JOIN FactoryDim f ON pf.FactoryID = f.FactoryID
GROUP BY f.FactoryName;

-- 7. Failed Products Analysis by Reason
SELECT r.Reason, SUM(ff.FailedQuantity) AS TotalFailed
FROM FailedFact ff
JOIN ReasonDim r ON ff.ReasonID = r.ReasonID
GROUP BY r.Reason;

-- 8. Promotion Effectiveness
SELECT p.PromotionName, SUM(sf.SalesAmount) AS PromotionSales
FROM ProductPromoBridge pb
JOIN PromoDim p ON pb.PromotionID = p.PromotionID
JOIN SalesFact sf ON pb.ProductID = sf.ProductID
GROUP BY p.PromotionName;

-- 9. Store Sales Aggregate Overview
SELECT sa.StoreID, s.StoreName, sa.DateID, sa.TotalSales, sa.TotalQuantitySold
FROM StoreSales_Aggregate sa
JOIN StoreDim s ON sa.StoreID = s.StoreID;

-- 10. Product Performance Aggregation
SELECT pa.ProductID, p.ProductName, pa.TotalSales, pa.TotalQuantitySold
FROM ProductPerformance_Aggregate pa
JOIN ProductDim p ON pa.ProductID = p.ProductID;

-- 11. Category Sales Analysis
SELECT cd.CategoryName, SUM(csa.SalesAmount) AS TotalCategorySales
FROM CategorySales_Aggregate csa
JOIN CategoryDim cd ON csa.CategoryID = cd.CategoryID
GROUP BY cd.CategoryName;

-- 12. Sales by Payment Method
SELECT pd.PaymentMethod, SUM(sf.SalesAmount) AS TotalSales
FROM SalesFact sf
JOIN OrderDim o ON sf.OrderDimID = o.OrderDimID
JOIN OrderPaymentBridge op ON o.OrderDimID = op.OrderDimID
JOIN PaymentDim pd ON op.PaymentID = pd.PaymentID
GROUP BY pd.PaymentMethod;

-- 13. Supplier Supply Performance
SELECT s.SupplierName, SUM(ssf.QuantitySupplied) AS TotalSupplied, SUM(ssf.SupplyCost) AS TotalCost
FROM SupplierSupplyFact ssf
JOIN SupplierDim s ON ssf.SupplierID = s.SupplierID
GROUP BY s.SupplierName;

-- 14. Sales Trend for a Specific Store (StoreID = 1)
SELECT d.Month, d.Year, SUM(sf.SalesAmount) AS MonthlySales
FROM SalesFact sf
JOIN OrderDim o ON sf.OrderDimID = o.OrderDimID
JOIN OrderDateDim d ON o.OrderDateID = d.DateID
WHERE o.StoreID = 1
GROUP BY d.Year, d.Month
ORDER BY d.Year,
    CASE d.Month
        WHEN 'January' THEN 1 WHEN 'February' THEN 2 WHEN 'March' THEN 3
        WHEN 'April' THEN 4 WHEN 'May' THEN 5 WHEN 'June' THEN 6
        WHEN 'July' THEN 7 WHEN 'August' THEN 8 WHEN 'September' THEN 9
        WHEN 'October' THEN 10 WHEN 'November' THEN 11 WHEN 'December' THEN 12
    END;

-- 15. Yearly Supplier Supply Analysis (Year = 2024)
SELECT s.SupplierName, d.Year, SUM(ssf.QuantitySupplied) AS TotalQuantity, SUM(ssf.SupplyCost) AS TotalSupplyCost
FROM SupplierSupplyFact ssf
JOIN SupplierDim s ON ssf.SupplierID = s.SupplierID
JOIN SupplyDateDim d ON ssf.SupplyDateID = d.DateID
WHERE d.Year = 2024
GROUP BY s.SupplierName, d.Year;

-- 16. Customer Feedback Summary
SELECT c.FirstName, c.LastName, AVG(cf.Rating) AS AvgRating, COUNT(cf.FeedbackFactID) AS FeedbackCount
FROM CustomerFeedbackFact cf
JOIN OrderDim o ON cf.OrderDimID = o.OrderDimID
JOIN CustomerDim c ON o.CustomerID = c.CustomerID
GROUP BY c.CustomerID, c.FirstName, c.LastName;

-- 17. Returns Analysis by Reason
SELECT ReturnReason, SUM(QuantityReturned) AS TotalReturned
FROM ReturnsFact
GROUP BY ReturnReason;

-- 18. Total Sales per Product in 2024
SELECT p.ProductName, SUM(sf.SalesAmount) AS TotalSales
FROM SalesFact sf
JOIN OrderDim o ON sf.OrderDimID = o.OrderDimID
JOIN OrderDateDim d ON o.OrderDateID = d.DateID
JOIN ProductDim p ON sf.ProductID = p.ProductID
WHERE d.Year = 2024
GROUP BY p.ProductName;

-- 19. Average Production Cost per Product
SELECT p.ProductName, AVG(pf.ProductCost) AS AvgCost
FROM ProductionFact pf
JOIN ProductDim p ON pf.ProductID = p.ProductID
GROUP BY p.ProductName;

-- 20. Supplier Supply Trend by Month (Year = 2024)
SELECT s.SupplierName, d.Month, d.Year, SUM(ssf.QuantitySupplied) AS TotalSupplied
FROM SupplierSupplyFact ssf
JOIN SupplierDim s ON ssf.SupplierID = s.SupplierID
JOIN SupplyDateDim d ON ssf.SupplyDateID = d.DateID
WHERE d.Year = 2024
GROUP BY s.SupplierName, d.Year, d.Month
ORDER BY s.SupplierName, d.Year,
    CASE d.Month
        WHEN 'January' THEN 1 WHEN 'February' THEN 2 WHEN 'March' THEN 3
        WHEN 'April' THEN 4 WHEN 'May' THEN 5 WHEN 'June' THEN 6
        WHEN 'July' THEN 7 WHEN 'August' THEN 8 WHEN 'September' THEN 9
        WHEN 'October' THEN 10 WHEN 'November' THEN 11 WHEN 'December' THEN 12
    END;

-- 21. Distribution Flow Volume by Store Pair
SELECT 
  ws.StoreName AS WholesaleStore, 
  rs.StoreName AS RetailStore, 
  d.ActualDate AS DistributionDate, 
  SUM(df.Quantity) AS TotalQuantity
FROM DistributionFact df
JOIN StoreDim ws ON df.WholesaleStoreID = ws.StoreID
JOIN StoreDim rs ON df.RetailStoreID = rs.StoreID
JOIN DateDim d ON df.DateID = d.DateID
GROUP BY ws.StoreName, rs.StoreName, d.ActualDate;


-- 22. Product View Count by Customer
SELECT c.FirstName, c.LastName, COUNT(*) AS TotalViews
FROM ProductViewFact pv
JOIN CustomerDim c ON pv.CustomerID = c.CustomerID
GROUP BY c.FirstName, c.LastName
ORDER BY TotalViews DESC;

-- 23. Most Viewed Products
SELECT TOP 5 p.ProductName, COUNT(*) AS ViewCount
FROM ProductViewFact pv
JOIN ProductDim p ON pv.ProductID = p.ProductID
GROUP BY p.ProductName
ORDER BY ViewCount DESC;




-- ===========================================
-- 📋 List All Tables in Current Database
-- ===========================================
SELECT 
    TABLE_SCHEMA AS SchemaName, 
    TABLE_NAME AS TableName
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY SchemaName, TableName;

-- ===========================================
-- 📋 List All Views
-- ===========================================
SELECT 
    TABLE_SCHEMA AS SchemaName, 
    TABLE_NAME AS ViewName
FROM INFORMATION_SCHEMA.VIEWS
ORDER BY SchemaName, ViewName;

-- ===========================================
-- 🔢 Total Table Count
-- ===========================================
SELECT COUNT(*) AS TotalTables
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE';

-- ===========================================
-- 🔍 Sample Data from Key Tables
-- ===========================================
SELECT TOP 5 * FROM CustomerDim;
SELECT TOP 5 * FROM ProductDim;
SELECT TOP 5 * FROM StoreDim;
SELECT TOP 5 * FROM DateDim;
SELECT TOP 5 * FROM OrderDim;
SELECT TOP 5 * FROM SalesFact;
SELECT TOP 5 * FROM ReturnsFact;
SELECT TOP 5 * FROM InventoryFact;
SELECT TOP 5 * FROM ProductionFact;
SELECT TOP 5 * FROM DistributionFact;
SELECT TOP 5 * FROM ProductViewFact;


-- ===========================================
-- 🔍 Sample Data from Views (Role-playing Dates)
-- ===========================================
SELECT TOP 5 * FROM OrderDateDim;
SELECT TOP 5 * FROM ReturnDateDim;
SELECT TOP 5 * FROM FeedbackDateDim;
SELECT TOP 5 * FROM SupplyDateDim;
SELECT TOP 5 * FROM SnapshotDateDim;

-- ===========================================
-- 🧩 Table Columns with Definitions
-- ===========================================
SELECT 
    t.TABLE_SCHEMA,
    t.TABLE_NAME,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.CHARACTER_MAXIMUM_LENGTH,
    c.IS_NULLABLE
FROM INFORMATION_SCHEMA.TABLES t
JOIN INFORMATION_SCHEMA.COLUMNS c
    ON t.TABLE_NAME = c.TABLE_NAME AND t.TABLE_SCHEMA = c.TABLE_SCHEMA
WHERE t.TABLE_TYPE = 'BASE TABLE'
ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME, c.ORDINAL_POSITION;

SELECT * FROM sys.tables;
