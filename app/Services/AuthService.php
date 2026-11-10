<?php

declare(strict_types=1);

namespace App\Services;

use App\Database\Connection;
use App\Support\Response;
use Firebase\JWT\JWT;
use PDOException;

final class AuthService
{
    public function register(string $username, string $password): array
    {
        $username = trim($username);

        if ($username === '' || strlen($username) > 100 || $password === '') {
            Response::error('DADOS_INVALIDOS', 400);
        }

        if (strlen($password) < 6) {
            Response::error('SENHA_MUITO_CURTA', 400);
        }

        $pdo = Connection::get();

        try {
            $stmt = $pdo->prepare(
                'INSERT INTO users (username, password) VALUES (:username, :password)'
            );
            $stmt->execute([
                'username' => $username,
                'password' => password_hash($password, PASSWORD_DEFAULT),
            ]);
        } catch (PDOException $e) {
            if ($e->getCode() === '23000') {
                Response::error('USUARIO_JA_EXISTE', 409);
            }
            throw $e;
        }

        return ['id' => (int) $pdo->lastInsertId()];
    }

    public function login(string $username, string $password): string
    {
        $stmt = Connection::get()->prepare(
            'SELECT id, password FROM users WHERE username = :username'
        );
        $stmt->execute(['username' => trim($username)]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($password, $user['password'])) {
            Response::error('CREDENCIAIS_INVALIDAS', 401);
        }

        $secret = getenv('JWT_SECRET') ?: '';
        if (strlen($secret) < 32) {
            throw new \RuntimeException('JWT_SECRET deve ter pelo menos 32 caracteres.');
        }

        $now = time();

        return JWT::encode([
            'iss' => 'api-ingressos',
            'iat' => $now,
            'exp' => $now + 86400,
            'sub' => (string) $user['id'],
        ], $secret, 'HS256');
    }
}
