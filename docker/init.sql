IF DB_ID(N'AceInvoice') IS NULL
BEGIN
  CREATE DATABASE AceInvoice;
END
GO

USE AceInvoice;
GO

-- Drop old tables if they exist (to allow re-running during development)
IF OBJECT_ID(N'dbo.LineItems', N'U') IS NOT NULL DROP TABLE dbo.LineItems;
IF OBJECT_ID(N'dbo.Orders', N'U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID(N'dbo.Products', N'U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID(N'dbo.Customers', N'U') IS NOT NULL DROP TABLE dbo.Customers;
GO

-- Customers (matches example fields)
CREATE TABLE dbo.Customers (
                               customerId           UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Customers_Id DEFAULT NEWID(),
                               customerName         NVARCHAR(200) NOT NULL,
                               customerAddress1     NVARCHAR(200) NOT NULL,
                               customerAddress2     NVARCHAR(200) NULL,
                               customerCity         NVARCHAR(100) NOT NULL,
                               customerState        NVARCHAR(2)   NOT NULL,
                               customerPostalCode   NVARCHAR(20)  NOT NULL,
                               customerTelephone    NVARCHAR(50)  NOT NULL,
                               customerContactName  NVARCHAR(100) NOT NULL,
                               customerEmailAddress NVARCHAR(320) NOT NULL,
                               CONSTRAINT PK_Customers PRIMARY KEY (customerId)
);
GO

-- Products (matches example fields)
CREATE TABLE dbo.Products (
                              productId   UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_Products_Id DEFAULT NEWID(),
                              productName NVARCHAR(200) NOT NULL,
                              productCost DECIMAL(10,2) NOT NULL,
                              CONSTRAINT PK_Products PRIMARY KEY (productId),
                              CONSTRAINT CK_Products_Cost CHECK (productCost >= 0)
);
GO

-- Orders (summary fields: invoiceNumber, invoiceDate, customerId)
CREATE TABLE dbo.Orders (
                            invoiceNumber INT IDENTITY(2,1) NOT NULL,
                            invoiceDate   DATETIME2(0) NOT NULL,
                            customerId    UNIQUEIDENTIFIER NOT NULL,
                            CONSTRAINT PK_Orders PRIMARY KEY (invoiceNumber),
                            CONSTRAINT FK_Orders_Customers FOREIGN KEY (customerId) REFERENCES dbo.Customers(customerId)
);
GO
CREATE INDEX IX_Orders_CustomerId ON dbo.Orders(customerId);
GO

-- Line Items (matches example fields + keeps integrity)
CREATE TABLE dbo.LineItems (
                               lineItemId    UNIQUEIDENTIFIER NOT NULL CONSTRAINT DF_LineItems_Id DEFAULT NEWID(),
                               invoiceNumber INT NOT NULL,
                               productId     UNIQUEIDENTIFIER NOT NULL,
                               quantity      INT NOT NULL,
                               productCost   DECIMAL(10,2) NOT NULL, -- snapshot at purchase time
                               CONSTRAINT PK_LineItems PRIMARY KEY (lineItemId),
                               CONSTRAINT FK_LineItems_Orders FOREIGN KEY (invoiceNumber) REFERENCES dbo.Orders(invoiceNumber) ON DELETE CASCADE,
                               CONSTRAINT FK_LineItems_Products FOREIGN KEY (productId) REFERENCES dbo.Products(productId),
                               CONSTRAINT CK_LineItems_Quantity CHECK (quantity > 0),
                               CONSTRAINT CK_LineItems_Cost CHECK (productCost >= 0)
);
GO
CREATE INDEX IX_LineItems_InvoiceNumber ON dbo.LineItems(invoiceNumber);
GO

-- Seed Customers (use fixed GUIDs so the provided Postman requests work unchanged)
INSERT INTO dbo.Customers
(customerId, customerName, customerAddress1, customerAddress2, customerCity, customerState, customerPostalCode, customerTelephone, customerContactName, customerEmailAddress)
VALUES
('aa5fd07a-05d6-460f-b8e3-6a09142f9d71', 'Smith, LLC', '505 Central Avenue', 'Suite 100', 'San Diego', 'CA', '90383', '619-483-0987', 'Jane Smith', 'email@jane.com'),
('15907644-3f44-448b-b64e-a949c529fa0b', 'Doe, Inc', '123 Main Street', NULL, 'Los Angeles', 'CA', '90010', '310-555-1212', 'John Doe', 'email@doe.com');
GO

-- Seed Products (fixed GUIDs for Postman compatibility)
INSERT INTO dbo.Products (productId, productName, productCost)
VALUES
('26812d43-cee0-4413-9a1b-0b2eabf7e92c', 'Thingie', 2.00),
('3c85f645-ce57-43a8-b192-7f46f8bbc273', 'Gadget',  5.15),
('a102e2b7-30d6-4ab6-b92b-8570a7e1659c', 'Gizmo',   1.00),
('9e3ef8ce-a6fd-4c9b-ac5d-c3cb471e1e27', 'Widget',  2.50);
GO

-- Seed Orders so invoiceNumber 2..5 exist (Postman commonly requests /details/5)
DECLARE @smith UNIQUEIDENTIFIER = 'aa5fd07a-05d6-460f-b8e3-6a09142f9d71';
DECLARE @doe   UNIQUEIDENTIFIER = '15907644-3f44-448b-b64e-a949c529fa0b';

INSERT INTO dbo.Orders (invoiceDate, customerId) VALUES ('2025-12-30T00:00:00', @smith); -- inv 2
INSERT INTO dbo.Orders (invoiceDate, customerId) VALUES ('2025-12-30T00:00:00', @doe);   -- inv 3
INSERT INTO dbo.Orders (invoiceDate, customerId) VALUES ('2024-12-20T14:30:00', @smith); -- inv 4
INSERT INTO dbo.Orders (invoiceDate, customerId) VALUES ('2024-12-20T14:30:00', @smith); -- inv 5
GO

-- Seed LineItems for invoice 5 (matches the reference example you showed)
INSERT INTO dbo.LineItems (invoiceNumber, productId, quantity, productCost)
VALUES
(5, '3c85f645-ce57-43a8-b192-7f46f8bbc273', 5, 5.15),
(5, '26812d43-cee0-4413-9a1b-0b2eabf7e92c', 2, 2.00);
GO
