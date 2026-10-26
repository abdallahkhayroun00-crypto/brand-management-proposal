/* Nohutçuk shop-day scenario model.
 * One self-contained, deterministic browser simulation, not real sensors or POS.
 * No marketplace API connections or personal data. All timestamps are simulated
 * local-shop wall-clock seconds; no physical hardware actions are performed.
 */
(function(root){
  'use strict';
  const DAY_START=10*3600+45*60, DAY_END=21*3600+30*60;
  const PHASES=Object.freeze([
    {id:'before',title:'Hazırlık',clock:'10:25',subtitle:'Before opening',at:10*3600+25*60},
    {id:'open',title:'Açılış',clock:'10:45',subtitle:'Opening',at:DAY_START},
    {id:'morning',title:'Sabah',clock:'11:15',subtitle:'First guests',at:11*3600+15*60},
    {id:'lunch',title:'Öğlen Yoğunluğu',clock:'13:00',subtitle:'Lunch rush',at:13*3600},
    {id:'afternoon',title:'Öğleden Sonra',clock:'16:00',subtitle:'Quiet afternoon',at:16*3600},
    {id:'evening',title:'Akşam',clock:'19:00',subtitle:'Evening service',at:19*3600},
    {id:'close',title:'Kapanış',clock:'21:30',subtitle:'Closing',at:DAY_END},
    {id:'after',title:'Kapalı',clock:'21:45',subtitle:'After hours',at:21*3600+45*60}
  ]);
  const titleOf={
    open:'Open the shop',close:'Close the shop',approach:'Guest approaches',
    walkPast:'Guest walks past',single:'Single head touch',double:'Double head touch',
    triple:'Triple head touch',long:'Long touch',wave:'Wave (manual simulation)',
    farewell:'Farewell',photo:'Photo pose',selfie:'Selfie',instagram:'Instagram pose',
    reels:'Reels pose',dance:'Worker dance',birthday:'Birthday (staff)',
    foodReady:'Falafel ready (staff)',crowdOn:'Crowded service',crowdOff:'Rush ends',
    staffMute:'Staff mutes robot',staffUnmute:'Staff unmutes robot',
    idle:'Idle period',wifiOff:'Wi-Fi lost',wifiOn:'Wi-Fi returns',
    powerOff:'Power lost',powerOn:'Power restored',fault:'Sensor fault',
    clearFault:'Staff clears fault',clean:'Cleaning mode',unclean:'Cleaning finished',
    tapping:'Accidental repeated tap',look:'Look towards guest',
    unauthorized:'Unknown command',socialStop:'Stop a social pose'
  };
  const regular={
    approach:{mood:'hello',say:'welcome',motion:'nod',hold:3000},
    single:{mood:'happy',motion:'nod',hold:1800},
    double:{mood:'shy',motion:'tilt',hold:2300},
    triple:{mood:'love',say:'love',motion:'nod',hold:2500},
    long:{mood:'sleeping',hold:2600},
    wave:{mood:'hello',motion:'wave',hold:2200},
    farewell:{mood:'goodbye',say:'goodbye',motion:'tilt',hold:2500},
    photo:{mood:'happy',say:'photo',motion:'tilt',hold:10000},
    selfie:{mood:'shy',motion:'tilt',hold:10000},
    instagram:{mood:'love',hold:10000},
    reels:{mood:'celebrating',motion:'dance',hold:6000},
    dance:{mood:'celebrating',motion:'dance',hold:4500},
    birthday:{mood:'celebrating',say:'birthday',hold:4500},
    foodReady:{mood:'hungry',say:'falafel',hold:1800},
    look:{mood:'normal',hold:1200}
  };
  const manualOnly=new Set(['photo','selfie','instagram','reels','dance','birthday','foodReady','wave','farewell']);
  const soundAllowed=new Set(['birthday','dance','reels']);
  function initial(){
    return {status:'closed',powered:true,fault:false,wifi:true,crowded:false,
      staffMuted:false,cleaning:false,lastWelcome:-Infinity,lastSpeech:-Infinity,
      phraseAt:{},holdUntil:0,lastActivity:0,phase:'before'};
  }
  function isQuiet(s){return s.crowded||s.staffMuted||s.cleaning;}
  function result(state,event,reason,mode='suppressed',reaction={}){
    const quiet=isQuiet(state);
    return {state,output:{event,mode,reason,phase:state.phase,quiet,
      mood:reaction.mood||null,say:quiet?null:(reaction.say||null),
      sound:quiet?false:Boolean(reaction.sound),motion:quiet?null:(reaction.motion||null),
      hold:reaction.hold||0}};
  }
  function dispatch(previous,event,at,options={}){
    const s={...previous,phraseAt:{...previous.phraseAt}};
    if(!Number.isFinite(at))return result(s,event,'invalid-time');
    if(at<0||at>=86400)return result(s,event,'time-out-of-range');
    s.phase=(PHASES.filter(p=>at>=p.at).at(-1)||PHASES[0]).id;
    if(!titleOf[event])return result(s,event,'unknown-event');
    // Physical power controls always win, even over faults, holds and closing.
    if(event==='powerOff'){
      if(!s.powered)return result(s,event,'power-already-off');
      s.powered=false;s.holdUntil=0;return result(s,event,'powered-off','shown',{mood:'sleeping'});
    }
    if(event==='powerOn'){
      if(s.powered)return result(s,event,'power-already-on');
      s.powered=true;return result(s,event,'powered-on','shown',{mood:s.status==='open'&&!s.fault?'normal':'sleeping'});
    }
    if(!s.powered)return result(s,event,'no-power');
    if(event==='fault'){
      if(s.fault)return result(s,event,'fault-already-active');
      s.fault=true;s.holdUntil=0;return result(s,event,'sensor-fault','shown',{mood:'confused'});
    }
    if(event==='clearFault'){
      if(!s.fault)return result(s,event,'no-active-fault');
      s.fault=false;return result(s,event,'staff-acknowledged','shown',{mood:s.status==='open'?'normal':'sleeping'});
    }
    if(event==='close'){
      if(s.status==='closed')return result(s,event,'already-closed');
      s.status='closed';s.holdUntil=0;s.crowded=false;s.cleaning=false;
      return result(s,event,'shop-closed','shown',{mood:'sleeping'});
    }
    if(s.fault)return result(s,event,'safety-fault');
    if(event==='open'){
      if(s.status==='open')return result(s,event,'already-open');
      if(at<DAY_START)return result(s,event,'before-opening-time');
      if(at>=DAY_END)return result(s,event,'outside-opening-hours');
      s.status='open';s.holdUntil=0;s.lastWelcome=-Infinity;s.lastSpeech=-Infinity;s.phraseAt={};
      return result(s,event,'shop-opened','shown',{mood:'hello',hold:1700});
    }
    if(s.status!=='open')return result(s,event,'shop-closed');
    // Simulated shop hours are checked independently of a forgotten close command.
    if(at>=DAY_END)return result(s,event,'after-hours');
    if(event==='wifiOff'){if(!s.wifi)return result(s,event,'already-offline');s.wifi=false;return result(s,event,'local-reactions-still-work','shown',{mood:'confused',hold:950});}
    if(event==='wifiOn'){if(s.wifi)return result(s,event,'already-online');s.wifi=true;return result(s,event,'reconnected','shown',{mood:'happy',hold:1100});}
    if(event==='crowdOn'){if(s.crowded)return result(s,event,'already-busy');s.crowded=true;return result(s,event,'busy-mode','shown',{mood:'normal'});}
    if(event==='crowdOff'){if(!s.crowded)return result(s,event,'not-busy');s.crowded=false;return result(s,event,'busy-mode-ended','shown',{mood:'normal'});}
    if(event==='staffMute'){if(s.staffMuted)return result(s,event,'already-muted');s.staffMuted=true;return result(s,event,'worker-muted','shown',{mood:'normal'});}
    if(event==='staffUnmute'){if(!s.staffMuted)return result(s,event,'not-muted');s.staffMuted=false;return result(s,event,'worker-unmuted','shown',{mood:'normal'});}
    if(event==='clean'){if(s.cleaning)return result(s,event,'already-cleaning');s.cleaning=true;s.holdUntil=0;return result(s,event,'cleaning-started','shown',{mood:'sleeping'});}
    if(event==='unclean'){if(!s.cleaning)return result(s,event,'not-cleaning');s.cleaning=false;return result(s,event,'cleaning-finished','shown',{mood:'normal'});}
    if(event==='socialStop'){s.holdUntil=0;return result(s,event,'pose-stopped','shown',{mood:'normal'});}
    if(event==='unauthorized')return result(s,event,'command-not-allowed');
    if(event==='walkPast')return result(s,event,'distance-threshold-not-reached');
    if(event==='tapping')return result(s,event,'debounced-accidental-touch');
    if(event==='idle'){
      if(at-s.lastActivity<300)return result(s,event,'not-idle-long-enough');
      s.holdUntil=0;return result(s,event,'auto-rest-5min','shown',{mood:'sleeping'});
    }
    if(s.cleaning)return result(s,event,'cleaning-in-progress');
    if(at<s.holdUntil)return result(s,event,'pose-in-progress');
    if(event==='approach'&&at-s.lastWelcome<30)return result(s,event,'welcome-30s-cooldown');
    if(options.untrusted&&manualOnly.has(event))return result(s,event,'worker-activation-required');
    const plan=regular[event];
    if(!plan)return result(s,event,'unknown-event');
    if(event==='approach')s.lastWelcome=at;
    s.lastActivity=at;
    let say=plan.say||null;
    if(say){
      if(isQuiet(s)||at-s.lastSpeech<22||at-(s.phraseAt[say]??-Infinity)<60){say=null;}
      else {s.lastSpeech=at;s.phraseAt[say]=at;}
    }
    let mood=plan.mood;
    let motion=plan.motion;
    if(isQuiet(s)){motion=null;if(event==='reels'||event==='dance')return result(s,event,'quiet-mode-blocks-performance');}
    if(['photo','selfie','instagram','reels'].includes(event))s.holdUntil=at+plan.hold/1000;
    return result(s,event,'guest-interaction','shown',{mood,say,motion,
      sound:!isQuiet(s)&&soundAllowed.has(event)&&Boolean(options.soundOptIn),
      hold:plan.hold});
  }
  const C=[];
  const add=(phase,name,event,at,setup=[],expect='shown',note='')=>C.push({
    id:'T'+String(C.length+1).padStart(3,'0'),phase,name,event,at,setup,expect,note
  });
  const open=(at=DAY_START)=>[['open',at]];
  // Distinct situations; every case is independently reconstructed from its setup.
  add('before','Power on while shop closed','powerOn',37500,[], 'suppressed');
  add('before','Closed before opening','approach',37510,[], 'suppressed');
  add('before','Touch during preparation','single',37520,[], 'suppressed');
  add('before','Wave before opening','wave',37530,[], 'suppressed');
  add('before','Try opening too early','open',37550,[], 'suppressed');
  add('before','Already closed on boot','close',37560,[], 'suppressed');
  add('before','Sensor fault before opening','fault',37600,[], 'shown');
  add('before','Fault acknowledged before opening','clearFault',37630,[['fault',37600]],'shown');
  add('before','Power outage before opening','powerOff',37640,[],'shown');
  add('before','Restart while closed','powerOn',37650,[['powerOff',37640]],'shown');
  add('open','Open shop at 10:45','open',DAY_START,[],'shown');
  add('open','Double opening is ignored','open',DAY_START+1,open(),'suppressed');
  add('open','First guest comes in','approach',DAY_START+25,open(),'shown');
  add('open','Second near trigger too soon','approach',DAY_START+28,[...open(),['approach',DAY_START+25]],'suppressed');
  add('open','Guest remains near sensor','approach',DAY_START+49,[...open(),['approach',DAY_START+25]],'suppressed');
  add('open','Greet new arrival after cooldown','approach',DAY_START+60,[...open(),['approach',DAY_START+25]],'shown');
  add('open','Person walking past door','walkPast',DAY_START+70,open(),'suppressed');
  add('open','Accidental double sensor pulse','tapping',DAY_START+80,open(),'suppressed');
  add('open','Long gentle head pet','long',DAY_START+95,open(),'shown');
  add('open','Single head tap','single',DAY_START+108,open(),'shown');
  add('open','Two taps make robot shy','double',DAY_START+120,open(),'shown');
  add('morning','Three taps show love','triple',41100,open(),'shown');
  add('morning','Wave by staff control','wave',41120,open(),'shown');
  add('morning','Unknown gesture without camera','unauthorized',41130,open(),'suppressed');
  add('morning','Look at visitor without face recognition','look',41145,open(),'shown');
  add('morning','Quick goodbye after hello','farewell',41150,[...open(),['approach',41139]],'shown');
  add('morning','Too much automatic talking prevented','triple',41159,[...open(),['approach',41145]],'shown');
  add('morning','Touch while network is offline','single',41300,[...open(),['wifiOff',41200]],'shown');
  add('morning','Reconnect after Wi-Fi returns','wifiOn',41330,[...open(),['wifiOff',41200]],'shown');
  add('morning','Repeated Wi-Fi loss ignored','wifiOff',41355,[...open(),['wifiOff',41200]],'suppressed');
  add('morning','Photo pose 10 seconds','photo',42000,open(),'shown');
  add('morning','Pet during photo pose ignored','single',42004,[...open(),['photo',42000]],'suppressed');
  add('morning','Another photo after pose','photo',42016,[...open(),['photo',42000]],'shown');
  add('morning','Staff cancels photo pose','socialStop',42005,[...open(),['photo',42000]],'shown');
  add('lunch','Rush-hour silent mode starts','crowdOn',46800,open(),'shown');
  add('lunch','Welcome without voice in rush','approach',46810,[...open(),['crowdOn',46800]],'shown');
  add('lunch','Touch should be quiet in rush','single',46814,[...open(),['crowdOn',46800]],'shown');
  add('lunch','Love reaction no speech in rush','triple',46820,[...open(),['crowdOn',46800]],'shown');
  add('lunch','No dance to distract workers','dance',46830,[...open(),['crowdOn',46800]],'suppressed');
  add('lunch','No reels performance in rush','reels',46840,[...open(),['crowdOn',46800]],'suppressed');
  add('lunch','Busy mode does not double-activate','crowdOn',46850,[...open(),['crowdOn',46800]],'suppressed');
  add('lunch','Worker requests mute','staffMute',46900,open(),'shown');
  add('lunch','Muted robot stays visually interactive','single',46910,[...open(),['staffMute',46900]],'shown');
  add('lunch','Unmute after busy period','staffUnmute',46920,[...open(),['staffMute',46900]],'shown');
  add('lunch','Crowd over restores normal movement','crowdOff',50000,[...open(),['crowdOn',46800]],'shown');
  add('lunch','No-op crowd reset when not busy','crowdOff',50010,open(),'suppressed');
  add('afternoon','Rest after 5 min inactivity','idle',57800,open(),'shown');
  add('afternoon','Do not sleep immediately after touch','idle',58010,[...open(),['single',58000]],'suppressed');
  add('afternoon','Wake on new guest after rest','approach',58020,[...open(),['idle',57800]],'shown');
  add('afternoon','Staff starts cleaning','clean',58030,open(),'shown');
  add('afternoon','Touch while cleaning ignored','single',58040,[...open(),['clean',58030]],'suppressed');
  add('afternoon','Welcome while cleaning ignored','approach',58045,[...open(),['clean',58030]],'suppressed');
  add('afternoon','Cleaning finished','unclean',58055,[...open(),['clean',58030]],'shown');
  add('afternoon','Birthday only with staff action','birthday',58300,open(),'shown');
  add('afternoon','Untrusted birthday trigger blocked','birthday',58310,open(),'suppressed','untrusted');
  add('afternoon','Selfie holds face pose','selfie',58400,open(),'shown');
  add('afternoon','Instagram pose for photo','instagram',58420,open(),'shown');
  add('afternoon','Staff starts quiet music/dance demo','dance',58500,open(),'shown');
  add('afternoon','Worker announces falafel is ready','foodReady',58520,open(),'shown');
  add('evening','Evening guests welcomed normally','approach',68400,open(),'shown');
  add('evening','Fast farewell stays friendly','farewell',68430,open(),'shown');
  add('evening','Photo request during evening','photo',68500,open(),'shown');
  add('evening','Battery/power goes out','powerOff',68600,open(),'shown');
  add('evening','Touch ignored while off','single',68605,[...open(),['powerOff',68600]],'suppressed');
  add('evening','Power returns without re-greeting','powerOn',68620,[...open(),['powerOff',68600]],'shown');
  add('evening','Sensor reports fault','fault',68700,open(),'shown');
  add('evening','Guest interaction ignored during fault','approach',68710,[...open(),['fault',68700]],'suppressed');
  add('evening','Dance ignored during fault','dance',68712,[...open(),['fault',68700]],'suppressed');
  add('evening','Fault cleared by worker','clearFault',68720,[...open(),['fault',68700]],'shown');
  add('evening','Repeated fault clear is no-op','clearFault',68730,open(),'suppressed');
  add('evening','Unknown commands do nothing','unauthorized',68740,open(),'suppressed');
  add('close','Shop closes exactly at 21:30','close',DAY_END,open(),'shown');
  add('close','Close twice does not talk twice','close',DAY_END+1,[...open(),['close',DAY_END]],'suppressed');
  add('close','No guest welcome after closing','approach',DAY_END+10,[...open(),['close',DAY_END]],'suppressed');
  add('close','Closing cancels active photo','close',DAY_END,[...open(),['photo',DAY_END-5]],'shown');
  add('close','Closing cancels celebration','close',DAY_END,[...open(),['birthday',DAY_END-3]],'shown');
  add('after','No accidental night speech','triple',78340,[...open(),['close',DAY_END]],'suppressed');
  add('after','No late-night music command','dance',78380,[...open(),['close',DAY_END]],'suppressed');
  add('after','Reopening after closing blocked','open',78400,[...open(),['close',DAY_END]],'suppressed');
  add('after','Restart after closing stays asleep','powerOn',78420,[...open(),['close',DAY_END],['powerOff',78410]],'shown');
  add('after','No interaction if forgot close command','approach',DAY_END+100,open(),'suppressed');
  add('after','Reopen command outside hours rejected','open',DAY_END+120,[],'suppressed');
  Object.freeze(C);
  function evaluate(test){
    let state=initial();
    for(const [event,at] of test.setup){state=dispatch(state,event,at).state;}
    return dispatch(state,test.event,test.at,{untrusted:test.note==='untrusted'});
  }
  function getPhase(id){return PHASES.find(p=>p.id===id)||PHASES[0];}
  function validate(){
    return C.map(test=>{const output=evaluate(test).output;return {
      id:test.id,name:test.name,phase:test.phase,event:test.event,expected:test.expect,
      actual:output.mode,reason:output.reason,passed:output.mode===test.expect,
      mood:output.mood,quiet:output.quiet,say:output.say
    };});
  }
  root.NohutcukDay=Object.freeze({initial,dispatch,evaluate,validate,getPhase,
    scenarios:C,phases:PHASES,DAY_START,DAY_END});
})(window);
