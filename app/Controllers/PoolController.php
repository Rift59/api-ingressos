<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Database\Connection;
use App\Middleware\AuthMiddleware;
use App\Support\Response;

final class PoolController
{
    public function consultar(): never
    {
        AuthMiddleware::userId();
        $pdo = Connection::get();

        // Uma única instrução fornece um snapshot consistente no MySQL.
        $stmt = $pdo->prepare(
            "SELECT s.total_ingressos AS total,
                    COUNT(p.id) AS ocupadas
             FROM shows s
             LEFT JOIN pedidos p
               ON p.show_id = s.id AND p.status = 'RESERVADO'
             WHERE s.id = 7
             GROUP BY s.id, s.total_ingressos"
        );
        $stmt->execute();
        $pool = $stmt->fetch();

        if (!$pool) {
            Response::error('SHOW_NAO_ENCONTRADO', 404);
        }

        $total = (int) $pool['total'];
        $ocupadas = (int) $pool['ocupadas'];

        Response::json([
            'total' => $total,
            'ocupadas' => $ocupadas,
            'livres' => $total - $ocupadas,
        ]);
    }
}
