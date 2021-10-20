#include "commit.h"
#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdio.h>

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

/*  Stream para as USARTs  */
FILE usart0_str = FDEV_SETUP_STREAM(USART0SendByte, USART0ReceiveByte, _FDEV_SETUP_RW);
FILE usart1_str = FDEV_SETUP_STREAM(USART1SendByte, USART1ReceiveByte, _FDEV_SETUP_RW);

/* Variaveis globais  */
char is_master;
int g_state; // init: 0 | servo: 1-5 | led:11-15

int main(void)
{
	DDRL = 0x00;
	is_master = (PINL == 0b10000000);
	g_state = 0;
	USART0Init();
	USART1Init();
	sei();
	if (is_master)
	{
		fprintf(&usart0_str, "%s*** MASTER ***\n", LAST_COMMIT);
	} 
	else
	{
		fprintf(&usart0_str, "%s*** SLAVE ***\n", LAST_COMMIT);
	}
    while (1) 
    {
		if (is_master)
		{
			fprintf(&usart0_str, "Insert a command to the slave>\n");
			char terminalEntryChar = '\0';
			while(!fscanf(&usart0_str, "%c", &terminalEntryChar) || terminalEntryChar == '\n'){}
			// logic
		} 
		else
		{
		}
    }
}

/***********************************
*  Interrupt driver para o Timer1  *
***********************************/
ISR(TIMER1_COMPA_vect)
{
	// Esta interrupção foi disparada porque a TCNT1 atingiu o valor de ICR1.
	// TCNT1 é automaticamente zerado pelo TIMER e a contagem recomeça.
}

/***********************************************
*  Interrupt driver para o Receptor da USART0  *
***********************************************/
ISR(USART0_RX_vect)
{
}

/***********************************************
*  Interrupt driver para o Receptor da USART1  *
***********************************************/
ISR(USART1_RX_vect)
{
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
    UCSR1B=(1<<RXCIE1) | (0<<TXCIE1) | (0<<UDRIE1) | (1<<RXEN1) | (1<<TXEN1) | (0<<UCSZ12) | (0<<RXB80) | (0<<TXB81);
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
