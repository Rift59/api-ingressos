# API sob Alta Demanda — PHP + MySQL

#alunos ITALO FIRMINO TIAGO CABRAL

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

Resposta:

```json
{"status":"OK","database":"CONNECTED"}
```

## Executar os testes

No PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\teste-api.ps1
```

## Encerrar o projeto

```bash
docker compose down
```

**Atenção:** não utilize `docker compose down -v` para encerrar normalmente. pois esse comando apaga os dados do banco armazenados no volume.


## Testando a API pelo Postman

### 1. Iniciar a aplicação

Na pasta do projeto, execute:

```powershell
docker compose up -d
```

Verifique se os containers estão funcionando:

```powershell
docker compose ps
```

Teste a conexão:

```text
GET http://localhost:8080/health
```

Resposta esperada:

```json
{
  "status": "OK",
  "database": "CONNECTED"
}
```

### 2. Cadastrar usuário

- Método: `POST`
- URL: `http://localhost:8080/auth/registrar`
- Body → raw → JSON:

```json
{
  "username": "firmino_apresentacao",
  "password": "Teste123456"
}
```

Clique em **Send** para cadastrar.

### 3. Fazer login e obter o token JWT

- Método: `POST`
- URL: `http://localhost:8080/auth/login`
- Body → raw → JSON:

```json
{
  "username": "firmino_apresentacao",
  "password": "Teste123456"
}
```

Clique em **Send** e copie o valor do campo `token` retornado pela API.

### 4. Criar pedido

- Método: `POST`
- URL: `http://localhost:8080/pedidos`
- Authorization → Bearer Token: informe o token recebido no login.
- Body → raw → JSON:

```json
{
  "showId": 7
}
```

Clique em **Send**.

A resposta retornará o ID do pedido e o status inicial `NO_CARRINHO`.

**Anote o ID retornado**, pois ele será utilizado na próxima etapa.

### 5. Reservar ingresso

- Método: `POST`
- URL: `http://localhost:8080/pedidos/ID/reservar`
- Substitua `ID` pelo identificador do pedido criado.
- Authorization → Bearer Token: utilize o mesmo token JWT.
- Body: deixe vazio.

Clique em **Send**.

Resposta esperada:

```json
{
  "id": 1,
  "status": "RESERVADO"
}
```

### 6. Consultar disponibilidade

- Método: `GET`
- URL: `http://localhost:8080/pool`
- Authorization → Bearer Token: utilize novamente o token JWT.

Resposta de exemplo:

```json
{
  "total": 100,
  "ocupadas": 1,
  "livres": 99
}
```

### 7. Cancelar reserva (opcional)

- Método: `POST`
- URL: `http://localhost:8080/pedidos/ID/cancelar`
- Substitua `ID` pelo identificador do pedido.
- Authorization → Bearer Token: utilize o mesmo token JWT.
- Body: deixe vazio.

Resposta esperada:

```json
{
  "id": 1,
  "status": "CANCELADO"
}
```

### Observações importantes

- Cadastro e login não exigem token JWT.
- Criar pedido, reservar, cancelar e consultar o estoque exigem autenticação.
- Nas requisições protegidas, utilize `Authorization → Bearer Token`.
- A API administra o show de ID `7`, com capacidade de 100 ingressos.
- Cada usuário pode possuir no máximo 2 reservas ativas.
- Na reserva e no cancelamento, utilize o método `POST`, não `GET`.