// Behavior tests for brief browser speech and its real cooldown policy.
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';

let time=1_000_000;
const heard=[];
let cancelled=0;
class FakeUtterance{
  constructor(text){this.text=text;this.lang='';this.volume=1;this.rate=1;this.pitch=1;}
}
const synth={
  speaking:false,pending:false,
  getVoices(){return [{lang:'tr-TR',name:'Türkçe test voice'},{lang:'en-US',name:'English voice'}];},
  speak(utterance){heard.push(utterance);},
  cancel(){cancelled++;}
};
const clipPlay=[];
class FakeAudio{constructor(url){this.url=url;this.volume=1;this.currentTime=0;}play(){clipPlay.push(this.url);return Promise.resolve();}pause(){}}
const browser={speechSynthesis:synth,SpeechSynthesisUtterance:FakeUtterance,Audio:FakeAudio,
  URL:{createObjectURL(){return 'blob:custom-voice';},revokeObjectURL(){}}};
class FakeDate extends Date{static now(){return time;}}
vm.runInNewContext(readFileSync(new URL('../voice.js',import.meta.url),'utf8'),{window:browser,Date:FakeDate,Math,Number,Boolean,Map,Object,console},{filename:'voice.js',timeout:1500});
const voice=browser.NohutcukVoice;
assert.ok(voice,'voice module must register');
assert.equal(voice.available(),true);
let status=null;
voice.onChange(event=>{status=event.status;});
voice.setOptions({enabled:true,quiet:false,language:'tr-TR',volume:.55});
assert.equal(voice.speak('welcome'),true);
assert.equal(heard.at(-1).text,'Hoş geldiiin!');
assert.equal(heard.at(-1).voice.lang,'tr-TR');
assert.equal(heard.at(-1).volume,.55);
assert.equal(voice.speak('love'),false,'no chattering right after a greeting');
assert.equal(status,'cooldown');
time+=23_000;
assert.equal(voice.speak('love'),true,'another selected cue can speak after global pause');
assert.equal(heard.at(-1).text,'Çok tatlısıın!');
time+=23_000;
assert.equal(voice.speak('welcome'),false,'same phrase must wait for per-cue cooldown');
assert.equal(voice.preview('welcome'),true,'manual test bypasses cooldown');
assert.ok(cancelled>0,'manual preview can replace currently playing sample');
assert.equal(voice.getPhrase('goodbye'),'Yine bekleriim!');
voice.setOptions({language:'en-US',volume:.25,style:'zipir'});
assert.equal(voice.styles.zipir.pitch,1.85);
assert.equal(voice.preview('photo'),true);
assert.equal(heard.at(-1).text,'Smiiile!');
assert.equal(heard.at(-1).lang,'en-US');
assert.equal(heard.at(-1).pitch,1.85);
assert.equal(heard.at(-1).rate,1.25);
voice.setOptions({quiet:true});
assert.equal(voice.speak('birthday'),false,'quiet mode must be silent');
assert.equal(voice.preview('birthday'),false,'quiet mode overrides manual samples');
voice.setOptions({quiet:false,enabled:false});
assert.equal(voice.speak('goodbye'),false,'disabled voice must stay silent');
voice.setOptions({enabled:true,language:'ar-MA'});
assert.equal(voice.preview('falafel'),true);
assert.equal(heard.at(-1).text,'بالصحة والراحة!');
assert.equal(heard.at(-1).lang,'ar-MA');
assert.equal(voice.speak('not-a-valid-key'),false,'only approved cues can speak');
voice.setOptions({language:'tr-TR',style:'minik'});
const candidates=voice.getVoices('tr-TR');
assert.equal(candidates.length,1,'matching installed voice should be shown');
voice.preview('welcome');
assert.equal(heard.at(-1).pitch,1.63,'default character style uses playful pitch');
assert.equal(heard.at(-1).rate,1.13,'default character style uses playful speed');
assert.equal(voice.setClip('welcome',{type:'audio/mpeg',name:'welcome.mp3'}),true);
assert.equal(voice.clipLoaded('welcome'),true);
assert.equal(voice.preview('welcome'),true);
assert.equal(clipPlay.length,1,'custom clip should play instead of system TTS');
assert.equal(voice.setClip('welcome',null),true);
assert.equal(voice.clipLoaded('welcome'),false);
console.log('Voice tests passed: cute profiles, same-language system voice choice, clip overrides, multilingual lines, 22s/60s cooldown and quiet mode.');
