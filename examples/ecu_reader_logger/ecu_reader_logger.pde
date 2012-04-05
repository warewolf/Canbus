/* Welcome to the ECU Reader project. This sketch uses the Canbus library.
It requires the CAN-bus shield for the Arduino. This shield contains the MCP2515 CAN controller and the MCP2551 CAN-bus driver.
A connector for an EM406 GPS receiver and an uSDcard holder with 3v level convertor for use in data logging applications.
The output data can be displayed on a serial LCD.

The SD test functions requires a FAT16 formated card with a text file of WRITE00.TXT in the card.


SK Pang Electronics www.skpang.co.uk

v3.0 21-02-11  Use library from Adafruit for sd card instead.

*/

#include <SD.h>
//#include <SdFatUtil.h>
#include <SoftwareSerial.h>
#include <Canbus.h>


/* microSD Card */
#define SD_SELECT 9 // CAN-BUS shield SD Card select is arduino digital pin 9.
Sd2Card card;
SdVolume volume;
SdFile root;
SdFile file;

/* Serial LCD */
SoftwareSerial sLCD =  SoftwareSerial(3, 6); /* Serial LCD is connected on pin 14 (Analog input 0) */
#define COMMAND 0xFE
#define CLEAR   0x01
#define LINE0   0x80
#define LINE1   0xC0


/* Define Joystick connection */
#define UP     A1
#define RIGHT  A2
#define DOWN   A3
#define CLICK  A4
#define LEFT   A5

// CAN buffer
char buffer[512];  //Data will be temporarily stored to this buffer before being written to the file
char tempbuf[15];
char lat_str[14];
char lon_str[14];

int read_size=0;   //Used as an indicator for how many characters are read from the file
int count=0;       //Miscellaneous variable

int D10 = 10;

int LED2 = 8;
int LED3 = 7;

// store error strings in flash to save RAM
#define error(s) error_P(PSTR(s))

void error_P(const char* str) {
  PgmPrint("error: ");
  SerialPrintln_P(str);
  
  clear_lcd();
  sLCD.print("SD error");
  
  if (card.errorCode()) {
    PgmPrint("SD error: ");
    Serial.print(card.errorCode(), HEX);
    
    Serial.print(',');
    Serial.println(card.errorData(), HEX);
   
  }
  while(1);
}

void setup() {

  /* Set LED pin state */
  pinMode(LED2, OUTPUT); 
  pinMode(LED3, OUTPUT); 
 
  digitalWrite(LED2, LOW);

  /* Set joystick PIN modes */
  pinMode(UP,INPUT);
  pinMode(DOWN,INPUT);
  pinMode(LEFT,INPUT);
  pinMode(RIGHT,INPUT);
  pinMode(CLICK,INPUT);

  /* Set joystick PIN states */
  digitalWrite(UP, HIGH);
  digitalWrite(DOWN, HIGH);
  digitalWrite(LEFT, HIGH);
  digitalWrite(RIGHT, HIGH);
  digitalWrite(CLICK, HIGH);
  
  
  Serial.begin(9600);
  Serial.println("ECU Reader");  /* For debug use */
  
  sLCD.begin(9600);              /* Setup serial LCD and clear the screen */
  clear_lcd();
 
  sLCD.print("D:CAN");
  sLCD.write(byte(COMMAND));
  sLCD.write(byte(LINE1));
  sLCD.print("L:SD   R:LOG");
  
  while(1)
  {
    
    if (digitalRead(DOWN) == 0) {
      sLCD.print("CAN");
      Serial.println("CAN");
      break;
    }
    
    if (digitalRead(LEFT) == 0) {
    
      Serial.println("SD test");
      sd_test();
    }
    
    if (digitalRead(RIGHT) == 0) {
    
      Serial.println("Logging");
      logging();
    }
    
  }
  
  clear_lcd();
  
  if(Canbus.init(CANSPEED_500))  /* Initialise MCP2515 CAN controller at the specified speed */
  {
    sLCD.print("CAN Init ok");
  } else
  {
    sLCD.print("Can't init CAN");
  } 
   
  delay(1000); 

}
 
void loop() {
 
  digitalWrite(LED3, HIGH);

  if(Canbus.ecu_req(ENGINE_RPM,buffer) == 1)          /* Request for engine RPM */
  {
    sLCD.write(byte(COMMAND));                   /* Move LCD cursor to line 0 */
    sLCD.write(byte(LINE0));
    sLCD.print(buffer);                         /* Display data on LCD */
  } 
   
  if(Canbus.ecu_req(VEHICLE_SPEED,buffer) == 1)
  {
    sLCD.write(byte(COMMAND));
    sLCD.write(byte(LINE0 + 9));
    sLCD.print(buffer);
  }
  
  if(Canbus.ecu_req(ENGINE_COOLANT_TEMP,buffer) == 1)
  {
    sLCD.write(byte(COMMAND));
    sLCD.write(byte(LINE1));                     /* Move LCD cursor to line 1 */
    sLCD.write(buffer);
  }
  
  if(Canbus.ecu_req(THROTTLE,buffer) == 1)
  {
    sLCD.write(byte(COMMAND));
    sLCD.write(byte(LINE1 + 9));
    sLCD.print(buffer);
     file.print(buffer);
  }  
   
   digitalWrite(LED3, LOW); 
   delay(100); 
}

void logging(void) {
  clear_lcd();
  
  if(Canbus.init(CANSPEED_500))  /* Initialise MCP2515 CAN controller at the specified speed */
  {
    sLCD.print("CAN Init ok");
  } else
  {
    sLCD.print("Can't init CAN");
  } 
   
  delay(500);
  clear_lcd(); 
  sLCD.print("Init SD card");  
  delay(500);
  clear_lcd(); 
  sLCD.print("Press J/S click");  
  sLCD.write(byte(COMMAND));
  sLCD.write(byte(LINE1));                     /* Move LCD cursor to line 1 */
   sLCD.print("to Stop"); 
  
  // initialize the SD card at SPI_HALF_SPEED to avoid bus errors with
  // breadboards.  use SPI_FULL_SPEED for better performance.
  if (!card.init(SPI_HALF_SPEED,9)) error("card.init failed");
  
  // initialize a FAT volume
  if (!volume.init(&card)) error("volume.init failed");
  
  // open the root directory
  if (!root.openRoot(&volume)) error("openRoot failed");

  // create a new file
  char name[] = "WRITE00.TXT";
  for (uint8_t i = 0; i < 100; i++) {
    name[5] = i/10 + '0';
    name[6] = i%10 + '0';
    if (file.open(&root, name, O_CREAT | O_EXCL | O_WRITE)) break;
  }
  if (!file.isOpen()) error ("file.create");
  Serial.print("Writing to: ");
  Serial.println(name);
  // write header
  // XXX FIXME RGH: writeError is not in SD lib
  // file.writeError = 0;
  file.print("READY....");
  file.println();  

  while(1)    /* Main logging loop */
  {

    if(Canbus.ecu_req(ENGINE_RPM,buffer) == 1)          /* Request for engine RPM */
      {
        sLCD.write(byte(COMMAND));                   /* Move LCD cursor to line 0 */
        sLCD.write(byte(LINE0));
        sLCD.print(buffer);                         /* Display data on LCD */
        file.print(buffer);
         file.print(',');
    
      } 
      digitalWrite(LED3, HIGH);
   
      if(Canbus.ecu_req(VEHICLE_SPEED,buffer) == 1)
      {
        sLCD.write(byte(COMMAND));
        sLCD.write(byte(LINE0 + 9));
        sLCD.print(buffer);
        file.print(buffer);
        file.print(','); 
      }
      
      if(Canbus.ecu_req(ENGINE_COOLANT_TEMP,buffer) == 1)
      {
        sLCD.write(byte(COMMAND));
        sLCD.write(byte(LINE1));                     /* Move LCD cursor to line 1 */
        sLCD.print(buffer);
         file.print(buffer);
       
      }
      
      if(Canbus.ecu_req(THROTTLE,buffer) == 1)
      {
        sLCD.write(byte(COMMAND));
        sLCD.write(byte(LINE1 + 9));
        sLCD.print(buffer);
         file.print(buffer);
      }  
    //  Canbus.ecu_req(O2_VOLTAGE,buffer);
       file.println();  
  
       digitalWrite(LED3, LOW); 
 
       if (digitalRead(CLICK) == 0){  /* Check for Click button */
           file.close();
           Serial.println("Done");
           sLCD.write(byte(COMMAND));
           sLCD.write(byte(CLEAR));
     
           sLCD.print("DONE");
          while(1);
        }

  }
 
 
 
 
}

void sd_test(void) {
 clear_lcd(); 
 sLCD.print("SD test"); 
 Serial.println("SD card test");
   
     // initialize the SD card at SPI_HALF_SPEED to avoid bus errors with
  // breadboards.  use SPI_FULL_SPEED for better performance.
  if (!card.init(SPI_HALF_SPEED,9)) error("card.init failed");
  
  // initialize a FAT volume
  if (!volume.init(&card)) error("volume.init failed");
  
  // open root directory
  if (!root.openRoot(&volume)) error("openRoot failed");
  // open a file
  if (file.open(&root, "LOGGER00.CSV", O_READ)) {
    Serial.println("Opened PRINT00.TXT");
  }
  else if (file.open(&root, "WRITE00.TXT", O_READ)) {
    Serial.println("Opened WRITE00.TXT");    
  }
  else{
    error("file.open failed");
  }
  Serial.println();
  
  // copy file to serial port
  int16_t n;
  uint8_t buf[7];// nothing special about 7, just a lucky number.
  while ((n = file.read(buf, sizeof(buf))) > 0) {
    for (uint8_t i = 0; i < n; i++) Serial.print(buf[i]);
  
  
  }
 clear_lcd();  
 sLCD.print("DONE"); 

  
 while(1);  /* Don't return */ 
    

}

void clear_lcd(void) {
  sLCD.write(byte(COMMAND));
  sLCD.write(byte(CLEAR));
}  
