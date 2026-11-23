import fs from 'node:fs/promises';
import {build} from './renderer.mjs';
const scene=JSON.parse(await fs.readFile(new URL('./current.scene.json',import.meta.url)));
if(scene.deck.length!==13||scene.poster.w!==1600||scene.poster.h!==1600)throw new Error('Unexpected current artifact geometry');
if(process.argv.includes('--check')){
 console.log('Current source loads: 13 slides and one square poster.');
}else{
 await build(scene.deck,'Niva_Presentation');
 await build([scene.poster],'Niva_Poster_1m',(1000/25.4*96)/1600);
}
