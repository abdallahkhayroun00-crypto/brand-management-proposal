// Full shop-day behavior acceptance tests — browser-independent, no hardware.
import assert from 'node:assert/strict';
import vm from 'node:vm';
import {readFileSync} from 'node:fs';
const window={};
vm.runInNewContext(readFileSync(new URL('../day.js',import.meta.url),'utf8'),{window,Date,Math,Number,Boolean,Map,Object,Set,console},{filename:'day.js',timeout:2000});
const day=window.NohutcukDay;
assert.ok(day,'shop day engine exported');
const cases=day.scenarios;
assert.ok(cases.length>=80,'at least 80 specific documented situations');
assert.equal(new Set(cases.map(x=>x.id)).size,cases.length,'IDs must be unique');
assert.equal(day.phases.length,8,'eight realistic daily phases');
const results=day.validate();
const failed=results.filter(x=>!x.passed);
assert.deepEqual(failed.map(x=>({id:x.id,name:x.name,expected:x.expected,actual:x.actual,reason:x.reason})),[],'scenario results must match expected');
function perform(s,action,at,options){return day.dispatch(s,action,at,options);}
const open=day.DAY_START,close=day.DAY_END;
let s=day.initial();
assert.equal(s.status,'closed');
let r=perform(s,'open',open);
assert.equal(r.state.status,'open');assert.equal(r.output.mood,'hello');
s=r.state;
r=perform(s,'approach',open+10);assert.equal(r.output.say,'welcome');
s=r.state;
r=perform(s,'approach',open+11);assert.equal(r.output.mode,'suppressed');assert.equal(r.output.reason,'welcome-30s-cooldown');
r=perform(s,'triple',open+16);
assert.equal(r.output.mode,'shown');assert.equal(r.output.say,null,'voice has 22 second global cooldown');
r=perform(s,'farewell',open+45);assert.equal(r.output.say,'goodbye');
const anotherWelcome=perform(s,'approach',open+45);
assert.equal(anotherWelcome.output.mode,'shown');assert.equal(anotherWelcome.output.say,null,'same phrase repeats after 60 seconds only');
const photo=perform(s,'photo',open+80);
assert.equal(photo.output.hold,10000);
assert.equal(perform(photo.state,'single',open+85).output.reason,'pose-in-progress');
const closed=perform(photo.state,'close',close);
assert.equal(closed.output.mode,'shown');
assert.equal(closed.output.mood,'sleeping');
assert.equal(closed.state.holdUntil,0,'closing cancels photo hold');
assert.equal(perform(closed.state,'approach',close+5).output.mode,'suppressed');
assert.equal(perform(closed.state,'dance',close+5).output.mode,'suppressed');
assert.equal(perform(s,'approach',close+30).output.reason,'after-hours','late welcome rejected even without a close event');
const muting=perform(s,'staffMute',open+90);
assert.equal(muting.state.staffMuted,true);
assert.equal(perform(muting.state,'triple',open+96).output.say,null);
assert.equal(perform(muting.state,'dance',open+96).output.mode,'suppressed');
const busy=perform(s,'crowdOn',open+110);
assert.equal(perform(busy.state,'approach',open+116).output.say,null);
assert.equal(perform(busy.state,'reels',open+119).output.mode,'suppressed');
const photoDuringCrowd=perform(busy.state,'photo',open+125);
assert.equal(photoDuringCrowd.output.say,null);
assert.equal(photoDuringCrowd.output.motion,null);
const fault=perform(s,'fault',open+180);
assert.equal(perform(fault.state,'single',open+185).output.reason,'safety-fault');
assert.equal(perform(fault.state,'clearFault',open+190).output.mode,'shown');
const offline=perform(s,'wifiOff',open+210);
assert.equal(perform(offline.state,'single',open+215).output.mode,'shown','local touch works without Wi-Fi');
const power=perform(s,'powerOff',open+230);
assert.equal(perform(power.state,'single',open+231).output.mode,'suppressed');
assert.equal(perform(power.state,'powerOn',open+235).output.mode,'shown');
const cleaning=perform(s,'clean',open+250);
assert.equal(perform(cleaning.state,'approach',open+260).output.reason,'cleaning-in-progress');
assert.equal(perform(s,'birthday',open+270,{untrusted:true}).output.mode,'suppressed');
assert.equal(perform(s,'birthday',open+270,{untrusted:false}).output.mode,'shown');
assert.equal(perform(s,'idle',open+280).output.reason,'not-idle-long-enough');
// Systematically permute 7 representative actions against safety/service modes.
let modeChecks=0;
for(const mode of ['closed','busy','cleaning','muted','offline','fault','powered-off']){
  let base=day.initial();
  if(mode!=='closed')base=perform(base,'open',open).state;
  if(mode==='busy')base=perform(base,'crowdOn',open+1).state;
  if(mode==='cleaning')base=perform(base,'clean',open+1).state;
  if(mode==='muted')base=perform(base,'staffMute',open+1).state;
  if(mode==='offline')base=perform(base,'wifiOff',open+1).state;
  if(mode==='fault')base=perform(base,'fault',open+1).state;
  if(mode==='powered-off')base=perform(base,'powerOff',open+1).state;
  for(const event of ['approach','single','double','triple','wave','dance','birthday','photo','foodReady']){
    const output=perform(base,event,open+20,{untrusted:false}).output;
    if(mode==='closed'||mode==='fault'||mode==='powered-off'||mode==='cleaning'){
      assert.equal(output.mode,'suppressed',mode+' must suppress '+event);
    }
    if(mode==='busy'||mode==='muted'){
      assert.equal(output.say,null,mode+' cannot speak in '+event);
      assert.equal(output.motion,null,mode+' cannot move in '+event);
    }
    if(mode==='offline')assert.equal(output.mode,'shown','local '+event+' should work without Wi-Fi');
    modeChecks++;
  }
}
// Deterministic randomized noise/stress: invalids, repeated sensors and shop lifecycle.
let seed=20261027;
function rand(){seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296;}
const actions=['approach','single','double','triple','long','walkPast','tapping','wave','farewell','photo',
  'selfie','instagram','reels','dance','birthday','foodReady','crowdOn','crowdOff','staffMute',
  'staffUnmute','idle','wifiOff','wifiOn','fault','clearFault','clean','unclean','unauthorized'];
let stress=0;
for(let round=0;round<50;round++){
  let state=day.initial();
  state=perform(state,'open',open).state;
  let t=open+4;
  for(let i=0;i<80;i++){
    t+=Math.round(1+rand()*25);
    if(t>=close)break;
    const action=actions[Math.floor(rand()*actions.length)];
    const {state:next,output}=perform(state,action,t,{untrusted:rand()<.18});
    assert.ok(output.mode==='shown'||output.mode==='suppressed');
    assert.ok(output.mood===null||typeof output.mood==='string');
    assert.ok(!(output.quiet&&(output.say||output.motion||output.sound)),'quiet means no speech/motion/sound');
    if(next.status!=='open'||!next.powered||next.fault){
      assert.ok(!output.say,'closed/unpowered/fault robot must not speak');
    }
    state=next;
    stress++;
  }
  const stopped=perform(state,'close',close).state;
  assert.equal(stopped.status,'closed');
  for(const action of actions.slice(0,16)){
    const out=perform(stopped,action,close+12).output;
    assert.equal(out.mode,'suppressed','closing suppresses '+action);
  }
}
console.log('Shop-day tests PASS: '+cases.length+' named cases + '+modeChecks+
  ' safety matrix checks + '+stress+' deterministic stress events across all opening-to-closing phases.');
