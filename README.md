# Ace Dev Candidate Test — Invoice API (Node.js + SQL Server)

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

### 1) Start SQL Server (Docker)
From the repo root:

```bash
cd docker
docker compose up -d
docker compose ps
docker compose logs db-init
