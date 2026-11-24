import fs from 'node:fs/promises';
let schema=await fs.readFile('supabase/schema.sql','utf8');
schema=schema.replace(/(create policy (\w+) on ([\w.]+))/gi,(_,full,name,table)=>`DROP POLICY IF EXISTS ${name} ON ${table};\n${full}`);
const parts=[schema];for(const file of ['migracao_v0_2.sql','migracao_v0_3_1.sql','importacao_privada.sql','migracao_v0_3_2.sql'])parts.push(await fs.readFile('supabase/'+file,'utf8'));
await fs.writeFile('supabase/INSTALAR_OU_ATUALIZAR.sql','-- Pontal da Serra 0.3.2: atualização completa sem dados reais.\n-- Uma transação, reaplicável no projeto existente.\nBEGIN;\n'+parts.map(part=>part.replace(/^(?:BEGIN|COMMIT);[ \t]*$/gm,'')).join('\n\n')+'\nCOMMIT;\n');
