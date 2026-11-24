import {build} from 'esbuild';import fs from 'node:fs/promises';import path from 'node:path';
await fs.mkdir('vendor/licenses',{recursive:true});
const qr=await build({entryPoints:['node_modules/qrcode/lib/browser.js'],bundle:true,minify:true,format:'iife',globalName:'QRCode',platform:'browser',target:'es2020',outfile:'vendor/qrcode.min.js',legalComments:'eof',metafile:true});
const sdk=await build({stdin:{contents:'export {createClient} from "@supabase/supabase-js";',resolveDir:process.cwd(),loader:'js'},bundle:true,minify:true,format:'esm',platform:'browser',target:'es2020',outfile:'vendor/supabase.js',legalComments:'eof',metafile:true});
await fs.copyFile('node_modules/xlsx/dist/xlsx.full.min.js','vendor/xlsx.full.min.js');
const names=new Set(['xlsx']);for(const file of [...Object.keys(qr.metafile.inputs),...Object.keys(sdk.metafile.inputs)]){const parts=file.split('node_modules/').at(-1).split('/');names.add(parts[0].startsWith('@')?parts.slice(0,2).join('/'):parts[0]);}
const versions=[];
for(const name of [...names].sort()){
 const dir=path.join('node_modules',name);let pkg;try{pkg=JSON.parse(await fs.readFile(path.join(dir,'package.json'),'utf8'));}catch{continue;}
 const file=(await fs.readdir(dir)).find(file=>/^licen[cs]e(?:\.[a-z]+)?$/i.test(file));const info=`${pkg.name} ${pkg.version}\nLicença: ${typeof pkg.license==='string'?pkg.license:JSON.stringify(pkg.license)}\n`;
 await fs.writeFile(path.join('vendor/licenses',name.replaceAll('/','_')+'.txt'),info+'\n'+(file?await fs.readFile(path.join(dir,file),'utf8'):''));versions.push(`- ${pkg.name} ${pkg.version} (${typeof pkg.license==='string'?pkg.license:'ver arquivo de licença'})`);
}
await fs.writeFile('vendor/README.md','# Bibliotecas locais\n\nGeradas com `npm run build:vendor`. A interface utiliza cópias locais para QR Code, leitura de Excel e cliente Supabase. O serviço remoto de autenticação e dados continua sendo o Supabase configurado.\n\n'+versions.join('\n')+'\n');
