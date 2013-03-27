#include <OneWire.h>
#include <WProgram.h>
/* DS18S20 Temperature chip i/o */
#include <Wire.h>
#include <DS1307.h>

OneWire  ds(3);  // on pin 3
byte Tdata[12];
int rtc[7];
//int deviceaddress = 0x50;
int deviceaddress = 0x52;
int addr=0; //first address
int lastTime;
byte saveDate[6];
boolean full=false;
int ledPin = 13; 
int outpin=3;
int val = 0;     // variable to store the read value


void writeByte(unsigned int eeaddress, byte data ) {
    int rdata = data;
    Wire.beginTransmission(deviceaddress);
    Wire.send((byte)(eeaddress >> 8)); // MSB
    Wire.send((byte)(eeaddress & 0xFF)); // LSB
    Wire.send(rdata);
    Wire.endTransmission();
}

  // WARNING: address is a page address, 6-bit end will wrap around
  // also, data can be maximum of about 30 bytes, because the Wire library has a buffer of 32 bytes
void writePage(unsigned int eeaddresspage, byte* data, byte length ) {
    Wire.beginTransmission(deviceaddress);
    Wire.send((byte)(eeaddresspage >> 8)); // MSB
    Wire.send((byte)(eeaddresspage & 0xFF)); // LSB
    byte c;
    for ( c = 0; c < length; c++)
      Wire.send(data[c]);
    Wire.endTransmission();
}

byte readByte(unsigned int eeaddress ) {
    byte rdata = 0xFF;
    Wire.beginTransmission(deviceaddress);
    Wire.send((byte)(eeaddress >> 8)); // MSB
    Wire.send((byte)(eeaddress & 0xFF)); // LSB
    Wire.endTransmission();
    Wire.requestFrom(deviceaddress,1);
    if (Wire.available()) rdata = Wire.receive();
    return rdata;
}

  // maybe let's not read more than 30 or 32 bytes at a time!
void readBuffer(unsigned int eeaddress, byte *buffer, int length ) {
    Wire.beginTransmission(deviceaddress);
    Wire.send((byte)(eeaddress >> 8)); // MSB
    Wire.send((byte)(eeaddress & 0xFF)); // LSB
    Wire.endTransmission();
    Wire.requestFrom(deviceaddress,length);
    int c = 0;
    for ( c = 0; c < length; c++ )
      if (Wire.available()) buffer[c] = Wire.receive();
}

void showRecord(void){
  byte i=0;
  byte Date[30];
 Serial.println("Show Record:");
 readBuffer(0, (byte *)Date, 30);
    for(i=0;i<30;i++){
        Serial.print(Date[i],DEC);
        Serial.print(" ");
    }
}
void showStr(void){
  byte i=0;
  byte Date[30];
 Serial.println("Show Record:");
 readBuffer(0, (byte *)Date, 30);
    for(i=0;i<30;i++){
        Serial.print(Date[i],HEX);
    }
}


void DS1302_SetOut(byte data ) {
    Wire.beginTransmission(B1101000);
    Wire.send(7); // LSB
    Wire.send(data);
    Wire.endTransmission();
}
byte DS1302_GetOut(void) {
    byte rdata = 0xFF;
    Wire.beginTransmission(B1101000);
    Wire.send(7); // LSB
    Wire.endTransmission();
    Wire.requestFrom(B1101000,1);
    if (Wire.available()) {
      rdata = Wire.receive();
      Serial.println(rdata,HEX);
    }
    return rdata;
}
void setup() 
{
  Serial.begin(9600);
  DDRC|=_BV(2) |_BV(3);
  PORTC |=_BV(3);
  DS1302_SetOut(0x00);
  RTC.get(rtc,true);
  if(rtc[6]<2011){
    RTC.stop();
    RTC.set(DS1307_SEC,1);
    RTC.set(DS1307_MIN,52);
    RTC.set(DS1307_HR,16);
    RTC.set(DS1307_DOW,2);
    RTC.set(DS1307_DATE,25);
    RTC.set(DS1307_MTH,1);
    RTC.set(DS1307_YR,11);
    RTC.start();
  }
  // writePage(0, (byte *)somedata, sizeof(somedata)); // write to EEPROM 
    pinMode(ledPin,OUTPUT);
    pinMode(outpin,INPUT);
    pinMode(4,OUTPUT);
     digitalWrite(4, LOW); 
     byte testStr[]={1,2,3,4,5,6,7,8,9,10,11};
     writePage(0, (byte *)testStr, sizeof(testStr));
     delay(100);
     showStr();
}

void loop() 
{

  byte i;
  byte present = 0;
  unsigned int Temper=0;
  float TT=0.0;
  byte incomingByte =0;
  if (Serial.available() > 0) {
     incomingByte  = Serial.read();
     if(incomingByte==0xff){
         DS1302_GetOut();
     }else{
        DS1302_SetOut(incomingByte);
        DS1302_GetOut();
     }
  }
  ds.reset();
  ds.write(0xCC,1);
  ds.write(0x44,1);         // start conversion, with parasite power on at the end
  RTC.get(rtc,true);
  if(rtc[6]<2011){
    RTC.stop();
    RTC.set(DS1307_SEC,1);
    RTC.set(DS1307_MIN,52);
    RTC.set(DS1307_HR,16);
    RTC.set(DS1307_DOW,2);
    RTC.set(DS1307_DATE,25);
    RTC.set(DS1307_MTH,1);
    RTC.set(DS1307_YR,11);
    RTC.start();
    DS1302_SetOut(0x00);
  }
  digitalWrite(ledPin, HIGH);   // sets the LED on
  delay(500);                 
  if(!full)    digitalWrite(ledPin, LOW);   
  delay(500);                 
   val = digitalRead(outpin);   // read the 
//------------------------

  if(val==LOW){
     Serial.println("Show Record:");
    showRecord();
    
  }else if((rtc[0]%2==0) && (!full) ){  //
      lastTime =rtc[1];
      present = ds.reset();
      ds.write(0xCC,1);    
      ds.write(0xBE);         // Read Scratchpad
      if(present){
          for(int i=0; i<7; i++)
        {
          Serial.print(rtc[i]);
          Serial.print(" ");
        }
       for ( i = 0; i < 9; i++) {           // we need 9 bytes
          Tdata[i] = ds.read();
        }
        Serial.print("\t Temperature=");
        Temper = (Tdata[1]<<8 | Tdata[0]);
        TT =Temper*0.0625;
        //12	11	10	9
        //750       375     187.5   93.75
        //0.0625	0.125	0.25	0.5	
        Serial.println(TT);
      }     
     saveDate[0]=rtc[4];  //DATE
     saveDate[1]=rtc[2];  //HOU
     saveDate[2]=rtc[1];  //MIN
     saveDate[3]=rtc[0];  //SEC
     saveDate[4]=Tdata[0];
     saveDate[5]=Tdata[1];
     writePage(addr, (byte *)saveDate, sizeof(saveDate));
     addr+=sizeof(saveDate);
     if(addr>4090){
       full=true;
       saveDate[0]=0xEE;
       saveDate[1]=0xEE;
       saveDate[2]=0xEE;
       writePage(addr, (byte *)saveDate,3);
       addr+=3;
     }
  }
  
}


