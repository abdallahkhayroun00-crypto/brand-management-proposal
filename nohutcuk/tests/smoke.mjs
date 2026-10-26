// Browser-free smoke test for Nohutçuk's event wiring and SVG face renderer.
// This is NOT a visual, hardware, motion-safety or touchscreen test.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

class FakeElement {
  constructor(id='', tag='div', doc=null) {
    this.id=id;this.tagName=tag;this.doc=doc;this.children=[];this.listeners={};
    this.dataset={};this.style={setProperty:()=>{}};this.className='';this.value='';
    this.checked=false;this.innerHTML='';this.textContent='';this.hidden=false;
    this.paused=true;this.volume=1;this.currentTime=0;
    this.classList={add:()=>{},remove:()=>{},toggle:()=>{}};
    if(doc)doc.elements.push(this);
  }
  append(...items){items.forEach(item=>{item.parent=this;this.children.push(item);});}
  appendChild(item){this.append(item);}
  prepend(item){item.parent=this;this.children.unshift(item);}
  replaceChildren(){this.children=[];}
  remove(){if(this.parent)this.parent.children=this.parent.children.filter(x=>x!==this);}
  before(){}
  pause(){this.paused=true;}
  get lastChild(){return this.children[this.children.length-1];}
  addEventListener(name,callback){(this.listeners[name]??=[]).push(callback);}
  emit(name){(this.listeners[name]||[]).forEach(fn=>fn({type:name,target:this}));}
  setAttribute(name,value){this[name]=value;}
  getBoundingClientRect(){return {left:0,top:0,width:320,height:160};}
}
class FakeDocument {
  constructor(){this.elements=[];this.byId={};this.documentElement=new FakeElement('', 'html',this);}
  getElementById(id){
    if(!this.byId[id])this.byId[id]=new FakeElement(id,'div',this);
    return this.byId[id];
  }
  createElement(tag){return new FakeElement('',tag,this);}
  querySelectorAll(query){
    if(query==='.emotion-btn')return this.elements.filter(e=>e.className.includes('emotion-btn'));
    if(query==='[data-tab]')return this.elements.filter(e=>e.dataset.tab);
    if(query==='.tab-panel')return this.elements.filter(e=>e.className==='tab-panel');
    if(query==='[data-action]')return this.elements.filter(e=>e.dataset.action);
    if(query==='[data-song]')return this.elements.filter(e=>e.dataset.song);
    if(query==='[data-voice]')return this.elements.filter(e=>e.dataset.voice);
    return [];
  }
}
const document=new FakeDocument();
for(const id of ['paletteSelect','customColor','languageSelect','durationRange','blinkRange','speedRange','volumeRange']){
  const el=document.getElementById(id);
  el.value=({paletteSelect:'expressive',customColor:'#a7edff',languageSelect:'tr-TR',durationRange:'3.5',blinkRange:'3',speedRange:'1',volumeRange:'50'})[id];
}
document.getElementById('autoBlink').checked=true;
document.getElementById('voiceEnabled').checked=true;
const source=readFileSync(new URL('../app.js',import.meta.url),'utf8');
const playLog=[];
const fakeAudio={songNames:{theme:'Nohutçuk Theme',dance:'Tiny Dance',lullaby:'Sleepy Stars',hello:'Happy Hello'},
  onSongChange(fn){this.callback=fn;},playSong(id){playLog.push('song:'+id);if(this.callback)this.callback(id);return true;},
  stopSong(){playLog.push('stop');if(this.callback)this.callback(null);},
  playEffect(id,force){playLog.push('effect:'+id+':'+Boolean(force));return true;},
  setVolume(level){playLog.push('volume:'+level);},setMuted(v){playLog.push('mute:'+v);},setEffectsEnabled(v){playLog.push('enabled:'+v);}};
for(const id of ['theme','dance','lullaby','hello']){
  const el=document.createElement('button');el.dataset.song=id;
}
const spoken=[];
const fakeVoice={
  onChange(fn){this.callback=fn;},speak(key){spoken.push('auto:'+key);return true;},
  preview(key){spoken.push('preview:'+key);if(this.callback)this.callback({status:'speaking',key,text:key});return true;},
  getPhrase(key){return key;},stop(){spoken.push('stop');},
  setOptions(options){this.options=options;},getVoices(){return [{name:'Türkçe test',lang:'tr-TR',voiceURI:'test-tr'}];},
  clipLoaded(){return false;},setClip(){return true;}
};
for(const key of ['welcome','thanks','love','goodbye','falafel','birthday']){
  const el=document.createElement('button');el.dataset.voice=key;
}
const browser={NohutcukAudio:fakeAudio,NohutcukVoice:fakeVoice,addEventListener(){}};
const context={document,window:browser,console,Date,Math,Number,String,Object,Set,
  clearTimeout(){},setTimeout(){return 1;},requestAnimationFrame(){return 1;}};
vm.runInNewContext(readFileSync(new URL('../day.js',import.meta.url),'utf8'),context,{filename:'day.js',timeout:2000});
vm.runInNewContext(source,context,{filename:'app.js',timeout:1500});
assert.equal(Number(document.getElementById('dayCaseTotal').textContent),browser.NohutcukDay.scenarios.length,'shop-day panel count');
assert.equal(Number(document.getElementById('dayPassed').textContent),browser.NohutcukDay.scenarios.length,'scenario model passes');
document.getElementById('runDayTests').emit('click');
assert.ok(document.getElementById('dayCaseList').children.length>0,'phase case listing populated');

const byId=id=>document.getElementById(id);
const moods=byId('emotionGrid').children;
assert.equal(moods.length,20,'all 20 face buttons should exist');
const face=byId('faceContent');
const moodNames=new Set();
const rendered=new Set();
for(const button of moods){
  button.emit('click');
  assert.ok(face.innerHTML.includes('<g'),'SVG markup should update');
  assert.ok(byId('currentMood').textContent,'current mood should be described');
  moodNames.add(button.dataset.mood);
  rendered.add(face.innerHTML);
}
assert.equal(moodNames.size,20,'20 distinct mood IDs');
assert.ok(rendered.size>=18,'most expressions should have distinct SVG shapes');

for(const id of ['interactionGrid','specialGrid']){
  const controls=byId(id).children;
  assert.ok(controls.length>=7,id+' should have control buttons');
  for(const button of controls)button.emit('click');
}
// Photo holds for 10 seconds even if an accidental guest tap happens.
byId('specialGrid').children[0].emit('click');
byId('screen').emit('click');
assert.match(byId('eventLog').children[0].children[1].textContent,/Sensor ignored/,
  'touch during photo pose must be suppressed by the main simulator');
byId('resetBtn').emit('click');
byId('playDay').emit('click');
assert.equal(byId('playDay').disabled,true,'accelerated day playback starts');
byId('stopDay').emit('click');
assert.equal(byId('playDay').disabled,false,'day playback can stop immediately');
assert.equal(byId('sfxGrid').children.length,10,'10 sound effect preview buttons');
byId('sfxGrid').children[0].emit('click');
assert.ok(playLog.includes('effect:happy:true'),'SFX soundboard should play on demand');
const firstSong=document.elements.find(e=>e.dataset.song==='theme');
firstSong.emit('click');
assert.ok(playLog.includes('song:theme'),'song button should request theme playback');
byId('stopMusic').emit('click');
assert.ok(playLog.includes('stop'),'stop music button should stop playback');
byId('effectsEnabled').checked=true;byId('effectsEnabled').emit('change');
assert.ok(playLog.includes('enabled:true'),'auto effect switch should enable effects');
byId('volumeRange').value='35';byId('volumeRange').emit('input');
byId('voiceStyle').value='zipir';byId('voiceStyle').emit('change');
assert.equal(fakeVoice.options.style,'zipir','character voice style is forwarded');
assert.ok(byId('voiceChoice').children.length>=2,'system voice dropdown is populated');
byId('voiceClipFor').value='welcome';
byId('clearVoiceClip').emit('click');
assert.ok(playLog.includes('volume:0.35'),'volume slider should update gain');
assert.equal(fakeVoice.options.volume,.35,'voice preview volume follows main volume');
assert.ok(spoken.includes('auto:welcome'),'welcome should have one short spoken cue');
assert.ok(spoken.includes('auto:love'),'third head touch can speak briefly');
assert.ok(!spoken.includes('auto:thanks'),'single pet should not speak automatically');
const manualVoice=document.elements.find(e=>e.dataset.voice==='thanks');
manualVoice.emit('click');
assert.ok(spoken.includes('preview:thanks'),'voice preview button should trigger its specific phrase');
byId('stopVoice').emit('click');
assert.ok(spoken.includes('stop'),'voice stop button should cancel speech');
const palette=byId('paletteSelect');
palette.value='rainbow';palette.emit('input');
assert.match(face.innerHTML,/url\(#rainbow\)/,'rainbow paint should reach SVG shapes');
palette.value='custom';palette.emit('input');
byId('customColor').value='#5dbbee';byId('customColor').emit('input');
assert.match(face.innerHTML,/#5dbbee/i,'custom color should reach SVG shape styling');
assert.ok(byId('eventLog').children.length>0,'actions should appear in event log');
assert.ok(source.includes('12000'),'welcome cooldown should be present');
assert.ok(!source.includes('restaurantGrid'),'restaurant/platform tab should be absent from mascot simulator');
console.log('Nohutçuk smoke tests passed: 20 moods, colors, songs, SFX, sparse speech triggers, manual voice, volume and interactions.');
