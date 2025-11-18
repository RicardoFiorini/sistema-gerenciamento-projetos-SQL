-- 1. Configurações e Charset
CREATE DATABASE IF NOT EXISTS GerenciamentoProjetos
CHARACTER SET utf8mb4
COLLATE utf8mb4_0900_ai_ci;

USE GerenciamentoProjetos;

-- 2. Controle de Acesso (RBAC - Role Based Access Control)
CREATE TABLE Funcoes (
    funcao_id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(50) NOT NULL UNIQUE, -- Ex: Admin, PM, Dev, Stakeholder
    permissoes JSON NOT NULL COMMENT 'Ex: {"criar_projeto": true, "deletar_tarefa": false}'
);

CREATE TABLE Usuarios (
    usuario_id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    senha_hash VARCHAR(255) NOT NULL,
    funcao_id INT NOT NULL,
    avatar_url VARCHAR(255),
    ativo BOOLEAN DEFAULT TRUE,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (funcao_id) REFERENCES Funcoes(funcao_id)
);

-- 3. Estrutura Organizacional
CREATE TABLE Workspaces (
    workspace_id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    dono_id INT NOT NULL,
    slug VARCHAR(50) UNIQUE, -- Para URL amigável (app.com/minha-empresa)
    FOREIGN KEY (dono_id) REFERENCES Usuarios(usuario_id)
);

CREATE TABLE Projetos (
    projeto_id INT AUTO_INCREMENT PRIMARY KEY,
    workspace_id INT NOT NULL,
    gerente_id INT NOT NULL,
    nome VARCHAR(100) NOT NULL,
    chave VARCHAR(10) NOT NULL COMMENT 'Prefixo para tarefas (ex: PROJ-123)',
    descricao TEXT,
    
    data_inicio DATE,
    data_fim_prevista DATE,
    
    -- Métricas calculadas via Trigger (Cache)
    progresso_percentual DECIMAL(5, 2) DEFAULT 0.00,
    total_horas_estimadas INT DEFAULT 0,
    total_horas_gastas INT DEFAULT 0,
    
    status ENUM('Planejamento', 'Ativo', 'Suspenso', 'Concluído') DEFAULT 'Planejamento',
    
    FOREIGN KEY (workspace_id) REFERENCES Workspaces(workspace_id) ON DELETE CASCADE,
    FOREIGN KEY (gerente_id) REFERENCES Usuarios(usuario_id),
    UNIQUE KEY uk_chave_workspace (workspace_id, chave)
);

-- 4. Metodologia Ágil (Sprints e Quadro)
CREATE TABLE Sprints (
    sprint_id INT AUTO_INCREMENT PRIMARY KEY,
    projeto_id INT NOT NULL,
    nome VARCHAR(100) NOT NULL, -- Ex: Sprint 23 - Login
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    objetivo TEXT,
    ativo BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (projeto_id) REFERENCES Projetos(projeto_id) ON DELETE CASCADE
);

CREATE TABLE ColunasKanban (
    coluna_id INT AUTO_INCREMENT PRIMARY KEY,
    projeto_id INT NOT NULL,
    nome VARCHAR(50) NOT NULL, -- Ex: To Do, In Progress, Code Review, Done
    ordem INT NOT NULL,
    limite_wip INT DEFAULT 0 COMMENT 'Work In Progress Limit (Conceito Kanban)',
    FOREIGN KEY (projeto_id) REFERENCES Projetos(projeto_id) ON DELETE CASCADE
);

-- 5. O Motor de Tarefas (Task Engine)
CREATE TABLE Tarefas (
    tarefa_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    codigo_visual VARCHAR(20) COMMENT 'Ex: PROJ-101 (Gerado via Trigger)',
    projeto_id INT NOT NULL,
    sprint_id INT DEFAULT NULL, -- Pode ser NULL (Backlog)
    coluna_id INT NOT NULL, -- Status dinâmico
    
    titulo VARCHAR(200) NOT NULL,
    descricao MEDIUMTEXT, -- Suporta Markdown/HTML
    prioridade ENUM('Baixa', 'Media', 'Alta', 'Critica') DEFAULT 'Media',
    tipo ENUM('Tarefa', 'Bug', 'Historia', 'Epico') DEFAULT 'Tarefa',
    
    -- Hierarquia (Subtarefas)
    tarefa_pai_id BIGINT DEFAULT NULL,
    
    -- Atribuição e Tempo
    atribuido_a INT DEFAULT NULL,
    criado_por INT NOT NULL,
    estimativa_horas DECIMAL(6, 2) DEFAULT 0,
    
    data_criacao DATETIME DEFAULT CURRENT_TIMESTAMP,
    data_vencimento DATETIME,
    
    FOREIGN KEY (projeto_id) REFERENCES Projetos(projeto_id) ON DELETE CASCADE,
    FOREIGN KEY (sprint_id) REFERENCES Sprints(sprint_id) ON DELETE SET NULL,
    FOREIGN KEY (coluna_id) REFERENCES ColunasKanban(coluna_id),
    FOREIGN KEY (tarefa_pai_id) REFERENCES Tarefas(tarefa_id) ON DELETE CASCADE,
    FOREIGN KEY (atribuido_a) REFERENCES Usuarios(usuario_id),
    FOREIGN KEY (criado_por) REFERENCES Usuarios(usuario_id),
    
    INDEX idx_busca_tarefa (titulo),
    INDEX idx_quadro (coluna_id, sprint_id)
);

-- 6. Dependências (Gráfico de Gantt)
-- Tarefa B depende da Tarefa A (Blocker)
CREATE TABLE Dependencias (
    tarefa_principal_id BIGINT NOT NULL,
    tarefa_bloqueadora_id BIGINT NOT NULL,
    tipo ENUM('Bloqueia', 'Relacionado') DEFAULT 'Bloqueia',
    
    PRIMARY KEY (tarefa_principal_id, tarefa_bloqueadora_id),
    FOREIGN KEY (tarefa_principal_id) REFERENCES Tarefas(tarefa_id) ON DELETE CASCADE,
    FOREIGN KEY (tarefa_bloqueadora_id) REFERENCES Tarefas(tarefa_id) ON DELETE CASCADE
);

-- 7. Time Tracking (Timesheets)
-- Onde o desenvolvedor loga: "Trabalhei 2h nisso hoje"
CREATE TABLE ApontamentoHoras (
    apontamento_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    tarefa_id BIGINT NOT NULL,
    usuario_id INT NOT NULL,
    horas_gastas DECIMAL(5, 2) NOT NULL,
    descricao_trabalho TEXT,
    data_registro DATE NOT NULL,
    
    FOREIGN KEY (tarefa_id) REFERENCES Tarefas(tarefa_id) ON DELETE CASCADE,
    FOREIGN KEY (usuario_id) REFERENCES Usuarios(usuario_id)
);

-- 8. Comentários e Colaboração
CREATE TABLE Comentarios (
    comentario_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    tarefa_id BIGINT NOT NULL,
    usuario_id INT NOT NULL,
    texto TEXT NOT NULL,
    criado_em DATETIME DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (tarefa_id) REFERENCES Tarefas(tarefa_id) ON DELETE CASCADE,
    FOREIGN KEY (usuario_id) REFERENCES Usuarios(usuario_id)
);

-- =========================================================
-- 🧠 LÓGICA SÊNIOR (AUTOMAÇÃO E CÁLCULOS)
-- =========================================================

-- TRIGGER: Gerar Código Visual (Ex: PROJ-1, PROJ-2)
DELIMITER //
CREATE TRIGGER trg_GerarCodigoTarefa
BEFORE INSERT ON Tarefas
FOR EACH ROW
BEGIN
    DECLARE v_chave VARCHAR(10);
    DECLARE v_proximo_id INT;
    
    -- Pega a chave do projeto
    SELECT chave INTO v_chave FROM Projetos WHERE projeto_id = NEW.projeto_id;
    
    -- Simulação simples de sequence (Em prod, usaríamos uma tabela de sequencias por projeto)
    -- Aqui usamos o AutoIncrement como base para simplificar o exemplo
    SET v_proximo_id = (SELECT IFNULL(MAX(tarefa_id), 0) + 1 FROM Tarefas);
    
    SET NEW.codigo_visual = CONCAT(v_chave, '-', v_proximo_id);
END //

-- TRIGGER: Atualizar Progresso do Projeto ao Apontar Horas
CREATE TRIGGER trg_AtualizarHorasProjeto
AFTER INSERT ON ApontamentoHoras
FOR EACH ROW
BEGIN
    DECLARE v_projeto_id INT;
    
    -- Descobre o projeto
    SELECT projeto_id INTO v_projeto_id FROM Tarefas WHERE tarefa_id = NEW.tarefa_id;
    
    -- Atualiza total de horas gastas no projeto (Cache)
    UPDATE Projetos 
    SET total_horas_gastas = total_horas_gastas + NEW.horas_gastas
    WHERE projeto_id = v_projeto_id;
    
    -- Nota: Em um sistema real, recalcularíamos o progresso % baseado no status das tarefas
END //
DELIMITER ;

-- VIEW: Burn-down Chart (Velocidade da Sprint)
-- Compara o que foi estimado vs o que foi gasto por Tarefa
CREATE OR REPLACE VIEW v_SprintBurndown AS
SELECT 
    s.nome AS sprint,
    t.codigo_visual,
    t.titulo,
    u.nome AS responsavel,
    t.estimativa_horas,
    IFNULL(SUM(ah.horas_gastas), 0) AS horas_reais,
    (t.estimativa_horas - IFNULL(SUM(ah.horas_gastas), 0)) AS saldo_horas,
    CASE 
        WHEN IFNULL(SUM(ah.horas_gastas), 0) > t.estimativa_horas THEN 'Estourado'
        ELSE 'No Prazo'
    END AS status_tempo
FROM Tarefas t
JOIN Sprints s ON t.sprint_id = s.sprint_id
LEFT JOIN Usuarios u ON t.atribuido_a = u.usuario_id
LEFT JOIN ApontamentoHoras ah ON t.tarefa_id = ah.tarefa_id
GROUP BY t.tarefa_id;

-- PROCEDURE: Mover Tarefa (Drag and Drop no Kanban)
-- Valida regras de negócio ao mover de coluna
DELIMITER //
CREATE PROCEDURE sp_MoverTarefa(
    IN p_tarefa_id BIGINT,
    IN p_nova_coluna_id INT,
    IN p_usuario_id INT -- Quem está movendo (para log)
)
BEGIN
    DECLARE v_limite_wip INT;
    DECLARE v_qtd_atual INT;
    
    -- 1. Verificar WIP (Work in Progress Limit)
    SELECT limite_wip INTO v_limite_wip FROM ColunasKanban WHERE coluna_id = p_nova_coluna_id;
    
    IF v_limite_wip > 0 THEN
        SELECT COUNT(*) INTO v_qtd_atual FROM Tarefas WHERE coluna_id = p_nova_coluna_id;
        
        IF v_qtd_atual >= v_limite_wip THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Bloqueio Kanban: Limite de WIP da coluna atingido.';
        END IF;
    END IF;
    
    -- 2. Atualizar Coluna
    UPDATE Tarefas SET coluna_id = p_nova_coluna_id WHERE tarefa_id = p_tarefa_id;
    
    -- 3. (Opcional) Inserir em tabela de Logs de Auditoria
    -- INSERT INTO ActivityLog ...
END //
DELIMITER ;
