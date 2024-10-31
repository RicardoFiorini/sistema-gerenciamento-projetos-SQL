-- Criação do banco de dados
CREATE DATABASE GerenciamentoProjetos;
USE GerenciamentoProjetos;

-- Tabela para armazenar informações dos usuários (membros da equipe)
CREATE TABLE Usuarios (
    usuario_id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela para armazenar informações dos projetos
CREATE TABLE Projetos (
    projeto_id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    status ENUM('Em Andamento', 'Concluído', 'Cancelado') DEFAULT 'Em Andamento',
    data_cadastro DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabela para armazenar tarefas
CREATE TABLE Tarefas (
    tarefa_id INT AUTO_INCREMENT PRIMARY KEY,
    projeto_id INT NOT NULL,
    usuario_id INT NOT NULL,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    prioridade ENUM('Baixa', 'Média', 'Alta') DEFAULT 'Média',
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    status ENUM('A Fazer', 'Em Progresso', 'Concluída') DEFAULT 'A Fazer',
    FOREIGN KEY (projeto_id) REFERENCES Projetos(projeto_id) ON DELETE CASCADE,
    FOREIGN KEY (usuario_id) REFERENCES Usuarios(usuario_id) ON DELETE CASCADE
);

-- Índices para melhorar a performance
CREATE INDEX idx_projeto_nome ON Projetos(nome);
CREATE INDEX idx_tarefa_nome ON Tarefas(nome);
CREATE INDEX idx_usuario_email ON Usuarios(email);
CREATE INDEX idx_tarefa_status ON Tarefas(status);
CREATE INDEX idx_projeto_status ON Projetos(status);

-- View para visualizar todas as tarefas com informações do projeto e usuário
CREATE VIEW ViewTarefasCompletas AS
SELECT t.tarefa_id, t.nome AS tarefa, t.descricao AS tarefa_descricao, 
       p.nome AS projeto, p.status AS projeto_status, 
       u.nome AS usuario, t.status AS tarefa_status, 
       t.data_inicio, t.data_fim
FROM Tarefas t
JOIN Projetos p ON t.projeto_id = p.projeto_id
JOIN Usuarios u ON t.usuario_id = u.usuario_id;

-- Função para calcular o total de tarefas em um projeto
DELIMITER //
CREATE FUNCTION CalcularTotalTarefas(projeto_id INT) RETURNS INT
BEGIN
    DECLARE total INT;
    SELECT COUNT(*) INTO total
    FROM Tarefas
    WHERE projeto_id = projeto_id;
    RETURN total;
END //
DELIMITER ;

-- Função para calcular o total de tarefas concluídas em um projeto
DELIMITER //
CREATE FUNCTION CalcularTotalTarefasConcluidas(projeto_id INT) RETURNS INT
BEGIN
    DECLARE total INT;
    SELECT COUNT(*) INTO total
    FROM Tarefas
    WHERE projeto_id = projeto_id AND status = 'Concluída';
    RETURN total;
END //
DELIMITER ;

-- Trigger para validar as datas de início e fim da tarefa
DELIMITER //
CREATE TRIGGER Trigger_ValidaDatasTarefa
BEFORE INSERT ON Tarefas
FOR EACH ROW
BEGIN
    IF NEW.data_fim < NEW.data_inicio THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'A data de término não pode ser anterior à data de início';
    END IF;
END //
DELIMITER ;

-- Trigger para validar as datas de início e fim do projeto
DELIMITER //
CREATE TRIGGER Trigger_ValidaDatasProjeto
BEFORE INSERT ON Projetos
FOR EACH ROW
BEGIN
    IF NEW.data_fim < NEW.data_inicio THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'A data de término não pode ser anterior à data de início';
    END IF;
END //
DELIMITER ;

-- Inserção de exemplo de usuários (membros da equipe)
INSERT INTO Usuarios (nome, email) VALUES 
('João Silva', 'joao.silva@example.com'),
('Maria Oliveira', 'maria.oliveira@example.com'),
('Carlos Pereira', 'carlos.pereira@example.com');

-- Inserção de exemplo de projetos
INSERT INTO Projetos (nome, descricao, data_inicio, data_fim) VALUES 
('Desenvolvimento do Site', 'Criação de um novo site institucional', '2024-10-01', '2024-12-01'),
('Lançamento de Produto', 'Preparação para o lançamento de um novo produto', '2024-11-01', '2024-11-30');

-- Inserção de exemplo de tarefas
INSERT INTO Tarefas (projeto_id, usuario_id, nome, descricao, prioridade, data_inicio, data_fim) VALUES 
(1, 1, 'Criar Wireframe', 'Desenvolver o wireframe do site', 'Alta', '2024-10-01', '2024-10-10'),
(1, 2, 'Desenvolver Frontend', 'Implementar o frontend do site', 'Média', '2024-10-11', '2024-11-01'),
(2, 3, 'Planejar Marketing', 'Criar estratégia de marketing para o lançamento', 'Alta', '2024-11-01', '2024-11-15');

-- Selecionar todas as tarefas com informações do projeto e usuário
SELECT * FROM ViewTarefasCompletas;

-- Calcular total de tarefas no projeto 1
SELECT CalcularTotalTarefas(1) AS total_tarefas;

-- Calcular total de tarefas concluídas no projeto 1
SELECT CalcularTotalTarefasConcluidas(1) AS total_tarefas_concluidas;

-- Excluir uma tarefa
DELETE FROM Tarefas WHERE tarefa_id = 1;

-- Excluir um projeto (isso removerá todas as tarefas associadas)
DELETE FROM Projetos WHERE projeto_id = 1;

-- Excluir um usuário (isso falhará se o usuário tiver tarefas associadas)
DELETE FROM Usuarios WHERE usuario_id = 1;
