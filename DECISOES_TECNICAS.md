# Decisões técnicas 0.3.1

- Base: preparação local 0.3.0 consolidada, preservada em diretório separado; origem inicial no ZIP fornecido pelo usuário.
- Motor financeiro determinístico em finance.js; regras por competência em rateios.js; interface de regras em admin-config.js; primeiro acesso em acesso.js.
- As regras individuais são registros temporais, não um atributo deduzido da taxa. Cotas são pesos explícitos; um responsável é contado uma vez por grupo.
- Dados reais não integram o código público. Importação privada tem lote identificável, validação administrativa, transação e auditoria; nomes e titularidade existentes não são reatribuídos silenciosamente.
- Primeiro acesso utiliza e-mail/senha do provedor e convite privado aleatório de 256 bits. O banco armazena hash SHA-256 do convite. A utilização exige sessão com e-mail confirmado, é única e não atribui papel administrativo.
- RLS separa administradores e responsáveis. Faturas individuais guardam somente sua própria regra; o mapa completo dos grupos fica na competência administrativa.
- Fechamento compara a fotografia de dados conferida com a origem atual e grava mês/faturas na mesma transação. Regras e emissão usam bloqueio transacional; inconsistência aborta a operação.
- A importação pelo SQL Editor também admite o proprietário de banco postgres sem SET ROLE nem JWT. A API autenticada de condôminos não tem essa condição. A operação pelo SQL Editor fica identificada sem inventar autoria de um usuário de aplicação.
- A execução local de SQL usa PostgreSQL/PGlite com auth e storage simulados. Não substitui conferir e-mails, usuários e políticas adicionais que já existam no projeto real.


## 0.3.2 — transparência, relatórios e atualização

O condômino não recebe SELECT de períodos, despesas, regras ou medidores alheios. `pontal_month_reports()` é uma projeção explicitamente selecionada, sem IDs, nomes ou saldos individuais; exige usuário autenticado e fatura própria em mês encerrado. Grupos usam a fotografia da regra do fechamento. Extras preservam descrição, modalidade, quantidade de participantes e cotas; motivos privados e listas de destinatários ficam fora da projeção. Faturas próprias conservam parcelas e critérios. Totais são agregados das faturas emitidas. Campos novos de data são opcionais e não são inventados.

Cache por versão, cache-first para os arquivos estáticos do conjunto; somente a mensagem ACTIVATE_UPDATE permite pular a espera. Uma janela avisa ao receber mudança de controlador e preserva formulário não salvo até decisão do usuário. A primeira passagem de uma instalação anterior à 0.3.2 deve ser conferida com todas as janelas antigas fechadas. Migrações precisam preceder o front-end e ser compatíveis com sessões antigas.

Planilha geral usa uma linha por responsabilidade financeira, com lotes agrupados e rubricas extra dinâmicas. Posição financeira atual e total da emissão são colunas distintas. Excel grava células numéricas; CSV usa separador ponto e vírgula, decimal brasileiro e neutralização de fórmulas em texto. Impressão da planilha ampla usa paisagem; relatórios compactos atendem A4.
