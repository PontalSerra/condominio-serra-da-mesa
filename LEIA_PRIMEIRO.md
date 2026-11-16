# PONTAL DA SERRA WEB — PRIMEIRA VERSÃO FUNCIONAL (0.1)

**Condomínio Pontal da Serra • Serra da Mesa • Niquelândia/GO**

Esta entrega é um **protótipo funcional**, preparado para ser colocado no GitHub Pages e, depois de conectado ao Supabase, usar autenticação e banco de dados. Não é uma entrega homologada nem um sistema de cobranças pronto para operar com valores reais sem conferência.

## 1. Como abrir e conhecer

Abra `index.html` em um navegador moderno; a versão de demonstração usa **dados fictícios**. Se o navegador bloquear módulos locais, publique primeiro pelo GitHub Pages ou execute um servidor local (ex.: `python -m http.server`).

O modo de demonstração permite experimentar o painel do síndico e o espaço individual do condômino. **Não importe dados reais na demonstração**: nessa modalidade as informações são armazenadas apenas no navegador, sem proteção por usuário e sem sincronização.

## 2. O que já está programado

- Visual responsivo para computador, iPhone e Android, com manifesto de instalação PWA;
- Visão do síndico e visão individual, controladas por login no Supabase;
- Cadastro de condôminos, WhatsApp, consentimento de mensagens, lotes e adesão à energia solar;
- Acesso de vários usuários a uma mesma conta de cobrança (coproprietários); associação de outros condôminos ao lote sem expor outras faturas;
- Abertura de competência mensal e vencimento no **dia 10 do mês seguinte**;
- Leituras individuais de energia e água, pelo nome do responsável; leituras do medidor geral e da bomba;
- Cálculo da energia por kWh, da água conforme despesa da bomba, taxas de R$ 75 e R$ 35, rateio de caseiro e iluminação apenas entre proprietários com construção, provisões, despesas extras e energia solar por lote aderente;
- Fechamento e geração de faturas individualizadas, com saldo anterior;
- Registro de pagamentos e consulta do histórico pelo condômino;
- Fatura individual formatada com discriminação, leituras, total anterior, saldo atualizado e **Pix Copia e Cola/QR Code estático com valor**, configurável pelo síndico;
- Impressão ou exportação da fatura em PDF pelo recurso *Imprimir / Salvar como PDF* do navegador;
- Mural de avisos gerais ou para destinatários selecionados;
- Preparação de mensagens de cobrança e comunicados por WhatsApp e exportação de CSV com links de envio assistido;
- Balancete coletivo em CSV e relatório financeiro administrativo nominal;
- Importação inicial assistida do arquivo XLSX de novembro de 2026, com leitura de `PLANILHA NOV` e `PLANILHA BASE`, quando presentes.

## 3. O que ainda DEPENDE de configuração ou validação

- **Banco de dados real:** criar o projeto Supabase, executar `supabase/schema.sql`, cadastrar os usuários e definir as permissões;
- **WhatsApp realmente automático:** configurar WhatsApp Business Platform, número apto, token, modelos aprovados, função `whatsapp-batch` e agendamento seguro. Sem isso, existem apenas mensagens assistidas e a estrutura de integração;
- **Fatura em PDF como anexo automático do WhatsApp:** NÃO implementada nesta versão. A API envia *modelo aprovado* com informações da fatura e orienta o acesso autenticado ao portal. O PDF individual é gerado pelo navegador;
- **Comprovante do Pix / baixa automática:** NÃO implementado. O código Pix contém valor, mas o pagamento continua dependendo de conferência e lançamento pelo síndico. Cobrança dinâmica com confirmação exige provedor bancário/PSP e webhook;
- **Revisão dos rateios conforme assembleia:** os modelos seguem as regras relatadas, mas ainda devem ser ratificados pelo condomínio;
- **Migração histórica:** valores pendentes e pagamentos importados devem ser conferidos antes da operação. A importação não presume que pagamentos do Excel foram liquidados;
- **Homologação com dados reais:** testar dois logins diferentes para confirmar que uma conta não consulta dados de outra; revisar fechamento e cálculos de pelo menos três meses.

## 4. Colocar os arquivos no GitHub (site)

1. Extraia o ZIP em uma pasta do computador.
2. No GitHub, crie um repositório, por exemplo `pontal-da-serra-web`.
3. Entre no repositório e escolha **Add file → Upload files**. Encaminhe os arquivos `index.html`, `app.js`, `style.css`, `config.js`, `manifest.webmanifest`, `sw.js` e a pasta `assets` (mantenha as mesmas pastas). Pode enviar também este manual e a pasta `supabase`.
4. Clique em **Commit changes**.
5. Em **Settings → Pages**, escolha publicação a partir da branch `main`, pasta `/ (root)`; salve.
6. Quando o GitHub publicar, o site normalmente terá endereço parecido com `https://SEU_USUARIO.github.io/pontal-da-serra-web/`.
7. **Atenção:** com `config.js` em branco, o site é apenas uma demonstração local. Nunca publique planilhas reais, nomes, telefones, saldos ou senhas no repositório.

**Importante:** GitHub Pages publica a interface; não é um banco de dados. O site não será multiusuário até ser conectado ao Supabase.

## 5. Configurar o Supabase (banco e usuários)

1. Crie um projeto no Supabase.
2. Abra **SQL Editor**, cole o conteúdo de `supabase/schema.sql` e execute.
3. Abra **Authentication → Users** e crie um usuário para o síndico, com e-mail e senha. Copie o identificador UUID (*User ID*).
4. Pelo **SQL Editor**, conceda papel administrativo a esse usuário (substitua pelo UUID correto):

   ```sql
   insert into public.app_admins(user_id)
   values ('COLE-AQUI-O-UUID-DO-SINDICO');
   ```

5. Em **Project Settings → API**, copie o `Project URL` e a **anon/publishable key** e informe em `config.js`:

   ```javascript
   window.PONTAL_CONFIG = {
     supabaseUrl: 'https://SEU-PROJETO.supabase.co',
     supabaseAnonKey: 'CHAVE-PUBLICA-ANON-OU-PUBLISHABLE',
     appName: 'Pontal da Serra Web'
   };
   ```

6. Salve o arquivo modificado e envie novamente ao repositório. **NUNCA coloque `service_role`, tokens privados do WhatsApp ou senhas em `config.js`.**
7. Acesse o site e entre com o usuário do síndico. Cadastre os titulares de cobrança e, se necessário, importe a planilha original.
8. Para cada condômino que terá acesso, crie um usuário em **Authentication → Users**, copie o UUID e inclua no campo de UID do cadastro. Caso duas pessoas precisem acessar a mesma fatura, use o botão **Acessos** no cadastro do titular para associar os UIDs adicionais.
9. Teste um segundo usuário: ele deverá ver apenas seus lotes, avisos e faturas, sem acesso a cadastros e débitos alheios. As regras RLS do banco protegem os dados mesmo que alguém manipule o código no navegador.

**Não disponibilize dados pessoais antes de concluir e testar essas etapas.**

## 6. Fluxo mensal sugerido ao síndico

1. **Novo mês:** criar competência (ex.: novembro de 2026, com vencimento 10/12/2026).
2. **Leituras:** digitar leituras recebidas do Farofa; a leitura anterior vem do mês anterior, quando disponível.
3. **Fechamento:** digitar conta geral de energia, leitura geral, leitura e gasto da bomba, salário/despesas do caseiro, iluminação, férias/13º, extraordinárias e, se houver, parcelas de energia solar.
4. **Conferência:** verificar a prévia detalhada, especialmente condomínios com dois lotes, construídos e vazios.
5. **Fechar mês:** o sistema cria faturas e mantém registro da competência. Se a API do WhatsApp estiver configurada, tentará disparar os modelos de fatura automaticamente.
6. **Pagamentos:** lançar cada recebimento com nome, data e valor. O saldo anterior é carregado pelo histórico de cobranças menos o histórico de pagamentos; não deve ser lançado uma segunda vez no novo mês.
7. **Dia 9:** a função agendada pode enviar lembretes aos destinatários que optaram pelo WhatsApp e ainda têm saldo, com vencimento no dia 10.
8. **Relatórios:** exportar balancete geral (sem dados pessoais) para o grupo e controle financeiro detalhado para a administração.

## 7. Regras que merecem confirmação

- **Taxa:** um rancho construído do mesmo titular paga R$ 75; os demais lotes do mesmo titular, R$ 35 cada, inclusive lotes vazios. Titulares sem construção pagam somente R$ 35 por lote.
- **Caseiro, iluminação e provisão:** uma cota por responsável com ao menos um lote construído; titulares só com lotes vazios são isentos dessas rubricas. **Confirme em assembleia**, especialmente no caso de propriedade compartilhada.
- **Energia elétrica individual:** (leitura atual − anterior) × tarifa de kWh do mês.
- **Água:** (leitura atual − anterior) ÷ 1.000, como indicam os registros originais do Excel. O divisor fica configurável para medidores diferentes. Valor do m³ = custo da bomba ÷ consumo total medido. Se não houver consumo total, não é possível ratear o custo da bomba automaticamente.
- **Energia solar:** por lote marcado como participante, com valor mensal configurado pelo síndico.
- **Despesas extras:** podem ser por titulares construídos (padrão), todos os titulares ou número de lotes, conforme decisão específica da assembleia.
- **Lotes com dois donos:** cada lote possui um responsável financeiro definido; outros acessos à mesma conta são cadastrados expressamente.
- **Dívida histórica:** o campo *Saldo inicial* serve para transportar valores já conferidos anteriores à implantação. Após começar a emitir faturas, não repita o valor em outro lançamento.

## 8. WhatsApp Business e agendamento de lembrete

O código da função está em `supabase/functions/whatsapp-batch/index.ts`. Ele **não envia mensagens por conta própria** até ser instalado e receber credenciais válidas.

1. Habilite a Plataforma WhatsApp Business da Meta e obtenha `PHONE_NUMBER_ID` e token com permissão de envio.
2. Crie e tenha aprovados os templates utilitários em português (`pt_BR`):
   - `pontal_fatura` — **4 campos**, nesta ordem: nome; competência; saldo; vencimento;
   - `pontal_lembrete` — **3 campos**, nesta ordem: nome; saldo; vencimento.
   O corpo do template deve informar que a fatura detalhada está disponível no portal após login; não inclua informações pessoais de terceiros.
3. Configure no Supabase os secrets `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_TEMPLATE_INVOICE`, `WHATSAPP_TEMPLATE_REMINDER`, `CRON_SECRET` e demais secrets do projeto. **Não envie esses segredos para o GitHub**.
4. Instale a Supabase CLI e execute `supabase functions deploy whatsapp-batch --no-verify-jwt`. A própria função valida o JWT do síndico ou o segredo do agendador; o flag de deploy exige esse cuidado.
5. Para executar automaticamente no dia 9, programe uma tarefa HTTP autenticada no Supabase Cron que faça `POST` na função `/functions/v1/whatsapp-batch`, com header `X-Cron-Secret: SEU_SEGREDO` e JSON `{"kind":"reminder"}`. A função descobre o mês anterior pela data de Brasília e só envia no dia 9. O cron em UTC para **08h30 de Brasília** é normalmente `30 11 9 * *` (UTC−3). Verifique a região e a configuração do projeto.
6. Teste com um número autorizado e confira os logs de entregas. O envio pode ter tarifas cobradas pela Meta/provedor.

**A API do WhatsApp não permite mensagens arbitrárias fora da janela autorizada; por isso os avisos automáticos usam templates aprovados.** Os comunicados livres ficam disponíveis no mural e como mensagens assistidas.

## 9. Uso no iPhone e Android

No iPhone, abra o site HTTPS pelo Safari e use **Compartilhar → Adicionar à Tela de Início**. No Android, abra pelo Chrome e escolha **Instalar aplicativo** ou **Adicionar à tela inicial**. No computador, o navegador também pode oferecer instalação.

O PWA usa um único código e uma única base remota. Os dados dependem de conexão para atualizar e consultar com segurança.

## 10. Atenções de segurança e jurídicas

- Este protótipo não é laudo sobre a regularidade fundiária do condomínio. Regras de rateio, cobrança e votação devem ser aprovadas conforme a situação jurídica real do Pontal da Serra.
- As leituras e débitos reais são dados pessoais/patrimoniais. A divulgação de relatórios nominais no grupo precisa ser avaliada pela administração à luz da LGPD, privilegiando um balancete coletivo sem nomes ou saldos individualizados.
- Não publique os arquivos reais do Excel nem as mensagens de WhatsApp originais no GitHub.
- Faça backups periódicos do Supabase e mantenha registros dos comprovantes.
- Faça uma conferência com o banco antes de usar o Pix; o **Pix estático com valor não confirma pagamento automaticamente**.

---

**Status da entrega:** aplicativo HTML/JS + PWA + SQL com RLS + função preparatória de WhatsApp. Testes programáticos verificaram a sintaxe JavaScript, as regras básicas R$ 75/R$ 35, isenção de caseiro para lote vazio e CRC do Pix. **Não foram feitos testes ponta a ponta em Supabase/Meta nem publicação no seu GitHub**, pois exigem suas contas e credenciais.
