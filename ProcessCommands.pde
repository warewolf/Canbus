/*
 * This is an exapmle for command processing on arduino.
 * See the following page.
 * http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1251426835
 */

#define MAX_COMMAND_LEN             (10)
#define MAX_PARAMETER_LEN           (10)
#define COMMAND_TABLE_SIZE          (4)
#define TO_UPPER(x) (((x >= 'a') && (x <= 'z')) ? ((x) - ('a' - 'A')) : (x))

int ledPin = 11;

char gCommandBuffer[MAX_COMMAND_LEN + 1];
char gParamBuffer[MAX_PARAMETER_LEN + 1];
long gParamValue;

typedef struct {
  char const    *name;
  void          (*function)(void);
} command_t;

command_t const gCommandTable[COMMAND_TABLE_SIZE] = {
  {"HELP",    commandsHelp,},
  {"LED",     commandsLed, },
  {"BUZZER",  commandsBuzzer, },
  {NULL,      NULL }
};
 
/**********************************************************************
 *
 * Function:    cliBuildCommand
 *
 * Description: Put received characters into the command buffer or the
 *              parameter buffer. Once a complete command is received
 *              return true.
 *
 * Notes:       
 *
 * Returns:     true if a command is complete, otherwise false.
 *
 **********************************************************************/
int cliBuildCommand(char nextChar) {
  static uint8_t idx = 0; //index for command buffer
  static uint8_t idx2 = 0; //index for parameter buffer
  enum { COMMAND, PARAM };
  static uint8_t state = COMMAND;
  /* Don't store any new line characters or spaces. */
  if ((nextChar == '\n') || (nextChar == ' ') || (nextChar == '\t') || (nextChar == '\r'))
    return false;

  /* The completed command has been received. Replace the final carriage
   * return character with a NULL character to help with processing the
   * command. */
  //if (nextChar == '\r')
  if (nextChar == ';') {
    gCommandBuffer[idx] = '\0';
    gParamBuffer[idx2] = '\0';
    idx = 0;
    idx2 = 0;
    state = COMMAND;
    return true;
  }

  if (nextChar == ',') {
    state = PARAM;
    return false;
  }

  if (state == COMMAND) {
    /* Convert the incoming character to upper case. This matches the case
     * of commands in the command table. Then store the received character
     * in the command buffer. */
    gCommandBuffer[idx] = TO_UPPER(nextChar);
    idx++;

    /* If the command is too long, reset the index and process
     * the current command buffer. */
    if (idx > MAX_COMMAND_LEN) {
      idx = 0;
       return true;
    }
  }

  if (state == PARAM) {
    /* Store the received character in the parameter buffer. */
    gParamBuffer[idx2] = nextChar;
    idx2++;

    /* If the command is too long, reset the index and process
     * the current parameter buffer. */
    if (idx > MAX_PARAMETER_LEN) {
      idx2 = 0;
      return true;
    }
  }

  return false;
}

/**********************************************************************
 *
 * Function:    cliProcessCommand
 *
 * Description: Look up the command in the command table. If the
 *              command is found, call the command's function. If the
 *              command is not found, output an error message.
 *
 * Notes:       
 *
 * Returns:     None.
 *
 **********************************************************************/
void cliProcessCommand(void)
{
  int bCommandFound = false;
  int idx;

  /* Convert the parameter to an integer value. 
   * If the parameter is empty, gParamValue becomes 0. */
  gParamValue = strtol(gParamBuffer, NULL, 0);

  /* Search for the command in the command table until it is found or
   * the end of the table is reached. If the command is found, break
   * out of the loop. */
  for (idx = 0; gCommandTable[idx].name != NULL; idx++) {
    if (strcmp(gCommandTable[idx].name, gCommandBuffer) == 0) {
      bCommandFound = true;
      break;
    }
  }

  /* If the command was found, call the command function. Otherwise,
   * output an error message. */
  if (bCommandFound == true) {
    Serial.println();
    (*gCommandTable[idx].function)();
  }
  else {
    Serial.println();
    Serial.println("Command not found.");
  }
}

/**********************************************************************
 *
 * Function:    commandsLed
 *
 * Description: Change the brightness of the LED.
 *              If this command is called with no parameter,
 *              the LED turns off.
 *
 * Notes:       
 *
 * Returns:     None.
 *
 **********************************************************************/
void commandsLed(void) {
  Serial.println("LED command received.");
  Serial.print("parameter value is ");
  Serial.println(gParamValue);
  if (gParamValue >=0 && gParamValue <= 255) {
    analogWrite(ledPin, gParamValue);
  }
  else {
    Serial.println("wrong parameter value");
  }
}

/**********************************************************************
 *
 * Function:    commandsBuzzer
 *
 * Description: Toggle the buzzer command function.
 *
 * Notes:       This is a dummy function, only prints the parameter value.
 *
 * Returns:     None.
 *
 **********************************************************************/
void commandsBuzzer(void) {
  Serial.println("BUZZER command received.");
  Serial.print("parameter value is ");
  Serial.println(gParamValue);
}

/**********************************************************************
 *
 * Function:    commandsHelp
 *
 * Description: Help command function.
 *
 * Notes:       
 *
 * Returns:     None.
 *
 **********************************************************************/
void commandsHelp(void) {
  int idx;

  /* Loop through each command in the table and send out the command
   * name to the serial port. */
  for (idx = 0; gCommandTable[idx].name != NULL; idx++) {
    Serial.println(gCommandTable[idx].name);
  }
}

void setup() {
  Serial.begin(9600);
  pinMode(ledPin, OUTPUT);   // sets the pin as output
  Serial.println("Arduino command processing example");
  Serial.print('>');
}

void loop() {
  char rcvChar;
  int  bCommandReady = false;

  if (Serial.available() > 0) {
    /* Wait for a character. */
    rcvChar = Serial.read();

    /* Echo the character back to the serial port. */
    Serial.print(rcvChar);

    /* Build a new command. */
    bCommandReady = cliBuildCommand(rcvChar);
  }

  /* Call the CLI command processing routine to verify the command entered 
   * and call the command function; then output a new prompt. */
  if (bCommandReady == true) {
    bCommandReady = false;
    cliProcessCommand();
    Serial.print('>');
  }
}
