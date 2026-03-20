# Sistema de Gerenciamento de Projetos (SQL)
Uma solução de backend desenvolvida em SQL focada em **administração de tarefas, controle de prazos e gestão de equipes** para ambientes corporativos.
## Funcionalidades do Esquema

- **Projetos:** Cadastro de marcos, orçamentos e cronogramas de execução.
- **Tarefas:** Detalhamento de atividades individuais com status de progresso.
- **Colaboradores:** Alocação de membros de equipe em projetos específicos.
- **Priorização:** Classificação de urgência para otimização do fluxo de trabalho.

## Status do Projeto
- [x] Definição de Tabelas e Relacionamentos
- [x] Implementação de Chaves Estrangeiras
- [x] Queries de acompanhamento de progresso
- [ ] Criar views para dashboards de produtividade
## Exemplo de Query (Progresso por Projeto)
Este script demonstra como verificar o status de todas as tarefas vinculadas a um projeto em andamento:
```sql

SELECT projetos.nome_projeto, tarefas.descricao, tarefas.status, colaboradores.nome AS responsavel
FROM tarefas
JOIN projetos ON tarefas.projeto_id = projetos.id
JOIN colaboradores ON tarefas.colaborador_id = colaboradores.id
WHERE projetos.status = 'Em Andamento'
ORDER BY tarefas.prazo ASC;

```
## Dicas de Performance
> [!TIP]
> Utilize índices nas colunas de data e status para acelerar consultas em relatórios de tarefas atrasadas ou concluídas recentemente.
## Estrutura das Tabelas
| Tabela | Descrição |
| --- | --- |
| projetos | Controle macro dos objetivos e datas do projeto |
| tarefas | Registro de ações pontuais e seus status |
| colaboradores | Dados dos membros da equipe e cargos |
| alocacoes | Vinculação entre pessoas e projetos |
