# Ativar chave de acesso — digital, Face ID ou PIN

A interface 0.3.5 implementa o cadastro e a entrada com chaves de acesso da própria conta. A autenticação é validada pelo Supabase, mantendo as mesmas permissões e vínculos. Não há reconhecimento facial feito pela câmera do aplicativo nem armazenamento de digital.

## Configuração no Supabase (uma vez)

No painel do projeto existente, abrir Authentication > Passkeys, se a opção estiver disponível, ativar a autenticação e informar:

- Nome: Pontal da Serra.
- RP ID: pontalserra.github.io (sem https e sem o caminho do repositório).
- Origem permitida: https://pontalserra.github.io (sem o caminho do repositório).

Salvar e conferir os valores. O mesmo domínio abriga os projetos GitHub Pages da conta. Se o condomínio adotar domínio próprio no futuro, planejar a migração e registrar novas chaves para esse domínio; chaves não podem ser transferidas livremente entre domínios.

O recurso do Supabase está classificado como experimental. Se a opção não existir no painel do projeto, manter o login por senha e informar o que aparece na tela para conferir a disponibilidade, sem alterar o banco manualmente.

## Uso por cada pessoa

Entrar com a própria conta já confirmada e vinculada. No rodapé, escolher Digital / Face ID > Ativar acesso com este aparelho. Confirmar no dispositivo. Após sair da conta, escolher Entrar com chave de acesso. O método (biometria, PIN ou chave externa) é definido pelo aparelho e pelo gerenciador de chaves.

Cada pessoa administra somente suas próprias chaves. A opção de remover uma chave não exclui a conta nem os dados. Manter acesso ao e-mail de recuperação. A sessão atual continua conectada; a chave é usada ao autenticar novamente, não como bloqueio obrigatório em cada abertura do app.

## Conferência no ambiente real

Testar cadastro da chave, logout, entrada, cancelamento, acesso ao lote correto e remoção em iPhone/Safari e Android/Chrome. O computador pode usar Windows Hello quando suportado. A entrega em arquivo não ativa o recurso no painel nem comprova funcionamento físico da biometria. Senha e recuperação por e-mail continuam funcionando como alternativas.

Fonte técnica: https://supabase.com/docs/guides/auth/passkeys
