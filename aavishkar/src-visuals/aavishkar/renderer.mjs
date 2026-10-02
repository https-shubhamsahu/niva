import fs from 'node:fs/promises';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
const ROOT = path.resolve(import.meta.dirname, '../..');
const TMP = path.join(ROOT,'data/visual-build');
const OUT = process.env.NIVA_OUTPUT_DIR ? path.resolve(process.env.NIVA_OUTPUT_DIR) : path.join(ROOT,'docs/aavishkar/current');
const DEP = 'C:/Users/shubh/.cache/codex-runtimes/codex-primary-runtime/dependencies';
process.env.RUNTIME_NODE_MODULES=DEP+'/node/node_modules';
const SKILL = 'C:/Users/shubh/.codex/plugins/cache/openai-primary-runtime/presentations/26.905.11957/skills/presentations';
const {Presentation,PresentationFile}=await import(pathToFileURL(DEP+'/node/node_modules/@oai/artifact-tool/dist/artifact_tool.mjs'));
const {Canvas,FontLibrary}=await import(pathToFileURL(DEP+'/node/node_modules/@oai/artifact-tool/node_modules/skia-canvas/lib/index.js'));
const {finalizePresentation,applyPresentationChartFont}=await import(pathToFileURL(SKILL+'/container_tools/artifact_tool_utils.mjs'));
const C={navy:'#14314B',teal:'#0B6F79',accent:'#08535B',ink:'#0F1B1E',mute:'#5A6C72',panel:'#EAF0F2',rule:'#CBD8DC',white:'#FFFFFF'};
const F={sans:'IBM Plex Sans',serif:'IBM Plex Serif',mono:'IBM Plex Mono'};
for(const [key,name] of Object.entries(F)) FontLibrary.use(name,[path.join(import.meta.dirname,`fonts/IBMPlex${key[0].toUpperCase()+key.slice(1)}-Regular.ttf`),path.join(import.meta.dirname,`fonts/IBMPlex${key[0].toUpperCase()+key.slice(1)}-Bold.ttf`)]);
const ctx=new Canvas(1,1).getContext('2d');
async function build(pages,label,scale=1){
 await fs.mkdir(TMP,{recursive:true});await fs.mkdir(OUT,{recursive:true});
 const tableOwners=pages.flatMap((p,i)=>p.objects.some(o=>o.kind==='table')?[i+1]:[]);
 const chartOwners=pages.flatMap((p,i)=>p.objects.some(o=>o.kind==='chart')?[i+1]:[]);
 const isPoster=pages.length===1 && pages[0].w===1600;
 const pres=Presentation.create({slideSize:{width:pages[0].w*scale,height:pages[0].h*scale}});
 for(let n=0;n<pages.length;n++){
 const p=pages[n],s=pres.slides.add();s.background.fill=C.white;
 for(let j=0;j<p.objects.length;j++){
  const o=p.objects[j],pos={left:o.x*scale,top:o.y*scale,width:o.w*scale,height:o.h*scale};
  if(o.kind==='vector'){
   const commands=o.loops.flatMap(loop=>[{moveTo:{x:loop[0][0],y:loop[0][1]}},...loop.slice(1).map(([x,y])=>({lineTo:{x,y}})),{close:{}}]);
   s.shapes.add({name:`logo-vector-${n+1}-${j}`,geometry:'custom',position:pos,fill:o.fill,line:{fill:'none',width:0},customPaths:[{width:o.vw,height:o.vh,commands}]});
  }else if(o.kind==='image'){
   s.images.add({blob:new Uint8Array(await fs.readFile(path.resolve(ROOT,o.path))),contentType:'image/png',alt:o.alt,fit:'contain',position:pos});
  }else if(o.kind==='chart'){
   const ch=s.charts.add('bar',{position:pos,categories:o.categories,series:o.series.map(v=>({...v,valuesFormatCode:'0.00'})),barOptions:{direction:'column',grouping:'clustered',gapWidth:100},hasLegend:true,legend:{position:'bottom',textStyle:{typeface:F.sans,fontSize:o.size*scale,fill:C.ink}},xAxis:{textStyle:{typeface:F.mono,fontSize:o.size*scale,fill:C.ink},majorGridlines:null,line:{fill:C.rule,width:scale}},yAxis:{min:0,max:15,majorUnit:5,numberFormatCode:'0',textStyle:{typeface:F.mono,fontSize:o.size*scale,fill:C.mute},majorGridlines:{fill:C.rule,width:scale},line:{fill:'none',width:0}},dataLabels:{showValue:false},chartFill:'none',plotAreaFill:'none'});applyPresentationChartFont(ch,{fontFamily:F.sans});
  }else if(o.kind==='table'){
   const t=s.tables.add({rows:o.rows.length,columns:o.rows[0].length,left:pos.left,top:pos.top,width:pos.width,height:pos.height,columnWidths:o.widths.map(v=>v*pos.width),values:o.rows});
   for(let r=0;r<o.rows.length;r++){t.rows[r].height=o.rowh*scale;for(let c=0;c<o.rows[r].length;c++){const cell=t.getCell(r,c);cell.fill=r===0?C.navy:(r%2?C.panel:C.white);cell.text.style={typeface:c===0?F.sans:F.mono,fontSize:o.size*scale,color:r===0?C.white:C.ink,bold:r===0};}}
   t.borders.assign({style:'solid',fill:C.white,width:scale});
  }else if(o.kind==='line'){
   const ww=Math.max(.01,Math.abs(o.w)*scale),hh=Math.max(.01,Math.abs(o.h)*scale);
   s.shapes.add({geometry:'custom',name:`line-${n+1}-${j}`,position:{left:Math.min(o.x,o.x+o.w)*scale,top:Math.min(o.y,o.y+o.h)*scale,width:ww,height:hh},fill:'none',line:{fill:o.stroke,width:o.sw*scale},customPaths:[{width:ww,height:hh,commands:[{moveTo:{x:o.w<0?ww:0,y:o.h<0?hh:0}},{lineTo:{x:o.w<0?0:ww,y:o.h<0?0:hh}}]}]});
  }else{
   const sh=s.shapes.add({name:`${o.kind}-${n+1}-${j}`,geometry:o.kind==='text'?'textbox':o.kind,position:pos,fill:o.kind==='text'?'none':o.fill,line:{fill:o.stroke??'none',width:(o.sw??0)*scale}});
   if(o.kind==='text'){sh.text=o.text;sh.text.style={typeface:o.font,fontSize:o.size*scale,color:o.color,bold:o.bold,autoFit:'none',wrap:'none',verticalAlignment:'top',insets:{top:0,right:0,bottom:0,left:0}};}
  }
 }
 s.speakerNotes.textFrame.setText(p.notes.join('\n'));
 }
 const candidate=path.join(TMP,label+'.candidate.pptx');await(await PresentationFile.exportPptx(pres)).save(candidate);
 console.log('Exported '+candidate);
 for(let i=0;i<pres.slides.items.length;i++){const blob=await pres.export({slide:pres.slides.items[i],format:'png',scale:isPoster?0.45:1});await fs.writeFile(path.join(TMP,`${label}-${i+1}.png`),new Uint8Array(await blob.arrayBuffer()));}
 const dest=path.join(OUT,label+'.pptx');
 await finalizePresentation({explicitTotalSlideCount:pages.length,requiredNativeChartOwnerSlides:chartOwners,requiredNativeTableOwnerSlides:tableOwners,materializeLiteralChartWorkbooks:true,workspaceDir:ROOT,candidatePath:candidate,finalPath:dest,pythonExecutable:DEP+'/python/python.exe',integrityValidatorPath:SKILL+'/container_tools/inspect_presentation_package_integrity.py',layoutValidatorPath:SKILL+'/container_tools/inspect_presentation_layout_geometry.py',layoutArgs:['--expected-slide-size-emu',`${Math.round(pages[0].w*scale*9525)},${Math.round(pages[0].h*scale*9525)}`,'--validate-heading-fit',...tableOwners.flatMap(n=>['--require-native-table-slide',String(n)])],fontPolicy:{basis:'user_request',families:Object.values(F)},verifyArtifactToolImport:true,receiptPath:path.join(TMP,label+'.validation.json')});
 console.log('Finalized '+dest);
}
export {ROOT,TMP,OUT,build};

