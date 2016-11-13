/******************************************
	
	Jeti RFID-Battery version 0.1
	Tero RC-Thoughts.com 2016 ( www.rc-thoughts.com )
	
	Huge thanks to pioneering work of Alastair Cormack
	99% of work done by alastair.cormack@gmail.com

    This is for personnal use only with the usual disclaimer of: Use this at your own risk.	 
    This would only have been possible to do this through the excellent efforts of:
       RFID code by
        Based on code Dr.Leong   ( WWW.B2CQSHOP.COM )
        Created by Miguel Balboa (circuitito.com), Jan, 2012.
        Rewritten by Søren Thing Andersen (access.thing.dk), fall of 2013 (Translation to English, refactored, comments, anti collision, cascade levels.) 
        Rudy Schlaf for www.makecourse.com
*/

/*
 *********
 The three lines below are where you need to modify the numbers to fit the pack you want to configure
 Eventually could write a graphical user interface to do this with a RFID writer on a PC/MAC.. But this is 
 is available at this point.. Challenge for someone else!!
 *********
*/
	short int uBatteryID = 12; // This is unique identificator
	short int uCapacity = 4400; // Battery mAh capacity
	short int uCycles= 46 ; // How many times battery have been cycled, 0 if new
	short int uCells= 7; // Battery cell-count
/*
 ******** DO NOT EDIT BELOW THIS LINE
*/

#include <SPI.h>	//include the SPI bus library
#include <MFRC522.h>	//include the RFID reader library
#define SS_PIN 10	//slave select pin
#define RST_PIN 5	//reset pin
MFRC522 mfrc522(SS_PIN, RST_PIN);	// instatiate a MFRC522 reader object.
MFRC522::MIFARE_Key key;	//create a MIFARE_Key struct named 'key', which will hold the card information

void setup() {
	Serial.begin(9600);	// Initialize serial communications with the PC
	SPI.begin();		// Init SPI bus
	mfrc522.PCD_Init();	// Init MFRC522 card (in case you wonder what PCD means: proximity coupling device)
	Serial.println("Scan a MIFARE Classic card");

	// Prepare the security key for the read and write functions - all six key bytes are set to 0xFF at chip delivery from the factory.
	// Since the cards in the kit are new and the keys were never defined, they are 0xFF
	// if we had a card that was programmed by someone else, we would need to know the key to be able to access it. This key would then need to be stored in 'key' instead.

		for (byte i = 0; i < 6; i++) {
			key.keyByte[i] = 0xFF;	//keyByte is defined in the "MIFARE_Key" 'struct' definition in the .h file of the library
		}
}

int blockJeti=4; //this is the block number we will write into and then read. Do not write into 'sector trailer' block, since this can make the block unusable.
int blockRobbe=2; // this is just to remind us that Robbe BID uses block 2 

//byte blockcontent[16] = {"makecourse_____"};//an array with 16 bytes to be written into one of the 64 card blocks is defined
byte blockcontent[16] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};	//all zeros. This can be used to delete a block.
byte readJetiBlock[18];	//This array is used for reading out a block. The MIFARE_Read method requires a buffer that is at least 18 bytes to hold the 16 bytes of a block.

void loop()
{
	/*** establishing contact with a tag/card ***/

	// Look for new cards (in case you wonder what PICC means: proximity integrated circuit card)
	if ( ! mfrc522.PICC_IsNewCardPresent()) {	//if PICC_IsNewCardPresent returns 1, a new card has been found and we continue
	return;	//if it did not find a new card is returns a '0' and we return to the start of the loop
	}

	// Select one of the cards
	if ( ! mfrc522.PICC_ReadCardSerial()) {	//if PICC_ReadCardSerial returns 1, the "uid" struct (see MFRC522.h lines 238-45)) contains the ID of the read card.
		return;	//if it returns a '0' something went wrong and we return to the start of the loop
	}
		// Among other things, the PICC_ReadCardSerial() method reads the UID and the SAK (Select acknowledge) into the mfrc522.uid struct, which is also instantiated
		// during this process.
		// The UID is needed during the authentication process
		//The Uid struct:
		//typedef struct {
		//byte		size;	// Number of bytes in the UID. 4, 7 or 10.
		//byte		uidByte[10];	//the user ID in 10 bytes.
		//byte		sak;	// The SAK (Select acknowledge) byte returned from the PICC after successful selection.
		//} Uid;

	Serial.println("card selected");

		/*** writing and reading a block on the card***/

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

		writeBlock(blockJeti, blockcontent);	//the blockcontent array is written into the card block
   
		//mfrc522.PICC_DumpToSerial(&(mfrc522.uid));

		//The 'PICC_DumpToSerial' method 'dumps' the entire MIFARE data block into the serial monitor. Very useful while programming a sketch with the RFID reader...
		//Notes:
		//(1) MIFARE cards conceal key A in all trailer blocks, and shows 0x00 instead of 0xFF. This is a secutiry feature. Key B appears to be public by default.
		//(2) The card needs to be on the reader for the entire duration of the dump. If it is removed prematurely, the dump interrupts and an error message will appear.
		//(3) The dump takes longer than the time alloted for interaction per pairing between reader and card, i.e. the readBlock function below will produce a timeout if
		//    the dump is used.
		//mfrc522.PICC_DumpToSerial(&(mfrc522.uid));	//uncomment this if you want to see the entire 1k memory with the block written into it.

		Serial.println("Checking card contents:");

		readBlock(blockJeti, readJetiBlock);	//read the block back

		//all the items are shorts.. so two bytes. Just read each byte back and construct a short
		uBatteryID = ((readJetiBlock[0] & 0xff) << 8) | readJetiBlock[1];
		uCapacity = ((readJetiBlock[2] & 0xff) << 8) | readJetiBlock[3];
		uCycles = ((readJetiBlock[4] & 0xff) << 8) | readJetiBlock[5];
		uCells = ((readJetiBlock[6] & 0xff) << 8) | readJetiBlock[7];
		Serial.print("ID:"); Serial.println(uBatteryID);
		Serial.print("Capacity:");Serial.println(uCapacity);
		Serial.print("Cycles:");Serial.println(uCycles);
		Serial.print("Cells:");Serial.println(uCells);
		Serial.println(""); 
}
