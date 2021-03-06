/** vim: ts=4
 * 
 *
 * Copyright (c) 2008-2009  All rights reserved.
 */
#include "Arduino.h"
#include <stdio.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include "pins_arduino.h"
#include <inttypes.h>
#include "global.h"
#include "mcp2515.h"
#include "defaults.h"
#include "Canbus.h"




/* C++ wrapper */
CanbusClass::CanbusClass() {


}

char CanbusClass::message_rx(unsigned char *buffer) {
	tCAN message;

	if (mcp2515_check_message()) {

		// Lese die Nachricht aus dem Puffern des MCP2515
		if (mcp2515_get_message(&message)) {

			int i;
			for (i=0; i<8 ; i++) {
				buffer[i] = message.data[i];
			}

		}
	}
    return 1;
}

char CanbusClass::message_tx(void) {
	tCAN message;


	// einige Testwerte
	message.id = PID_REQUEST;
	message.header.rtr = 0;
	message.header.length = 8;
	message.data[0] = 0x02;
	message.data[1] = 0x01;
	message.data[2] = 0x05;
	message.data[3] = 0x00;
	message.data[4] = 0x00;
	message.data[5] = 0x00;
	message.data[6] = 0x00;
	message.data[7] = 0x00;						
	
	
	
	
//	mcp2515_bit_modify(CANCTRL, (1<<REQOP2)|(1<<REQOP1)|(1<<REQOP0), (1<<REQOP1));	
		mcp2515_bit_modify(CANCTRL, (1<<REQOP2)|(1<<REQOP1)|(1<<REQOP0), 0);
		
	if (mcp2515_send_message(&message)) {
		return 1;
	
	}
	else {
	//	PRINT("Fehler: konnte die Nachricht nicht auslesen\n\n");
	return 0;
	}
return 1;
 
}

/* Calling convention:
 * CanbusClass.decode_textual(&message,return_buffer);
 * returns 1 if decoded, 0 if not decoded (unsupported)
 */

char CanbusClass::decode_textual(tCAN *message, char *buffer) {

	float engine_data;
    char message_supported = 1;

	switch(message->data[2])
	{
	/* Details from http://en.wikipedia.org/wiki/OBD-II_PIDs */

		case ENGINE_RPM:  			//   ((A*256)+B)/4    [RPM]
		engine_data =  ((message->data[3]*256) + message->data[4])/4;
		sprintf(buffer,"%d rpm ",(int) engine_data);
		break;

		case ENGINE_COOLANT_TEMP: 	// 	A-40			  [degree C]
		engine_data =  message->data[3] - 40;
		sprintf(buffer,"%d degC",(int) engine_data);
		break;

		case VEHICLE_SPEED: 		// A				  [km]
		engine_data =  message->data[3];
		sprintf(buffer,"%d km ",(int) engine_data);
		break;

		case MAF_SENSOR:   			// ((256*A)+B) / 100  [g/s]
		engine_data =  ((message->data[3]*256) + message->data[4])/100;
		sprintf(buffer,"%d g/s",(int) engine_data);
		break;

		case O2_VOLTAGE:    		// A * 0.005   (B-128) * 100/128 (if B==0xFF, sensor is not used in trim calc)
		engine_data = message->data[3]*0.005;
		sprintf(buffer,"%d v",(int) engine_data);
        break;

		case THROTTLE:				// Throttle Position
		engine_data = (message->data[3]*100)/255;
		sprintf(buffer,"%d %% ",(int) engine_data);
		break;

        default:
        // unsupported PID
        message_supported=0;
		sprintf(buffer,"unsupported");
        break;   

	}
	return message_supported;
}

char CanbusClass::ecu_req(unsigned char pid,  char *buffer) {
	tCAN tx_message;
	tCAN rx_message;

	int timeout = 0;
	char message_ok = 0;
	// Prepair message
	tx_message.id = PID_REQUEST;
	tx_message.header.rtr = 0;
	tx_message.header.length = 8;
	tx_message.data[0] = 0x02;
	tx_message.data[1] = 0x01;
	tx_message.data[2] = pid;
	tx_message.data[3] = 0x00;
	tx_message.data[4] = 0x00;
	tx_message.data[5] = 0x00;
	tx_message.data[6] = 0x00;
	tx_message.data[7] = 0x00;
	

	mcp2515_bit_modify(CANCTRL, (1<<REQOP2)|(1<<REQOP1)|(1<<REQOP0), 0);
//		SET(LED2_HIGH);	
	if (mcp2515_send_message(&tx_message)) {
	}
	
	while(timeout < 4000)
	{
		timeout++;
				if (mcp2515_check_message()) 
				{

					if (mcp2515_get_message(&rx_message))
					{
							// replies can come from 0x7E8 through 0x7EF
							if((rx_message.id <= 0x7EF && rx_message.id >= 0x7E8 ) && (rx_message.data[2] == pid))	// Check message is the reply and its the right PID
							{
								
 								message_ok = decode_textual(&rx_message,buffer);
							}

					}
				}
				if(message_ok == 1) return 1;
	}


 	return 0;
}

char CanbusClass::init(unsigned char speed) {

  return mcp2515_init(speed);
 
}

CanbusClass Canbus;
