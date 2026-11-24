# Validação local 0.3.2

## Testes automatizados

44 testes Node/PostgreSQL passaram. Cobertura: participação independente da taxa e da construção; cotas fracionárias; denominadores por grupo; múltiplos lotes; vigência temporária e retorno; exclusão individual; distribuição exata em centavos; competências fechadas; salário incluído ou separado; medidores de bomba e caseiro; água proporcional; provisões; bloqueios por pendências e diferenças; convite único e expirado; ausência de elevação administrativa; isolamento de registros por RLS; bloqueio de acesso anônimo; importação administrativa, transacional e sem repetição.

## Instalação e dados reais

Instalador completo executado em PostgreSQL local novo e reaplicado. Importação privada real executada duas vezes sem repetir registros: 31 responsáveis, 35 lotes e 41 lançamentos solares. A origem conferida no cliente correspondeu à fotografia do banco. Um fechamento de teste com 31 faturas, após resolver as pendências somente na cópia de teste, conciliou R$ 5.609,94. O arquivo entregue conserva as pendências e a competência em rascunho.

## Interface

Navegador Chromium: configuração individual de lote vazio com meia cota, salvamento e persistência após recarregar, participantes do fechamento e navegação móvel. Sem erros JavaScript nos fluxos executados. QR Code de uma fatura fictícia decodificado e comparado com o Pix Copia e Cola e o saldo mostrado. Impressão isolada da fatura verificada em uma página, sem avisos sobrepostos. Datas de emissão exibidas no horário de Brasília. Telas revisadas visualmente em computador e celular.

Primeiro acesso: cadastro com solicitação de confirmação de e-mail, rejeição de convite inválido e vínculo ao portal de proprietário, com provedor simulado. O resgate de convite, uso único, expiração e RLS foram testados no PostgreSQL local.

## Verificação final no projeto real

A entrega de e-mails pelo Supabase real, os redirecionamentos publicados e uma conta real de condômino precisam ser verificados depois da atualização. Políticas adicionais que já existam no banco remoto e a configuração efetiva do provedor de e-mail não foram inspecionadas nesta preparação.

Não houve publicação nem alterações no Supabase remoto. Os dados reais permanecem em arquivos privados de importação e na base local isolada de conferência.


## Evidências adicionais 0.3.2

Dez relatórios abertos pela interface, dez downloads CSV e dez downloads Excel (.xlsx), sem erros JavaScript no fluxo executado. A biblioteca reabriu os arquivos Excel e confirmou números, filtro de cabeçalho e texto sem fórmulas executáveis. Planilha mensal soma rubricas e totais sem multiplicar dono de vários lotes. Cobrança a vencer, pagamentos parciais, créditos, datas de Brasília, extras e isolamento do extrato foram testados.

Demonstrativo verificado em computador e viewport móvel de 390 px, sem transbordamento horizontal da página; a tabela larga permite rolagem dentro do painel. Impressão com cabeçalho do mês e tabelas, guia PDF de duas páginas e entrada com foto foram revisados visualmente. Instalação física em Android/iPhone precisa do teste no ambiente real.

Atualização real entre dois identificadores de cache em servidor HTTPS local: aviso exibido, cancelamento manteve o campo não salvo, confirmação aplicou a nova versão e recuperou somente os dados já gravados. Teste de atualização externa não descarta formulário. URLs de API e JSON privado não são interceptadas pelo cache. Falha de download não ativa conjunto incompleto.

Instalador consolidado completo aplicado duas vezes em banco local, importação real repetida sem duplicar, 31 faturas locais totalizando R$ 5.609,94; relatório agregado SQL e cliente conciliados e sem nomes/IDs de responsáveis. As pendências só foram resolvidas na cópia de teste, não no arquivo real de importação.
