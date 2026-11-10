<?php

declare(strict_types=1);

namespace App\Middleware;

use App\Support\Request;
use App\Support\Response;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Throwable;

final class AuthMiddleware
{
    public static function userId(): int
    {
        $token = Request::bearerToken();

        if ($token === null) {
            Response::error('NAO_AUTENTICADO', 401);
        }

        $secret = getenv('JWT_SECRET') ?: '';

        try {
            $payload = JWT::decode($token, new Key($secret, 'HS256'));
            $userId = filter_var($payload->sub ?? null, FILTER_VALIDATE_INT);

            if (!$userId || $userId < 1) {
                Response::error('TOKEN_INVALIDO', 401);
            }

            return (int) $userId;
        } catch (Throwable $e) {
            Response::error('TOKEN_INVALIDO', 401);
        }
    }
}
