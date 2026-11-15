# API sob Alta Demanda — PHP + MySQL

API REST para gerenciar 100 ingressos de um show, com limite de 2 reservas ativas por usuário.

## Requisitos

- Docker
- Docker Compose
- Git

## Como executar

**1. Clonar o projeto**

```bash
git clone https://github.com/Rift59/api-ingressos.git
cd api-ingressos
```

**2. Configurar o ambiente**

No PowerShell:

```powershell
Copy-Item .env.example .env
```

**3. Iniciar a API**

```bash
docker compose up --build -d
```

**4. Verificar funcionamento**

Acesse:

http://localhost:8080/health

Resposta esperada:

```json
{"status":"OK","database":"CONNECTED"}
```

## Executar os testes

No PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\testes-api.ps1
```

## Encerrar o projeto

```bash
docker compose down
```

**Atenção:** não utilize `docker compose down -v` para encerrar normalmente, pois esse comando apaga os dados do banco armazenados no volume.
