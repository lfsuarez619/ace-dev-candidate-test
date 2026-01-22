/* database/stored-procs.sql
   Stored procedures for the assessment
*/

USE AceInvoice;
GO

-- Get all customers
CREATE OR ALTER PROCEDURE dbo.uspCustomer_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT customerId, customerName, email, createdAtUtc
    FROM dbo.Customers
    ORDER BY customerId;
END
GO

-- Get all products
CREATE OR ALTER PROCEDURE dbo.uspProduct_GetAll
AS
BEGIN
    SET NOCOUNT ON;
    SELECT productId, sku, productName, unitPrice, isActive, createdAtUtc
    FROM dbo.Products
    ORDER BY productId;
END
GO

-- Get all orders (summary)
CREATE OR ALTER PROCEDURE dbo.uspOrder_GetAll
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        o.invoiceNumber,
        o.invoiceDateUtc,
        o.status,
        o.customerId,
        c.customerName,
        CAST(ISNULL(SUM(oi.quantity * oi.unitPrice), 0) AS DECIMAL(10,2)) AS orderTotal
    FROM dbo.Orders o
    JOIN dbo.Customers c ON c.customerId = o.customerId
    LEFT JOIN dbo.OrderItems oi ON oi.invoiceNumber = o.invoiceNumber
    GROUP BY o.invoiceNumber, o.invoiceDateUtc, o.status, o.customerId, c.customerName
    ORDER BY o.invoiceNumber DESC;
END
GO

-- Get a specific order with full details
CREATE OR ALTER PROCEDURE dbo.uspOrder_GetByInvoiceNumber
    @invoiceNumber INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Header
    SELECT
        o.invoiceNumber,
        o.invoiceDateUtc,
        o.status,
        o.customerId,
        c.customerName,
        c.email
    FROM dbo.Orders o
    JOIN dbo.Customers c ON c.customerId = o.customerId
    WHERE o.invoiceNumber = @invoiceNumber;

    -- Line items
    SELECT
        oi.orderItemId,
        oi.invoiceNumber,
        oi.productId,
        p.sku,
        p.productName,
        oi.quantity,
        oi.unitPrice,
        CAST(oi.quantity * oi.unitPrice AS DECIMAL(10,2)) AS lineTotal
    FROM dbo.OrderItems oi
    JOIN dbo.Products p ON p.productId = oi.productId
    WHERE oi.invoiceNumber = @invoiceNumber
    ORDER BY oi.orderItemId;
END
GO

-- Get all orders with line item details (useful for /vieworderdetail)
CREATE OR ALTER PROCEDURE dbo.uspOrder_GetAllWithDetails
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        o.invoiceNumber,
        o.invoiceDateUtc,
        o.status,
        o.customerId,
        c.customerName,
        oi.orderItemId,
        oi.productId,
        p.sku,
        p.productName,
        oi.quantity,
        oi.unitPrice
    FROM dbo.Orders o
    JOIN dbo.Customers c ON c.customerId = o.customerId
    LEFT JOIN dbo.OrderItems oi ON oi.invoiceNumber = o.invoiceNumber
    LEFT JOIN dbo.Products p ON p.productId = oi.productId
    ORDER BY o.invoiceNumber DESC, oi.orderItemId;
END
GO

/* Add a new order (with line items)
   Input JSON format example:
   [
     {"productId": 1, "quantity": 2},
     {"productId": 2, "quantity": 1}
   ]
*/
CREATE OR ALTER PROCEDURE dbo.uspOrder_Create
    @customerId INT,
    @itemsJson NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Validate customer exists
    IF NOT EXISTS (SELECT 1 FROM dbo.Customers WHERE customerId = @customerId)
    BEGIN
        THROW 50001, 'Customer does not exist.', 1;
    END

    -- Parse items JSON
    DECLARE @items TABLE (
        productId INT NOT NULL,
        quantity  INT NOT NULL
    );

    INSERT INTO @items(productId, quantity)
    SELECT productId, quantity
    FROM OPENJSON(@itemsJson)
    WITH (
        productId INT '$.productId',
        quantity  INT '$.quantity'
    );

    -- Validate at least one item
    IF NOT EXISTS (SELECT 1 FROM @items)
    BEGIN
        THROW 50002, 'Order must include at least one line item.', 1;
    END

    -- Validate quantities
    IF EXISTS (SELECT 1 FROM @items WHERE quantity IS NULL OR quantity <= 0)
    BEGIN
        THROW 50003, 'Line item quantity must be > 0.', 1;
    END

    -- Validate products exist (answers “what if someone orders a product that doesn’t exist?”)
    IF EXISTS (
        SELECT 1
        FROM @items i
        LEFT JOIN dbo.Products p ON p.productId = i.productId
        WHERE p.productId IS NULL
    )
    BEGIN
        THROW 50004, 'One or more products do not exist.', 1;
    END

    BEGIN TRAN;

        INSERT INTO dbo.Orders(customerId, status)
        VALUES (@customerId, 'Created');

        DECLARE @invoiceNumber INT = SCOPE_IDENTITY();

        INSERT INTO dbo.OrderItems(invoiceNumber, productId, quantity, unitPrice)
        SELECT
            @invoiceNumber,
            i.productId,
            i.quantity,
            p.unitPrice
        FROM @items i
        JOIN dbo.Products p ON p.productId = i.productId;

    COMMIT TRAN;

    SELECT @invoiceNumber AS invoiceNumber;
END
GO
