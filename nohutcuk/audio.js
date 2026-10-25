/* Nohutçuk Sound Engine — original synthesized music and sound effects.
   Uses only Web Audio API; no tracks downloaded and no external audio assets.
   Starts ONLY after a user interaction, respecting browser autoplay policies. */
(function (root) {
  'use strict';

  const SONGS = {
    theme: {
      name: 'Nohutçuk Theme', bpm: 126, voice: 'triangle',
      notes: [
        ['E5',0,.45],['G5',.5,.42],['A5',1,.45],['G5',1.5,.45],
        ['E5',2,.45],['D5',2.5,.4],['C5',3,.9],
        ['E5',4,.42],['G5',4.5,.42],['C6',5,.8],['B5',6,.42],['G5',6.5,.42],['A5',7,.9],
        ['G5',8,.45],['E5',8.5,.42],['D5',9,.45],['E5',9.5,.45],
        ['G5',10,.4],['E5',10.5,.4],['D5',11,.38],['C5',11.5,.8],
        ['G5',12.5,.4],['A5',13,.4],['G5',13.5,.4],['E5',14,.45],['C5',14.5,1.2]
      ],
      bass: [['C3',0,1.8],['A3',2,1.8],['F3',4,1.8],['G3',6,1.8],['C3',8,1.8],['F3',10,1.8],['G3',12,1.8],['C3',14,1.8]]
    },
    dance: {
      name: 'Tiny Dance', bpm: 154, voice: 'square',
      notes: [
        ['A5',0,.25],['C6',.5,.25],['E6',1,.55],['C6',1.75,.3],
        ['A5',2,.25],['G5',2.5,.25],['E5',3,.4],['G5',3.5,.35],
        ['A5',4,.25],['C6',4.5,.25],['D6',5,.25],['E6',5.5,.3],['G6',6,.45],['E6',6.75,.3],['C6',7.25,.6],
        ['E6',8,.3],['G6',8.5,.25],['A6',9,.45],['E6',9.75,.3],
        ['D6',10.25,.3],['C6',10.75,.3],['A5',11.25,.55],
        ['C6',12,.3],['E6',12.5,.3],['G6',13,.4],['E6',13.75,.3],['C6',14.25,.3],['A5',14.75,1]
      ],
      bass: [['A3',0,.7],['A3',1,.65],['G3',2,.65],['E3',3,.7],['A3',4,.65],['A3',5,.65],['G3',6,.65],['E3',7,.65],['F3',8,.7],['F3',9,.7],['G3',10,.7],['G3',11,.7],['A3',12,.7],['E3',13,.7],['A3',14,1.6]]
    },
    lullaby: {
      name: 'Sleepy Stars', bpm: 78, voice: 'sine',
      notes: [
        ['G5',0,.8],['E5',1,.8],['D5',2,.85],['E5',3,1.1],
        ['G5',4,.8],['A5',5,.8],['G5',6,1.4],
        ['E5',8,.8],['D5',9,.8],['C5',10,1.6],
        ['E5',12,.8],['D5',13,.8],['C5',14,1.8]
      ],
      bass: [['C4',0,3.7],['F3',4,3.7],['G3',8,3.7],['C4',12,3.7]]
    },
    hello: {
      name: 'Happy Hello', bpm: 116, voice: 'triangle',
      notes: [
        ['C5',0,.4],['E5',.5,.4],['G5',1,.5],['C6',1.7,.8],
        ['A5',3,.4],['G5',3.5,.4],['E5',4,.5],['G5',4.75,.35],['C6',5.5,1.1]
      ],
      bass: [['C4',0,1.3],['F3',2,1.3],['G3',4,1.3],['C4',5.5,1.1]]
    }
  };
  const EFFECTS = {
    normal: [['G5',0,.075],['B5',.09,.075]],
    happy: [['C6',0,.09],['E6',.11,.09],['G6',.22,.16]],
    hello: [['G5',0,.1],['C6',.12,.13],['E6',.27,.15]],
    love: [['E5',0,.12],['G5',.15,.13],['C6',.31,.28]],
    shy: [['A5',0,.1],['E5',.13,.15]],
    laughing: [['C6',0,.06],['E6',.09,.06],['C6',.18,.06],['G6',.28,.17]],
    sad: [['E5',0,.18],['D5',.21,.2],['C5',.43,.3]],
    angry: [['D4',0,.08],['C4',.1,.1],['D4',.22,.12]],
    sleeping: [['G5',0,.3],['E5',.34,.4],['C5',.8,.5]],
    surprised: [['C6',0,.07],['G6',.1,.2]],
    thinking: [['D5',0,.15],['F5',.22,.15]],
    cool: [['A4',0,.13],['C5',.18,.13],['E5',.36,.17]],
    kissing: [['G5',0,.13],['D6',.16,.18]],
    hungry: [['C5',0,.09],['E5',.11,.09],['G5',.24,.14]],
    dizzy: [['G5',0,.08],['F5',.1,.08],['D5',.2,.08],['B4',.3,.1]],
    bored: [['C5',0,.24],['B4',.27,.22]],
    celebrating: [['C6',0,.08],['E6',.12,.08],['G6',.24,.1],['C7',.39,.24]],
    goodbye: [['G5',0,.15],['E5',.2,.18],['C5',.42,.3]],
    confused: [['E5',0,.15],['C5',.22,.2],['F5',.5,.15]],
    drama: [['C4',0,.12],['D4',.15,.12],['C4',.35,.17]],
    touch: [['C6',0,.08],['E6',.13,.13]],
    wink: [['A5',0,.05],['C6',.1,.12]]
  };
  const $ = f => typeof f === 'function';
  let ctx=null, master=null, volume=.5, muted=false, effectsEnabled=false, playing=null,
    songNodes=[], endTimer=null, endedCallback=null;

  function init() {
    if(ctx) {
      if(ctx.state==='suspended')ctx.resume().catch(()=>{});
      return true;
    }
    const Ctor=root.AudioContext || root.webkitAudioContext;
    if(!Ctor)return false;
    try {
      ctx=new Ctor();
      master=ctx.createGain();
      master.gain.value=muted?0:volume;
      master.connect(ctx.destination);
      if(ctx.state==='suspended')ctx.resume().catch(()=>{});
      return true;
    } catch(_) {return false;}
  }
  function noteHz(note) {
    const match=/^([A-G])([#b]?)([0-8])$/.exec(note);
    if(!match)return 0;
    const semis={C:0,D:2,E:4,F:5,G:7,A:9,B:11};
    let index=semis[match[1]]+(match[2]==='#'?1:match[2]==='b'?-1:0);
    let midi=(Number(match[3])+1)*12+index;
    return 440*Math.pow(2,(midi-69)/12);
  }
  function schedule(freq,time,length,type,level,collection) {
    if(!ctx||!master||!freq)return;
    const oscillator=ctx.createOscillator();
    const envelope=ctx.createGain();
    oscillator.type=type;
    oscillator.frequency.setValueAtTime(freq,time);
    envelope.gain.setValueAtTime(0.0001,time);
    envelope.gain.exponentialRampToValueAtTime(Math.max(level,.0002),time+.018);
    envelope.gain.setValueAtTime(Math.max(level*.75,.0002),Math.max(time+.019,time+length-.07));
    envelope.gain.exponentialRampToValueAtTime(.0001,time+length+.08);
    oscillator.connect(envelope);
    envelope.connect(master);
    oscillator.start(time);
    oscillator.stop(time+length+.1);
    if(collection)collection.push(oscillator);
  }
  function setVolume(level) {
    volume=Math.max(0,Math.min(1,Number(level)||0));
    if(master&&ctx)master.gain.setTargetAtTime(muted?0:volume,ctx.currentTime,.018);
  }
  function setMuted(enabled) {
    muted=Boolean(enabled);
    if(master&&ctx)master.gain.setTargetAtTime(muted?0:volume,ctx.currentTime,.018);
    if(muted)stopSong();
  }
  function setEffectsEnabled(value){effectsEnabled=Boolean(value);}
  function playEffect(id,force=false) {
    if(muted||(!effectsEnabled&&!force)||!EFFECTS[id]||!init())return false;
    const start=ctx.currentTime+.015;
    const type=['sleeping','sad','shy','love','kissing'].includes(id)?'sine':
      ['angry','drama'].includes(id)?'sawtooth':'triangle';
    const level=['angry','drama'].includes(id)?.045:.10;
    for(const [note,offset,duration] of EFFECTS[id]){
      schedule(noteHz(note),start+offset,duration,type,level);
    }
    return true;
  }
  function stopSong() {
    if(endTimer!==null){clearTimeout(endTimer);endTimer=null;}
    for(const node of songNodes){try{node.stop();}catch(_){}}
    songNodes=[];
    const prior=playing;
    playing=null;
    if(prior&&$(endedCallback))endedCallback(null);
  }
  function playSong(id) {
    if(!SONGS[id]||muted||!init())return false;
    stopSong();
    const track=SONGS[id];
    const beat=60/track.bpm;
    const start=ctx.currentTime+.045;
    let maxEnd=0;
    for(const [note,offset,length] of track.notes){
      schedule(noteHz(note),start+offset*beat,length*beat,track.voice,.13,songNodes);
      maxEnd=Math.max(maxEnd,offset+length);
    }
    for(const [note,offset,length] of track.bass){
      schedule(noteHz(note),start+offset*beat,length*beat,'sine',.065,songNodes);
      maxEnd=Math.max(maxEnd,offset+length);
    }
    playing=id;
    if($(endedCallback))endedCallback(id);
    endTimer=setTimeout(()=>{
      songNodes=[];endTimer=null;
      const prior=playing;playing=null;
      if(prior&&$(endedCallback))endedCallback(null);
    },Math.ceil((maxEnd*beat+.3)*1000));
    return true;
  }
  function onSongChange(fn){endedCallback=$(fn)?fn:null;}
  function available(){return Boolean(root.AudioContext||root.webkitAudioContext);}
  root.NohutcukAudio=Object.freeze({
    playSong,stopSong,playEffect,setVolume,setMuted,setEffectsEnabled,onSongChange,
    available,getPlaying:()=>playing,songNames:Object.freeze(Object.fromEntries(Object.entries(SONGS).map(([k,v])=>[k,v.name])))
  });
})(window);
