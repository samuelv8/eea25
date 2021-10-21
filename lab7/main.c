#include "commit.h"
#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdio.h>
#include <string.h>

#define CONST_OCR1X 2999
#define CONST_ICR1 39999

/*  Protótipos de funções  */
void Timer1Init(void);
void USART1Init(void);
void USART0Init(void);
int USART1SendByte(char,FILE *);
int USART0SendByte(char,FILE *);
int USART1ReceiveByte(FILE *);
int USART0ReceiveByte(FILE *);

void ChangeServoAngle(char,int);
void SwitchLed(char,char);

/*  Stream para as USARTs  */
FILE usart0_str = FDEV_SETUP_STREAM(USART0SendByte, USART0ReceiveByte, _FDEV_SETUP_RW);
FILE usart1_str = FDEV_SETUP_STREAM(USART1SendByte, USART1ReceiveByte, _FDEV_SETUP_RW);

/* Variaveis globais  */
char is_master;
int g_state; // init: 0 | servo: 1-5 | led:11-15

int main(void)
{
	DDRB = 0x00;
	DDRF = 0x01;
	DDRH = 0x03;
	DDRL = 0x00;
	is_master = (PINL == 0x80);  // PL7 alto -> master
	g_state = 0;
	USART0Init();
	USART1Init();
	sei();
	if (is_master)
	{
		fprintf(&usart0_str, "%s *** MASTER ***\n", LAST_COMMIT);
		PORTF = 0x01;
		char inputMessage[6];
		char responseMessage[8];
		int inputLength;
		int responseLength;
		while (1)
		{
			inputLength = 0;
			strcpy(inputMessage, "");
			fprintf(&usart0_str, "Insert a command to the slave>\n");
			// receives input
			while (1)
			{
				char terminalEntryChar = '\0';
				while(!fscanf(&usart0_str, "%c", &terminalEntryChar)){}
				if (terminalEntryChar == '\b')
				{
					inputLength--;
				}
				else if (terminalEntryChar == '\n' || inputLength == 5)
				{
					// send string to slave
					fprintf(&usart1_str, "%s", inputMessage);
					break;
				}
				else
				{
					inputMessage[inputLength++] = terminalEntryChar;
				}	
			}
			// wait for slave response
			responseLength = 0;
			while (1)
			{
				char responseChar = '\0';
				while(!fscanf(&usart1_str, "%c", &responseChar)){}
				responseMessage[responseLength++] = responseChar;
				if (responseLength == 7)
				{
					fprintf(&usart0_str, "%s\n", responseMessage);
					break;
				}
			}
		}
			
	} 
	else
	{
		fprintf(&usart0_str, "%s *** SLAVE ***\n", LAST_COMMIT);
		PORTF = 0x00;
		char masterMessage[6];
		int currentLength;
		char returnMessage[8];
		while (1)
		{
			currentLength = 0;
			strcpy(masterMessage, "");
			// waits for master
			while (1)
			{
				char masterChar = '\0';
				while(!fscanf(&usart1_str, "%c", &masterChar)){}
				masterMessage[currentLength++] = masterChar;
				if (currentLength == 5)
				{
					break;
				}
			}
			// process command
			char valid = 0;
			char servo;
			int angle;
			int servoAttr = sscanf(masterMessage, "S%[0-2]%3d", &servo, &angle);
			char led;
			char switchChar;
			int ledAttr = sscanf(masterMessage, "L%[0-1]O%c", &led, &switchChar);
			// executes command if valid
			if (servoAttr == 2)
			{
				valid = 1;
				fprintf(&usart0_str, "servo: %c angle: %d\n", servo, angle);
				ChangeServoAngle(servo, angle);
			} 
			else if (ledAttr == 2)
			{
				valid = 1;
				fprintf(&usart0_str, "led: %c char: %c\n", led, switchChar);
				SwitchLed(led, switchChar);
			}
			// returns response
			if (valid)
			{
				strcpy(returnMessage, "ACK    ");
			} 
			else
			{
				strcpy(returnMessage, "INVALID");
			}
			fprintf(&usart1_str, "%s", returnMessage);
			
		}
	}
}

int angle_lookup_table[181] = {
	1999,2010,2021,2032,2043,2055,2066,2077,2088,2099,2110,2121,2132,2143,2155,2166,2177,2188,2199,2210,2221,2232,2243,2255,2266,
	2277,2288,2299,2310,2321,2332,2343,2355,2366,2377,2388,2399,2410,2421,2432,2443,2455,2466,2477,2488,2499,2510,2521,2532,2543,
	2555,2566,2577,2588,2599,2610,2621,2632,2643,2655,2666,2677,2688,2699,2710,2721,2732,2743,2755,2766,2777,2788,2799,2810,2821,
	2832,2843,2855,2866,2877,2888,2899,2910,2921,2932,2943,2955,2966,2977,2988,2999,3010,3021,3032,3043,3055,3066,3077,3088,3099,
	3110,3121,3132,3143,3155,3166,3177,3188,3199,3210,3221,3232,3243,3255,3266,3277,3288,3299,3310,3321,3332,3343,3355,3366,3377,
	3388,3399,3410,3421,3432,3443,3455,3466,3477,3488,3499,3510,3521,3532,3543,3555,3566,3577,3588,3599,3610,3621,3632,3643,3655,
	3666,3677,3688,3699,3710,3721,3732,3743,3755,3766,3777,3788,3799,3810,3821,3832,3843,3855,3866,3877,3888,3899,3910,3921,3932,
	3943,3955,3966,3977,3988,3999
};

int AngleLogic(int angle)
{
	return angle_lookup_table[90+angle];
}

void ChangeServoAngle(char servo,int angle)
{
	if (angle < -90) {
		angle = -90;
	}
	if (angle > 90) {
		angle = 90;
	}
	int angleConst = AngleLogic(angle);
	switch(servo)
	{
		case '0':
			OCR1AH = angleConst>>8;
			OCR1AL = angleConst & 0xff;
		case '1':
			OCR1BH = angleConst>>8;
			OCR1BL = angleConst & 0xff;
		case '2':
			OCR1CH = angleConst>>8;
			OCR1CL = angleConst & 0xff;
			break;
	}
	return;
}
void SwitchLed(char led,char switchCar)
{
	int ledId = led - '0';
	if (switchCar == 'N') {
		PORTH ^= ((-1) ^ PORTH) & (1 << ledId);
	}
	else
	{
		PORTH ^= (0 ^ PORTH) & (0 << ledId);
	}
	return;
}

/***********************************
*  Interrupt driver para o Timer1  *
***********************************/
ISR(TIMER1_COMPA_vect)
{
	// Esta interrupção foi disparada porque a TCNT1 atingiu o valor de ICR1.
	// TCNT1 é automaticamente zerado pelo TIMER e a contagem recomeça.
}

/***********************
*  FUNÇÕES  DO TIMER1  *
***********************/

void Timer1Init(void)
  {
    /* Inicializacao to TIMER1:
            Modo 14, Fast-PWM, PRESCALER/8
    */
    TCCR1A=(1<<COM1A1) | (0<<COM1A0) | (1<<COM1B1) | (0<<COM1B0) | (1<<COM1C1) | (0<<COM1C0) | (1<<WGM11) | (0<<WGM10);
    TCCR1B=(0<<ICNC1) | (0<<ICES1) | (1<<WGM13) | (1<<WGM12) | (0<<CS12) | (1<<CS11) | (0<<CS10);
 
    OCR1AH=OCR1BH=OCR1CH=CONST_OCR1X>>8;
    OCR1AL=OCR1BL=OCR1CL=CONST_OCR1X & 0xff;
	
	ICR1H=CONST_ICR1>>8;
	ICR1L=CONST_ICR1 & 0xff;

  }

/************************
*  FUNÇÕES  DA USART0   *
************************/
void USART0Init(void)
{
	/* Inicializacao da USART1:
	       8 bits, 1 stop bit, sem paridade
		   Baud rate = 9600 bps
		   Sem interrupcoes
	*/
	UCSR0A=(0<<RXC0) | (0<<TXC0) | (0<<UDRE0) | (0<<FE0) | (0<<DOR0) | (0<<UPE0) | (0<<U2X0) | (0<<MPCM0);
	UCSR0B=(0<<RXCIE0) | (0<<TXCIE0) | (0<<UDRIE0) | (1<<RXEN0) | (1<<TXEN0) | (0<<UCSZ02) | (0<<RXB80) | (0<<TXB80);
	UCSR0C=(0<<UMSEL01) |(0<<UMSEL00) | (0<<UPM01) | (0<<UPM00) | (0<<USBS0) | (1<<UCSZ01) | (1<<UCSZ00) | (0<<UCPOL0);
	UBRR0H=0x00;
	UBRR0L=16;
}

int USART0SendByte(char u8Data,FILE *stream)
{
	if(u8Data == '\n')
	{
		USART0SendByte('\r',stream);
	}
	//wait while previous byte is completed
	while(!(UCSR0A&(1<<UDRE0))){};
	// Transmit data
	UDR0 = u8Data;
	return 0;
}  

int USART0ReceiveByte(FILE *stream)
{
	if (is_master)
	{
		uint8_t u8Data;
		// Espera recepcao de byte
		while(!(UCSR0A&(1<<RXC0)));
		u8Data=UDR0;
		// Ecoa o caractere no terminal
		USART0SendByte(u8Data,stream);
		// Retorna dado o recebido
		return u8Data;	
	} 
	else
	{
		return 0;
	}
} 

/************************
*  FUNÇÕES  DA USART1   *
************************/
void USART1Init(void)
{
    /* Inicializacao da USART1:
	       8 bits, 1 stop bit, sem paridade
		   Baud rate = 9600 bps
		   Interrupcoes por recepcao de caractere
	*/
	UCSR1A=(0<<RXC1) | (0<<TXC1) | (0<<UDRE1) | (0<<FE1) | (0<<DOR1) | (0<<UPE1) | (0<<U2X1) | (0<<MPCM1);
    UCSR1B=(0<<RXCIE1) | (0<<TXCIE1) | (0<<UDRIE1) | (1<<RXEN1) | (1<<TXEN1) | (0<<UCSZ12) | (0<<RXB80) | (0<<TXB81);
    UCSR1C=(0<<UMSEL11) |(0<<UMSEL10) | (0<<UPM11) | (0<<UPM10) | (0<<USBS1) | (1<<UCSZ11) | (1<<UCSZ10) | (0<<UCPOL1);
    UBRR1H=0x00;
    UBRR1L=16;
}

int USART1SendByte(char u8Data,FILE *stream)
{
   if(u8Data == '\n')
      {
         USART1SendByte('\r',stream);
      }
  // Espera byte anterior ser completado
  while(!(UCSR1A&(1<<UDRE1))){};
  // Transmite o dado
  UDR1 = u8Data;
  return 0;
}                         

int USART1ReceiveByte(FILE *stream)
{
	uint8_t u8Data;
	// Espera recepcao de byte
	while(!(UCSR1A&(1<<RXC1)));
	u8Data=UDR1;
	// Retorna dado o recebido
	return u8Data;
}
