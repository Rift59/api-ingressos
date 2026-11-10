CREATE TABLE IF NOT EXISTS users (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS shows (
    id BIGINT UNSIGNED PRIMARY KEY,
    total_ingressos INT UNSIGNED NOT NULL,
    CONSTRAINT chk_total_ingressos CHECK (total_ingressos = 100)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pedidos (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    show_id BIGINT UNSIGNED NOT NULL,
    status ENUM('NO_CARRINHO', 'RESERVADO', 'CANCELADO')
        NOT NULL DEFAULT 'NO_CARRINHO',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_pedido_user FOREIGN KEY (user_id)
        REFERENCES users(id),
    CONSTRAINT fk_pedido_show FOREIGN KEY (show_id)
        REFERENCES shows(id),
    INDEX idx_pedidos_show_status (show_id, status),
    INDEX idx_pedidos_user_show_status (user_id, show_id, status)
) ENGINE=InnoDB;

INSERT INTO shows (id, total_ingressos)
VALUES (7, 100)
ON DUPLICATE KEY UPDATE total_ingressos = VALUES(total_ingressos);
