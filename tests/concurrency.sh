#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8080}"
SHOW_ID=7
USERS="${USERS:-60}"

echo "== Teste de concorrência: $USERS usuários tentando reservar =="
echo "Este teste cria usuários e pedidos novos. Use um banco limpo."

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

for i in $(seq 1 "$USERS"); do
  (
    username="concorrente_${i}_$(date +%s%N)"
    password="senha123"

    curl -sS -o "$tmpdir/register_$i.json" -w '%{http_code}' \
      -H 'Content-Type: application/json' \
      -d "{\"username\":\"$username\",\"password\":\"$password\"}" \
      "$BASE_URL/auth/registrar" > "$tmpdir/register_$i.status"

    curl -sS -o "$tmpdir/login_$i.json" \
      -H 'Content-Type: application/json' \
      -d "{\"username\":\"$username\",\"password\":\"$password\"}" \
      "$BASE_URL/auth/login"

    token="$(php -r '$d=json_decode(file_get_contents($argv[1]),true); echo $d["token"] ?? "";' "$tmpdir/login_$i.json")"

    curl -sS -o "$tmpdir/order_$i.json" \
      -H "Authorization: Bearer $token" \
      -H 'Content-Type: application/json' \
      -d "{\"showId\":$SHOW_ID}" \
      "$BASE_URL/pedidos"

    order_id="$(php -r '$d=json_decode(file_get_contents($argv[1]),true); echo $d["id"] ?? "";' "$tmpdir/order_$i.json")"

    curl -sS -o "$tmpdir/reserve_$i.json" -w '%{http_code}' \
      -X POST -H "Authorization: Bearer $token" \
      "$BASE_URL/pedidos/$order_id/reservar" > "$tmpdir/reserve_$i.status"
  ) &
done

wait

echo "Reservas 200: $(grep -l '^200$' "$tmpdir"/reserve_*.status 2>/dev/null | wc -l)"
echo "Reservas 409: $(grep -l '^409$' "$tmpdir"/reserve_*.status 2>/dev/null | wc -l)"
echo "Pool final:"
curl -sS "$BASE_URL/pool"
echo
