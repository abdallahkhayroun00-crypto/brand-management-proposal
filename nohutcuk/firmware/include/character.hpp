#pragma once
#include <stdint.h>

namespace nohut {
enum class Mood : uint8_t {
  Normal, Happy, Love, Shy, Laughing, Sad, Angry, Sleeping,
  Surprised, Thinking, Cool, Kissing, Hungry, Dizzy, Bored,
  Celebrating, Hello, Goodbye, Confused, Drama, COUNT
};
static constexpr unsigned MOOD_COUNT=static_cast<unsigned>(Mood::COUNT);
static constexpr const char* MOOD_NAMES[]={
  "normal","happy","love","shy","laughing","sad","angry","sleeping",
  "surprised","thinking","cool","kissing","hungry","dizzy","bored",
  "celebrating","hello","goodbye","confused","drama"
};
static_assert(sizeof(MOOD_NAMES)/sizeof(MOOD_NAMES[0])==MOOD_COUNT,"All 20 moods must have names");

inline const char* name(Mood m){
  unsigned n=static_cast<unsigned>(m);
  return n<MOOD_COUNT?MOOD_NAMES[n]:"invalid";
}
inline bool fromName(const char* str,Mood& result){
  if(!str)return false;
  for(unsigned i=0;i<MOOD_COUNT;i++){
    const char*a=str,*b=MOOD_NAMES[i];
    while(*a&&*b&&*a==*b){++a;++b;}
    if(!*a&&!*b){result=static_cast<Mood>(i);return true;}
  }
  return false;
}
inline bool elapsed(uint32_t now,uint32_t then,uint32_t duration){
  return static_cast<uint32_t>(now-then)>=duration;
}

class Character {
public:
  void begin(uint32_t now){mood_=Mood::Normal;lastInteraction_=now;hold_=0;hasWelcomed_=false;quiet_=false;demo_=false;}
  Mood mood()const{return mood_;}
  bool quiet()const{return quiet_;}
  bool isDemo()const{return demo_;}
  void setQuiet(bool quiet){quiet_=quiet;}
  void setDemo(bool demo){demo_=demo;}
  void show(Mood mood,uint32_t now,uint32_t holdMs=3500){
    mood_=mood;lastInteraction_=now;poseAt_=now;hold_=holdMs;
  }
  bool isPoseActive(uint32_t now)const{return hold_>0&&!elapsed(now,poseAt_,hold_);}
  bool approach(uint32_t now){
    if(hasWelcomed_&&!elapsed(now,lastWelcome_,30000))return false;
    hasWelcomed_=true;lastWelcome_=now;show(Mood::Hello,now,2500);
    return true;
  }
  void touch(uint8_t taps,bool longPress,uint32_t now){
    if(isPoseActive(now)&&((mood_==Mood::Shy&&hold_==10000)||(mood_==Mood::Happy&&hold_==10000)))return;
    show(longPress?Mood::Sleeping:taps>=3?Mood::Love:taps==2?Mood::Shy:Mood::Happy,now,2500);
  }
  void photo(uint32_t now,bool selfie){show(selfie?Mood::Shy:Mood::Happy,now,10000);}
  void stopPose(uint32_t now){show(Mood::Normal,now,0);}
  void update(uint32_t now){
    if(hold_ && elapsed(now,poseAt_,hold_)) {
      hold_=0;mood_=Mood::Normal;
    }
    if(!hold_&&mood_==Mood::Normal&&elapsed(now,lastInteraction_,30000))
      mood_=Mood::Sleeping;
  }
private:
  Mood mood_=Mood::Normal;
  uint32_t lastInteraction_=0;
  uint32_t lastWelcome_=0;
  uint32_t poseAt_=0;
  uint32_t hold_=0;
  bool hasWelcomed_=false;
  bool quiet_=false;
  bool demo_=false;
};
} // namespace nohut
