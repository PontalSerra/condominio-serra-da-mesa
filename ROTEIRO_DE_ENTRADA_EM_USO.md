# Pontal da Serra 0.3.2 — entrada em uso

Preparado em 24/11/2026. Atualização e dados reais ainda não aplicados ao projeto remoto.

## 1. Preservar o que já existe

Guardar cópia dos arquivos atuais do GitHub e backup do banco Supabase. Backup do código não é backup dos cadastros, usuários e pagamentos. Conservar as cópias fora do repositório público. Confirmar acesso administrativo ao mesmo projeto e endereço já utilizados.

## 2. Atualizar o banco e importar os dados

No SQL Editor do projeto existente, executar `supabase/INSTALAR_OU_ATUALIZAR.sql` deste pacote. Ele reúne a instalação e as migrações até 0.3.2, em transação reaplicável. Para quem já aplicou integralmente 0.3.1, também existe a migração incremental `supabase/migracao_v0_3_2.sql`.

Aplicar os dados reais pelo SQL privado ou pela importação JSON em Configurações. O pacote privado anterior continua compatível. Não publicar JSON, SQL privado, planilhas e relatórios nominais. Não executar duas importações diferentes para tentar corrigir um erro sem conferir a origem.

## 3. Conferir os cadastros e a competência

Conferir 31 responsáveis e 35 lotes importados; não presumir que exemplos antigos devem ser excluídos. Inativar exemplos apenas depois de identificá-los. Conferir responsáveis independentes e lotes compartilhados, regras individuais, cotas, taxas e vigências. Conferir telefones ausentes antes do envio de mensagens; não foram inventados.

Novembro permanece em rascunho. Rever saldos anteriores, pagamentos posteriores, divergências de leitura geral e bomba, unidade dos hidrômetros e inclusão do salário nas taxas. Registrar as datas de leitura e a próxima data. Conferir os 26 participantes de caseiro/iluminação/provisões. No solar, conferir diferença do cabeçalho de R$ 180 e marcações PAGO inconsistentes. Não emitir cobrança definitiva antes de resolver as pendências.

## 4. Publicar o código

Atualizar a raiz do mesmo repositório somente com o pacote Web, mantendo pastas e endereço. Confirmar publicação do GitHub Pages. Se já houver app instalado com versão antiga, fechar todas as suas janelas, abrir o endereço conectado e conferir 0.3.2 no rodapé. A partir de 0.3.2 existe aviso e botão de atualização.

Em versões futuras, alterar a versão do aplicativo e o identificador de cache em sw.js, publicar todos os arquivos juntos e testar a passagem entre duas versões. Aplicar migrações do banco antes da interface que depende delas. Não reutilizar o mesmo identificador de cache para arquivos diferentes. Mudança de estrutura deve ser compatível com janelas que ainda estejam abertas; planejar uma janela de manutenção se houver ruptura.

## 5. Testar no ambiente publicado

- Login do síndico e acesso a todos os menus, principalmente Relatórios.
- Configuração da chave Pix e conferência do titular no aplicativo bancário, sem concluir um pagamento de teste desnecessário.
- Supabase Auth: cadastro habilitado, confirmação de e-mail, endereço do site e redirecionamento de recuperação; testar entrega real de e-mails. Não desativar confirmação apenas para contornar problema de entrega.
- Gerar convite individual para uma pessoa de teste autorizada, criar conta, confirmar e-mail, vincular, sair e entrar novamente.
- Conferir com login de condômino real que apenas suas faturas, pagamentos, lotes e leituras são acessíveis. O demonstrativo coletivo traz apenas agregados e sua própria parcela. A prévia administrativa não testa segurança do banco.
- Testar recuperação de senha, instalação em Android e iPhone, impressão de uma fatura, Pix Copia e Cola e atualização de uma versão para outra no endereço real.

## 6. Encerrar o primeiro mês e distribuir acessos

Rever cada fatura e aprová-la. Encerrar o mês somente após conferir pendências; o demonstrativo fica disponível ao condômino com sua fatura. Conferir Relatórios > Resumo coletivo, memória de cálculo e saldos. Em Configurações > Acesso dos condôminos, gerar um convite por pessoa e enviar individualmente junto com `instalar.html` ou o PDF do guia. A senha é escolhida por cada usuário.

A competência fechada preserva os dados. Não há fluxo completo de retificação e reabertura de faturas: em caso de erro após emissão, interromper a distribuição e solicitar correção auditável antes de alterar o banco. Não editar linhas fechadas manualmente.

## 7. Rotina do síndico

Abrir o mês → lançar leituras e datas → conferir conta geral/bomba/caseiro → despesas e provisões → conferir regras e faturas → encerrar → distribuir avisos. Recebimentos são registrados com data e referência após conferência bancária. Não registrar duas vezes um pagamento importado do solar. Baixas de férias/13º usam as reservas e não criam nova cobrança pelo mesmo valor.

Na Central de relatórios: cobrança e saldos, parcela vencida estimada, leituras, recebimentos por data, reservas, despesas previstas, solar, extrato individual, faturas e comprovantes de recebimento. Há impressão/PDF, Excel (.xlsx) e CSV. A Planilha geral mensal reúne todas as rubricas, os lotes agrupados por responsável e a linha de totais. Relatórios nominais são administrativos. O resumo coletivo não identifica devedores.

## Limites que precisam ser conhecidos

O sistema não consulta banco para confirmar Pix. Não há abertura universal de aplicativo bancário; usa-se Copia e Cola ou QR Code. O relatório de despesas é previsão de cobrança, não livro-caixa de todas as saídas bancárias. Baixas de reservas são os pagamentos efetivamente registrados. Inadimplência é estimativa por vencimento e saldo, pois pagamentos não estão vinculados automaticamente a faturas. WhatsApp automático exige configuração de integração externa; abrir conversa ou copiar mensagem é envio assistido. Este pacote não envia convites ou mensagens sozinho.

## Atualizar ou voltar uma versão

Guardar a versão anterior antes de publicar. Para voltar a interface, restaurar os arquivos anteriores com identificador de cache NOVO e superior, para que o navegador detecte a alteração. Não apagar dados nem desfazer migração por tentativa. Usar backup e procedimento de restauração se o problema for do banco. Migração 0.3.2 é aditiva; não remove tabelas ou usuários.
