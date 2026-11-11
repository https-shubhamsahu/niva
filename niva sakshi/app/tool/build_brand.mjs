// Original editable vector identity. Raster exports use the same SVG geometry.
// Run with Node and sharp available through SAKSHI_NODE_MODULES or local modules.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
let sharp;
try { sharp = require('sharp'); }
catch { sharp = require(path.join(process.env.SAKSHI_NODE_MODULES, 'sharp')); }
const app = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const kit = path.resolve(app, '../docs/brand');
const colours = {
  light: ['#0066CC', '#F47758', '#173B59'],
  dark: ['#A9D4FF', '#FF9577', '#EAF3FF'],
  mono: ['#173B59', '#173B59', '#173B59'],
  white: ['#FFFFFF', '#FFFFFF', '#FFFFFF'],
};
const eye = 'M16 56 C40 22 88 22 112 56 C88 90 40 90 16 56 Z';
function mark(mode='light') {
  const [stroke, pupil, beam] = colours[mode];
  return `<path d="${eye}" fill="none" stroke="${stroke}" stroke-width="12" stroke-linejoin="round"/><circle cx="64" cy="56" r="12" fill="${pupil}"/><path d="M36 106 H92" stroke="${beam}" stroke-width="12" stroke-linecap="round"/>`;
}
function svg(w,h,body) { return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`; }
async function save(name, source, size) {
  await fs.writeFile(path.join(kit, name+'.svg'), source);
  await sharp(Buffer.from(source)).resize(size?.[0],size?.[1]).png().toFile(path.join(kit,name+'.png'));
}
await fs.mkdir(kit,{recursive:true});
await fs.mkdir(path.join(app,'assets/brand'),{recursive:true});
await fs.mkdir(path.join(app,'assets/icon'),{recursive:true});
for (const mode of ['light','dark','mono','white']) {
  await save('mark-'+mode, svg(128,128,mark(mode)),[512,512]);
  const ink = mode === 'white' ? '#FFFFFF' : mode === 'dark' ? '#EAF3FF' : '#173B59';
  const label = mode === 'white' ? '#FFFFFF' : mode === 'mono' ? '#173B59' : mode === 'dark' ? '#A9D4FF' : '#0066CC';
  const type = `<text x="166" y="80" fill="${ink}" font-family="Segoe UI,Arial,sans-serif" font-weight="700" font-size="67" letter-spacing="-3">niva</text><text x="169" y="113" fill="${label}" font-family="Segoe UI,Arial,sans-serif" font-weight="600" font-size="18" letter-spacing="6">SAKSHI</text>`;
  await save('wordmark-'+mode,svg(390,144,`<g transform="translate(8,8)">${mark(mode)}</g>${type}`),[1170,432]);
}
const stacked = svg(320,340,`<g transform="translate(80,16) scale(1.25)">${mark()}</g><text x="160" y="246" text-anchor="middle" fill="#173B59" font-family="Segoe UI,Arial,sans-serif" font-size="75" font-weight="700" letter-spacing="-3">niva</text><text x="160" y="286" text-anchor="middle" fill="#0066CC" font-family="Segoe UI,Arial,sans-serif" font-size="20" font-weight="600" letter-spacing="7">SAKSHI</text>`);
await save('stacked-light',stacked,[640,680]);
await save('stacked-dark',stacked.replaceAll('#173B59','#EAF3FF').replaceAll('#0066CC','#A9D4FF').replaceAll('#F47758','#FF9577'),[640,680]);
const tile = mode => svg(1024,1024,`<rect width="1024" height="1024" fill="${mode==='light'?'#F4F8FC':'#102B46'}"/><g transform="translate(153.6,153.6) scale(5.6)">${mark(mode==='light'?'light':mode==='tinted'?'white':'dark')}</g>`);
for (const mode of ['light','dark','tinted']) {
  await save('app-icon-'+mode,tile(mode),[1024,1024]);
  await fs.copyFile(path.join(kit,'app-icon-'+mode+'.png'),path.join(app,'assets/icon','sakshi-'+mode+'.png'));
}
// A 58/108dp mark remains inside the Android adaptive icon's safe circle.
const foreground = svg(108,108,`<g transform="translate(25,25) scale(.453125)">${mark('dark')}</g>`);
await save('adaptive-foreground',foreground,[432,432]);
await fs.copyFile(path.join(kit,'adaptive-foreground.png'),path.join(app,'assets/icon','sakshi-foreground.png'));
for (const [density,scale] of [['mdpi',1],['hdpi',1.5],['xhdpi',2],['xxhdpi',3],['xxxhdpi',4]]) {
  const res = path.join(app,'android/app/src/main/res');
  await sharp(Buffer.from(tile('dark'))).resize(Math.round(48*scale)).png().toFile(path.join(res,'mipmap-'+density,'ic_launcher.png'));
  await sharp(Buffer.from(foreground)).resize(Math.round(108*scale)).png().toFile(path.join(res,'drawable-'+density,'ic_launcher_foreground.png'));
}
const vector = (mode,adaptive=false) => {
  const [stroke,pupil,beam] = colours[mode];
  const groupStart = adaptive ? '<group android:translateX="25" android:translateY="25" android:scaleX="0.453125" android:scaleY="0.453125">' : '';
  const extent = adaptive?108:128;
  // The launch mark shows at 144dp, the size the Flutter launch continues from.
  // Android 12+ uses the hand-written drawable-v31/sakshi_splash_animated.xml.
  const dp = adaptive?108:144;
  return `<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="${dp}dp" android:height="${dp}dp" android:viewportWidth="${extent}" android:viewportHeight="${extent}">${groupStart}<path android:pathData="${eye}" android:fillColor="@android:color/transparent" android:strokeColor="${stroke}" android:strokeWidth="12" android:strokeLineJoin="round"/><path android:pathData="M52,56 a12,12 0,1 0,24 0 a12,12 0,1 0,-24 0" android:fillColor="${pupil}"/><path android:pathData="M36,106 L92,106" android:strokeColor="${beam}" android:strokeWidth="12" android:strokeLineCap="round"/>${adaptive?'</group>':''}</vector>`;
};
const res=path.join(app,'android/app/src/main/res');
await fs.writeFile(path.join(res,'drawable/sakshi_launch_mark.xml'),vector('light'));
await fs.mkdir(path.join(res,'drawable-night'),{recursive:true});
await fs.writeFile(path.join(res,'drawable-night/sakshi_launch_mark.xml'),vector('dark'));
await fs.writeFile(path.join(res,'drawable/sakshi_monochrome.xml'),vector('white',true));
await fs.writeFile(path.join(res,'values/colors.xml'),'<resources><color name="ic_launcher_background">#102B46</color></resources>\n');
const ios = path.join(app,'ios/Runner/Assets.xcassets/AppIcon.appiconset');
const catalog = JSON.parse(await fs.readFile(path.join(ios,'Contents.json'),'utf8'));
for (const item of catalog.images) {
  if (!item.filename || item.appearances) continue;
  const px = Math.round(Number(item.size.split('x')[0])*Number((item.scale??'1x').replace('x','')));
  await sharp(Buffer.from(tile('light'))).resize(px).removeAlpha().png().toFile(path.join(ios,item.filename));
}
for (const mode of ['dark','tinted']) {
  const filename='Icon-App-'+mode+'-1024.png';
  await sharp(Buffer.from(tile(mode))).removeAlpha().png().toFile(path.join(ios,filename));
  if (!catalog.images.some(x=>x.filename===filename)) catalog.images.push({idiom:'universal',platform:'ios',size:'1024x1024',filename,appearances:[{appearance:'luminosity',value:mode}]});
}
await fs.writeFile(path.join(ios,'Contents.json'),JSON.stringify(catalog,null,2)+'\n');
const launch = path.join(app,'ios/Runner/Assets.xcassets/LaunchImage.imageset');
const launchCatalog = {images:[],info:{version:1,author:'xcode'}};
for (const scale of [1,2,3]) {
  for (const mode of ['light','dark']) {
    const filename = `Sakshi-${mode}@${scale}x.png`;
    await sharp(Buffer.from(svg(128,128,mark(mode)))).resize(128*scale).png().toFile(path.join(launch,filename));
    launchCatalog.images.push({idiom:'universal',filename,scale:scale+'x',
      ...(mode==='dark'?{appearances:[{appearance:'luminosity',value:'dark'}]}:{})});
  }
}
await fs.writeFile(path.join(launch,'Contents.json'),JSON.stringify(launchCatalog,null,2)+'\n');
// Windows ICO contains actual PNG images at multiple launcher sizes.
const iconSizes = [16,24,32,48,64,128,256];
const pngs = await Promise.all(iconSizes.map(px=>sharp(Buffer.from(tile('dark'))).resize(px).png().toBuffer()));
const icoHeader = Buffer.alloc(6 + iconSizes.length*16);
icoHeader.writeUInt16LE(1,2); icoHeader.writeUInt16LE(iconSizes.length,4);
let offset=icoHeader.length;
pngs.forEach((png,i)=>{
  const pos=6+i*16,px=iconSizes[i];
  icoHeader[pos]=px===256?0:px; icoHeader[pos+1]=px===256?0:px;
  icoHeader.writeUInt16LE(1,pos+4); icoHeader.writeUInt16LE(32,pos+6);
  icoHeader.writeUInt32LE(png.length,pos+8); icoHeader.writeUInt32LE(offset,pos+12);
  offset+=png.length;
});
const ico=Buffer.concat([icoHeader,...pngs]);
await fs.writeFile(path.join(kit,'app-icon-windows.ico'),ico);
await fs.writeFile(path.join(app,'windows/runner/resources/app_icon.ico'),ico);
await fs.copyFile(path.join(kit,'wordmark-light.png'),path.join(app,'assets/brand/sakshi-wordmark-light.png'));
await fs.copyFile(path.join(kit,'wordmark-dark.png'),path.join(app,'assets/brand/sakshi-wordmark-dark.png'));
for (const px of [16,32,48]) await sharp(Buffer.from(svg(128,128,mark()))).resize(px).png().toFile(path.join(kit,'favicon-'+px+'.png'));
await fs.copyFile(path.join(kit,'favicon-32.png'),path.join(app,'web/favicon.png'));
await fs.writeFile(path.join(app,'web/favicon.svg'),svg(128,128,`<style>@media(prefers-color-scheme:dark){.eye{stroke:#A9D4FF}.beam{stroke:#EAF3FF}}</style><path class="eye" d="${eye}" fill="none" stroke="#0066CC" stroke-width="12" stroke-linejoin="round"/><circle cx="64" cy="56" r="12" fill="#F47758"/><path class="beam" d="M36 106H92" stroke="#173B59" stroke-width="12" stroke-linecap="round"/>`));
for (const size of [192,512]) {
  await sharp(Buffer.from(tile('light'))).resize(size).png().toFile(path.join(app,`web/icons/Icon-${size}.png`));
  await sharp(Buffer.from(svg(1024,1024,`<rect width="1024" height="1024" fill="#102B46"/><g transform="translate(256,256) scale(4)">${mark('dark')}</g>`))).resize(size).png().toFile(path.join(app,`web/icons/Icon-maskable-${size}.png`));
}
let board='<rect width="1200" height="780" fill="#EEF3F8"/><text x="40" y="58" font-family="Segoe UI,Arial" font-size="31" font-weight="700" fill="#173B59">Niva Sakshi / Balance witnessed</text>';
const cells=[['Primary / light','light','wordmark'],['Primary / dark','dark','wordmark'],['App icon','dark','tile'],['Standalone mark','light','mark'],['Monochrome','mono','mark'],['Small sizes / favicon','light','small']];
cells.forEach(([label,mode,kind],i)=>{
  const x=40+(i%3)*380,y=92+Math.floor(i/3)*334,dark=mode==='dark';
  board+=`<g transform="translate(${x},${y})"><rect width="360" height="308" rx="24" fill="${dark?'#102B46':'#FFFFFF'}"/><text x="24" y="38" fill="${dark?'#A9D4FF':'#65798A'}" font-family="Segoe UI,Arial" font-size="17">${label}</text>`;
  if(kind==='wordmark') board+=`<g transform="translate(27,112) scale(.76)">${mark(mode)}<text x="166" y="76" font-family="Segoe UI,Arial" font-size="62" font-weight="700" fill="${dark?'#EAF3FF':'#173B59'}" letter-spacing="-3">niva</text><text x="169" y="110" font-family="Segoe UI,Arial" font-size="18" letter-spacing="6" fill="${dark?'#A9D4FF':'#0066CC'}">SAKSHI</text></g>`;
  else if(kind==='small') { for(const [j,s] of [16,32,64].entries()) board+=`<g transform="translate(${64+j*85},145) scale(${s/128})">${mark(mode)}</g>`; }
  else board+=`<g transform="translate(100,92) scale(1.25)">${mark(mode)}</g>`;
  board+='</g>';
});
await save('brand-board',svg(1200,780,board),[1200,780]);
console.log('Sakshi brand assets exported to '+kit);
