USE AceInvoice;
GO

-- Customers
CREATE OR ALTER PROCEDURE dbo.uspCustomer_GetAll
    AS
BEGIN
  SET NOCOUNT ON;
SELECT
    customerId,
    customerName,
    customerAddress1,
    customerAddress2,
    customerCity,
    customerState,
    customerPostalCode,
    customerTelephone,
    customerContactName,
    customerEmailAddress
FROM dbo.Customers
ORDER BY customerName;
END
GO

-- Products
CREATE OR ALTER PROCEDURE dbo.uspProduct_GetAll
    AS
BEGIN
  SET NOCOUNT ON;
SELECT
    productId,
    productName,
    productCost
FROM dbo.Products
ORDER BY productName;
END
GO

-- Orders (summary)
CREATE OR ALTER PROCEDURE dbo.uspOrder_GetAll
    AS
BEGIN
  SET NOCOUNT ON;
SELECT
    invoiceNumber,
    invoiceDate,
    customerId
FROM dbo.Orders
ORDER BY invoiceNumber;
END
GO

-- One invoice details (3 recordsets: customerDetail, orderDetail, lineItems)
CREATE OR ALTER PROCEDURE dbo.uspOrder_GetInvoiceDetails
    @invoiceNumber INT
    AS
BEGIN
  SET NOCOUNT ON;

  -- customerDetail
SELECT
    c.customerId,
    c.customerName,
    c.customerAddress1,
    c.customerAddress2,
    c.customerCity,
    c.customerState,
    c.customerPostalCode,
    c.customerTelephone,
    c.customerContactName,
    c.customerEmailAddress
FROM dbo.Orders o
         JOIN dbo.Customers c ON c.customerId = o.customerId
WHERE o.invoiceNumber = @invoiceNumber;

-- orderDetail
SELECT
    o.invoiceNumber,
    o.invoiceDate,
    o.customerId
FROM dbo.Orders o
WHERE o.invoiceNumber = @invoiceNumber;

-- lineItems
SELECT
    li.lineItemId,
    li.productId,
    li.quantity,
    o.invoiceDate,
    p.productName,
    li.productCost,
    CAST(li.quantity * li.productCost AS DECIMAL(10,2)) AS totalCost
FROM dbo.Orders o
         LEFT JOIN dbo.LineItems li ON li.invoiceNumber = o.invoiceNumber
         LEFT JOIN dbo.Products p ON p.productId = li.productId
WHERE o.invoiceNumber = @invoiceNumber
ORDER BY li.lineItemId;
END
GO

-- All invoices with details (flat rows for Node to group)
CREATE OR ALTER PROCEDURE dbo.uspOrder_GetAllInvoiceDetails_Flat
    AS
BEGIN
  SET NOCOUNT ON;

SELECT
    -- customerDetail fields
    c.customerId,
    c.customerName,
    c.customerAddress1,
    c.customerAddress2,
    c.customerCity,
    c.customerState,
    c.customerPostalCode,
    c.customerTelephone,
    c.customerContactName,
    c.customerEmailAddress,

    -- orderDetail fields
    o.invoiceNumber,
    o.invoiceDate,
    o.customerId AS orderCustomerId,

    -- line item fields (nullable when no items)
    li.lineItemId,
    li.productId,
    li.quantity,
    p.productName,
    li.productCost,
    CAST(li.quantity * li.productCost AS DECIMAL(10,2)) AS totalCost
FROM dbo.Orders o
         JOIN dbo.Customers c ON c.customerId = o.customerId
         LEFT JOIN dbo.LineItems li ON li.invoiceNumber = o.invoiceNumber
         LEFT JOIN dbo.Products p ON p.productId = li.productId
ORDER BY o.invoiceNumber, li.lineItemId;
END
GO

-- Create a new order (expects JSON items: [{productId:"guid", quantity: 1}, ...])
CREATE OR ALTER PROCEDURE dbo.uspOrder_Create
    @customerId UNIQUEIDENTIFIER,
    @invoiceDate DATETIME2(0) = NULL,
    @itemsJson NVARCHAR(MAX)
    AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;

  IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE customerId = @customerId)
    THROW 50001, 'Customer does not exist.', 1;

  DECLARE @items TABLE (
    productId UNIQUEIDENTIFIER NOT NULL,
    quantity  INT NOT NULL
  );

INSERT INTO @items(productId, quantity)
SELECT productId, quantity
FROM OPENJSON(@itemsJson)
    WITH (
    productId UNIQUEIDENTIFIER '$.productId',
    quantity  INT '$.quantity'
    );

IF NOT EXISTS (SELECT 1 FROM @items)
    THROW 50002, 'Order must include at least one line item.', 1;

  IF EXISTS (SELECT 1 FROM @items WHERE quantity <= 0)
    THROW 50003, 'Line item quantity must be > 0.', 1;

  IF EXISTS (
    SELECT 1
    FROM @items i
    LEFT JOIN dbo.Products p ON p.productId = i.productId
    WHERE p.productId IS NULL
  )
    THROW 50004, 'One or more products do not exist.', 1;

BEGIN TRAN;

INSERT INTO dbo.Orders(invoiceDate, customerId)
VALUES (ISNULL(@invoiceDate, SYSUTCDATETIME()), @customerId);

DECLARE @invoiceNumber INT = SCOPE_IDENTITY();

INSERT INTO dbo.LineItems(invoiceNumber, productId, quantity, productCost)
SELECT
    @invoiceNumber,
    i.productId,
    i.quantity,
    p.productCost
FROM @items i
         JOIN dbo.Products p ON p.productId = i.productId;

COMMIT TRAN;

SELECT @invoiceNumber AS invoiceNumber;
END
GO
