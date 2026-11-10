<?php

declare(strict_types=1);

require_once __DIR__ . '/../vendor/autoload.php';

use App\Support\Response;

header('Content-Type: application/json; charset=utf-8');

try {
    require __DIR__ . '/../routes/api.php';
} catch (Throwable $e) {
    error_log((string) $e);
    Response::error('INTERNAL_SERVER_ERROR', 500);
}
