/* Nohutçuk character voice — short, occasional lines.
 * Voice styles control Web Speech prosody; the user's OS/browser chooses its
 * underlying voice. Optional local recorded MP3/WAV files override TTS.
 * This page does not record, upload or store customer speech.
 */
(function(root){
  'use strict';
  const LINES=Object.freeze({
    welcome:{'tr-TR':'Hoş geldiiin!','en-US':'Hellooo!','ar-MA':'مرحبا بيك!'},
    thanks:{'tr-TR':'Teşekkür ederiiim!','en-US':'Thank yooou!','ar-MA':'شكراً بزاف!'},
    love:{'tr-TR':'Çok tatlısıın!','en-US':'So sweeet!','ar-MA':'زوين بزاف!'},
    goodbye:{'tr-TR':'Yine bekleriim!','en-US':'See youuu!','ar-MA':'عاود زورنا!'},
    falafel:{'tr-TR':'Afiyet olsuuun!','en-US':'Enjoyyy!','ar-MA':'بالصحة والراحة!'},
    photo:{'tr-TR':'Gülüümse!','en-US':'Smiiile!','ar-MA':'ضحك شوية!'},
    birthday:{'tr-TR':'İyi ki doğduuunn!','en-US':'Happy birthdaaay!','ar-MA':'عيد ميلاد سعيد!'}
  });
  const STYLES=Object.freeze({
    minik:{name:'Minik Nohutçuk',pitch:1.63,rate:1.13},
    yumusak:{name:'Yumuşacık',pitch:1.36,rate:1.03},
    zipir:{name:'Zıpır Nohutçuk',pitch:1.85,rate:1.25}
  });
  let settings={
    language:'tr-TR',volume:.5,enabled:true,quiet:false,style:'minik',
    selectedVoiceURI:'auto',globalCooldownMs:22000,phraseCooldownMs:60000
  };
  let lastSpokenAt=-Infinity;
  const lastByKey=new Map();
  const clipUrls=new Map();
  let listener=null,activeClip=null;
  function available(){return !!(root.speechSynthesis&&root.SpeechSynthesisUtterance);}
  function getPhrase(key,language=settings.language){return LINES[key]?.[language]||LINES[key]?.['tr-TR']||'';}
  function emit(status,key,extra={}){
    if(typeof listener==='function')listener({status,key,text:getPhrase(key),...extra});
  }
  function onChange(fn){listener=typeof fn==='function'?fn:null;}
  function getVoices(language=settings.language){
    if(!available())return [];
    const primary=language.split('-')[0].toLowerCase();
    const list=root.speechSynthesis.getVoices?.()||[];
    return list.filter(v=>(v.lang||'').toLowerCase().split('-')[0]===primary)
      .map(v=>({name:v.name,lang:v.lang,voiceURI:v.voiceURI||v.name,localService:v.localService}));
  }
  function pickVoice(){
    const voices=getVoices(settings.language);
    if(settings.selectedVoiceURI!=='auto'){
      const chosen=voices.find(v=>v.voiceURI===settings.selectedVoiceURI);
      if(chosen){
        const all=root.speechSynthesis.getVoices?.()||[];
        return all.find(v=>(v.voiceURI||v.name)===chosen.voiceURI)||null;
      }
    }
    // Favor youthful-sounding female voices when installed, never fake Turkish
    // proficiency by forcing an English voice. Gender can't be reliably inferred.
    const words=/emel|filiz|zeynep|selin|deniz|google|natural|premium|neural/i;
    const result=voices.find(v=>words.test(v.name))||voices[0];
    if(!result)return null;
    return (root.speechSynthesis.getVoices?.()||[]).find(v=>(v.voiceURI||v.name)===result.voiceURI)||null;
  }
  function setOptions(next={}){
    settings={...settings,...next};
    if(!STYLES[settings.style])settings.style='minik';
    settings.volume=Math.max(0,Math.min(1,Number(settings.volume)||0));
    if(!settings.enabled||settings.quiet)stop();
  }
  function stop(){
    try{root.speechSynthesis?.cancel?.();}catch(_){}
    if(activeClip){
      try{activeClip.pause();activeClip.currentTime=0;}catch(_){}
      activeClip=null;
    }
  }
  function setClip(key,file){
    if(!Object.prototype.hasOwnProperty.call(LINES,key))return false;
    const old=clipUrls.get(key);
    if(old && root.URL?.revokeObjectURL)root.URL.revokeObjectURL(old);
    clipUrls.delete(key);
    if(!file)return true;
    if(!file.type?.startsWith('audio/')||!root.URL?.createObjectURL)return false;
    clipUrls.set(key,root.URL.createObjectURL(file));
    return true;
  }
  function clipLoaded(key){return clipUrls.has(key);}
  function speak(key,{force=false}={}){
    if(!Object.prototype.hasOwnProperty.call(LINES,key))return false;
    if(!settings.enabled||settings.quiet||settings.volume<=0)return false;
    const time=Date.now();
    if(!force&&(time-lastSpokenAt<settings.globalCooldownMs||
      time-(lastByKey.get(key)??-Infinity)<settings.phraseCooldownMs)){
      emit('cooldown',key);
      return false;
    }
    if(!force&&(activeClip||root.speechSynthesis?.speaking||root.speechSynthesis?.pending))return false;
    if(force)stop();
    const clip=clipUrls.get(key);
    if(clip&&typeof root.Audio==='function'){
      try{
        const player=new root.Audio(clip);
        player.volume=settings.volume;
        activeClip=player;
        player.onended=()=>{if(activeClip===player)activeClip=null;emit('ended',key);};
        player.onerror=()=>{if(activeClip===player)activeClip=null;emit('error',key);};
        const p=player.play();
        if(p?.catch)p.catch(()=>{if(activeClip===player)activeClip=null;emit('error',key);});
        if(!force){lastSpokenAt=time;lastByKey.set(key,time);}
        emit('speaking',key,{source:'clip'});
        return true;
      }catch(_){emit('error',key);return false;}
    }
    if(!available()){emit('unsupported',key);return false;}
    try{
      const utterance=new root.SpeechSynthesisUtterance(getPhrase(key));
      const style=STYLES[settings.style];
      utterance.lang=settings.language;
      utterance.pitch=style.pitch;
      utterance.rate=style.rate;
      utterance.volume=settings.volume;
      const found=pickVoice();
      if(found)utterance.voice=found;
      utterance.onend=()=>emit('ended',key);
      utterance.onerror=()=>emit('error',key);
      root.speechSynthesis.speak(utterance);
      if(!force){lastSpokenAt=time;lastByKey.set(key,time);}
      emit('speaking',key,{source:'browser',style:settings.style});
      return true;
    }catch(_){emit('unsupported',key);return false;}
  }
  root.NohutcukVoice=Object.freeze({
    speak,preview:key=>speak(key,{force:true}),getPhrase,available,
    getVoices,setOptions,onChange,stop,setClip,clipLoaded,
    styles:STYLES,lines:LINES
  });
})(window);
