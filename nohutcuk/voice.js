/* Nohutçuk Voice — deliberately sparse short phrases in Turkish, English, or Arabic.
 * Browser prototype using SpeechSynthesis; actual robot requires a speaker,
 * tested audio amplifier and prerecorded or synthesized voice assets.
 * Nothing records, streams, or uploads guest audio.
 */
(function (root) {
  'use strict';
  const LINES = Object.freeze({
    welcome:  {'tr-TR':'Hoş geldin!',        'en-US':'Welcome!',             'ar-MA':'مرحبا بيك!'},
    thanks:   {'tr-TR':'Teşekkür ederim!',   'en-US':'Thank you!',           'ar-MA':'شكراً بزاف!'},
    love:     {'tr-TR':'Çok tatlısın!',      'en-US':'You are so sweet!',    'ar-MA':'نتا زوين بزاف!'},
    goodbye:  {'tr-TR':'Yine beklerim!',     'en-US':'See you again!',      'ar-MA':'عاود زورنا!'},
    falafel:  {'tr-TR':'Afiyet olsun!',      'en-US':'Enjoy your meal!',    'ar-MA':'بالصحة والراحة!'},
    photo:    {'tr-TR':'Gülümse!',           'en-US':'Smile!',              'ar-MA':'ضحك شوية!'},
    birthday: {'tr-TR':'İyi ki doğdun!',    'en-US':'Happy birthday!',     'ar-MA':'عيد ميلاد سعيد!'}
  });
  const DEFAULTS = {
    language:'tr-TR',
    volume:.5,
    enabled:true,
    quiet:false,
    globalCooldownMs:22000,
    phraseCooldownMs:60000
  };
  let settings={...DEFAULTS};
  let lastSpokenAt=-Infinity;
  const lastByKey=new Map();
  let listener=null;

  function getPhrase(key,locale=settings.language){
    return LINES[key]?.[locale]||LINES[key]?.['tr-TR']||'';
  }
  function available(){
    return Boolean(root.speechSynthesis && root.SpeechSynthesisUtterance);
  }
  function pickVoice(lang){
    const voices=root.speechSynthesis?.getVoices?.()||[];
    return voices.find(v=>v.lang?.toLowerCase()===lang.toLowerCase())
      || voices.find(v=>v.lang?.split('-')[0].toLowerCase()===lang.split('-')[0].toLowerCase())||null;
  }
  function setOptions(next={}){
    settings={...settings,...next};
    settings.volume=Math.max(0,Math.min(1,Number(settings.volume)||0));
    if(!settings.enabled||settings.quiet)stop();
  }
  function onChange(fn){listener=typeof fn==='function'?fn:null;}
  function report(status,key){
    if(listener)listener({status,key,text:getPhrase(key)});
  }
  function speak(key,{force=false}={}){
    if(!LINES[key])return false;
    if(!settings.enabled||settings.quiet||settings.volume<=0)return false;
    if(!available()){report('unsupported',key);return false;}
    const now=Date.now();
    if(!force&&(now-lastSpokenAt<settings.globalCooldownMs
        ||now-(lastByKey.get(key)??-Infinity)<settings.phraseCooldownMs)) {
      report('cooldown',key);
      return false;
    }
    if(!force&&(root.speechSynthesis.speaking||root.speechSynthesis.pending))return false;
    const text=getPhrase(key);
    try{
      if(force)root.speechSynthesis.cancel();
      const utterance=new root.SpeechSynthesisUtterance(text);
      utterance.lang=settings.language;
      utterance.rate=.96;
      utterance.pitch=1.12;
      utterance.volume=settings.volume;
      const voice=pickVoice(settings.language);
      if(voice)utterance.voice=voice;
      utterance.onend=()=>report('ended',key);
      utterance.onerror=()=>report('error',key);
      root.speechSynthesis.speak(utterance);
      if(!force){
        lastSpokenAt=now;
        lastByKey.set(key,now);
      }
      report('speaking',key);
      return true;
    }catch(_){
      report('unsupported',key);
      return false;
    }
  }
  function stop(){
    try {root.speechSynthesis?.cancel?.();}catch(_){}
  }
  root.NohutcukVoice=Object.freeze({
    speak,preview:key=>speak(key,{force:true}),getPhrase,
    available,setOptions,onChange,stop,
    lines:LINES
  });
})(window);
