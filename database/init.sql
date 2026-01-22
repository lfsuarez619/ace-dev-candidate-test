/* database/init.sql
   AceInvoice schema + seed data (idempotent-ish)
*/

-- 1) Create DB if missing (run in master context)
IF DB_ID(N'AceInvoice') IS NULL
BEGIN
    CREATE DATABASE AceInvoice;
END
GO

USE AceInvoice;
GO

-- 2) Create tables (only if missing)

IF OBJECT_ID(N'dbo.Customers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Customers (
        customerId     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customers PRIMARY KEY,
        customerName   NVARCHAR(200)      NOT NULL,
        email          NVARCHAR(320)      NULL,
        createdAtUtc   DATETIME2(0)       NOT NULL CONSTRAINT DF_Customers_createdAtUtc DEFAULT (SYSUTCDATETIME())
    );

    -- Optional basic email sanity check (loose; avoids rejecting valid-but-unusual emails)
    ALTER TABLE dbo.Customers
      ADD CONSTRAINT CK_Customers_EmailFormat
      CHECK (email IS NULL OR email LIKE '%_@_%._%');
END
GO

IF OBJECT_ID(N'dbo.Products', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Products (
        productId      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Products PRIMARY KEY,
        sku            NVARCHAR(50)       NOT NULL,
        productName    NVARCHAR(200)      NOT NULL,
        unitPrice      DECIMAL(10,2)      NOT NULL,
        isActive       BIT                NOT NULL CONSTRAINT DF_Products_isActive DEFAULT (1),
        createdAtUtc   DATETIME2(0)       NOT NULL CONSTRAINT DF_Products_createdAtUtc DEFAULT (SYSUTCDATETIME())
    );

    ALTER TABLE dbo.Products
      ADD CONSTRAINT UQ_Products_sku UNIQUE (sku);

    ALTER TABLE dbo.Products
      ADD CONSTRAINT CK_Products_UnitPriceNonNegative CHECK (unitPrice >= 0);
END
GO

IF OBJECT_ID(N'dbo.Orders', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Orders (
        invoiceNumber  INT IDENTITY(1000,1) NOT NULL CONSTRAINT PK_Orders PRIMARY KEY,
        customerId     INT                  NOT NULL,
        invoiceDateUtc DATETIME2(0)         NOT NULL CONSTRAINT DF_Orders_invoiceDateUtc DEFAULT (SYSUTCDATETIME()),
        status         NVARCHAR(50)         NOT NULL CONSTRAINT DF_Orders_status DEFAULT ('Created'),

        CONSTRAINT FK_Orders_Customers
            FOREIGN KEY (customerId) REFERENCES dbo.Customers(customerId)
            ON DELETE NO ACTION
            ON UPDATE NO ACTION
    );

    -- Helps "get all orders" / "get order by invoiceNumber" / joins by customer
    CREATE INDEX IX_Orders_customerId ON dbo.Orders(customerId);
END
GO

IF OBJECT_ID(N'dbo.OrderItems', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.OrderItems (
        orderItemId    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrderItems PRIMARY KEY,
        invoiceNumber  INT               NOT NULL,
        productId      INT               NOT NULL,
        quantity       INT               NOT NULL,
        unitPrice      DECIMAL(10,2)     NOT NULL, -- snapshot at order time

        CONSTRAINT FK_OrderItems_Orders
            FOREIGN KEY (invoiceNumber) REFERENCES dbo.Orders(invoiceNumber)
            ON DELETE CASCADE,

        CONSTRAINT FK_OrderItems_Products
            FOREIGN KEY (productId) REFERENCES dbo.Products(productId)
            ON DELETE NO ACTION,

        CONSTRAINT CK_OrderItems_QuantityPositive CHECK (quantity > 0),
        CONSTRAINT CK_OrderItems_UnitPriceNonNegative CHECK (unitPrice >= 0),

        -- Prevent same product appearing multiple times on same invoice
        CONSTRAINT UQ_OrderItems_invoice_product UNIQUE (invoiceNumber, productId)
    );

    CREATE INDEX IX_OrderItems_invoiceNumber ON dbo.OrderItems(invoiceNumber);
END
GO

-- 3) Seed data (upsert-style to avoid duplicates)

-- Customers
MERGE dbo.Customers AS tgt
USING (VALUES
   (N'Ada Lovelace', N'ada@example.com'),
   (N'Alan Turing',  N'alan@example.com')
) AS src(customerName, email)
ON tgt.email = src.email
WHEN NOT MATCHED THEN
  INSERT (customerName, email) VALUES (src.customerName, src.email);
GO

-- Products
MERGE dbo.Products AS tgt
USING (VALUES
   (N'P-100', N'Parking Pass - Daily',   CAST(15.00 AS DECIMAL(10,2))),
   (N'P-200', N'Parking Pass - Monthly', CAST(120.00 AS DECIMAL(10,2)))
) AS src(sku, productName, unitPrice)
ON tgt.sku = src.sku
WHEN MATCHED THEN
  UPDATE SET productName = src.productName, unitPrice = src.unitPrice
WHEN NOT MATCHED THEN
  INSERT (sku, productName, unitPrice) VALUES (src.sku, src.productName, src.unitPrice);
GO

-- Seed one sample order only if no orders exist (so re-running doesn't explode invoices)
IF NOT EXISTS (SELECT 1 FROM dbo.Orders)
BEGIN
    DECLARE @customerId INT = (SELECT TOP 1 customerId FROM dbo.Customers ORDER BY customerId);
    INSERT INTO dbo.Orders (customerId, status) VALUES (@customerId, 'Created');

    DECLARE @invoiceNumber INT = SCOPE_IDENTITY();

    -- Add two items
    INSERT INTO dbo.OrderItems (invoiceNumber, productId, quantity, unitPrice)
    SELECT
        @invoiceNumber,
        p.productId,
        v.quantity,
        p.unitPrice
    FROM (VALUES
        (N'P-100', 2),
        (N'P-200', 1)
    ) AS v(sku, quantity)
    JOIN dbo.Products p ON p.sku = v.sku;
END
GO
