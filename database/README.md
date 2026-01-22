# Database Design Notes

## Key design decisions
- `OrderItems.unitPrice` stores the unit price at the time of purchase (price snapshot), so historical invoices do not change if product prices are updated later.
- Foreign keys prevent invalid references (cannot create an order item for a non-existent product).
- CHECK constraints prevent invalid values (quantity > 0, non-negative prices).
- UNIQUE constraints prevent duplicates (e.g., SKU unique; one product per invoice).

## Stored procedure mapping
- `uspCustomer_GetAll` -> Get all customers
- `uspProduct_GetAll` -> Get all products
- `uspOrder_GetAll` -> Get all orders (summary)
- `uspOrder_GetByInvoiceNumber` -> Get a specific order with details
- `uspOrder_GetAllWithDetails` -> Get all orders with line items (useful for order detail endpoint)
- `uspOrder_Create` -> Add a new order with line items (transactional)