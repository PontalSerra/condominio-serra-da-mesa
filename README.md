# Pontal da Serra Web 0.3.2

Atualização preparada para conferência antes da publicação no mesmo endereço e projeto Supabase. O pacote Web contém somente código e exemplos fictícios. Os dados reais são entregues separadamente em um pacote privado.


## O que foi concluído em 0.3.2

- Central de relatórios com dez opções: planilha geral mensal com todas as rubricas e totais; resumo coletivo; cobranças e saldos; vencimentos estimados; leituras; recebimentos; provisões e baixas; despesas previstas; investimento solar; extrato individual.
- Exportação Excel (.xlsx), CSV e impressão/PDF dos relatórios. Valores numéricos são conservados como números no Excel. O resumo coletivo não lista devedores. A planilha geral é administrativa e agrupa lotes por responsabilidade, sem duplicação de cobrança. Rascunhos e saldos pendentes ficam identificados.
- Explicação do mês na visão individual: conta geral, bomba, água, caseiro, provisões, grupos, cotas e parcela própria. Disponível após o fechamento com fatura própria; valores de terceiros são agregados no servidor sem abrir cadastros alheios. Datas de leitura e próxima leitura podem ser registradas no fechamento.
- Aviso de nova versão, botão de atualização e confirmação quando há edição não salva. Cache guarda somente a interface pública; dados financeiros exigem internet. Novas versões devem receber identificador de cache próprio.
- Guia do morador em `instalar.html` e `Guia_do_Morador_Pontal_da_Serra.pdf`, incluído no convite individual. Instalação pelo navegador, cadastro, senha, Pix e atualização.
- Foto real do condomínio na entrada, convertida para WebP com 90.042 bytes, sem imagem nas faturas/relatórios.
- Roteiro operacional completo em `ROTEIRO_DE_ENTRADA_EM_USO.md` e verificações em Relatórios > Preparação para começar a usar.

O Pix usa o saldo total atualizado. O usuário copia o código e abre seu banco; não há abertura universal de banco nem conciliação automática. Despesas previstas não são todas as saídas bancárias. Relatórios de vencimento estimam abatimento dos saldos mais antigos; pagamentos não têm alocação automática por fatura.

## Conferir sem instalar

Abra **PREVIA_OFFLINE.html** no Chrome ou Edge para experimentar as telas e regras com exemplos fictícios. A prévia não utiliza dados reais nem cria contas. A versão conectada ao banco é index.html.

## Instalar ou atualizar

1. Guarde uma cópia do banco e dos arquivos atuais.
2. No SQL Editor do projeto Supabase existente, execute **supabase/INSTALAR_OU_ATUALIZAR.sql**. O script é transacional e reaplicável; preserva usuários e administradores existentes.
3. Para os dados reais, execute no mesmo SQL Editor o arquivo **Importar_Dados_Reais_PRIVADO.sql**, entregue separadamente. Outra opção é entrar como síndico e selecionar o JSON privado em **Configurações > Importar dados reais**. O mesmo lote de importação não é repetido.
4. Atualize os arquivos deste pacote na raiz do repositório do site. Preserve o endereço atual. A configuração pública do Supabase foi mantida.
5. Entre no aplicativo. Em **Fechamento**, confira as pendências de novembro e os saldos anteriores. Em **Configurações**, revise as regras por responsável. O mês permanece em rascunho até a conferência individual das faturas.

O arquivo privado com os dados reais, a conferência nominal e o SQL de importação **não devem ser publicados no repositório do site**.

## Primeiro acesso dos condôminos

- O síndico entra com sua conta administrativa existente.
- Em **Configurações > Acesso dos condôminos**, gera um convite individual e o entrega à pessoa certa.
- O condômino escolhe **Primeiro acesso - criar minha conta**, informa seu e-mail, convite e senha de pelo menos12 caracteres.
- Confirma o e-mail recebido, entra e informa o convite para vincular seu cadastro. Se a sessão já estiver confirmada, o vínculo acontece durante o cadastro.
- O convite tem validade de 30 dias e uma única utilização. Para outra pessoa consultar a mesma cobrança, o síndico gera um novo convite. O primeiro acesso permanece válido.
- A conta nova nunca recebe permissão administrativa por nome, e-mail ou informação digitada no cadastro. O acesso depende da autorização registrada no banco.

Antes de divulgar para todos, teste uma conta real de condômino e a recuperação de senha. No Supabase, confira o envio de e-mails, o Site URL e os redirecionamentos para o endereço do site e recuperar-acesso.html. O cadastro e a recuperação dependem desse serviço de e-mail. Na primeira instalação de um projeto vazio, o primeiro administrador deve ser criado no Supabase e incluído em app_admins; essa concessão não é pública.

## Regras flexíveis

Em **Configurações > Regras de cobrança por responsável**, cada pessoa pode ter:

- Taxa condominial diferente, inclusive isenção, com vigência.
- Participação independente em caseiro, iluminação, provisões e despesas extraordinárias do período.
- Seguir cadastro, participar por exceção ou ficar fora do grupo.
- Número de cotas por grupo, inclusive cotas fracionárias, sem inferir a participação pelo valor da taxa.
- Mês inicial, término opcional e motivo obrigatório. Uma exceção temporária devolve a regra anterior quando termina.

Sem regra individual, o padrão considera construção e uma participação por responsável. Vários lotes da mesma pessoa não multiplicam automaticamente o rateio. Duas responsabilidades realmente independentes podem ser vinculadas ao mesmo lote em **Casa independente**. Despesas extras cadastradas separadamente conservam seus próprios destinatários.

O fechamento mostra os participantes e a soma das cotas de cada grupo. Despesas sem destinatário bloqueiam a emissão. Faturas fechadas preservam valores, critérios e identificação histórica; regras retroativas que alcancem meses fechados são bloqueadas.

## Energia, água e provisões

- O central engloba ranchos, bomba, casa do caseiro e residual quando a bomba faz parte do geral.
- As leituras da casa do caseiro identificam seu consumo de energia e água; 100% desses custos entram no grupo caseiro.
- A água é proporcional aos hidrômetros, incluindo a casa do caseiro no denominador. O fator de conversão precisa ser conferido no medidor.
- Quando o salário já estiver incluído nas taxas ordinárias, marque essa opção; as provisões continuam calculadas sobre o salário-base.
- Provisão mensal:13º=salário/12 e férias com1/3=salário/9; total=salário×7/36.
- As parcelas são distribuídas em centavos, com desempate estável por identificador. A soma dos componentes concilia com o total; pequenas diferenças em relação a aproximações manuais decorrem dessa distribuição.

## Dados reais e conferência

A importação privada organiza responsáveis, lotes, leituras, participação, taxas e investimento solar. Não presume quitações não comprovadas nem transforma marcações PAGO em pagamentos inventados. Saldos de abertura permanecem sinalizados para conferência. As divergências dos documentos ficam registradas na importação e na competência.

O investimento solar mantém razão própria, uma cota por responsabilidade participante. Pagamentos e devoluções são separados. Os valores extraídos de imagens são identificados como informados na planilha de origem, não como conciliação bancária automática.

## Testes e estado

Veja **TESTES_DE_HOMOLOGACAO.md** e **ESTADO_DO_PROJETO.md**. A atualização foi testada localmente. Isso não significa implantação no projeto remoto nem teste de entrega de e-mails no serviço real. A publicação e aplicação no Supabase serão feitas depois da conferência.

As bibliotecas de QR Code, leitura de Excel e cliente Supabase estão incluídas localmente, com versões e licenças em vendor/.

Para executar os testes de desenvolvimento: Node 24 ou compatível, `npm install`, `npm test` e `npm run check`. A aplicação estática não precisa de Node para funcionar no GitHub Pages.

O arquivo **demonstracao.html** permite uma demonstração separada com dados fictícios. Ele não importa dados reais nem substitui o banco autenticado.

## Documentação técnica

- [Cadastro por e-mail no Supabase](https://supabase.com/docs/reference/javascript/auth-signup)
- [Funções e permissões no Supabase](https://supabase.com/docs/guides/database/functions)
