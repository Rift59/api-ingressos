
$ErrorActionPreference = "Stop"

$BaseUrl = "http://localhost:8080"
$ShowId = 7
$Password = "TesteApi123!"

$script:Aprovados = 0
$script:Reprovados = 0
$script:ReservasTeste = @()
$script:TokenRelatorio = ""

function Testar {
    param(
        [string]$Nome,
        [bool]$Resultado,
        [string]$Detalhe = ""
    )

    if ($Resultado) {
        $script:Aprovados++
        Write-Host "[APROVADO] $Nome $Detalhe" -ForegroundColor Green
    }
    else {
        $script:Reprovados++
        Write-Host "[REPROVADO] $Nome $Detalhe" -ForegroundColor Red
    }
}

function Requisicao {
    param(
        [string]$Metodo,
        [string]$Rota,
        [string]$Token = "",
        $Body = $null
    )

    $Headers = @{}

    if ($Token) {
        $Headers["Authorization"] = "Bearer $Token"
    }

    $Parametros = @{
        Uri = "$BaseUrl$Rota"
        Method = $Metodo
        Headers = $Headers
        TimeoutSec = 30
        UseBasicParsing = $true
    }

    if ($null -ne $Body) {
        $Parametros.ContentType = "application/json"
        $Parametros.Body = $Body | ConvertTo-Json -Compress
    }

    $RespostaHeaders = @{}
    $Conteudo = ""
    $Codigo = 0

    try {
        $Resposta = Invoke-WebRequest @Parametros

        $Codigo = [int]$Resposta.StatusCode
        $Conteudo = $Resposta.Content
        $RespostaHeaders = $Resposta.Headers
    }
    catch {
        $WebResponse = $_.Exception.Response

        if ($null -eq $WebResponse) {
            throw "Erro de conexao em $Rota : $($_.Exception.Message)"
        }

        $Codigo = [int]$WebResponse.StatusCode
        $RespostaHeaders = $WebResponse.Headers

        if ($_.ErrorDetails.Message) {
            $Conteudo = $_.ErrorDetails.Message
        }
        else {
            try {
                $Stream = $WebResponse.GetResponseStream()
                $Reader = New-Object System.IO.StreamReader($Stream)
                $Conteudo = $Reader.ReadToEnd()
                $Reader.Close()
            }
            catch {
                $Conteudo = ""
            }
        }
    }

    $Json = $null

    if ($Conteudo) {
        try {
            $Json = $Conteudo | ConvertFrom-Json
        }
        catch {}
    }

    return [PSCustomObject]@{
        Codigo = $Codigo
        Conteudo = $Conteudo
        Json = $Json
        Headers = $RespostaHeaders
    }
}

function CriarUsuario {
    param([string]$Nome)

    $Sufixo = [Guid]::NewGuid().ToString("N").Substring(0,8)
    $Usuario = "${Nome}_$Sufixo"

    $Cadastro = Requisicao -Metodo POST `
        -Rota "/auth/registrar" `
        -Body @{
            username = $Usuario
            password = $Password
        }

    if ($Cadastro.Codigo -ne 201) {
        throw "Falha no cadastro de $Usuario. HTTP $($Cadastro.Codigo)"
    }

    $Login = Requisicao -Metodo POST `
        -Rota "/auth/login" `
        -Body @{
            username = $Usuario
            password = $Password
        }

    if ($Login.Codigo -ne 200 -or -not $Login.Json.token) {
        throw "Falha no login de $Usuario."
    }

    return [PSCustomObject]@{
        Username = $Usuario
        Token = [string]$Login.Json.token
    }
}

function CriarPedido {
    param([string]$Token)

    $Resposta = Requisicao -Metodo POST `
        -Rota "/pedidos" `
        -Token $Token `
        -Body @{
            showId = $ShowId
        }

    if ($Resposta.Codigo -ne 201) {
        throw "Falha ao criar pedido. HTTP $($Resposta.Codigo)"
    }

    return [int]$Resposta.Json.id
}

function ReservarPedido {
    param(
        [int]$Id,
        [string]$Token
    )

    $Resposta = Requisicao -Metodo POST `
        -Rota "/pedidos/$Id/reservar" `
        -Token $Token

    if ($Resposta.Codigo -eq 200 -and
        $Resposta.Json.status -eq "RESERVADO") {

        $script:ReservasTeste += [PSCustomObject]@{
            Id = $Id
            Token = $Token
        }
    }

    return $Resposta
}

function RemoverReservaControle {
    param([int]$Id)

    $script:ReservasTeste = @(
        $script:ReservasTeste |
        Where-Object { $_.Id -ne $Id }
    )
}

function LimparReservasTeste {

    Write-Host ""
    Write-Host "===== LIMPEZA DAS RESERVAS =====" -ForegroundColor Yellow

    $Erros = 0

    foreach ($Item in @($script:ReservasTeste)) {

        $Resposta = Requisicao -Metodo POST `
            -Rota "/pedidos/$($Item.Id)/cancelar" `
            -Token $Item.Token

        if ($Resposta.Codigo -eq 200) {
            Write-Host "[LIMPO] Pedido $($Item.Id)" -ForegroundColor Yellow
            RemoverReservaControle -Id $Item.Id
        }
        else {
            $Erros++
            Write-Host "[ERRO] Pedido $($Item.Id) HTTP $($Resposta.Codigo)" -ForegroundColor Red
        }
    }

    return $Erros
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "       AUTOMACAO COMPLETA DA API" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

try {

    # 1. SAUDE DA API

    Write-Host ""
    Write-Host "===== 1. SAUDE E AUTENTICACAO =====" -ForegroundColor Cyan

    $Health = Requisicao -Metodo GET -Rota "/health"

    Testar "Endpoint health" ($Health.Codigo -eq 200) `
        "HTTP $($Health.Codigo)"

    $SemToken = Requisicao -Metodo GET -Rota "/pool"

    Testar "Bloqueio sem JWT" ($SemToken.Codigo -eq 401) `
        "HTTP $($SemToken.Codigo)"

    $TokenInvalido = Requisicao -Metodo GET `
        -Rota "/pool" `
        -Token "token_invalido"

    Testar "Bloqueio de JWT invalido" (
        $TokenInvalido.Codigo -eq 401
    ) "HTTP $($TokenInvalido.Codigo)"

    # 2. CADASTRO E LOGIN

    Write-Host ""
    Write-Host "===== 2. CADASTRO E LOGIN =====" -ForegroundColor Cyan

    $UsuarioA = CriarUsuario -Nome "teste_completo_a"
    $script:TokenRelatorio = $UsuarioA.Token

    Testar "Cadastro de usuario" $true

    $CadastroDuplicado = Requisicao -Metodo POST `
        -Rota "/auth/registrar" `
        -Body @{
            username = $UsuarioA.Username
            password = $Password
        }

    Testar "Bloqueio de usuario duplicado" (
        $CadastroDuplicado.Codigo -eq 409
    ) "HTTP $($CadastroDuplicado.Codigo)"

    $SenhaErrada = Requisicao -Metodo POST `
        -Rota "/auth/login" `
        -Body @{
            username = $UsuarioA.Username
            password = "SenhaErrada123"
        }

    Testar "Bloqueio de senha incorreta" (
        $SenhaErrada.Codigo -eq 401
    ) "HTTP $($SenhaErrada.Codigo)"

    $Login = Requisicao -Metodo POST `
        -Rota "/auth/login" `
        -Body @{
            username = $UsuarioA.Username
            password = $Password
        }

    Testar "Login e geracao JWT" (
        $Login.Codigo -eq 200 -and
        $Login.Json.token
    ) "HTTP $($Login.Codigo)"

    # 3. CRIACAO DE PEDIDOS

    Write-Host ""
    Write-Host "===== 3. CRIACAO DE PEDIDOS =====" -ForegroundColor Cyan

    $PedidoA1 = CriarPedido -Token $UsuarioA.Token
    $PedidoA2 = CriarPedido -Token $UsuarioA.Token
    $PedidoA3 = CriarPedido -Token $UsuarioA.Token

    Testar "Criacao de tres pedidos" $true

    # 4. RESERVAS E COTA PESSOAL

    Write-Host ""
    Write-Host "===== 4. RESERVAS E COTA =====" -ForegroundColor Cyan

    $Reserva1 = ReservarPedido -Id $PedidoA1 -Token $UsuarioA.Token

    Testar "Primeira reserva" (
        $Reserva1.Codigo -eq 200 -and
        $Reserva1.Json.status -eq "RESERVADO"
    ) "HTTP $($Reserva1.Codigo)"

    $Lote = [string]$Reserva1.Headers["X-Lote"]

    Testar "Cabecalho X-Lote" (
        $Lote -eq "7F3A"
    ) "Valor: $Lote"

    $Reserva2 = ReservarPedido -Id $PedidoA2 -Token $UsuarioA.Token

    Testar "Segunda reserva" (
        $Reserva2.Codigo -eq 200 -and
        $Reserva2.Json.status -eq "RESERVADO"
    )

    $Reserva3 = Requisicao -Metodo POST `
        -Rota "/pedidos/$PedidoA3/reservar" `
        -Token $UsuarioA.Token

    Testar "Limite de duas reservas" (
        $Reserva3.Codigo -eq 409 -and
        $Reserva3.Conteudo -match "COTA_PESSOAL"
    ) "HTTP $($Reserva3.Codigo)"

    $Duplicada = Requisicao -Metodo POST `
        -Rota "/pedidos/$PedidoA1/reservar" `
        -Token $UsuarioA.Token

    Testar "Bloqueio de reserva duplicada" (
        $Duplicada.Codigo -eq 409
    ) "HTTP $($Duplicada.Codigo)"

    # 5. CANCELAMENTO E PROPRIEDADE

    Write-Host ""
    Write-Host "===== 5. CANCELAMENTO =====" -ForegroundColor Cyan

    $UsuarioB = CriarUsuario -Nome "teste_completo_b"

    $CancelamentoAlheio = Requisicao -Metodo POST `
        -Rota "/pedidos/$PedidoA1/cancelar" `
        -Token $UsuarioB.Token

    Testar "Bloqueio de cancelamento por outro usuario" (
        $CancelamentoAlheio.Codigo -eq 404
    ) "HTTP $($CancelamentoAlheio.Codigo)"

    $Cancelamento = Requisicao -Metodo POST `
        -Rota "/pedidos/$PedidoA1/cancelar" `
        -Token $UsuarioA.Token

    if ($Cancelamento.Codigo -eq 200) {
        RemoverReservaControle -Id $PedidoA1
    }

    Testar "Cancelamento pelo proprietario" (
        $Cancelamento.Codigo -eq 200 -and
        $Cancelamento.Json.status -eq "CANCELADO"
    )

    $CancelamentoDuplicado = Requisicao -Metodo POST `
        -Rota "/pedidos/$PedidoA1/cancelar" `
        -Token $UsuarioA.Token

    Testar "Bloqueio de cancelamento duplicado" (
        $CancelamentoDuplicado.Codigo -eq 409
    ) "HTTP $($CancelamentoDuplicado.Codigo)"

    $ReservaDepois = ReservarPedido -Id $PedidoA3 -Token $UsuarioA.Token

    Testar "Reserva depois de liberar vaga" (
        $ReservaDepois.Codigo -eq 200 -and
        $ReservaDepois.Json.status -eq "RESERVADO"
    )

    # 6. CONCORRENCIA COM DUAS VAGAS DISPONIVEIS

    Write-Host ""
    Write-Host "===== 6. CONCORRENCIA =====" -ForegroundColor Cyan

    $PedidoB1 = CriarPedido -Token $UsuarioB.Token
    $PedidoB2 = CriarPedido -Token $UsuarioB.Token

    Write-Host "Disparando duas reservas simultaneamente..."

    $ScriptReservaSimultanea = {
        param($Url, $Id, $Token)

        try {
            $Resposta = Invoke-WebRequest `
                -Uri "$Url/pedidos/$Id/reservar" `
                -Method POST `
                -Headers @{ Authorization = "Bearer $Token" } `
                -TimeoutSec 30 `
                -UseBasicParsing

            [PSCustomObject]@{
                Id = $Id
                Codigo = [int]$Resposta.StatusCode
                Conteudo = $Resposta.Content
            }
        }
        catch {
            $Codigo = 0
            $Conteudo = ""

            if ($_.Exception.Response) {
                $Codigo = [int]$_.Exception.Response.StatusCode

                if ($_.ErrorDetails.Message) {
                    $Conteudo = $_.ErrorDetails.Message
                }
            }

            [PSCustomObject]@{
                Id = $Id
                Codigo = $Codigo
                Conteudo = $Conteudo
            }
        }
    }

    $Jobs = @(
        Start-Job -ArgumentList $BaseUrl, $PedidoB1, $UsuarioB.Token `
            -ScriptBlock $ScriptReservaSimultanea

        Start-Job -ArgumentList $BaseUrl, $PedidoB2, $UsuarioB.Token `
            -ScriptBlock $ScriptReservaSimultanea
    )

    $Jobs | Wait-Job | Out-Null
    $Resultados = @($Jobs | Receive-Job)
    $Jobs | Remove-Job

    $DuasReservasOK = ($Resultados.Count -eq 2)

    foreach ($Resultado in $Resultados) {

        if ($Resultado.Codigo -eq 200) {
            $script:ReservasTeste += [PSCustomObject]@{
                Id = [int]$Resultado.Id
                Token = $UsuarioB.Token
            }
        }
        else {
            $DuasReservasOK = $false
        }
    }

    Testar "Duas reservas simultaneas dentro da cota" `
        $DuasReservasOK `
        "HTTP: $(($Resultados.Codigo -join ', '))"

    # 7. CONSISTENCIA DO ESTOQUE

    Write-Host ""
    Write-Host "===== 7. CONSISTENCIA DO ESTOQUE =====" -ForegroundColor Cyan

    $Pool = Requisicao -Metodo GET `
        -Rota "/pool" `
        -Token $UsuarioA.Token

    $PoolOK = (
        $Pool.Codigo -eq 200 -and
        [int]$Pool.Json.total -eq 100 -and
        [int]$Pool.Json.total -eq (
            [int]$Pool.Json.ocupadas + [int]$Pool.Json.livres
        )
    )

    Testar "Total de ingressos e consistencia" $PoolOK `
        "Total: $($Pool.Json.total) | Ocupadas: $($Pool.Json.ocupadas) | Livres: $($Pool.Json.livres)"

    # 8. LIMPAR TESTES FUNCIONAIS ANTES DE LOTAR O POOL

    $ErrosLimpezaInicial = LimparReservasTeste

    Testar "Limpeza dos testes funcionais" (
        $ErrosLimpezaInicial -eq 0
    )

    if ($ErrosLimpezaInicial -gt 0) {
        throw "Nao foi possivel limpar todas as reservas funcionais. Teste de lotacao interrompido."
    }

    # 9. PREPARAR POOL COM 99 INGRESSOS OCUPADOS

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "       TESTE DE POOL E ULTIMA VAGA" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $PoolAtual = Requisicao -Metodo GET `
        -Rota "/pool" `
        -Token $UsuarioA.Token

    if ($PoolAtual.Codigo -ne 200) {
        throw "Nao foi possivel consultar o pool."
    }

    $Total = [int]$PoolAtual.Json.total
    $Livres = [int]$PoolAtual.Json.livres

    if ($Total -ne 100) {
        throw "O total do pool nao e 100. Valor encontrado: $Total"
    }

    if ($Livres -lt 1) {
        throw "O pool ja esta cheio. Nao existe ultima vaga para disputar."
    }

    $VagasParaPreencher = $Livres - 1

    Write-Host "Vagas livres no inicio: $Livres"
    Write-Host "Vagas que serao ocupadas: $VagasParaPreencher"
    Write-Host "Objetivo: deixar exatamente uma vaga livre."

    $Preenchidas = 0

    while ($Preenchidas -lt $VagasParaPreencher) {

        $UsuarioLote = CriarUsuario -Nome "teste_pool"

        $Quantidade = [Math]::Min(
            2,
            $VagasParaPreencher - $Preenchidas
        )

        for ($i = 1; $i -le $Quantidade; $i++) {

            $PedidoLote = CriarPedido -Token $UsuarioLote.Token

            $ReservaLote = ReservarPedido `
                -Id $PedidoLote `
                -Token $UsuarioLote.Token

            if ($ReservaLote.Codigo -ne 200) {
                throw "Falha ao preencher o pool. Pedido $PedidoLote retornou HTTP $($ReservaLote.Codigo)."
            }

            $Preenchidas++

            Write-Progress `
                -Activity "Preparando o teste de concorrencia" `
                -Status "$Preenchidas de $VagasParaPreencher vagas ocupadas" `
                -PercentComplete (($Preenchidas / $VagasParaPreencher) * 100)
        }
    }

    Write-Progress -Activity "Preparando o teste de concorrencia" -Completed

    $Pool99 = Requisicao -Metodo GET `
        -Rota "/pool" `
        -Token $UsuarioA.Token

    Testar "Preparacao de 99 ingressos ocupados" (
        $Pool99.Codigo -eq 200 -and
        [int]$Pool99.Json.ocupadas -eq 99 -and
        [int]$Pool99.Json.livres -eq 1
    ) "Ocupadas: $($Pool99.Json.ocupadas) | Livres: $($Pool99.Json.livres)"

    if ([int]$Pool99.Json.livres -ne 1) {
        throw "O estoque nao ficou com exatamente uma vaga. Disputa cancelada."
    }

    # 10. DISPUTA PELA ULTIMA VAGA

    Write-Host ""
    Write-Host "Disparando duas reservas para a ultima vaga..." -ForegroundColor Cyan

    $UsuarioCorridaA = CriarUsuario -Nome "teste_corrida_a"
    $UsuarioCorridaB = CriarUsuario -Nome "teste_corrida_b"

    $PedidoCorridaA = CriarPedido -Token $UsuarioCorridaA.Token
    $PedidoCorridaB = CriarPedido -Token $UsuarioCorridaB.Token

    $JobsUltimaVaga = @(
        Start-Job -ArgumentList $BaseUrl, $PedidoCorridaA, $UsuarioCorridaA.Token `
            -ScriptBlock $ScriptReservaSimultanea

        Start-Job -ArgumentList $BaseUrl, $PedidoCorridaB, $UsuarioCorridaB.Token `
            -ScriptBlock $ScriptReservaSimultanea
    )

    $JobsUltimaVaga | Wait-Job | Out-Null
    $ResultadoCorrida = @($JobsUltimaVaga | Receive-Job)
    $JobsUltimaVaga | Remove-Job

    $Vencedores = @(
        $ResultadoCorrida |
        Where-Object { $_.Codigo -eq 200 }
    )

    $Perdedores = @(
        $ResultadoCorrida |
        Where-Object {
            $_.Codigo -eq 409 -and
            $_.Conteudo -match "POOL_CHEIO"
        }
    )

    foreach ($Vencedor in $Vencedores) {

        if ($Vencedor.Id -eq $PedidoCorridaA) {
            $TokenVencedor = $UsuarioCorridaA.Token
        }
        else {
            $TokenVencedor = $UsuarioCorridaB.Token
        }

        $script:ReservasTeste += [PSCustomObject]@{
            Id = [int]$Vencedor.Id
            Token = $TokenVencedor
        }
    }

    $DisputaOK = (
        $ResultadoCorrida.Count -eq 2 -and
        $Vencedores.Count -eq 1 -and
        $Perdedores.Count -eq 1
    )

    Testar "Protecao da ultima vaga sob concorrencia" `
        $DisputaOK `
        "HTTP: $(($ResultadoCorrida.Codigo -join ', '))"

    # 11. TENTAR RESERVAR COM POOL CHEIO

    Write-Host ""
    Write-Host "===== TESTE DE POOL CHEIO =====" -ForegroundColor Cyan

    $UsuarioExtra = CriarUsuario -Nome "teste_pool_cheio"
    $PedidoExtra = CriarPedido -Token $UsuarioExtra.Token

    $ReservaExtra = Requisicao -Metodo POST `
        -Rota "/pedidos/$PedidoExtra/reservar" `
        -Token $UsuarioExtra.Token

    Testar "Bloqueio de reserva com pool cheio" (
        $ReservaExtra.Codigo -eq 409 -and
        $ReservaExtra.Conteudo -match "POOL_CHEIO"
    ) "HTTP $($ReservaExtra.Codigo)"

    # 12. CONFERENCIA DOS 100 INGRESSOS

    $PoolCheio = Requisicao -Metodo GET `
        -Rota "/pool" `
        -Token $UsuarioA.Token

    Testar "Pool completamente ocupado" (
        $PoolCheio.Codigo -eq 200 -and
        [int]$PoolCheio.Json.total -eq 100 -and
        [int]$PoolCheio.Json.ocupadas -eq 100 -and
        [int]$PoolCheio.Json.livres -eq 0
    ) "Total: $($PoolCheio.Json.total) | Ocupadas: $($PoolCheio.Json.ocupadas) | Livres: $($PoolCheio.Json.livres)"

    # 13. TESTE FINAL: 100 PESSOAS SIMULTANEAMENTE

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host " TESTE FINAL: 100 PESSOAS SIMULTANEAS"
    Write-Host "========================================" -ForegroundColor Cyan

    # Liberar reservas anteriores para preparar a simulacao
    Write-Host ""
    Write-Host "Liberando reservas dos testes anteriores..."

    $ErrosLimpeza100 = LimparReservasTeste

    Testar "Limpeza antes do teste de 100 pessoas" (
        $ErrosLimpeza100 -eq 0
    )

    if ($ErrosLimpeza100 -gt 0) {
        throw "Nao foi possivel liberar as reservas anteriores."
    }

    # Consultar estoque inicial
    $PoolAntes100 = Requisicao -Metodo GET `
        -Rota "/pool" `
        -Token $UsuarioA.Token

    if ($PoolAntes100.Codigo -ne 200) {
        throw "Falha ao consultar estoque antes do teste de 100 pessoas."
    }

    $OcupadasAntes100 = [int]$PoolAntes100.Json.ocupadas
    $LivresAntes100 = [int]$PoolAntes100.Json.livres

    Write-Host "Ingressos ocupados: $OcupadasAntes100"
    Write-Host "Ingressos disponiveis: $LivresAntes100"

    # Criar 100 usuarios diferentes e 100 pedidos
    Write-Host ""
    Write-Host "Preparando 100 usuarios e 100 pedidos..." -ForegroundColor Cyan

    $Usuarios100 = @()

    for ($i = 1; $i -le 100; $i++) {

        $NovoUsuario = CriarUsuario -Nome "teste_simultaneo_$i"
        $NovoPedido = CriarPedido -Token $NovoUsuario.Token

        $Usuarios100 += [PSCustomObject]@{
            Username = $NovoUsuario.Username
            Token = $NovoUsuario.Token
            PedidoId = $NovoPedido
        }

        if ($i % 10 -eq 0) {
            Write-Host "Preparados: $i/100"
        }
    }

    Testar "Preparacao dos 100 usuarios e pedidos" (
        $Usuarios100.Count -eq 100
    )

    # Criar conexoes HTTP para enviar requisicoes em paralelo
    Add-Type -AssemblyName System.Net.Http

    [System.Net.ServicePointManager]::DefaultConnectionLimit = 200

    $Handler100 = New-Object System.Net.Http.HttpClientHandler
    $Http100 = New-Object System.Net.Http.HttpClient($Handler100)
    $Http100.Timeout = [TimeSpan]::FromSeconds(120)

    $Requisicoes100 = New-Object System.Collections.ArrayList
    $Tarefas100 = New-Object System.Collections.ArrayList

    Write-Host ""
    Write-Host "DISPARANDO 100 RESERVAS EM PARALELO..." -ForegroundColor Yellow

    try {

        foreach ($Usuario in $Usuarios100) {

            $Request100 = New-Object System.Net.Http.HttpRequestMessage

            $Request100.Method = [System.Net.Http.HttpMethod]::Post

            $Request100.RequestUri = [Uri](
                "$BaseUrl/pedidos/$($Usuario.PedidoId)/reservar"
            )

            $Request100.Headers.Authorization =
                New-Object System.Net.Http.Headers.AuthenticationHeaderValue(
                    "Bearer",
                    $Usuario.Token
                )

            [void]$Requisicoes100.Add($Request100)

            $Tarefa100 = $Http100.SendAsync($Request100)

            [void]$Tarefas100.Add($Tarefa100)
        }

        Write-Host "100 requisicoes enviadas. Aguardando respostas..." -ForegroundColor Yellow

        try {
            [System.Threading.Tasks.Task]::WaitAll(
                [System.Threading.Tasks.Task[]]$Tarefas100.ToArray()
            )
        }
        catch {
            Write-Host "Algumas requisicoes apresentaram erros de comunicacao." -ForegroundColor Red
        }

        $Aprovados100 = 0
        $Recusados100 = 0
        $Erros100 = 0

        for ($i = 0; $i -lt 100; $i++) {

            $Tarefa = $Tarefas100[$i]
            $Usuario = $Usuarios100[$i]

            if ($Tarefa.IsFaulted -or $Tarefa.IsCanceled) {

                $Erros100++

                Write-Host "[ERRO] Usuario $($i + 1): falha de comunicacao" -ForegroundColor Red

                continue
            }

            $Resposta100 = $Tarefa.Result

            $Codigo100 = [int]$Resposta100.StatusCode

            $Conteudo100 = $Resposta100.Content.ReadAsStringAsync().
                GetAwaiter().GetResult()

            if ($Codigo100 -eq 200) {

                $Aprovados100++

                $script:ReservasTeste += [PSCustomObject]@{
                    Id = [int]$Usuario.PedidoId
                    Token = $Usuario.Token
                }

                Write-Host "[APROVADO] Usuario $($i + 1) - Pedido $($Usuario.PedidoId)" -ForegroundColor Green

            }
            elseif (
                $Codigo100 -eq 409 -and
                $Conteudo100 -match "POOL_CHEIO"
            ) {

                $Recusados100++

                Write-Host "[RECUSADO] Usuario $($i + 1) - Pool cheio" -ForegroundColor Yellow

            }
            else {

                $Erros100++

                Write-Host "[ERRO] Usuario $($i + 1) - HTTP $Codigo100 - $Conteudo100" -ForegroundColor Red
            }

            $Resposta100.Dispose()
        }

        $Esperado100 = [Math]::Min(100, $LivresAntes100)

        Write-Host ""
        Write-Host "========== RESULTADO DAS 100 PESSOAS ==========" -ForegroundColor Cyan
        Write-Host "Pessoas tentando reservar: 100"
        Write-Host "Reservas aprovadas: $Aprovados100" -ForegroundColor Green
        Write-Host "Reservas recusadas por pool cheio: $Recusados100" -ForegroundColor Yellow
        Write-Host "Erros inesperados: $Erros100" -ForegroundColor Red
        Write-Host "Vagas disponiveis antes: $LivresAntes100"
        Write-Host "Reservas esperadas: $Esperado100"
        Write-Host "===============================================" -ForegroundColor Cyan

        Testar "Quantidade de reservas aprovadas" (
            $Aprovados100 -eq $Esperado100
        ) "Esperado: $Esperado100 | Obtido: $Aprovados100"

        Testar "Recusas por falta de ingressos" (
            $Recusados100 -eq (100 - $Esperado100)
        ) "Esperado: $(100 - $Esperado100) | Obtido: $Recusados100"

        Testar "Nenhum erro inesperado nas 100 requisicoes" (
            $Erros100 -eq 0
        )

        # Conferir estoque depois da concorrencia
        $PoolDepois100 = Requisicao -Metodo GET `
            -Rota "/pool" `
            -Token $UsuarioA.Token

        if ($PoolDepois100.Codigo -ne 200) {
            throw "Falha ao consultar estoque depois das 100 reservas."
        }

        $OcupadasDepois100 = [int]$PoolDepois100.Json.ocupadas
        $LivresDepois100 = [int]$PoolDepois100.Json.livres

        Write-Host ""
        Write-Host "ESTOQUE APOS AS 100 TENTATIVAS" -ForegroundColor Cyan
        Write-Host "Ocupadas: $OcupadasDepois100"
        Write-Host "Livres: $LivresDepois100"

        Testar "Estoque nunca ultrapassou 100 ingressos" (
            $OcupadasDepois100 -le 100
        )

        Testar "Consistencia do estoque apos concorrencia" (
            $OcupadasDepois100 + $LivresDepois100 -eq 100
        )

        Testar "Quantidade ocupada corresponde as reservas aprovadas" (
            $OcupadasDepois100 -eq ($OcupadasAntes100 + $Aprovados100)
        )

    }
    finally {

        foreach ($Request100 in $Requisicoes100) {
            $Request100.Dispose()
        }

        $Http100.Dispose()
        $Handler100.Dispose()
    }

}
catch {
    Write-Host ""
    Write-Host "[ERRO FATAL] $($_.Exception.Message)" -ForegroundColor Red
}
finally {

    # 14. LIMPEZA FINAL

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "          LIMPEZA FINAL" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow

    $ErrosFinal = LimparReservasTeste

    if ($ErrosFinal -eq 0) {
        Write-Host "Todas as reservas criadas pela automacao foram canceladas." -ForegroundColor Green
    }
    else {
        Write-Host "ATENCAO: $ErrosFinal reservas nao foram canceladas." -ForegroundColor Red
    }

    if ($script:TokenRelatorio) {

        try {
            $PoolFinal = Requisicao -Metodo GET `
                -Rota "/pool" `
                -Token $script:TokenRelatorio

            if ($PoolFinal.Codigo -eq 200) {

                $FinalOK = (
                    [int]$PoolFinal.Json.total -eq
                    ([int]$PoolFinal.Json.ocupadas + [int]$PoolFinal.Json.livres)
                )

                Testar "Consistencia final do estoque" $FinalOK `
                    "Total: $($PoolFinal.Json.total) | Ocupadas: $($PoolFinal.Json.ocupadas) | Livres: $($PoolFinal.Json.livres)"
            }
            else {
                Testar "Consulta final do estoque" $false
            }
        }
        catch {
            Testar "Consulta final do estoque" $false
        }
    }
}

# 15. RELATORIO

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "          RELATORIO FINAL" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "APROVADOS: $script:Aprovados" -ForegroundColor Green
Write-Host "REPROVADOS: $script:Reprovados" -ForegroundColor Red

Write-Host ""
Write-Host "Usuarios e pedidos de teste permanecem no banco."
Write-Host "As reservas criadas pela automacao foram canceladas."
Write-Host "A restricao de 100 ingressos nao foi modificada."

Write-Host ""
Write-Host "Fim da automacao."
