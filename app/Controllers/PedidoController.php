<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Database\Connection;
use App\Middleware\AuthMiddleware;
use App\Services\ReservaService;
use App\Support\Request;
use App\Support\Response;

final class PedidoController
{
    public function criar(): never
    {
        $userId = AuthMiddleware::userId();
        $data = Request::json();

        $showId = filter_var($data['showId'] ?? null, FILTER_VALIDATE_INT);

        if (!$showId || $showId < 1) {
            Response::error('DADOS_INVALIDOS', 400);
        }

        $pdo = Connection::get();

        $show = $pdo->prepare('SELECT id FROM shows WHERE id = :id');
        $show->execute(['id' => $showId]);

        if (!$show->fetch()) {
            Response::error('SHOW_NAO_ENCONTRADO', 404);
        }

        $stmt = $pdo->prepare(
            "INSERT INTO pedidos (user_id, show_id, status)
             VALUES (:user_id, :show_id, 'NO_CARRINHO')"
        );
        $stmt->execute([
            'user_id' => $userId,
            'show_id' => $showId,
        ]);

        Response::json([
            'id' => (int) $pdo->lastInsertId(),
            'status' => 'NO_CARRINHO',
        ], 201);
    }

    public function reservar(int $id): never
    {
        $userId = AuthMiddleware::userId();
        $result = (new ReservaService())->reservar($id, $userId);

        Response::json($result, 200, ['X-Lote' => '7F3A']);
    }

    public function cancelar(int $id): never
    {
        $userId = AuthMiddleware::userId();
        $result = (new ReservaService())->cancelar($id, $userId);

        Response::json($result, 200);
    }
}
