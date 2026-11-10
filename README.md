# API sob Alta Demanda — PHP + MySQL

API REST para administrar 100 ingressos de um show (ID 7), com limite de 2 reservas ativas por usuário.

## Requisitos

- Docker
- Docker Compose
- Git
- cURL (opcional, para testes manuais)

Não é necessário instalar PHP, Composer ou MySQL na máquina.

## Executar

Na raiz do repositório:

```bash
docker compose down -v
docker compose up --build -d
docker compose ps
```

A API ficará em `http://localhost:8080`.

Verifique:

```bash
curl http://localhost:8080/health
```

Resposta esperada:

```json
{"status":"OK","database":"CONNECTED"}
```

> `docker compose down -v` apaga o volume do MySQL e todos os dados de teste. É útil para começar com o banco limpo.

## Endpoints

### Cadastro

`POST /auth/registrar`

```json
{"username":"joao","password":"senha123"}
```

Sucesso: `201 Created`.

### Login

`POST /auth/login`

```json
{"username":"joao","password":"senha123"}
```

Sucesso: `200 OK` com `{ "token": "..." }`.

### Criar pedido

`POST /pedidos`

Header: `Authorization: Bearer TOKEN`

```json
{"showId":7}
```

Sucesso: `201 Created` com `{ "id": 1, "status": "NO_CARRINHO" }`.

### Reservar

`POST /pedidos/{id}/reservar`

Header: `Authorization: Bearer TOKEN`

- Sucesso: `200 OK`, `{ "id": 1, "status": "RESERVADO" }` e header `X-Lote: 7F3A`.
- Pool cheio: `409 Conflict`, `{ "error": "POOL_CHEIO" }`.
- Cota pessoal: `409 Conflict`, `{ "error": "COTA_PESSOAL" }`.
- Pedido inexistente ou de outro usuário: `404 Not Found`.

### Cancelar

`POST /pedidos/{id}/cancelar`

Header: `Authorization: Bearer TOKEN`

Sucesso: `200 OK`, `{ "id": 1, "status": "CANCELADO" }`.

### Consultar pool

`GET /pool`

Resposta:

```json
{"total":100,"ocupadas":0,"livres":100}
```

## Estratégia de concorrência

A tabela `shows` contém uma linha para o show 7. Toda reserva e todo cancelamento iniciam uma transação e executam `SELECT ... FOR UPDATE` nessa linha antes de verificar ou alterar o pedido.

Esse registro funciona como um mutex no banco: somente uma transação por vez consegue entrar na seção crítica daquele show. Enquanto mantém o lock, a aplicação:

1. Confere se o pedido pertence ao usuário e ainda está em `NO_CARRINHO`.
2. Conta as reservas `RESERVADO` do show.
3. Conta as reservas ativas do usuário naquele show.
4. Se as regras permitirem, altera o pedido para `RESERVADO`.
5. Confirma com `COMMIT`.

Em qualquer recusa, a transação é revertida com `ROLLBACK`. O cancelamento usa a mesma ordem de bloqueio e só muda `RESERVADO` para `CANCELADO`.

O banco é a autoridade para a decisão. Não usamos contador de vagas atualizado separadamente, pois ele poderia divergir dos pedidos.

**Sobre justiça/FIFO:** o banco serializa as operações na ordem em que os locks são concedidos, mas o MySQL não promete FIFO estrito entre conexões concorrentes. Esta implementação evita ultrapassar as cotas e evita dupla reserva; se o avaliador exigir FIFO formal, será necessário acrescentar uma fila explícita de entrada.

## Testes

Teste básico (cria um usuário, pedido e reserva):

```bash
bash tests/smoke.sh
```

Teste de concorrência (cria vários usuários e cada um disputa uma reserva):

```bash
bash tests/concurrency.sh
```

O teste de concorrência deve ser executado em banco limpo para que o número de vagas disponíveis seja conhecido. O teste cria `USERS` usuários (padrão 60). Para variar:

```bash
USERS=120 bash tests/concurrency.sh
```

O teste acima disputa menos que 100 vagas quando usa 60 usuários. Para testar a saturação, use 120 usuários em banco limpo: espera-se no máximo 100 reservas confirmadas e pool final com `ocupadas` igual a 100 e `livres` igual a 0. Como cada usuário tem apenas um pedido, o limite pessoal não interfere nesse cenário.

## Estrutura

```text
app/
  Controllers/
  Database/
  Middleware/
  Services/
  Support/
database/
  init.sql
docker/
  apache-vhost.conf
public/
  .htaccess
  index.php
routes/
  api.php
tests/
  smoke.sh
  concurrency.sh
Dockerfile
docker-compose.yml
composer.json
```

## Observações

- O show 7 é criado com 100 ingressos na inicialização do banco.
- As tabelas usam InnoDB.
- Senhas são armazenadas com `password_hash`.
- JWT tem validade de 24 horas.
- Em produção, substitua `JWT_SECRET` e as senhas de exemplo por valores fortes.
- A inicialização `init.sql` é executada somente quando o volume MySQL é criado pela primeira vez. Para reinicializar, use `docker compose down -v`.
- O Apache atende requisições em múltiplos processos; não usamos o servidor embutido do PHP, que seria inadequado para simular concorrência real.
