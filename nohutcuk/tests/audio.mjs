// Unit smoke tests for the Nohutçuk Web Audio synthesizer (no actual speakers).
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';

let notes=0;
class AudioParam {
  setValueAtTime(value){this.value=value;}
  exponentialRampToValueAtTime(value){this.value=value;}
  setTargetAtTime(value){this.value=value;}
}
class AudioNode {connect(){}}
class GainNode extends AudioNode {constructor(){super();this.gain=new AudioParam();}}
class Oscillator extends AudioNode {
  constructor(){super();this.frequency=new AudioParam();this.type='sine';}
  start(){notes++;}
  stop(){}
}
class FakeAudioContext {
  constructor(){this.currentTime=0;this.state='running';this.destination={};}
  createGain(){return new GainNode();}
  createOscillator(){return new Oscillator();}
}
const window={AudioContext:FakeAudioContext};
const context={window,Math,Number,Object,Boolean,Map,console,setTimeout:()=>42,clearTimeout:()=>{}};
vm.runInNewContext(readFileSync(new URL('../audio.js',import.meta.url),'utf8'),context,{timeout:1500,filename:'audio.js'});
const a=window.NohutcukAudio;
assert.ok(a,'sound engine should be exported');
assert.equal(a.available(),true);
assert.equal(a.playEffect('happy'),false,'automatic effects should require opt-in');
assert.equal(a.playEffect('happy',true),true,'manual preview sound should play on click');
assert.ok(notes>=3,'effect synthesizes actual notes');
a.setEffectsEnabled(true);
assert.equal(a.playEffect('love'),true);
let lastSong='unset';a.onSongChange(name=>{lastSong=name;});
for(const key of ['theme','dance','lullaby','hello']){
  const before=notes;
  assert.equal(a.playSong(key),true,key+' should start');
  assert.equal(a.getPlaying(),key);
  assert.equal(lastSong,key);
  assert.ok(notes-before>5,key+' should synthesize a melody');
  a.stopSong();
  assert.equal(a.getPlaying(),null);
}
a.setVolume(.3);
a.setMuted(true);
assert.equal(a.playSong('theme'),false,'quiet mode stops music');
assert.equal(a.playEffect('happy',true),false,'quiet mode silences manual sounds');
a.setMuted(false);
assert.equal(a.playSong('hello'),true);
a.stopSong();
console.log('Sound engine tests passed: 4 original songs, synthesizer, effect opt-in, manual previews, volume and quiet mode.');
