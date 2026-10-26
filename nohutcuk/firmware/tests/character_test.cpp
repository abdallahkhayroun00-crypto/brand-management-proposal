// Native C++ contract tests: no Arduino SDK/hardware required.
// Compile: g++ -std=c++17 -Wall -Wextra -Werror -Ifirmware/include firmware/tests/character_test.cpp -o /tmp/nohut-test
#include "character.hpp"
#include <cassert>
#include <cstring>
#include <iostream>
using namespace nohut;
int main(){
  static_assert(MOOD_COUNT==20,"20 eyes required");
  Character bot;bot.begin(1000);
  assert(bot.mood()==Mood::Normal);
  for(unsigned i=0;i<MOOD_COUNT;i++){
    Mood parsed=Mood::Normal;
    assert(fromName(MOOD_NAMES[i],parsed));
    assert(static_cast<unsigned>(parsed)==i);
    assert(std::strcmp(MOOD_NAMES[i],name(parsed))==0);
  }
  Mood parsed;
  assert(!fromName("yemeksepeti",parsed));
  assert(!fromName("FAKE",parsed));
  assert(!fromName(nullptr,parsed));
  assert(bot.approach(2000));
  assert(bot.mood()==Mood::Hello);
  assert(!bot.approach(2001));
  assert(!bot.approach(31999));
  assert(bot.approach(32000));
  bot.update(34501);
  assert(bot.mood()==Mood::Normal);
  bot.touch(1,false,34510);assert(bot.mood()==Mood::Happy);
  bot.touch(2,false,34520);assert(bot.mood()==Mood::Shy);
  bot.touch(3,false,34530);assert(bot.mood()==Mood::Love);
  bot.touch(1,true,34540);assert(bot.mood()==Mood::Sleeping);
  bot.photo(34600,false);
  assert(bot.mood()==Mood::Happy);
  assert(bot.isPoseActive(34800));
  bot.touch(1,false,34850);
  assert(bot.mood()==Mood::Happy);
  bot.update(44599);
  assert(bot.mood()==Mood::Happy);
  bot.update(44600);
  assert(bot.mood()==Mood::Normal);
  bot.photo(45000,true);
  assert(bot.mood()==Mood::Shy);
  bot.touch(2,false,45001);
  assert(bot.mood()==Mood::Shy);
  bot.stopPose(45100);
  assert(bot.mood()==Mood::Normal);
  bot.update(80000);
  assert(bot.mood()==Mood::Sleeping);
  bot.setQuiet(true);assert(bot.quiet());
  bot.setQuiet(false);assert(!bot.quiet());
  bot.setDemo(true);assert(bot.isDemo());
  bot.setDemo(false);assert(!bot.isDemo());
  // millis() wraps every ~49.7 days. Time delta arithmetic must survive.
  assert(elapsed(15,UINT32_MAX-9,24));
  assert(!elapsed(15,UINT32_MAX-9,25));
  Character afterWrap;afterWrap.begin(UINT32_MAX-500);
  assert(afterWrap.approach(UINT32_MAX-400));
  assert(!afterWrap.approach(15));
  assert(afterWrap.approach(30000));
  std::cout<<"PASS: 20 moods + touch, photo lock, welcome cooldown, idle sleep, quiet, invalid command and uint32 rollover"<<std::endl;
}
