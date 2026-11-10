<?php

declare(strict_types=1);

namespace App\Services;

use App\Database\Connection;
use App\Support\Response;
use PDO;
use Throwable;

final class ReservaService
{
    /**
     * O registro do show é o mutex lógico do pool.
     *
     * Toda reserva e todo cancelamento do mesmo show bloqueiam primeiro
     * a mesma linha em shows. Assim, a contagem global e a cota pessoal
     * são verificadas em uma seção crítica serializada.
     */
    public function reservar(int $pedidoId, int $userId): array
    {
        $pdo = Connection::get();
        $pdo->beginTransaction();

        try {
            // Descobre o show sem revelar pedidos de terceiros.
            $stmt = $pdo->prepare(
                'SELECT show_id FROM pedidos WHERE id = :id AND user_id = :user_id'
            );
            $stmt->execute(['id' => $pedidoId, 'user_id' => $userId]);
            $pedido = $stmt->fetch();

            if (!$pedido) {
                $pdo->rollBack();
                Response::error('NOT_FOUND', 404);
            }

            $showId = (int) $pedido['show_id'];

            // Ponto único de sincronização para o pool deste show.
            $lockShow = $pdo->prepare(
                'SELECT id, total_ingressos FROM shows WHERE id = :show_id FOR UPDATE'
            );
            $lockShow->execute(['show_id' => $showId]);
            $show = $lockShow->fetch();

            if (!$show) {
                $pdo->rollBack();
                Response::error('NOT_FOUND', 404);
            }

            // Revalida e bloqueia o pedido depois do lock do show.
            $lockPedido = $pdo->prepare(
                'SELECT id, status FROM pedidos
                 WHERE id = :id AND user_id = :user_id FOR UPDATE'
            );
            $lockPedido->execute(['id' => $pedidoId, 'user_id' => $userId]);
            $pedidoAtual = $lockPedido->fetch();

            if (!$pedidoAtual) {
                $pdo->rollBack();
                Response::error('NOT_FOUND', 404);
            }

            if ($pedidoAtual['status'] !== 'NO_CARRINHO') {
                $pdo->rollBack();
                Response::error('ESTADO_INVALIDO', 409);
            }

            $global = $pdo->prepare(
                "SELECT COUNT(*) FROM pedidos
                 WHERE show_id = :show_id AND status = 'RESERVADO'"
            );
            $global->execute(['show_id' => $showId]);
            $ocupadas = (int) $global->fetchColumn();

            if ($ocupadas >= (int) $show['total_ingressos']) {
                $pdo->rollBack();
                Response::error('POOL_CHEIO', 409);
            }

            $personal = $pdo->prepare(
                "SELECT COUNT(*) FROM pedidos
                 WHERE user_id = :user_id AND show_id = :show_id
                   AND status = 'RESERVADO'"
            );
            $personal->execute([
                'user_id' => $userId,
                'show_id' => $showId,
            ]);
            $reservasUsuario = (int) $personal->fetchColumn();

            if ($reservasUsuario >= 2) {
                $pdo->rollBack();
                Response::error('COTA_PESSOAL', 409);
            }

            $update = $pdo->prepare(
                "UPDATE pedidos SET status = 'RESERVADO'
                 WHERE id = :id AND user_id = :user_id AND status = 'NO_CARRINHO'"
            );
            $update->execute(['id' => $pedidoId, 'user_id' => $userId]);

            if ($update->rowCount() !== 1) {
                $pdo->rollBack();
                Response::error('ESTADO_INVALIDO', 409);
            }

            $pdo->commit();

            return ['id' => $pedidoId, 'status' => 'RESERVADO'];
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $e;
        }
    }

    public function cancelar(int $pedidoId, int $userId): array
    {
        $pdo = Connection::get();
        $pdo->beginTransaction();

        try {
            $stmt = $pdo->prepare(
                'SELECT show_id FROM pedidos WHERE id = :id AND user_id = :user_id'
            );
            $stmt->execute(['id' => $pedidoId, 'user_id' => $userId]);
            $pedido = $stmt->fetch();

            if (!$pedido) {
                $pdo->rollBack();
                Response::error('NOT_FOUND', 404);
            }

            $showId = (int) $pedido['show_id'];

            // Mesmo lock e mesma ordem usados na reserva.
            $lockShow = $pdo->prepare(
                'SELECT id FROM shows WHERE id = :show_id FOR UPDATE'
            );
            $lockShow->execute(['show_id' => $showId]);

            if (!$lockShow->fetch()) {
                $pdo->rollBack();
                Response::error('NOT_FOUND', 404);
            }

            $lockPedido = $pdo->prepare(
                'SELECT id, status FROM pedidos
                 WHERE id = :id AND user_id = :user_id FOR UPDATE'
            );
            $lockPedido->execute(['id' => $pedidoId, 'user_id' => $userId]);
            $pedidoAtual = $lockPedido->fetch();

            if (!$pedidoAtual) {
                $pdo->rollBack();
                Response::error('NOT_FOUND', 404);
            }

            if ($pedidoAtual['status'] !== 'RESERVADO') {
                $pdo->rollBack();
                Response::error('ESTADO_INVALIDO', 409);
            }

            $update = $pdo->prepare(
                "UPDATE pedidos SET status = 'CANCELADO'
                 WHERE id = :id AND user_id = :user_id AND status = 'RESERVADO'"
            );
            $update->execute(['id' => $pedidoId, 'user_id' => $userId]);

            if ($update->rowCount() !== 1) {
                $pdo->rollBack();
                Response::error('ESTADO_INVALIDO', 409);
            }

            $pdo->commit();

            return ['id' => $pedidoId, 'status' => 'CANCELADO'];
        } catch (Throwable $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $e;
        }
    }
}
