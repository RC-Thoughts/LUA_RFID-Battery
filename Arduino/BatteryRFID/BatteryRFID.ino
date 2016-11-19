/*
   --------------------------------------------------------
          Jeti RFID-Battery version 1.0
   --------------------------------------------------------
   
    Tero Salminen RC-Thoughts.com 2016 www.rc-thoughts.com

    - Improved performance from previous solutions
    - Compatibility with Jeti R- and REX-receivers improved
    - RFID-tag Writing via Jetibox from transmitter added
    - Compatible with DC/DS-14/16/24
    - Code housekeeping (Poorly...)
   --------------------------------------------------------
     ALWAYS test functions thoroughly before use!
   --------------------------------------------------------
    Huge thanks to pioneering work of 
    Alastair Cormack alastair.cormack@gmail.com
   --------------------------------------------------------
    This is made possible by the original work of:
    
    Mav2Duplex by DevFor8.com, info@devfor8.com
    RFID by Dr.Leong www..b2cqshop.com
    Miguel Balboa www.circuitito.com Jan 2012
    Søren Thing Andersen fall of 2013
    Rudy Schlaf  www.makecourse.com
   --------------------------------------------------------
    Shared under MIT-license by Tero Salminen 2016
   --------------------------------------------------------
*/

#include <EEPROM.h>
#include <SoftwareSerialJeti.h>
#include <JETI_EX_SENSOR.h>
#include <SPI.h>
#include <MFRC522.h>

#define SS_PIN 10
#define RST_PIN 5
MFRC522 mfrc522(SS_PIN, RST_PIN);
MFRC522::MIFARE_Key key;

#define prog_char char PROGMEM
#define GETCHAR_TIMEOUT_ms 20

#ifndef JETI_RX
#define JETI_RX 3
#endif

#ifndef JETI_TX
#define JETI_TX 4
#endif

short int uBatteryID;
short int uCapacity;
short int uCycles;
short int uCells;
short int wBatteryID;
short int wCapacity;
short int wCycles;
short int wCells;

#define ITEMNAME_1 F("ID")
#define ITEMTYPE_1 F("")
#define ITEMVAL_1 &uBatteryID

#define ITEMNAME_2 F("Capacity")
#define ITEMTYPE_2 F("mAh")
#define ITEMVAL_2 &uCapacity

#define ITEMNAME_3 F("Cycles")
#define ITEMTYPE_3 F("")
#define ITEMVAL_3 &uCycles

#define ITEMNAME_4 F("Cells")
#define ITEMTYPE_4 F("")
#define ITEMVAL_4 &uCells

#define ABOUT_1 F(" RCT Jeti Tools")
#define ABOUT_2 F("  RFID-Battery")

SoftwareSerial JetiSerial(JETI_RX, JETI_TX);

void JetiUartInit()
{
  JetiSerial.begin(9800);
}

void JetiTransmitByte(unsigned char data, boolean setBit9)
{
  JetiSerial.set9bit = setBit9;
  JetiSerial.write(data);
  JetiSerial.set9bit = 0;
}

unsigned char JetiGetChar(void)
{
  unsigned long time = millis();
  while ( JetiSerial.available()  == 0 )
  {
    if (millis() - time >  GETCHAR_TIMEOUT_ms)
      return 0; // return, if timout occures
  }
  int read = -1;
  if (JetiSerial.available() > 0 )
  {
    read = JetiSerial.read();
  }
  long wait = (millis() - time) - GETCHAR_TIMEOUT_ms;
  if (wait > 0)
    delay(wait);
  return read;
}

char * floatToString(char * outstr, float value, int places, int minwidth = 0) {
  int digit;
  float tens = 0.1;
  int tenscount = 0;
  int i;
  float tempfloat = value;
  int c = 0;
  int charcount = 1;
  int extra = 0;
  float d = 0.5;
  if (value < 0)
    d *= -1.0;
  for (i = 0; i < places; i++)
    d /= 10.0;
  tempfloat +=  d;
  if (value < 0)
    tempfloat *= -1.0;
  while ((tens * 10.0) <= tempfloat) {
    tens *= 10.0;
    tenscount += 1;
  }
  if (tenscount > 0)
    charcount += tenscount;
  else
    charcount += 1;
  if (value < 0)
    charcount += 1;
  charcount += 1 + places;
  minwidth += 1; // both count the null final character
  if (minwidth > charcount) {
    extra = minwidth - charcount;
    charcount = minwidth;
  }
  if (value < 0)
    outstr[c++] = '-';
  if (tenscount == 0)
    outstr[c++] = '0';
  for (i = 0; i < tenscount; i++) {
    digit = (int) (tempfloat / tens);
    itoa(digit, &outstr[c++], 10);
    tempfloat = tempfloat - ((float)digit * tens);
    tens /= 10.0;
  }
  if (places > 0)
    outstr[c++] = '.';
  for (i = 0; i < places; i++) {
    tempfloat *= 10.0;
    digit = (int) tempfloat;
    itoa(digit, &outstr[c++], 10);
    tempfloat = tempfloat - (float) digit;
  }
  if (extra > 0 ) {
    for (int i = 0; i < extra; i++) {
      outstr[c++] = ' ';
    }
  }
  outstr[c++] = '\0';
  return outstr;
}

JETI_Box_class JB;

unsigned char SendFrame()
{
  boolean bit9 = false;
  for (int i = 0 ; i < JB.frameSize ; i++ )
  {
    if (i == 0)
      bit9 = false;
    else if (i == JB.frameSize - 1)
      bit9 = false;
    else if (i == JB.middle_bit9)
      bit9 = false;
    else
      bit9 = true;
    JetiTransmitByte(JB.frame[i], bit9);
  }
}
unsigned char DisplayFrame()
{
  for (int i = 0 ; i < JB.frameSize ; i++ )
  {
  }
}

uint8_t frame[10];
short value = 27;
int uLoopCount = 0;
#define MAX_SCREEN 8     //Jetibox screens
#define MAX_CONFIG 1     //Jetibox configurations
#define COND_LES_EQUAL 1
#define COND_MORE_EQUAL 2

void setup()
{
  Serial.begin(9600);
  SPI.begin();
  mfrc522.PCD_Init();
  Serial.println("Scan a MIFARE Classic card");
  for (byte i = 0; i < 6; i++) {
    key.keyByte[i] = 0xFF;
  }
  analogReference(EXTERNAL);
  pinMode(13, OUTPUT);
  digitalWrite(13, HIGH);
  pinMode(JETI_RX, OUTPUT);

  JetiUartInit();
  JB.JetiBox(ABOUT_1, ABOUT_2);
  JB.Init(F("RFID"));
  JB.addData(ITEMNAME_1, ITEMTYPE_1);
  JB.addData(ITEMNAME_2, ITEMTYPE_2);
  JB.addData(ITEMNAME_3, ITEMTYPE_3);
  JB.addData(ITEMNAME_4, ITEMTYPE_4);
  JB.setValue(1, ITEMVAL_1);
  JB.setValue(2, ITEMVAL_2);
  JB.setValue(3, ITEMVAL_3);
  JB.setValue(4, ITEMVAL_4);
  do {
    JB.createFrame(1);
    SendFrame();
    delay(GETCHAR_TIMEOUT_ms);
  }
  while (sensorFrameName != 0);
  digitalWrite(13, LOW);
  uBatteryID = 0;
  uCapacity = 0;
  uCycles = 0;
  uCells = 0;
  wBatteryID = 0;
  wCapacity = 0;
  wCycles = 0;
  wCells = 0;
}

int block = 4;
byte blockcontent[16] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
byte readbackblock[18];
int header = 0;
int lastbtn = 240;
int current_screen = 0;
int current_config = 0;
char temp[LCDMaxPos / 2];
char msg_line1[LCDMaxPos / 2];
char msg_line2[LCDMaxPos / 2];
boolean bReadCard = false;
boolean tagValues = false;

void process_screens()
{
  switch (current_screen)
  {
    case 0 : {
        JB.JetiBox(ABOUT_1, ABOUT_2);
        break;
      }
    case 1 : {
        msg_line1[0] = 0; msg_line2[0] = 0;
        strcat_P((char*)&msg_line1, (prog_char*)F("ID:"));
        temp[0] = 0;
        floatToString((char*)&temp, wBatteryID, 0);
        strcat((char*)&msg_line1, (char*)&temp);
        strcat_P((char*)&msg_line2, (prog_char*)F("Cap:"));
        temp[0] = 0;
        floatToString((char*)&temp, wCapacity, 0);
        strcat((char*)&msg_line2, (char*)&temp);
        strcat_P((char*)&msg_line1, (prog_char*)F(" Cyc:"));
        temp[0] = 0;
        floatToString((char*)&temp, wCycles, 0);
        strcat((char*)&msg_line1, (char*)&temp);
        strcat_P((char*)&msg_line2, (prog_char*)F(" Cel:"));
        temp[0] = 0;
        floatToString((char*)&temp, wCells, 0);
        strcat((char*)&msg_line2, (char*)&temp);
        JB.JetiBox((char*)&msg_line1, (char*)&msg_line2);
        break;
      }
    case 2 : {
        msg_line1[0] = 0; msg_line2[0] = 0;
        strcat_P((char*)&msg_line1, (prog_char*)F("Tag ID: "));
        temp[0] = 0;
        floatToString((char*)&temp, wBatteryID, 0);
        strcat((char*)&msg_line1, (char*)&temp);
        strcat_P((char*)&msg_line2, (prog_char*)F("Set Up/Dn Next>"));
        JB.JetiBox((char*)&msg_line1, (char*)&msg_line2);
        break;
      }
    case 3 : {
        msg_line1[0] = 0; msg_line2[0] = 0;
        strcat_P((char*)&msg_line1, (prog_char*)F("Capacity: "));
        temp[0] = 0;
        floatToString((char*)&temp, wCapacity, 0);
        strcat((char*)&msg_line1, (char*)&temp);
        strcat_P((char*)&msg_line2, (prog_char*)F("Set Up/Dn Next>"));
        JB.JetiBox((char*)&msg_line1, (char*)&msg_line2);
        break;
      }
    case 4 : {
        msg_line1[0] = 0; msg_line2[0] = 0;
        strcat_P((char*)&msg_line1, (prog_char*)F("Cycles: "));
        temp[0] = 0;
        floatToString((char*)&temp, wCycles, 0);
        strcat((char*)&msg_line1, (char*)&temp);
        strcat_P((char*)&msg_line2, (prog_char*)F("Set Up/Dn Next>"));
        JB.JetiBox((char*)&msg_line1, (char*)&msg_line2);
        break;
      }
    case 5 : {
        msg_line1[0] = 0; msg_line2[0] = 0;
        strcat_P((char*)&msg_line1, (prog_char*)F("Cells: "));
        temp[0] = 0;
        floatToString((char*)&temp, wCells, 0);
        strcat((char*)&msg_line1, (char*)&temp);
        strcat_P((char*)&msg_line2, (prog_char*)F("Set Up+Dn Next>"));
        JB.JetiBox((char*)&msg_line1, (char*)&msg_line2);
        break;
      }
    case 6 : {
        msg_line1[0] = 0; msg_line2[0] = 0;
        strcat_P((char*)&msg_line1, (prog_char*)F("Save: Up and Dn"));
        strcat_P((char*)&msg_line2, (prog_char*)F("Back: <"));
        JB.JetiBox((char*)&msg_line1, (char*)&msg_line2);
        break;
      }
    case 99 : {
        msg_line1[0] = 0; msg_line2[0] = 0;
        strcat_P((char*)&msg_line1, (prog_char*)F("Tag Written!"));
        strcat_P((char*)&msg_line2, (prog_char*)F("Press < to exit"));
        JB.JetiBox((char*)&msg_line1, (char*)&msg_line2);
        break;
      }
    case MAX_SCREEN : {
        JB.JetiBox(ABOUT_1, ABOUT_2);
        break;
      }
  }
}

void loop()
{
  if (! bReadCard) {
    if ( ! mfrc522.PICC_IsNewCardPresent()) {
      return;
    }
    if ( ! mfrc522.PICC_ReadCardSerial()) {
      return;
    }
    Serial.println("card selected");
    readBlock(block, readbackblock);
    uBatteryID = ((readbackblock[0] & 0xff) << 8) | readbackblock[1];
    uCapacity = ((readbackblock[2] & 0xff) << 8) | readbackblock[3];
    uCycles = ((readbackblock[4] & 0xff) << 8) | readbackblock[5];
    uCells = ((readbackblock[6] & 0xff) << 8) | readbackblock[7];
    Serial.print("ID:"); Serial.println(uBatteryID);
    Serial.print("Capacity:"); Serial.println(uCapacity);
    Serial.print("Cycles:"); Serial.println(uCycles);
    Serial.print("Cells:"); Serial.println(uCells);
    Serial.println("");
    bReadCard = true;
    if (! tagValues)
    {
      wBatteryID = uBatteryID;
      wCapacity = uCapacity;
      wCycles = uCycles;
      wCells = uCells;
    }
    tagValues = true;
  }
  if ((uLoopCount == 240) && bReadCard) {
      Serial.println("Writing out new cycle count");
      uCycles = uCycles + 1;
      unsigned char high = (byte)(uBatteryID >> 8);
      unsigned char low  = (byte)uBatteryID;
      blockcontent[0] = high; blockcontent[1]=low;
      high = (byte)(uCapacity >> 8);
      low  = (byte)uCapacity ;
      blockcontent[2] = high; blockcontent[3]=low;
      high = (byte)(uCycles >> 8);
      low  = (byte)uCycles;
      blockcontent[4] = high; blockcontent[5]=low;
      high = (byte)(uCells >> 8);
      low  = (byte)uCells;
      blockcontent[6] = high; blockcontent[7]=low;
      writeBlock(block, blockcontent);//the blockcontent array is written into the card block
    }
    
  if ((uLoopCount < 241) && bReadCard) {
    uLoopCount++;
  }
  
  unsigned long time = millis();
  SendFrame();
  time = millis();
  int read = 0;
  pinMode(JETI_RX, INPUT);
  pinMode(JETI_TX, INPUT_PULLUP);
  JetiSerial.listen();
  JetiSerial.flush();
  
  while ( JetiSerial.available()  == 0 )
  {
    if (millis() - time >  5) //5ms to waiting
      break; // return, if timout occures
  }
  if (JetiSerial.available() > 0 )
  { read = JetiSerial.read();
    //240 = no buttons
    if (lastbtn != read)
    {
      lastbtn = read;
      switch (read)
      {
        case 224 : // RIGHT
          if (current_screen  != MAX_SCREEN)
          {
            current_screen++;
            if (current_screen == 7) current_screen = 0;
          }
          break;
        case 112 : // LEFT
          if (current_screen  != MAX_SCREEN)
            if (current_screen == 99) {
              current_screen = 1;
            }
            else
            {
              current_screen--;
              if (current_screen > MAX_SCREEN) current_screen = 0;
            }
          break;
        case 208 : // UP
          if (current_screen == 2) {
            wBatteryID++;
            current_screen = 2;
          }
          if (current_screen == 3) {
            wCapacity = (wCapacity + 100);
            current_screen = 3;
          }
          if (current_screen == 4) {
            wCycles++;
            current_screen = 4;
          }
          if (current_screen == 5) {
            wCells++;
            current_screen = 5;
          }
          break;
        case 176 : // DOWN
          if (current_screen == 2) {
            wBatteryID = (wBatteryID + 10);
            current_screen = 2;
          }
          if (current_screen == 3) {
            wCapacity = (wCapacity + 1000);
            current_screen = 3;
          }
          if (current_screen == 4) {
            wCycles = (wCycles + 10);
            current_screen = 4;
          }
          if (current_screen == 5) {
            wCells = (wCells + 10);
            current_screen = 5;
          }
          break;
        case 144 : // UP+DOWN
          {
            if (current_screen == 3) {
              wCapacity = (wCapacity + 50);
              current_screen = 3;
            }
            if (current_screen == 6) {
              current_screen = 99;
              if (bReadCard) {
                unsigned char high = (byte)(wBatteryID >> 8);
                unsigned char low  = (byte)wBatteryID;
                blockcontent[0] = high; blockcontent[1] = low;
                high = (byte)(wCapacity >> 8);
                low  = (byte)wCapacity ;
                blockcontent[2] = high; blockcontent[3] = low;
                high = (byte)(wCycles >> 8);
                low  = (byte)wCycles;
                blockcontent[4] = high; blockcontent[5] = low;
                high = (byte)(wCells >> 8);
                low  = (byte)wCells;
                blockcontent[6] = high; blockcontent[7] = low;
                writeBlock(block, blockcontent);
                tagValues = false;
                readBlock(block, readbackblock);
                uBatteryID = ((readbackblock[0] & 0xff) << 8) | readbackblock[1];
                uCapacity = ((readbackblock[2] & 0xff) << 8) | readbackblock[3];
                uCycles = ((readbackblock[4] & 0xff) << 8) | readbackblock[5];
                uCells = ((readbackblock[6] & 0xff) << 8) | readbackblock[7];
                bReadCard = true;
                if (! tagValues)
                {
                  wBatteryID = uBatteryID;
                  wCapacity = uCapacity;
                  wCycles = uCycles;
                  wCells = uCells;
                }
                tagValues = true;
              }
            }
          }
          break;
        case 96 : // LEFT+RIGHT
          if (current_screen == 2) {
            wBatteryID = 0;
            current_screen = 2;
          }
          if (current_screen == 3) {
            wCapacity = 0;
            current_screen = 3;
          }
          if (current_screen == 4) {
            wCycles = 0;
            current_screen = 4;
          }
          if (current_screen == 5) {
            wCells = 0;
            current_screen = 5;
          }
          break;
      }
    }
  }
  if (current_screen != MAX_SCREEN)
    current_config = 0;
  process_screens();
  header++;
  if (header >= 5)
  {
    JB.createFrame(1);
    header = 0;
  }
  else
  {
    JB.createFrame(0);
  }
  long wait = GETCHAR_TIMEOUT_ms;
  long milli = millis() - time;
  if (milli > wait)
    wait = 0;
  else
    wait = wait - milli;
  pinMode(JETI_TX, OUTPUT);
}
