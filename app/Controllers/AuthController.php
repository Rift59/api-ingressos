<?php

declare(strict_types=1);

namespace App\Controllers;

use App\Services\AuthService;
use App\Support\Request;
use App\Support\Response;

final class AuthController
{
    public function registrar(): never
    {
        $data = Request::json();

        if (
            !isset($data['username'], $data['password'])
            || !is_string($data['username'])
            || !is_string($data['password'])
        ) {
            Response::error('DADOS_INVALIDOS', 400);
        }

        $user = (new AuthService())->register(
            $data['username'],
            $data['password']
        );

        Response::json([
            'message' => 'USUARIO_CRIADO',
            'user_id' => $user['id']
        ], 201);
    }

    public function login(): never
    {
        $data = Request::json();

        if (
            !isset($data['username'], $data['password'])
            || !is_string($data['username'])
            || !is_string($data['password'])
        ) {
            Response::error('DADOS_INVALIDOS', 400);
        }

        $token = (new AuthService())->login(
            $data['username'],
            $data['password']
        );

        Response::json(['token' => $token], 200);
    }
}
