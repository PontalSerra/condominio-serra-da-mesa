# Verificações 0.3.6 — locais

63 testes Node/PGlite aprovados. Incluem RLS das notas, conclusão com versão/motivo, publicação administrativa de prévias, origem alterada, isolamento entre famílias e coproprietário autorizado, proibição de escrita pelo morador, invalidação de prévia, ausência de fatura gerada e exclusão exata do teste com vínculos bloqueados e auditoria. Testes financeiros anteriores preservados.

Interface automatizada: explicação provisória acessada por login de condômino simulado, oito seções, leituras próprias e tela de 390 px sem transbordamento; regressão de 50 cliques de navegação em cinco tamanhos e dez relatórios com Excel. botão no perfil administrativo, criar/editar/copiar estrutura de nota, persistência após recarregar, status e validação, botão oculto ao condômino, layout móvel. Fluxo de explicação usa provedor de autenticação simulado; segurança efetiva também testada no PostgreSQL local. Não houve operação de escrita no Supabase ou GitHub remoto. Não foram testados aparelhos físicos nem ativadas integrações externas.

# Validação local 0.3.5 — 24/11/2026

## Testes automatizados

58 testes Node/PostgreSQL passaram. Cobertura financeira anterior preservada: tarifas, bomba incluída ou externa ao geral, caseiro integralmente rateado, água proporcional, provisão 7/36, participação/cotas, regras por vigência e arredondamento em centavos. Testes de faturas, relatórios, Excel, convites e RLS mantidos.

Novos testes: simulação sem alteração de dados; reabertura administrativa com motivo, arquivo integral das faturas, retirada do saldo ativo e novo fechamento; bloqueios por pagamentos, competência posterior, baixa de reserva e envio registrado; proteção contra variável de sessão forjada e contra reutilização de IDs arquivados. Documentos gerais, mensais e do solar publicados somente para membros; rascunhos e arquivos sem publicação visível não são expostos. Usuários comuns não publicam documentos nem alteram permissões.

Passkeys: suporte do navegador, confirmação de sessão pelo servidor, cadastro, remoção, cancelamento e mensagens de recurso desabilitado. Esses testes usam chamadas simuladas; não representam homologação da biometria física.

## Instalação e dados

Instalador completo aplicado e reaplicado em PostgreSQL local. Importação privada repetida sem duplicação. Correção solar aplicada duas vezes: mesmo valor final e um único ajuste identificado na auditoria. Fechamento de cópia local com 31 responsáveis conciliou o cálculo e o demonstrativo agregado do servidor; a reabertura arquivou as 31 faturas e retirou-as do razão ativo. Nenhuma dessas operações foi executada no projeto real nesta preparação. As pendências só foram resolvidas na cópia local para testar o ciclo.

## Interface e relatórios

Chromium: dez menus administrativos em 1280×900, 1366×768, 1024×600, 1024×480 e 800×360. Sem sobreposição do rodapé, incluindo Relatórios/Configurações. Texto ampliado e navegação móvel 390×844. Dez relatórios abertos e dez exportações Excel. Sem erros JavaScript nesses fluxos.

Simular, conferir faturas, fechar, reabrir com motivo e ciência e fechar novamente: faturas não duplicadas, novos identificadores e histórico preservado. Documentos publicados e rascunhos persistiram após recarregar; a visão do condômino ocultou rascunhos e mostrou documentos mensais/solares.

Fluxo conectado com provedor simulado: criar/remover chave e entrar novamente; enviar PDF mensal e do investimento no bucket privado; abrir link temporário de 90 segundos. Não houve upload real de documentos pessoais nesses testes.

Atualização real de cache de 0.3.2 diretamente para 0.3.5 em HTTPS local: aviso, aplicação e preservação dos dados fictícios salvos; menu Relatórios acessível após atualizar.

Guia do morador gerado da fonte HTML distribuída e revisado visualmente em três páginas, sem cortes ou sobreposição.

## Conferência depois da implantação

Aplicar o SQL cumulativo e a correção privada; atualizar a interface; conferir 0.3.5. Testar conta real não administrativa, acesso do síndico, entrega de e-mails, confirmação/recuperação de senha e upload/download efetivo dos documentos. Ativar passkeys no Supabase e testar iPhone/Safari e Android/Chrome antes de divulgar a função como pronta para todos.

Fontes ambientais são acessadas por links externos oficiais, sem dados de clima, lua ou pesca inventados. Documentos do estatuto, atas, contas e fotos precisam ser anexados pelo síndico.
