/* Nohutçuk Eye Studio — dependency-free browser simulator.
   Hardware integration is deliberately absent. Restaurant events are ONLY simulations
   of sanitized messages that would eventually be emitted by our PC management app.
   Expressions, event mapping and renderer stay separate for future ESP32-S3 porting. */
(() => {
  'use strict';

  const MOODS = [
    {id:'normal',name:'Normal',tr:'Normal',icon:'◉',color:'#9ceaff'},
    {id:'happy',name:'Happy',tr:'Mutlu',icon:'☺',color:'#7bdeff'},
    {id:'love',name:'In Love',tr:'Aşık',icon:'♥',color:'#ff7fbd'},
    {id:'shy',name:'Shy',tr:'Utangaç',icon:'❀',color:'#d5a8ff'},
    {id:'laughing',name:'Laughing',tr:'Gülüyor',icon:'✧',color:'#83ecff'},
    {id:'sad',name:'Sad',tr:'Üzgün',icon:'☂',color:'#80b8ff'},
    {id:'angry',name:'Angry',tr:'Kızgın',icon:'⚡',color:'#ff787a'},
    {id:'sleeping',name:'Sleeping',tr:'Uykulu',icon:'☾',color:'#96b9ed'},
    {id:'surprised',name:'Surprised',tr:'Şaşkın',icon:'!',color:'#b2f1ff'},
    {id:'thinking',name:'Thinking',tr:'Düşünüyor',icon:'?',color:'#8ad4ff'},
    {id:'cool',name:'Cool',tr:'Havalı',icon:'⌐■',color:'#7bf4ec'},
    {id:'kissing',name:'Kissing',tr:'Öpücük',icon:'♡',color:'#ff92cb'},
    {id:'hungry',name:'Hungry',tr:'Aç',icon:'◉',color:'#b1f98c'},
    {id:'dizzy',name:'Dizzy',tr:'Başı dönüyor',icon:'◎',color:'#c2a0ff'},
    {id:'bored',name:'Bored',tr:'Sıkılmış',icon:'−',color:'#a7bfe3'},
    {id:'celebrating',name:'Celebrating',tr:'Kutlama',icon:'★',color:'#ffd16f'},
    {id:'hello',name:'Hello',tr:'Selam',icon:'✿',color:'#90ffca'},
    {id:'goodbye',name:'Goodbye',tr:'Veda',icon:'☽',color:'#91baff'},
    {id:'confused',name:'Confused',tr:'Kararsız',icon:'¿',color:'#e5beff'},
    {id:'drama',name:'Drama',tr:'Drama',icon:'!!',color:'#ff9a6c'}
  ];
  const BY_ID = Object.fromEntries(MOODS.map(m => [m.id, m]));
  const INTERACTIONS = [
    ['welcome','👋','Approach / Welcome'],['touch1','💚','1× Touch • Smile'],
    ['touch2','🥹','2× Touch • Shy'],['touch3','💕','3× Touch • Hearts'],
    ['touchLong','😌','Long touch • Relax'],['wave','🙌','Wave hello'],
    ['friendship','🌱','Friendship +1'],['drama','🎭','Drama mode'],
    ['fakeSleep','💤','Fake sleeping'],['bye','👋','Say goodbye'],
    ['dance','💃','Dance mode'],['cool','😎','Cool mode'],
    ['loveAttack','💗','Love attack'],['falafel','🧆','Falafel lover']
  ];
  const RESTAURANT = [
    ['trendyol','🟠','Trendyol Go order'],['yemeksepeti','💗','Yemeksepeti order'],
    ['migros','🟧','Migros Yemek order'],['table','🍽','Table order'],
    ['extra','🥤','Extra drink / item'],['card','💳','Card payment confirmed'],
    ['cash','💵','Cash payment confirmed'],['fail','⚠️','Payment failed'],
    ['delay','⏳','Order delayed'],['cancel','❌','Order cancelled'],
    ['ready','🎉','Order ready'],['close','🌙','Restaurant closing']
  ];
  const SPECIAL = [
    ['photo','📸','Photo pose • 10 sec'],['selfie','🤳','Selfie pose'],
    ['instagram','💖','Instagram mode'],['reels','🎬','Reels / performance'],
    ['ramadan','🌙','Ramadan'],['eid','✨','Bayram / Eid'],
    ['newyear','🎄','New Year'],['birthday','🎂','Birthday']
  ];
  const $ = id => document.getElementById(id);
  const els = {
    face:$('faceContent'),svg:$('face'),screen:$('screen'),robot:$('robot'),
    bubble:$('speechBubble'),currentMood:$('currentMood'),currentEvent:$('currentEvent'),
    badge:$('statusBadge'),eventLog:$('eventLog'),friendCount:$('friendCount'),
    palette:$('paletteSelect'),customColor:$('customColor'),language:$('languageSelect'),
    duration:$('durationRange'),blink:$('blinkRange'),speed:$('speedRange'),
    autoBlink:$('autoBlink'),autoSleep:$('autoSleep'),voice:$('voiceEnabled'),quiet:$('quietMode')
  };
  const state = {
    mood:'normal',label:'Idle • Blink • Glance',token:0,timeout:0,bubbleTimeout:0,motionTimeout:0,
    palette:'expressive',customColor:'#a7edff',duration:3.5,blinkEvery:3,speed:1,
    autoBlink:true,autoSleep:false,voice:false,quiet:false,language:'tr-TR',
    blinkStarted:0,nextBlink:Date.now()+2400,glanceX:0,glanceY:0,lastPointer:0,
    lastInteraction:Date.now(),lastGlance:Date.now(),lastWelcome:0,friendship:0,
    previewSequence:0,frame:0
  };
  const phrases = {
    welcome:{'tr-TR':'Hoş geldiiin!','en-US':'Hellooo!','ar-MA':'مرحبا بيك!'},
    pet:{'tr-TR':'Çok teşekkür ederim!','en-US':'Thank you!','ar-MA':'شكراً بزاف!'},
    goodbye:{'tr-TR':'Yine gel, tamam mı?','en-US':'Come back soon!','ar-MA':'عاود زورنا!'},
    ready:{'tr-TR':'Afiyet olsun!','en-US':'Enjoy your meal!','ar-MA':'بالصحة والراحة!'},
    birthday:{'tr-TR':'İyi ki doğdun!','en-US':'Happy birthday!','ar-MA':'عيد ميلاد سعيد!'}
  };
  const clamp = (x,a,b) => Math.max(a,Math.min(b,x));
  const esc = v => String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const now = () => new Date().toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit',second:'2-digit'});

  function log(message) {
    const item=document.createElement('li');
    const tm=document.createElement('time');tm.textContent=now();
    const msg=document.createElement('span');msg.textContent=message;
    item.append(tm,msg);
    els.eventLog.prepend(item);
    while(els.eventLog.children.length>10) els.eventLog.lastChild.remove();
  }
  function bubble(text,ms=3000) {
    clearTimeout(state.bubbleTimeout);
    if(!text){els.bubble.classList.add('is-hidden');return;}
    els.bubble.textContent=text;
    els.bubble.classList.remove('is-hidden');
    state.bubbleTimeout=setTimeout(()=>els.bubble.classList.add('is-hidden'),ms);
  }
  function say(key) {
    if(!state.voice || state.quiet || !('speechSynthesis' in window)) return;
    const text=phrases[key] && phrases[key][state.language];
    if(!text)return;
    try {
      window.speechSynthesis.cancel();
      const utterance=new SpeechSynthesisUtterance(text);
      utterance.lang=state.language;utterance.rate=1.08;utterance.pitch=1.28;utterance.volume=.72;
      window.speechSynthesis.speak(utterance);
    } catch(err){log('Browser voice is unavailable: '+err.message);}
  }
  function clearMotion(){
    clearTimeout(state.motionTimeout);
    els.robot.classList.remove('is-dancing','is-nodding','is-waving');
    $('head').style.setProperty('--tilt','0deg');
  }
  function motion(name,duration){
    clearMotion();
    if(state.quiet)return;
    if(name==='dance')els.robot.classList.add('is-dancing');
    if(name==='nod')els.robot.classList.add('is-nodding');
    if(name==='wave')els.robot.classList.add('is-waving');
    if(name==='tilt')$('head').style.setProperty('--tilt','-8deg');
    if(name)state.motionTimeout=setTimeout(clearMotion,duration);
  }
  function markSelected(){
    document.querySelectorAll('.emotion-btn').forEach(b=>b.classList.toggle('is-active',b.dataset.mood===state.mood));
  }
  function setMood(id,options={}) {
    if(!BY_ID[id])return;
    state.token++;
    const token=state.token;
    clearTimeout(state.timeout);
    state.mood=id;
    state.label=options.label || 'Manual expression';
    state.glanceX=0;state.glanceY=0;state.blinkStarted=0;
    els.currentMood.textContent=BY_ID[id].tr+' / '+BY_ID[id].name;
    els.currentEvent.textContent=state.label;
    els.badge.textContent=id==='sleeping'?'● RESTING':'● ACTIVE';
    if(options.interactive!==false)state.lastInteraction=Date.now();
    markSelected();
    motion(options.motion||'',options.duration||2000);
    if(options.bubble)bubble(options.bubble,options.duration||3000);
    if(options.say)say(options.say);
    if(options.log!==false)log(state.label+' → '+BY_ID[id].name);
    const delay=Object.hasOwn(options,'duration')?options.duration:state.duration*1000/state.speed;
    if(delay>0 && id!=='normal'){
      state.timeout=setTimeout(()=>{
        if(state.token===token)setMood('normal',{label:'Idle • Blink • Glance',duration:0,interactive:false,log:false});
      },delay);
    }
    draw();
    return token;
  }
  function runAction(action) {
    const t=Date.now();
    state.previewSequence++;
    if(action==='welcome'){
      if(t-state.lastWelcome<12000){log('Welcome cooldown — prevents repeated greetings (12s).');return;}
      state.lastWelcome=t;
      setMood('hello',{label:'Proximity sensor • simulated',motion:'nod',bubble:phrases.welcome[state.language],say:'welcome'});return;
    }
    if(action==='touch1'){setMood('happy',{label:'Head touch ×1 • simulated',motion:'nod',bubble:'Başımı okşa! 💚',say:'pet'});return;}
    if(action==='touch2'){setMood('shy',{label:'Head touch ×2 • simulated',motion:'tilt',bubble:'Awww 🥹'});return;}
    if(action==='touch3'){setMood('love',{label:'Head touch ×3 • simulated',motion:'nod',bubble:'Seni seviyorum! 💕'});return;}
    if(action==='touchLong'){setMood('sleeping',{label:'Long head touch • relax',bubble:'Mmm... 😌'});return;}
    if(action==='wave'){setMood('hello',{label:'Wave / button • simulated',motion:'wave',bubble:phrases.welcome[state.language],say:'welcome'});return;}
    if(action==='friendship'){
      state.friendship=(state.friendship%4)+1;
      els.friendCount.textContent=state.friendship+' / 4';
      const sequence=['shy','happy','love','celebrating'];
      setMood(sequence[state.friendship-1],{label:'Friendship stage '+state.friendship+'/4',motion:state.friendship===4?'dance':'nod',bubble:['Hello, friend!','You make me happy!','❤️❤️❤️','Best friends! ✨'][state.friendship-1]});return;
    }
    if(action==='drama'){
      const token=setMood('angry',{label:'Drama • pretending to be angry',bubble:'Hmph! 😤',duration:0});
      setTimeout(()=>{if(state.token===token)setMood('laughing',{label:'Drama • just kidding!',motion:'nod',bubble:'Şakaaa! 😂'});},1400/state.speed);return;
    }
    if(action==='fakeSleep'){
      const token=setMood('sleeping',{label:'Fake sleeping...',duration:0,bubble:'Zzz...'});
      setTimeout(()=>{if(state.token===token)setMood('surprised',{label:'Fake sleep • surprise wake',motion:'nod',bubble:'Aaa! 😲'});},1900/state.speed);return;
    }
    if(action==='bye'){setMood('goodbye',{label:'Farewell interaction',motion:'tilt',bubble:phrases.goodbye[state.language],say:'goodbye'});return;}
    if(action==='dance'){setMood('celebrating',{label:'Dance mode',motion:'dance',duration:4500/state.speed,bubble:'Hadi dans edelim! 🎵'});return;}
    if(action==='cool'){setMood('cool',{label:'Cool mode',motion:'tilt',bubble:'Çok havalı! 😎'});return;}
    if(action==='loveAttack'){setMood('love',{label:'Love attack',motion:'nod',bubble:'💗💗💗'});return;}
    if(action==='falafel'){setMood('hungry',{label:'Falafel lover',motion:'nod',bubble:'Falafel! 🧆'});return;}
    if(action==='photo'){setMood('happy',{label:'Photo mode • holds pose 10s',duration:10000,motion:'tilt',bubble:'Çek bakalım! 📸'});return;}
    if(action==='selfie'){setMood('shy',{label:'Selfie pose',duration:5000,motion:'tilt',bubble:'Selfie! 🤳'});return;}
    if(action==='instagram'){setMood('love',{label:'Instagram mode',motion:'nod',bubble:'Beni etiketle! #Nohutçuk'});return;}
    if(action==='reels'){setMood('celebrating',{label:'Reels performance',motion:'dance',duration:6000,bubble:'Nohutçuk Reels 🎬'});return;}
    const holidays={ramadan:['thinking','Ramazan mübarek olsun! 🌙'],eid:['celebrating','İyi Bayramlar! ✨'],newyear:['celebrating','Mutlu yıllar! 🎄'],birthday:['love',phrases.birthday[state.language]]};
    if(holidays[action]){
      const entry=holidays[action];setMood(entry[0],{label:'Special event • '+action,motion:'nod',bubble:entry[1],say:action==='birthday'?'birthday':null});return;
    }
    const pcEvents={
      trendyol:['surprised','New Trendyol Go order','Trendyol Go 🟠','nod'],
      yemeksepeti:['happy','New Yemeksepeti order','Yemeksepeti 💗','nod'],
      migros:['hello','New Migros Yemek order','Migros Yemek 🟠','nod'],
      table:['hungry','New table order','Masa siparişi! 🍽','nod'],
      extra:['happy','Extra item added','Ek sipariş! 🥤','nod'],
      card:['happy','Card payment confirmed','Kart ödemesi başarılı ✓','nod'],
      cash:['love','Cash payment confirmed','Nakit ödeme başarılı ✓','nod'],
      fail:['confused','Payment failed','Ödeme başarısız ⚠️',''],
      delay:['sad','Order delayed','Sipariş gecikiyor ⏳','tilt'],
      cancel:['sad','Order cancelled','Sipariş iptal edildi','tilt'],
      ready:['celebrating','Order ready','Sipariş hazır! 🎉','dance'],
      close:['sleeping','Restaurant closing','İyi geceler! 🌙','']
    };
    if(pcEvents[action]){
      const e=pcEvents[action];
      setMood(e[0],{label:'PC-app DEMO • '+e[1],bubble:e[2],motion:e[3],say:action==='ready'?'ready':null,duration:action==='close'?0:undefined});
      // The robot consumes no actual marketplace or payment data.
      return;
    }
    log('Unknown demo action: '+action);
  }

  // Pure-ish expression renderer: generated SVG shapes are based only on a known mood ID.
  // The colors are intentionally per-emotion, including pink, aqua, gold and purple.
  const attrs='stroke="currentColor" stroke-width="10" fill="none" stroke-linecap="round" stroke-linejoin="round"';
  function path(d,extra=''){return '<path d="'+d+'" '+attrs+' '+extra+'/>';}
  function ring(rx=19,ry=24){return '<ellipse cx="0" cy="0" rx="'+rx+'" ry="'+ry+'" '+attrs+'/>';}
  function star(cx,cy,r,inner,n=5){
    let points=[];
    for(let i=0;i<n*2;i++){
      const a=-Math.PI/2+i*Math.PI/n;
      const rr=i%2?inner:r;
      points.push((cx+Math.cos(a)*rr).toFixed(1)+','+(cy+Math.sin(a)*rr).toFixed(1));
    }
    return '<polygon points="'+points.join(' ')+'" fill="currentColor"/>';
  }
  function heart(){
    return '<path d="M0 23 C-9 15 -32 2 -30 -13 C-28 -32 -7 -34 0 -17 C7 -34 28 -32 30 -13 C32 2 9 15 0 23Z" fill="currentColor"/>';
  }
  function eye(id,left){
    const closed=path('M-25 6 Q0 15 25 6');
    switch(id){
      case 'happy':case 'hello':return path('M-27 15 Q0 -26 27 15');
      case 'love':return heart();
      case 'shy':return '<ellipse cx="0" cy="11" rx="19" ry="10" fill="currentColor"/>';
      case 'laughing':return path(left?'M-25 -9 L1 10 L-25 16':'M25 -9 L-1 10 L25 16');
      case 'sad':return path('M-25 -5 Q0 17 25 -5')+path('M-25 -5 L-18 -14');
      case 'angry':return '<path d="'+(left?'M-30 -16 L25 -2 L18 19 L-21 18Z':'M30 -16 L-25 -2 L-18 19 L21 18Z')+'" fill="currentColor"/>';
      case 'sleeping':return closed;
      case 'surprised':return ring(26,34)+'<circle cx="0" cy="0" r="8" fill="currentColor"/>';
      case 'thinking':return left?ring(12,18):'<text x="-13" y="19" font-size="62" font-family="Arial" font-weight="700" fill="currentColor">?</text>';
      case 'cool':return '<rect x="-30" y="-16" width="60" height="36" rx="11" fill="currentColor" opacity=".88"/><path d="M-20 -4 L0 -10" stroke="#061118" stroke-width="5"/>';
      case 'kissing':return left?path('M-25 8 Q0 -17 25 8'):heart();
      case 'hungry':return ring(27,29)+'<circle r="7" fill="currentColor"/><circle cx="12" cy="-15" r="3" fill="#fff"/>';
      case 'dizzy':return '<path d="M 0 0 C 2 -12 15 -10 16 0 C 19 19 -21 22 -24 0 C -28 -33 24 -41 31 -6" '+attrs+' stroke-width="7"/>';
      case 'bored':return '<rect x="-26" y="-2" width="52" height="15" rx="8" fill="currentColor"/>';
      case 'celebrating':return star(0,0,30,13);
      case 'goodbye':return left?path('M-25 6 Q0 19 25 6'):ring(18,22);
      case 'confused':return left?ring(13,19):path('M-25 -8 Q0 -25 25 -8');
      case 'drama':return '<path d="'+(left?'M-30 -18 L25 1 L16 20 L-19 16Z':'M30 -18 L-25 1 L-16 20 L19 16Z')+'" fill="currentColor"/>';
      default:return '<rect x="-22" y="-31" width="44" height="66" rx="22" fill="currentColor"/>';
    }
  }
  function renderColor(){
    const palette=state.palette;
    const color=palette==='expressive'?BY_ID[state.mood].color:
      ({rainbow:'#e6a6f4',cyan:'#9ceaff',pink:'#ff81c0',mint:'#9effb0',amber:'#ffd174',custom:state.customColor}[palette]||'#9ceaff');
    els.svg.style.color=color;
    document.documentElement.style.setProperty('--eye',color);
    document.documentElement.style.setProperty('--eye-glow',color+'66');
    return palette==='rainbow'?'url(#rainbow)':color;
  }
  function draw(){
    const id=state.mood;
    const fill=renderColor();
    const t=Date.now();
    const speed=state.speed;
    let blinkScale=1;
    if(state.blinkStarted>0){
      const phase=(t-state.blinkStarted)/(170/speed);
      if(phase>=1){state.blinkStarted=0;}
      else blinkScale=Math.max(.055,1-.95*Math.sin(phase*Math.PI));
    }
    // Resting and deliberately closed expressions remain expressive without random blinks.
    if(['sleeping','laughing','bored'].includes(id))blinkScale=1;
    const glX=['normal','shy','surprised','hungry','confused','thinking'].includes(id)?state.glanceX:0;
    const glY=['normal','shy','surprised','hungry','confused','thinking'].includes(id)?state.glanceY:0;
    let extras='';
    if(id==='shy'||id==='kissing')extras='<ellipse cx="62" cy="128" rx="18" ry="7" fill="#ff96b9" opacity=".55"/><ellipse cx="260" cy="128" rx="18" ry="7" fill="#ff96b9" opacity=".55"/>';
    if(id==='sleeping')extras='<text x="245" y="40" font-size="28" fill="#9ec7ff" font-weight="800">zZ</text>';
    if(id==='celebrating')extras='<g fill="#fff1a7">'+star(52,29,13,6)+star(270,130,11,5)+star(165,22,7,3)+'</g>';
    if(id==='love'||id==='kissing')extras+='<g fill="#ffc7e0" opacity=".8">'+star(162,26,7,3,4)+'</g>';
    if(id==='sad'||id==='goodbye')extras+='<path d="M252 122 Q260 102 268 122 Q268 137 260 137 Q252 137 252 122Z" fill="#69bdff"/>';
    if(id==='hungry')extras+='<path d="M143 130 Q160 145 177 130" stroke="#a1ff9c" stroke-width="6" fill="none" stroke-linecap="round"/>';
    if(id==='normal'||id==='hello')extras+='<path d="M147 126 Q160 135 173 126" stroke="'+esc(fill)+'" opacity=".65" stroke-width="4" fill="none" stroke-linecap="round"/>';
    const xA=102+glX,xB=218+glX,y=78+glY;
    const sx='<g transform="translate(0 80) scale(1 '+blinkScale.toFixed(3)+') translate(0 -80)">';
    const eyes='<g filter="url(#eye-glow)" style="color:'+esc(fill)+'">'+
      '<g transform="translate('+xA.toFixed(1)+' '+y.toFixed(1)+')">'+eye(id,true)+'</g>'+
      '<g transform="translate('+xB.toFixed(1)+' '+y.toFixed(1)+')">'+eye(id,false)+'</g>'+
      '</g>';
    els.face.innerHTML=sx+eyes+'</g>'+extras;
  }

  function buildButtons(target,entries,kind){
    const grid=$(target);
    entries.forEach(item=>{
      const button=document.createElement('button');
      button.type='button';
      if(kind==='emotion'){
        button.className='emotion-btn';
        button.dataset.mood=item.id;
        button.setAttribute('aria-label',item.name+' / '+item.tr);
        button.innerHTML='<span class="tiny-face is-'+item.id+'" style="--tiny-color:'+item.color+'"><i></i><i></i></span>'+
          '<span class="mood-label">'+esc(item.tr)+'</span><span class="mood-sub">'+esc(item.name)+'</span>';
        button.addEventListener('click',()=>{state.previewSequence++;setMood(item.id,{label:'Manual • '+item.name,duration:item.id==='normal'?0:undefined});});
      } else {
        button.innerHTML='<span aria-hidden="true">'+item[1]+'</span>'+esc(item[2]);
        button.addEventListener('click',()=>runAction(item[0]));
      }
      grid.appendChild(button);
    });
  }
  buildButtons('emotionGrid',MOODS,'emotion');
  buildButtons('interactionGrid',INTERACTIONS,'action');
  buildButtons('restaurantGrid',RESTAURANT,'action');
  buildButtons('specialGrid',SPECIAL,'action');
  const cycleButton=document.createElement('button');
  cycleButton.type='button';cycleButton.className='secondary-button';
  cycleButton.style.cssText='width:100%;margin:2px 0 13px;padding:11px;';
  cycleButton.textContent='▶ Preview all 20 emotions automatically';
  $('emotionGrid').before(cycleButton);
  cycleButton.addEventListener('click',()=>{
    const seq=++state.previewSequence;
    cycleButton.disabled=true;cycleButton.textContent='Playing all 20 expressions…';
    MOODS.forEach((m,i)=>setTimeout(()=>{
      if(state.previewSequence!==seq)return;
      setMood(m.id,{label:'All emotions preview '+(i+1)+' / '+MOODS.length,duration:0,interactive:false,log:false});
      if(i===MOODS.length-1)setTimeout(()=>{
        if(state.previewSequence===seq)setMood('normal',{label:'All 20 emotions previewed',duration:0,log:true,interactive:false});
        cycleButton.disabled=false;cycleButton.textContent='▶ Preview all 20 emotions automatically';
      },930);
    },i*930));
  });
  document.querySelectorAll('[data-tab]').forEach(tab=>tab.addEventListener('click',()=>{
    const key=tab.dataset.tab;
    document.querySelectorAll('[data-tab]').forEach(b=>b.setAttribute('aria-selected',String(b===tab)));
    document.querySelectorAll('.tab-panel').forEach(p=>p.hidden=(p.id!=='panel-'+key));
  }));
  document.querySelectorAll('[data-action]').forEach(b=>b.addEventListener('click',()=>runAction(b.dataset.action)));
  $('resetBtn').addEventListener('click',()=>{
    state.previewSequence++;state.lastWelcome=0;state.friendship=0;els.friendCount.textContent='0 / 4';
    setMood('normal',{label:'Idle • Blink • Glance',duration:0,bubble:'Merhaba! Ben Nohutçuk 💚'});
  });
  $('clearLog').addEventListener('click',()=>{els.eventLog.replaceChildren();log('History cleared (demo only).');});
  function refreshSettings(){
    state.palette=els.palette.value;
    state.customColor=els.customColor.value;
    state.language=els.language.value;
    state.duration=Number(els.duration.value);
    state.blinkEvery=Number(els.blink.value);
    state.speed=Number(els.speed.value);
    state.autoBlink=els.autoBlink.checked;
    state.autoSleep=els.autoSleep.checked;
    state.voice=els.voice.checked;
    state.quiet=els.quiet.checked;
    $('durationValue').textContent=state.duration+'s';
    $('blinkValue').textContent=state.blinkEvery+'s';
    $('speedValue').textContent=state.speed+'×';
    document.documentElement.style.setProperty('--speed',state.speed);
    if(state.quiet){clearMotion();try{window.speechSynthesis.cancel();}catch(_){}}
    draw();
  }
  ['paletteSelect','customColor','languageSelect','durationRange','blinkRange','speedRange','autoBlink','autoSleep','voiceEnabled','quietMode'].forEach(id=>{
    $(id).addEventListener('input',refreshSettings);
    $(id).addEventListener('change',refreshSettings);
  });
  els.screen.addEventListener('pointermove',e=>{
    const r=els.screen.getBoundingClientRect();
    state.glanceX=clamp(((e.clientX-r.left)/r.width-.5)*22,-11,11);
    state.glanceY=clamp(((e.clientY-r.top)/r.height-.5)*14,-7,7);
    state.lastPointer=Date.now();
  });
  els.screen.addEventListener('pointerleave',()=>{state.lastPointer=0;state.glanceX=0;state.glanceY=0;});
  els.screen.addEventListener('click',()=>runAction('touch1'));
  function tick(ts){
    if(ts-state.frame<45){requestAnimationFrame(tick);return;}
    state.frame=ts;
    const t=Date.now();
    if(state.autoBlink&&state.mood!=='sleeping'&&t>=state.nextBlink){
      state.blinkStarted=t;
      state.nextBlink=t+state.blinkEvery*1000+(Math.random()-.5)*650;
    }
    if(state.autoBlink&&t-state.lastGlance>3000&&t-state.lastPointer>1400&&state.mood==='normal'){
      state.glanceX=(Math.random()-.5)*16;
      state.glanceY=(Math.random()-.5)*10;
      state.lastGlance=t;
    }
    if(state.autoSleep&&t-state.lastInteraction>30000&&state.mood==='normal'){
      setMood('sleeping',{label:'Auto sleep • 30s idle',duration:0,interactive:false,bubble:'Zzz...'});
    }
    draw();
    requestAnimationFrame(tick);
  }
  refreshSettings();
  setMood('normal',{duration:0,log:false,interactive:false,label:'Idle • Blink • Glance'});
  log('Nohutçuk Eye Studio ready. All events are simulated.');
  requestAnimationFrame(tick);
})();