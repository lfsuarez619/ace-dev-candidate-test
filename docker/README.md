# Docker Setup (Recommended for macOS/Linux)

This folder contains a Docker Compose configuration to quickly set up SQL Server for local development.

> **Windows users**: The commands below use bash syntax. If using PowerShell, environment variable syntax differs (e.g., `$env:SA_PASSWORD="..."` instead of `SA_PASSWORD=...`).

## Quick Start

### 1. Create your database initialization script

Create a file called `init.sql` in this folder with your schema and any seed data you need for testing:

```sql
-- Create database
CREATE DATABASE AceInvoice;
GO

USE AceInvoice;
GO

-- Create your tables here...
-- (define the structures you need for customers, products, orders, etc.)

-- Add seed data...
-- INSERT INTO ... VALUES (...);
```

### 2. Start SQL Server

```bash
docker compose up -d
```

This will:
1. Pull and start SQL Server 2022
2. Wait for it to be healthy
3. Automatically run your `init.sql` script

### 3. Verify it's working

```bash
# Check containers are running
docker compose ps

# View initialization logs (check here if database isn't set up correctly)
docker compose logs db-init
```

> **Tip**: If something isn't working, always check the logs first. Most issues are visible in `docker compose logs db-init` or `docker compose logs sqlserver`.

### 4. Connect to the database

| Setting | Value |
|---------|-------|
| Server | `localhost,1433` |
| Username | `sa` |
| Password | `YourStrong@Passw0rd` |
| Database | `AceInvoice` |

Use [Azure Data Studio](https://azure.microsoft.com/en-us/products/data-studio/) (free, cross-platform) or any SQL client.

## Adding Your API

Once your API is ready, uncomment the appropriate section in `docker-compose.yml`:

- **C#/.NET**: Uncomment "OPTION A" and adjust the Dockerfile path
- **Node.js**: Uncomment "OPTION B" and adjust as needed

> **Important**: Only uncomment ONE option (A or B), not both.

Then run:

```bash
docker compose up -d --build
```

Your API will be available at `http://localhost:5001`

## Configuration

Override defaults with environment variables:

```bash
# Custom password and port
SA_PASSWORD=MySecret123! API_PORT=8080 docker compose up -d
```

| Variable | Default | Description |
|----------|---------|-------------|
| `SA_PASSWORD` | `YourStrong@Passw0rd` | SQL Server SA password |
| `API_KEY` | (you define) | Your API authentication key |
| `API_PORT` | `5001` | Port to expose your API |

## Cleanup

```bash
# Stop containers
docker compose down

# Stop and remove all data (fresh start)
docker compose down -v
```

## Troubleshooting

### Container won't start
- Ensure Docker Desktop is running
- Check `docker compose logs sqlserver` for errors

### Can't connect to database
- Wait 30-60 seconds for SQL Server to fully start
- Verify with `docker compose ps` - sqlserver should show "healthy"

### init.sql errors
- Check `docker compose logs db-init` for SQL errors
- Ensure your SQL syntax is correct for SQL Server (use `GO` between statements)
