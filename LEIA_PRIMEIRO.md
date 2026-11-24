# Pontal da Serra Web 0.3.5

Atualização cumulativa para a versão publicada 0.3.2. Inclui as correções 0.3.3 e 0.3.4. Não é necessário instalar as versões intermediárias. Pacote preparado e testado localmente; não publicado automaticamente.

## O que está incluído

- Menu lateral com rolagem própria: Relatórios e Configurações acessíveis mesmo em janelas baixas.
- Relatórios mensais com todas as rubricas e totais, Excel/CSV e impressão/PDF.
- Contagem de todas as contas vinculadas ao responsável, incluindo familiares. Painel de acessos, atualização dos vínculos e convites individuais simultâneos com instruções de cadastro e instalação.
- Campo descritivo de proprietário síndico. Não concede administração automaticamente aos familiares nem substitui a permissão da conta no banco.
- Simular fechamento, sem emitir cobranças, alterar saldos ou remover pendências. Usa os últimos dados salvos e identifica resultados provisórios.
- Reabrir mês com motivo, confirmação e arquivamento integral das faturas anteriores. Não apaga o histórico. Bloqueia reabertura com pagamentos potencialmente relacionados, reservas baixadas, envio registrado ou mês posterior dependente. Conferência individual novamente exigida ao fechar. Identificadores antigos não são reutilizados.
- Vida no Pontal: documentos, normas, contatos, agenda e informações publicados pelo síndico, com rascunhos e PDF/imagens privados. Links externos oficiais para pesca/piracema, fases da Lua, clima e reservatórios. Não há atualização automática desses dados nem indicação automática de pesca liberada.
- Documentos do mês: conta de energia em PDF e fotos das leituras (geral, bomba, caseiro, individuais e outros), associados à competência. Publicados para todos os condôminos cadastrados, inclusive antes de fechar. Administração: Fechamento > Documentos do mês. Condômino: Explicação do mês > Documentos do mês, além de Vida no Pontal.
- Investimentos > Documentos do investimento solar: notas fiscais, contratos, garantias e documentos comprobatórios. O síndico publica PDF ou imagem com título e descrição. Todos os membros podem consultar os documentos publicados, preservando o acesso restrito aos saldos individuais de terceiros.
- Chaves de acesso (passkeys): cadastro após login, entrada sem digitar senha, lista e remoção da própria chave. Usa a confirmação do aparelho (digital, Face ID ou PIN conforme suporte). Integração depende de ativação no Supabase e teste no aparelho real; o recurso do provedor é experimental. Não exige biometria a cada abertura quando a sessão já está conectada.
- Guia do morador atualizado e ícone .ico para atalhos no Windows, em assets/Pontal_da_Serra.ico.

## Atualizar a instalação existente

1. No mesmo projeto Supabase, executar **supabase/INSTALAR_OU_ATUALIZAR.sql**. É uma atualização cumulativa, transacional e reaplicável; preserva cadastros, usuários, administradores, pagamentos e leituras.
2. Aplicar a correção solar privada entregue fora desta pasta pública. Não reimportar os dados reais. A correção valida o lançamento original, impede alteração se ele já estiver diferente e pode ser repetida sem duplicar ajustes.
3. Atualizar os arquivos desta pasta na raiz do repositório do site. Preservar o endereço existente e config.js. Nunca enviar a pasta privada ao GitHub.
4. No aplicativo, usar Atualizar aplicativo. Conferir versão 0.3.5 no rodapé. Entrar novamente se necessário.
5. Fazer a primeira conferência com **Simular fechamento**. As pendências reais de novembro continuam identificadas. Não marcar uma pendência como resolvida apenas para testar o fechamento efetivo.
6. Para digital/Face ID, seguir **ATIVAR_CHAVE_DE_ACESSO.md**. Enquanto a autenticação estiver desabilitada no provedor, a aplicação informa a pendência e mantém a senha disponível.

## Documentos e publicação

Use Vida no Pontal > Publicar informação ou os botões específicos em Fechamento/Investimentos. Cada publicação aceita um PDF ou imagem de até 5 MB; várias publicações permitem quantos documentos forem necessários. Anexos não entram no cache offline. O arquivo fica em armazenamento privado e é aberto com link temporário de 90 segundos.

Informações publicadas são compartilhadas com os membros ativos do condomínio. Rascunhos são administrativos. As contas precisam estar vinculadas por convite; apenas criar conta não dá acesso aos documentos. Comprovantes financeiros privados já existentes não são publicados automaticamente por esta atualização.

## Acesso administrativo

A conta do síndico precisa constar em app_admins. Convite e identificação do proprietário como síndico não dão essa permissão. Contas novas do mesmo lote consultam a cobrança autorizada. Não compartilhar senhas de contas pessoais nem do Gmail.

## Financeiro e limitações atuais

As regras confirmadas de energia, água, caseiro e cotas permanecem. Os valores de novembro são provisórios enquanto faltarem validação das leituras, unidade dos hidrômetros, composição salarial, participantes e saldos. Reabrir um mês não resolve suas pendências.

Reabertura após pagamentos, baixas ou dependências exige retificação acompanhada; o aplicativo bloqueia a reversão automática. O envio manual de PDFs/WhatsApp não pode ser detectado pelo sistema: a confirmação de reabertura informa que cópias anteriores precisam ser substituídas e os destinatários avisados.

WhatsApp automático, conciliação bancária, notificações ambientais automáticas e cadastro de solicitações com acompanhamento não foram acrescentados nesta revisão. A cópia de mensagens e as consultas externas continuam identificadas como operações manuais.

Consulte TESTES_DE_HOMOLOGACAO.md, REGRAS_FINANCEIRAS.md e ESTADO_DO_PROJETO.md. Para desenvolvimento: npm install; npm test; npm run check. A interface não precisa de Node para ser publicada no GitHub Pages.
