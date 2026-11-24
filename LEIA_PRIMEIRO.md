# Pontal da Serra Web 0.3.6 — 24/11/2026

Correção da versão 0.3.5. Implementada e testada localmente; ainda não aplicada ao site ou ao banco remoto.

## Correções desta entrega

- **Anotar melhoria** no topo e no rodapé do perfil administrativo. Anotações privadas por conta, com problema, sugestão, situação, motivo da solução e versão. Salvas no banco; persistem ao trocar de aparelho. Copiar o texto permite encaminhá-lo para manutenção. Registrar não envia nem implementa automaticamente. Só marcar concluída após conferir a alteração, informando versão e resultado; inviável exige motivo.
- **Explicação detalhada do mês:** conta geral e tarifa, bomba, água e conversão, caseiro, salário, provisões, participantes e cotas dos rateios, despesas extraordinárias, total coletivo e parcela própria. Inclui as leituras individuais e a memória do consumo. Não divulga nomes, leituras, pagamentos ou saldos individuais de outras famílias.
- **Prévia antes do fechamento:** em Fechamento, salvar os dados e clicar em **Disponibilizar explicação provisória**. Condôminos consultam em **Explicação do mês**. Não gera faturas e não autoriza pagamento. Pendências permanecem e são sinalizadas. Qualquer alteração nas fontes de cálculo retira as prévias de circulação; é necessário publicar novamente. Após fechar, vale a explicação preservada com a fatura. Documentos publicados continuam disponíveis separadamente.
- **Teste de Homologação:** a migração tenta excluir somente o UUID fictício conhecido e o lote TESTE-01, se inativos, sem saldo, conta vinculada ou dependências. O identificador e o nome precisam conferir exatamente. Se houver vínculo, nada é apagado e aparece o botão **Excluir teste de homologação** em Cadastros para conferir o resultado. Nenhuma conta de autenticação é excluída. Exclusão administrativa auditada; cadastros reais permanecem.

## Instalar, uma etapa de cada vez

1. No SQL Editor do mesmo Supabase, executar **02_ATUALIZAR_BANCO.sql** (somente a migração desta versão, para quem já instalou 0.3.5). A estrutura é reaplicável. O comando contém exclusão controlada do cadastro fictício pedido pelo responsável.
2. No GitHub, enviar o conteúdo de **01_SITE_PUBLICAR**, preservando as pastas, e confirmar o commit. Esperar o GitHub Pages ficar verde.
3. Abrir o aplicativo, aplicar a atualização e conferir **0.3.6**. Não reimportar dados reais nem reaplicar a correção solar que já foi concluída.
4. Conferir o botão **Anotar melhoria**. Em Cadastros, verificar a ausência do teste; se ainda existir, o botão de exclusão informa o vínculo que impediu a remoção. Em Fechamento, disponibilizar a explicação provisória quando desejar mostrá-la aos moradores.

O instalador cumulativo continua em `01_SITE_PUBLICAR/supabase/INSTALAR_OU_ATUALIZAR.sql` para instalações anteriores. Quem já está em 0.3.5 pode usar o arquivo incremental acima. Esta entrega não fecha o mês, não altera leituras, não regulariza pendências nem emite cobranças.

## Pendências que não são apresentadas como concluídas

- Chaves de acesso/Face ID: dependem da ativação no Supabase e de teste físico nos aparelhos.
- Piracema, fases da Lua, clima e reservatório: são consultas por links externos; ainda não há atualização automática dentro do app.
- WhatsApp automático e lembrete do dia 9: dependem de integração/configuração; não foram ativados.
- Conciliação bancária, abertura automática do banco, solicitações com acompanhamento e lembretes de agenda: não implementados.
- Valores de novembro continuam provisórios enquanto faltarem conferências de leituras, unidade da água, salário, participantes e saldos.

A configuração pública existente foi preservada. A entrega não contém dados reais, senhas nem pacote privado de importação.
