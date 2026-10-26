#include <Arduino.h>
#include <Arduino_GFX_Library.h>
#include "pins.h"
#include "character.hpp"

// Nohutçuk bench firmware. Real SPI color display; optional touch/proximity
// sensors require explicit build flags + wiring. NO servo/audio/Wi-Fi integration.
// Code is open-loop and must be validated on actual chosen hardware.
static Arduino_DataBus* bus = new Arduino_HWSPI(
  nohut::LCD_DC, nohut::LCD_CS, nohut::LCD_SCLK, nohut::LCD_MOSI);
#if NOHUT_DISPLAY_ILI9341
// Selected purchase target: Waveshare 2.4" ILI9341, portrait panel in landscape.
static Arduino_GFX* gfx = new Arduino_ILI9341(bus, nohut::LCD_RST, 1 /* 320x240 landscape */);
#else
// Old reference only: Waveshare 1.9" ST7789V2 with RAM offset.
static Arduino_GFX* gfx = new Arduino_ST7789(
  bus, nohut::LCD_RST, 1 /* landscape */, 0 /* IPS */,
  nohut::PANEL_NATIVE_W, nohut::PANEL_NATIVE_H,
  nohut::PANEL_OFFSET_X, 0, nohut::PANEL_OFFSET_X, 0);
#endif
static nohut::Character character;
static bool displayReady=false;

static uint16_t rgb(uint8_t r,uint8_t g,uint8_t b){
  return static_cast<uint16_t>(((r&0xf8)<<8)|((g&0xfc)<<3)|(b>>3));
}
constexpr uint16_t BLACK=0x0000;
static uint16_t pink(){return rgb(255,130,192);}
static uint16_t colorFor(nohut::Mood m){
  using nohut::Mood;
  switch(m){
    case Mood::Love:case Mood::Kissing:return pink();
    case Mood::Shy:case Mood::Dizzy:case Mood::Confused:return rgb(204,165,250);
    case Mood::Celebrating:return rgb(255,215,95);
    case Mood::Angry:case Mood::Drama:return rgb(255,112,114);
    case Mood::Sad:case Mood::Sleeping:case Mood::Goodbye:return rgb(125,175,245);
    case Mood::Hungry:return rgb(167,240,135);
    case Mood::Cool:return rgb(115,245,225);
    default:return rgb(135,233,255);
  }
}
static uint32_t lastBlink=0,lastFrame=0,demoAt=0;
static unsigned demoIndex=0;
static bool inBlink(uint32_t now){
  if(nohut::elapsed(now,lastBlink,3400)){lastBlink=now;return true;}
  return static_cast<uint32_t>(now-lastBlink)<110;
}
static void bar(int x,int y,int w,int h,int rad,uint16_t color){
  if(w<1||h<1)return;
  gfx->fillRoundRect(x,y,w,h,rad,color);
}
static void happyArc(int x,int y,uint16_t col){
  // Five short line segments create a curved eyelid (happy smile).
  gfx->drawLine(x-28,y+17,x-20,y-1,col);
  gfx->drawLine(x-20,y-1,x-7,y-12,col);
  gfx->drawLine(x-7,y-12,x+7,y-12,col);
  gfx->drawLine(x+7,y-12,x+20,y-1,col);
  gfx->drawLine(x+20,y-1,x+28,y+17,col);
  gfx->drawLine(x-28,y+18,x-20,y,col);
  gfx->drawLine(x+20,y,x+28,y+18,col);
}
static void heart(int x,int y,uint16_t col){
  gfx->fillCircle(x-11,y-7,14,col);
  gfx->fillCircle(x+11,y-7,14,col);
  gfx->fillTriangle(x-23,y-1,x+23,y-1,x,y+29,col);
}
static void star(int x,int y,uint16_t col){
  gfx->fillTriangle(x,y-28,x-12,y+8,x+12,y+8,col);
  gfx->fillTriangle(x-28,y-9,x+28,y-9,x,y+28,col);
}
static void closedEye(int x,int y,uint16_t col){
  gfx->drawLine(x-26,y+7,x-8,y+12,col);
  gfx->drawLine(x-8,y+12,x+8,y+12,col);
  gfx->drawLine(x+8,y+12,x+26,y+7,col);
}
static void drawEye(nohut::Mood mood,int x,int y,bool left,uint16_t col,bool blink){
  using nohut::Mood;
  if(blink&&mood!=Mood::Sleeping&&mood!=Mood::Bored){
    closedEye(x,y,col);return;
  }
  switch(mood){
    case Mood::Happy:case Mood::Hello:case Mood::Laughing:
      happyArc(x,y,col);break;
    case Mood::Love:heart(x,y,col);break;
    case Mood::Shy:
      bar(x-20,y+5,40,20,10,col);break;
    case Mood::Sad:
      gfx->drawLine(x-23,y-12,x,y+10,col);
      gfx->drawLine(x,y+10,x+23,y-12,col);break;
    case Mood::Angry:case Mood::Drama:
      if(left)gfx->fillTriangle(x-29,y-20,x+26,y-5,x-13,y+27,col);
      else gfx->fillTriangle(x+29,y-20,x-26,y-5,x+13,y+27,col);
      break;
    case Mood::Sleeping:case Mood::Bored:closedEye(x,y,col);break;
    case Mood::Surprised:
      gfx->fillCircle(x,y,26,col);gfx->fillCircle(x,y,9,BLACK);break;
    case Mood::Thinking:
      if(left)bar(x-13,y-16,26,34,13,col);
      else {gfx->drawCircle(x,y-6,14,col);gfx->fillCircle(x,y+23,3,col);}break;
    case Mood::Cool:
      bar(x-31,y-17,62,38,9,col);
      gfx->drawLine(x-20,y-9,x+7,y-9,BLACK);break;
    case Mood::Kissing:
      if(left)closedEye(x,y,col);
      else heart(x,y,col);
      break;
    case Mood::Hungry:
      gfx->fillCircle(x,y,27,col);gfx->fillCircle(x,y,12,BLACK);break;
    case Mood::Dizzy:
      gfx->drawCircle(x,y,24,col);gfx->drawCircle(x-6,y-5,14,col);
      gfx->fillCircle(x-8,y-5,5,col);break;
    case Mood::Celebrating:star(x,y,col);break;
    case Mood::Goodbye:
      if(left)happyArc(x,y,col);
      else bar(x-17,y-24,34,56,15,col);
      break;
    case Mood::Confused:
      if(left)bar(x-12,y-22,24,47,12,col);
      else closedEye(x,y,col);
      break;
    default:bar(x-22,y-35,44,74,22,col);break;
  }
}
static void faceFrame(uint32_t now){
  // Keep both eyes proportional on either 320x240 or legacy 320x170.
  const int verticalOffset=(nohut::FACE_H-170)/2;
  const auto mood=character.mood();
  const uint16_t col=colorFor(mood);
  // No transparent overlays or bitmaps; every frame is drawn from primitives.
  gfx->fillScreen(BLACK);
  const bool blink=inBlink(now);
  drawEye(mood,103,76+verticalOffset,true,col,blink);
  drawEye(mood,217,76+verticalOffset,false,col,blink);
  if(mood==nohut::Mood::Shy||mood==nohut::Mood::Kissing){
    bar(36,130+verticalOffset,32,8,4,rgb(250,104,158));
    bar(250,130+verticalOffset,32,8,4,rgb(250,104,158));
  }
  if(mood==nohut::Mood::Celebrating){
    gfx->fillCircle(35,25+verticalOffset,6,pink());
    gfx->fillCircle(289,136+verticalOffset,6,rgb(122,240,155));
  }
  if(mood==nohut::Mood::Sleeping){
    gfx->setTextColor(rgb(144,181,248));
    gfx->setTextSize(2);gfx->setCursor(275,18+verticalOffset);gfx->print("zZ");
  }
  // Bright ambient indicator; no touch/servo/audio operation implied.
  gfx->fillCircle(160,152+verticalOffset,3,col);
}

#if NOHUT_ENABLE_TOUCH
static bool lastRawTouch=false,stableTouch=false,longSent=false;
static uint32_t rawChanged=0,downAt=0,upAt=0;
static uint8_t tapCount=0;
static void pollTouch(uint32_t now){
  const bool raw=digitalRead(nohut::TOUCH_OUT)==HIGH;
  if(raw!=lastRawTouch){lastRawTouch=raw;rawChanged=now;}
  if(raw!=stableTouch && nohut::elapsed(now,rawChanged,35)){
    stableTouch=raw;
    if(raw){downAt=now;longSent=false;}
    else if(!longSent){if(tapCount<3)tapCount++;upAt=now;}
  }
  if(stableTouch&&!longSent&&nohut::elapsed(now,downAt,700)){
    longSent=true;tapCount=0;character.touch(1,true,now);
    Serial.println("touch LONG");
  }
  if(!stableTouch&&tapCount>0&&nohut::elapsed(now,upAt,360)){
    character.touch(tapCount,false,now);
    Serial.printf("touch count %u\n",tapCount);
    tapCount=0;
  }
}
#endif

// A real distance sensor should be added only after the screen is verified.
// Optional Adafruit VL53L0X implementation is compiled when the flag is 1.
#if NOHUT_ENABLE_TOF
#include <Wire.h>
#include <Adafruit_VL53L0X.h>
static Adafruit_VL53L0X tof;
static bool tofReady=false,inRange=false;
static uint32_t sensorAt=0;
static void pollDistance(uint32_t now){
  if(!tofReady||!nohut::elapsed(now,sensorAt,250))return;
  sensorAt=now;
  VL53L0X_RangingMeasurementData_t data;
  tof.rangingTest(&data,false);
  if(data.RangeStatus==4){inRange=false;return;}
  // Hysteresis avoids repeated greetings at the threshold.
  if(data.RangeMilliMeter<650&&!inRange){
    inRange=true;if(character.approach(now))Serial.println("welcome via ToF");
  }
  if(data.RangeMilliMeter>1000)inRange=false;
}
#endif

static String serialLine;
static void help(){
  Serial.println("Nohutcuk bench: help, list, mood <name>, next, normal, greet, tap1, tap2, tap3, long, photo, selfie, stop, demo, quiet on|off");
}
static void handleCommand(String cmd,uint32_t now){
  cmd.trim();cmd.toLowerCase();
  if(cmd=="help"){help();return;}
  if(cmd=="list"){
    for(unsigned i=0;i<nohut::MOOD_COUNT;i++){Serial.print(nohut::MOOD_NAMES[i]);Serial.print(i+1==nohut::MOOD_COUNT?'\n':' ');}return;
  }
  if(cmd=="next"){character.show(static_cast<nohut::Mood>(demoIndex++%nohut::MOOD_COUNT),now,4500);}
  else if(cmd=="normal")character.stopPose(now);
  else if(cmd=="greet")character.approach(now);
  else if(cmd=="tap1")character.touch(1,false,now);
  else if(cmd=="tap2")character.touch(2,false,now);
  else if(cmd=="tap3")character.touch(3,false,now);
  else if(cmd=="long")character.touch(1,true,now);
  else if(cmd=="photo")character.photo(now,false);
  else if(cmd=="selfie")character.photo(now,true);
  else if(cmd=="stop"){character.stopPose(now);character.setDemo(false);}
  else if(cmd=="demo"){character.setDemo(!character.isDemo());demoAt=now;}
  else if(cmd=="quiet on")character.setQuiet(true);
  else if(cmd=="quiet off")character.setQuiet(false);
  else if(cmd.startsWith("mood ")){
    nohut::Mood choice;
    if(nohut::fromName(cmd.substring(5).c_str(),choice))character.show(choice,now,4500);
    else {Serial.println("Unknown mood. Type list.");return;}
  }else{Serial.println("Unknown command. Type help.");return;}
  Serial.print("mood=");Serial.println(nohut::name(character.mood()));
}
static void pollSerial(uint32_t now){
  while(Serial.available()){
    const char c=static_cast<char>(Serial.read());
    if(c=='\n'||c=='\r'){
      if(serialLine.length())handleCommand(serialLine,now);
      serialLine="";
    }else if(serialLine.length()<63&&c>=32&&c<=126)serialLine+=c;
  }
}

void setup(){
  Serial.begin(115200);
  character.begin(millis());
#if NOHUT_ENABLE_TOUCH
  pinMode(nohut::TOUCH_OUT,INPUT); // TTP223 active HIGH, external 3.3V only
#endif
#if NOHUT_ENABLE_TOF
  Wire.begin(nohut::TOF_SDA,nohut::TOF_SCL);
  tofReady=tof.begin();
  Serial.printf("VL53L0X %s\n",tofReady?"ready":"NOT FOUND");
#endif
  // The Waveshare breakout BL pin is a backlight CONTROL input, not an LED
  // supply. Use its pin with the provisional control map after checking wiring.
  pinMode(nohut::LCD_BL,OUTPUT);
  digitalWrite(nohut::LCD_BL,HIGH);
  displayReady=gfx->begin(24000000);
  if(!displayReady){
    Serial.println("ERROR: LCD begin failed. Verify SPI pinout, display revision.");
    return;
  }
  gfx->fillScreen(BLACK);
#if NOHUT_DISPLAY_ILI9341
  Serial.println("Nohutcuk ESP32-S3 2.4in ILI9341 320x240 COLOR EYES bench build (no audio or servo).");
#else
  Serial.println("Nohutcuk ESP32-S3 legacy 1.9in ST7789 320x170 COLOR EYES bench build.");
#endif
  help();
}
void loop(){
  const uint32_t now=millis();
  pollSerial(now);
#if NOHUT_ENABLE_TOUCH
  pollTouch(now);
#endif
#if NOHUT_ENABLE_TOF
  pollDistance(now);
#endif
  if(character.isDemo()&&nohut::elapsed(now,demoAt,3500)){
    demoAt=now;
    character.show(static_cast<nohut::Mood>(demoIndex++%nohut::MOOD_COUNT),now,3300);
  }
  character.update(now);
  if(displayReady&&nohut::elapsed(now,lastFrame,100)){lastFrame=now;faceFrame(now);}
  delay(1);
}
