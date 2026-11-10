<?php

declare(strict_types=1);

namespace App\Database;

use PDO;

final class Connection
{
    public static function get(): PDO
    {
        static $pdo = null;

        if ($pdo instanceof PDO) {
            return $pdo;
        }

        $host = getenv('DB_HOST') ?: 'db';
        $port = getenv('DB_PORT') ?: '3306';
        $database = getenv('DB_DATABASE') ?: 'ingressos';
        $username = getenv('DB_USERNAME') ?: 'api_user';
        $password = getenv('DB_PASSWORD') ?: 'senha_api_123';

        $dsn = sprintf(
            'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
            $host,
            $port,
            $database
        );

        $pdo = new PDO($dsn, $username, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::ATTR_PERSISTENT => false,
        ]);

        // READ COMMITTED reduz leituras desnecessárias de versões antigas.
        $pdo->exec('SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED');

        return $pdo;
    }
}
