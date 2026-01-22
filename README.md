# Ace Dev Candidate Test — Invoice API & SQL Schema (Node.js + SQL Server)

This repository contains:
- A SQL Server schema (tables + seed data) and stored procedures
- A Node.js REST API (Express + `mssql`) that exposes invoice/order endpoints

The API and database are designed to match the request/response field names and shapes shown in the provided `examples/` folder.

---

## Tech Stack
- SQL Server (Docker)
- Node.js 18+ (Express)
- `mssql` for SQL Server connectivity
- Postman (optional)

---

## Repository Layout
- `database/`
  - `init.sql` — schema + seed data (deliverable)
  - `stored-procs.sql` — stored procedures (deliverable)
- `docker/`
  - Docker Compose setup for local SQL Server
  - `init.sql` — used by Docker DB initialization
- `src/`
  - Node.js REST API source code
- `examples/`
  - JSON samples that define required request/response shapes
- `Ace-Recruiting-Test-Example.postman_collection.json`
  - Postman collection for exploring/testing endpoints

---

## Prerequisites
- Docker Desktop
- Node.js 18+ and npm
- (Optional) Postman

---

## Setup

## Start SQL Server (Docker)
From the repo root:

```bash
cd docker
docker compose up -d
docker compose ps
docker compose logs db-init
```
Expected:

- sqlserver becomes healthy
- db-init runs the initialization and then exits (expected behavior)

What initializes the DB?

Docker runs docker/init.sql automatically on startup.
The deliverable schema script is database/init.sql.

If you update the deliverable schema, keep Docker’s init in sync:

```cp database/init.sql docker/init.sql```

##Connect with a SQL client (optional)

Connection info:

Server: localhost,1433
User: sa
Password: (from docker-compose.yml, often YourStrong@Passw0rd unless overridden)
Database: AceInvoice

---

## Configure the Connection String (API)

The API reads DB configuration from environment variables via dotenv (no hard-coded credentials).

### Create a local .env
cp src/.env.example src/.env


Edit src/.env and set values. Example:
```
PORT=5001

DB_SERVER=localhost
DB_PORT=1433
DB_DATABASE=AceInvoice
DB_USER=sa
DB_PASSWORD=YourStrong@Passw0rd

API_KEY=my-test-key
```
Notes:

DB_SERVER=localhost is correct when SQL Server is running via Docker on your machine.
Do not commit src/.env (it is ignored by .gitignore). Commit src/.env.example only.

### Run the API Locally

From the repo root:
```
cd src
npm i
npm run dev
```

API base URL:
- ```http://localhost:5001```

## Authentication (API Key)

All endpoints except the health check require:

- Header: ```x-api-key```
- Value: the ```API_KEY``` you set in ```src/.env```

### If missing or invalid: 401 Unauthorized

Copy ```.env.example``` → ```.env```

Choose any string for ```API_KEY```

Use that same value in the ```x-api-key``` header when calling endpoints

## Endpoints

### Public (no auth):

-GET /api/public/hello

### Auth required:

- GET /api/customer/viewall
- GET /api/product/viewall
- GET /api/order/viewall
- GET /api/order/vieworderdetail
- GET /api/order/details/{invoiceNumber}
- POST /api/order/new

## Testing
##Quick Smoke Tests (curl)

Health check (no auth):

```curl http://localhost:5001/api/public/hello```


Products (auth required):

```curl -H "x-api-key: my-test-key" http://localhost:5001/api/product/viewall```


Verify auth enforcement (should return 401):

```curl -i http://localhost:5001/api/product/viewall```

Postman Testing (Local)

1. Import the collection:

- ```Ace-Recruiting-Test-Example.postman_collection.json```

2. Create an environment named Local with:

- ```baseUrl``` = ```http://localhost:5001```

- ```apiKey``` = the same value as ```API_KEY``` in ```src/.env```

3. Ensure requests include:

```x-api-key: {{apiKey}}```

4. Run the requests (or use Collection Runner):

- Health check
- Customers
- Products
- Orders summary
- Orders with details
- Order details by invoice number
- Create new order

## Postman Testing (Reference API)

The original assessment provides a reference API for behavior comparison:

Base URL: ```https://candidateinvoice-bcc4a5djcrbthwep.westus3-01.azurewebsites.net```

API Key: ```DE7405BBC91A42319C6820C48B8DCE51```

Then switching environments lets you compare Reference vs Local quickly.

---

## Error Handling

The API uses these status codes:

- ```400 Bad Request``` — invalid input
- ```401 Unauthorized``` — missing/invalid API key
- ```404 Not Found``` — resource not found
- ```500 Internal Server Error``` — unexpected errors (no internal details exposed)

---

## Assumptions / Design Decisions

- GUID IDs (```UNIQUEIDENTIFIER```) are used for ```customerId```, ```productId```, and ```lineItemId``` to align with the provided ```examples/``` shapes.
- ```invoiceNumber``` is an integer identity key on orders.
- Line item cost is snapshotted at purchase time (stored on the line item) so old invoices don’t change if product prices change later.
- Integrity constraints are enforced with foreign keys and CHECK constraints (e.g., quantity > 0, non-negative costs).
- Stored procedures are used for core operations (list customers/products/orders, invoice details, create order).
- Auth middleware enforces ```x-api-key``` for all endpoints except ```/api/public/hello```.

## Optional: Run the API with Docker Compose

The Docker setup supports running the API container alongside SQL Server (optional).

In docker/docker-compose.yml:
-Uncomment ONLY the Node.js section (Option B) and leave the other option commented.
- Then run:
```bash
cd docker
docker compose up -d --build
```

API will be available at:
- ```http://localhost:5001```
