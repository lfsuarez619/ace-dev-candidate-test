# Docker Starter Templates

These are starter Dockerfiles to help you containerize your API. Choose the one that matches your technology stack.

## Available Templates

| File | Use For |
|------|---------|
| `Dockerfile.csharp` | C# / .NET 9 projects |
| `Dockerfile.node` | Node.js projects (Express, Fastify, NestJS, Next.js, etc.) |

## How to Use

### 1. Copy the template to your project

```bash
# For C#/.NET
cp docker/starters/Dockerfile.csharp ./Dockerfile

# For Node.js
cp docker/starters/Dockerfile.node ./Dockerfile
```

### 2. Update the file for your project

Open the `Dockerfile` and look for lines marked with `UPDATE:` - these are the parts you may need to change based on your project structure.

**C# projects:**
- Update the `.csproj` filename
- Update the `.dll` name in ENTRYPOINT

**Node.js projects:**
- Ensure `package.json` has `"build"` and `"start"` scripts
- Update the COPY line if your build output folder isn't `dist/`

### 3. Build and run

```bash
# Build your image
docker build -t my-api .

# Run it
docker run -p 5001:8080 my-api
```

### 4. Use with docker-compose (recommended)

Once your Dockerfile works, uncomment the `api` section in `docker/docker-compose.yml` to run everything together:

```bash
cd docker
docker compose up -d
```

## Tips

- **Test locally first**: Make sure your app runs with `npm start` or `dotnet run` before containerizing
- **Check the logs**: If the container fails, run `docker logs <container-id>` to see what went wrong
- **Port mismatch**: The container exposes port 8080 internally, mapped to 5001 externally
