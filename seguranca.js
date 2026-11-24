// A biometria e o PIN são tratados exclusivamente pelo autenticador do aparelho.
export function supportsPasskeys(env=globalThis){return !!(env.isSecureContext&&env.PublicKeyCredential&&env.navigator?.credentials);}
export function passkeyMessage(error){
 const code=String(error?.code||error?.error_code||error?.name||'');
 if(/passkey_disabled/.test(code))return 'O acesso por chave ainda precisa ser ativado na autenticação do condomínio. Entre com sua senha por enquanto.';
 if(/NotAllowed|CANCEL|ABORT|AbortError/i.test(code))return 'A confirmação no aparelho foi cancelada ou expirou. Você pode tentar novamente ou entrar com sua senha.';
 if(/email_not_confirmed/.test(code))return 'Confirme seu e-mail antes de cadastrar ou usar a chave de acesso.';
 if(/credential_exists/.test(code))return 'Esta chave já está cadastrada para a conta.';
 return 'Não foi possível usar a chave de acesso. Confira a conexão e o suporte do aparelho, ou entre com sua senha.';
}
export async function signInPasskey(client){
 const {data,error}=await client.auth.signInWithPasskey();
 if(error)throw Error(passkeyMessage(error));
 if(!data?.session||!data?.user)throw Error('A entrada não foi confirmada. Tente novamente ou entre com sua senha.');
 return data;
}
export async function registerPasskey(client){
 const {data,error}=await client.auth.registerPasskey();if(error)throw Error(passkeyMessage(error));
 if(!data?.id)throw Error('A chave não foi confirmada pelo servidor.');return data;
}
export async function listPasskeys(client){const {data,error}=await client.auth.passkey.list();if(error)throw Error(passkeyMessage(error));return data||[];}
export async function removePasskey(client,id){const {error}=await client.auth.passkey.delete({passkeyId:id});if(error)throw Error(passkeyMessage(error));}

