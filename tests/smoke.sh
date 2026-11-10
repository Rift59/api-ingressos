#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
SUFFIX="$(date +%s)"
USER="teste_${SUFFIX}"

echo "1) Health"
curl -fsS "$BASE_URL/health"
echo

echo "2) Cadastro"
curl -fsS -X POST "$BASE_URL/auth/registrar" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USER\",\"password\":\"senha123\"}"
echo

echo "3) Login"
LOGIN="$(curl -fsS -X POST "$BASE_URL/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USER\",\"password\":\"senha123\"}")"

TOKEN="$(php -r '$d=json_decode($argv[1],true); echo $d["token"] ?? "";' "$LOGIN")"

echo "4) Criar pedido"
ORDER="$(curl -fsS -X POST "$BASE_URL/pedidos" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"showId":7}')"

ID="$(php -r '$d=json_decode($argv[1],true); echo $d["id"] ?? "";' "$ORDER")"
echo "$ORDER"

echo "5) Reservar (deve retornar X-Lote: 7F3A)"
curl -fsS -i -X POST "$BASE_URL/pedidos/$ID/reservar" \
  -H "Authorization: Bearer $TOKEN"
echo

echo "6) Pool"
curl -fsS "$BASE_URL/pool"
echo
