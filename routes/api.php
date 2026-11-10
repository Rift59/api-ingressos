<?php

declare(strict_types=1);

use App\Controllers\AuthController;
use App\Controllers\PedidoController;
use App\Controllers\PoolController;
use App\Support\Response;

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);

if ($method === 'GET' && $path === '/health') {
    try {
        \App\Database\Connection::get()->query('SELECT 1');
        Response::json(['status' => 'OK', 'database' => 'CONNECTED']);
    } catch (Throwable $e) {
        Response::error('DATABASE_UNAVAILABLE', 503);
    }
}

$auth = new AuthController();
$pedidos = new PedidoController();
$pool = new PoolController();

if ($method === 'POST' && $path === '/auth/registrar') {
    $auth->registrar();
}

if ($method === 'POST' && $path === '/auth/login') {
    $auth->login();
}

if ($method === 'POST' && $path === '/pedidos') {
    $pedidos->criar();
}

if ($method === 'GET' && $path === '/pool') {
    $pool->consultar();
}

if ($method === 'POST' && preg_match('#^/pedidos/([0-9]+)/reservar$#', $path, $m)) {
    $pedidos->reservar((int) $m[1]);
}

if ($method === 'POST' && preg_match('#^/pedidos/([0-9]+)/cancelar$#', $path, $m)) {
    $pedidos->cancelar((int) $m[1]);
}

Response::error('NOT_FOUND', 404);
