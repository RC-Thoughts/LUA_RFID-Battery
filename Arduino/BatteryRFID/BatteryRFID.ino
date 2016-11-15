/*
    Jeti RFID-Battery version 0.2
    Tero RC-Thoughts.com 2016 ( www.rc-thoughts.com )
	- Improved performance
	- Full compatibility with Jeti R- and REX-receivers
	
    Huge thanks to pioneering work of Alastair Cormack
    95% of work done by alastair.cormack@gmail.com
    
    This is for personnal use only with the usual disclaimer of: Use this at your own risk.   
    This would only have been possible to do this through the excellent efforts of:
    Mav2Duplex by DevFor8.com, info@devfor8.com
	
    RFID code by
    Based on code Dr.Leong   ( WWW.B2CQSHOP.COM )
    Created by Miguel Balboa (circuitito.com), Jan, 2012.
    Rewritten by Søren Thing Andersen (access.thing.dk), fall of 2013 (Translation to English, refactored, comments, anti collision, cascade levels.) 
    Rudy Schlaf for www.makecourse.com
    If you modify/improve this please post back so that all can benefit    
*/

#include <EEPROM.h>
#include <SoftwareSerialJeti.h>
#include <JETI_EX_SENSOR.h>
#include <SPI.h>//include the SPI bus library
#include <MFRC522.h>//include the RFID reader library

#define SS_PIN 10  //slave select pin
#define RST_PIN 5  //reset pin
MFRC522 mfrc522(SS_PIN, RST_PIN);        // instatiate a MFRC522 reader object.
MFRC522::MIFARE_Key key;//create a MIFARE_Key struct named 'key', which will hold the card information

#define prog_char char PROGMEM     //prog_char is depreciated,replace with PROGMEM
#define GETCHAR_TIMEOUT_ms 20  // 20ms timeout for Getchar Routine, just to make sure. Never ran into timeout

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

#define ABOUT_1 F(" RCT Jeti Tools")    //Jetibox line 1
#define ABOUT_2 F(" RFID-Battery")        //Jetibox line 2

SoftwareSerial JetiSerial(JETI_RX,JETI_TX);

void JetiUartInit() 
{
    JetiSerial.begin(9700);
}
// Transmits one byte to the box, specify if bit 9 will be set or not; attention: used  digital Pin 3 
void JetiTransmitByte(unsigned char data, boolean setBit9)
{
	JetiSerial.set9bit = setBit9;
	JetiSerial.write(data);
	JetiSerial.set9bit = 0;
}
// Read the ack from the box
unsigned char JetiGetChar(void)
{
	unsigned long time = millis();
	// Wait for data to be received
	while ( JetiSerial.available()  == 0 )
	{
		if (millis()-time >  GETCHAR_TIMEOUT_ms) 
		return 0; // return, if timout occures
	}
	int read = -1;
	if (JetiSerial.available() >0 )
	{
		read = JetiSerial.read();
	}
	long wait = (millis()-time) - GETCHAR_TIMEOUT_ms;
	if (wait > 0)
		delay(wait);
	return read;
}
//char * floatToString(char * outstr, float value, int places, int minwidth=, bool rightjustify) {
char * floatToString(char * outstr, float value, int places, int minwidth=0) {
    // this is used to write a float value to string, outstr.  oustr is also the return value.
    int digit;
    float tens = 0.1;
    int tenscount = 0;
    int i;
    float tempfloat = value;
    int c = 0;
    int charcount = 1;
    int extra = 0;
    // make sure we round properly. this could use pow from <math.h>, but doesn't seem worth the import
    // if this rounding step isn't here, the value  54.321 prints as 54.3209
    // calculate rounding term d:   0.5/pow(10,places)  
    float d = 0.5;
    if (value < 0)
		d *= -1.0;
    // divide by ten for each decimal place
    for (i = 0; i < places; i++)
	d/= 10.0;    
    // this small addition, combined with truncation will round our values properly 
    tempfloat +=  d;
    // first get value tens to be the large power of ten less than value    
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
    if (minwidth > charcount){        
        extra = minwidth - charcount;
        charcount = minwidth;
	}
    // write out the negative if needed
    if (value < 0)
		outstr[c++] = '-';
    if (tenscount == 0) 
		outstr[c++] = '0';
    for (i=0; i< tenscount; i++) {
        digit = (int) (tempfloat/tens);
        itoa(digit, &outstr[c++], 10);
        tempfloat = tempfloat - ((float)digit * tens);
        tens /= 10.0;
	}
    // if no places after decimal, stop now and return
    // otherwise, write the point and continue on
    if (places > 0)
		outstr[c++] = '.';
    // now write out each decimal place by shifting digits one by one into the ones place and writing the truncated value
    for (i = 0; i < places; i++) {
        tempfloat *= 10.0; 
        digit = (int) tempfloat;
        itoa(digit, &outstr[c++], 10);
        // once written, subtract off that digit
        tempfloat = tempfloat - (float) digit; 
	}
    if (extra > 0 ) {
        for (int i = 0; i< extra; i++) {
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
    for (int i = 0 ; i<JB.frameSize ; i++ )
    {
		if (i == 0)
			bit9 = false;
		else
		if (i == JB.frameSize-1)
			bit9 = false;
		else
		if (i == JB.middle_bit9)
			bit9 = false;
		else
			bit9 = true;
			JetiTransmitByte(JB.frame[i], bit9);
	}
}
unsigned char DisplayFrame()
{
    for (int i = 0 ; i<JB.frameSize ; i++ )
    {
		// Serial.print(JB.frame[i],HEX);
	}
    //Serial.println("");
}

short zero_val = 0;
uint8_t frame[10];
short cmpt = 0;
short value = 27;
int uLoopCount =0;
#define MAX_SCREEN 5     //Jetibox screens
#define MAX_CONFIG 1     //Jetibox configurations
#define COND_LES_EQUAL 1
#define COND_MORE_EQUAL 2

void setup() 
{
    Serial.begin(9600);        // Initialize serial communications with the PC
    SPI.begin();               // Init SPI bus
    mfrc522.PCD_Init();        // Init MFRC522 card (in case you wonder what PCD means: proximity coupling device)
    Serial.println("Scan a MIFARE Classic card");
    // Prepare the security key for the read and write functions - all six key bytes are set to 0xFF at chip delivery from the factory.
    // Since the cards in the kit are new and the keys were never defined, they are 0xFF
    // if we had a card that was programmed by someone else, we would need to know the key to be able to access it. This key would then need to be stored in 'key' instead.
    for (byte i = 0; i < 6; i++) {
        key.keyByte[i] = 0xFF;//keyByte is defined in the "MIFARE_Key" 'struct' definition in the .h file of the library
	}
    analogReference(EXTERNAL);   //use reference voltage from breakout board
    pinMode(13, OUTPUT);     
    digitalWrite(13, HIGH);   // turn the LED on (HIGH is the voltage level)
    //Serial.begin(9600);
    //Serial.println(F("Ready")); //progmem
    pinMode(JETI_RX, OUTPUT);
    //strcpy_P((char*)&LastMessage,(prog_char*)F("Inclinometer OK"));
    //InitAlarms();
    JetiUartInit();          // Requires JETIBOX.INO library...
    //Serial.println(F("JetiUartInit")); //progmem
    JB.JetiBox(ABOUT_1,ABOUT_2); //change to this for copy directly from F() and also to AddData in F() form only
    JB.Init(F("RFID"));
    JB.addData(ITEMNAME_1,ITEMTYPE_1);
    JB.addData(ITEMNAME_2,ITEMTYPE_2);
    JB.addData(ITEMNAME_3,ITEMTYPE_3);
    JB.addData(ITEMNAME_4,ITEMTYPE_4);
    JB.setValue(1,ITEMVAL_1);
    JB.setValue(2,ITEMVAL_2);    // JB.setValue(2,ITEMVAL_2); for integer values 
    JB.setValue(3,ITEMVAL_3);
    JB.setValue(4,ITEMVAL_4);
    do {
		JB.createFrame(1);
		SendFrame();
		delay(GETCHAR_TIMEOUT_ms);
		//Serial.write(sensorFrameName);
	}
    while (sensorFrameName != 0);
		//Serial.print("Ready done");
		digitalWrite(13, LOW);   // turn the LED on (HIGH is the voltage level)
		uBatteryID = 0;
		uCapacity = 0;
		uCycles = 0;
		uCells = 0;
}
int block=4;//this is the block number we will write into and then read. Do not write into 'sector trailer' block, since this can make the block unusable.
byte blockcontent[16] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};//all zeros. This can be used to delete a block.
byte readbackblock[18];//This array is used for reading out a block. The MIFARE_Read method requires a buffer that is at least 18 bytes to hold the 16 bytes of a block.
int header = 0;
int lastbtn = 240;
int current_screen = 1; // 0 - about , 2 - message ,1 - Inclinometer value, 3 - Alarms
int current_config = 0; // 0 - Alarms, 1 - capacity warn, 2 - dist warn
int alarm_id = -1;
float alarm_current = 0;
char temp[LCDMaxPos/2];
char msg_line1[LCDMaxPos/2];
char msg_line2[LCDMaxPos/2];
boolean bReadCard = false;
void loop() 
{
	/************ establishing contact with a tag/card ************/
	if (! bReadCard) { //if we have not read a card
		// Look for new cards (in case you wonder what PICC means: proximity integrated circuit card)
		if ( ! mfrc522.PICC_IsNewCardPresent()) {//if PICC_IsNewCardPresent returns 1, a new card has been found and we continue
			return;//if it did not find a new card is returns a '0' and we return to the start of the loop
		}
		// Select one of the cards
		if ( ! mfrc522.PICC_ReadCardSerial()) {//if PICC_ReadCardSerial returns 1, the "uid" struct (see MFRC522.h lines 238-45)) contains the ID of the read card.
			return;//if it returns a '0' something went wrong and we return to the start of the loop
		}
		// Among other things, the PICC_ReadCardSerial() method reads the UID and the SAK (Select acknowledge) into the mfrc522.uid struct, which is also instantiated
		// during this process.
		// The UID is needed during the authentication process
		//The Uid struct:
		//typedef struct {
		//byte    size;     // Number of bytes in the UID. 4, 7 or 10.
		//byte    uidByte[10];            //the user ID in 10 bytes.
		//byte    sak;      // The SAK (Select acknowledge) byte returned from the PICC after successful selection.
	//} Uid;
    Serial.println("card selected");
    readBlock(block, readbackblock);//read the block back
    //all the items are shorts.. so two bytes. Just read each byte back and construct a short
    uBatteryID = ((readbackblock[0] & 0xff) << 8) | readbackblock[1];
    uCapacity = ((readbackblock[2] & 0xff) << 8) | readbackblock[3];
    uCycles = ((readbackblock[4] & 0xff) << 8) | readbackblock[5];
    uCells = ((readbackblock[6] & 0xff) << 8) | readbackblock[7];
    Serial.print("ID:"); Serial.println(uBatteryID);
    Serial.print("Capacity:");Serial.println(uCapacity);
    Serial.print("Cycles:");Serial.println(uCycles);
    Serial.print("Cells:");Serial.println(uCells);
    Serial.println("");  
    bReadCard = true;  // we have read a card
}
//if we have read a card and have gone around 60 times then we can increase the cycle count
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
//If we have read a card then increase the loop count only if we have looped less than the number of times to trigger an increase in cycle count 
if ((uLoopCount < 241)&& bReadCard) {
	uLoopCount++;
}
unsigned long time = millis();
SendFrame();
//Serial.print("Send frame :");Serial.println(millis()-time);
time = millis();
int read = 0;
pinMode(JETI_RX, INPUT);
pinMode(JETI_TX, INPUT_PULLUP);
//digitalWrite(JETI_TX,LOW);
JetiSerial.listen();
JetiSerial.flush();
while ( JetiSerial.available()  == 0 )
{
    if (millis()-time >  5) //5ms to waiting
    break; // return, if timout occures
}
if (JetiSerial.available() >0 )
{read = JetiSerial.read();
    //240 = no buttons
    //224 - right
    //112 - left
    //208 up
    //176 down
    //144 up+down
    //96 left+right
    if (lastbtn != read)
    {
        //Serial.println(read);
        lastbtn = read;
        // process buttons
		switch (read)
        {
			case 224 : 
			break;
			case 112 : 
			break;
			case 208 : 
			
			break;       
			case 176 : 
			break;       
		}
	}
}
if (current_screen !=MAX_SCREEN)
	current_config = 0; //zero 5th screen
	//process_screens();
	// prepare frame
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
//pinMode(JETI_RX, OUTPUT);  this line gave comm error
long wait = GETCHAR_TIMEOUT_ms;
long milli = millis()-time;
if (milli > wait)
	wait = 0;
else
	wait = wait - milli;
	pinMode(JETI_TX, OUTPUT);
}