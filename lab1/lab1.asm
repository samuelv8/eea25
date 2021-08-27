;********************************************************************
;********************************************************************
;**   lab1.asm                                                     **
;**
;**   Target MCU: Atmel ATmega328P                                 **
;**   X-TAL frequency: 16 MHz                                      **
;**   IDE: AVR Assembler 2 (Atmel Studio 6.2.1153)                 **
;**   Compiler: 
;**
;**   Description:                                                 **
;**       Sets the USART to operate in asynch mode with:           **
;**            57600 bps,                                          **
;**            1 stop bit,                                         **
;**            no  parity                                          **
; COMPLETE THIS
;**       PORTD with bits 2 to 5 configured as OUTPUT              **
;**                  bit 7 as INPUT                                **
;**       The main program's part shows 4 LEDs connected to        **
;**       4 least significant bits of PORT D.                      **
;**       The pulse counter applied in PD7 when SW2 is pushed and  **
;**       released. Register R17 is used to hold the pulse counter **
;**       value.                                                   **
;**
;**   Created: 2021/08/26 by samuelv8                              **
;********************************************************************
;********************************************************************

   ;; constants for baut rates
   .EQU	BAUD_RATE_2400 = 416
   .EQU	BAUD_RATE_9600 = 103
   .EQU	BAUD_RATE_57600 = 16
   .EQU	BAUD_RATE_115200 = 8
                        
   .CSEG                         ; FLASH segment code
   .ORG 0                        ; entry point after POWER/RESET

RESET:
	LDI	 R16, LOW(0x8ff)	     ; init stack pointer
	OUT	 SPL, R16
	LDI	 R16, HIGH(0x8ff)
	OUT	 SPH, R16
	LDI  R16, 0b00001111         ; set PB0 to PB3 as OUTPUTS and PB4 to PB7 as INPUTS
	OUT  DDRB, R16               ; 
	LDI  R17, 0b00000000         ; resets inicial pulse counter
	OUT  PORTB, R17              ; write it to PORT B
	CALL USART_INIT		         ; goes to USART init code
	LDI  R18, 'I'                ; increments by default

PRINT_MSG:
	LDI	 ZH, HIGH(2*PROMPT1)	 ; prints the intial message
	LDI	 ZL, LOW(2*PROMPT1)
	CALL SENDS
	LDI	 ZH, HIGH(2*PROMPT2)	 ; 
	LDI	 ZL, LOW(2*PROMPT2)
	CALL SENDS

READ_TO_GO:                      ; waits for open switch to start counting
    IN   R16, PIND               ;
    ANDI R16, 0b10000000         ;
    BREQ READ_TO_GO              ;

WAIT_SWITCH:
    IN   R16, PIND               ;
    ANDI R16, 0b10000000         ;
	BREQ WAIT_SWITCH_RELEASE

WAIT_USART:
	LDS  R16, UCSR0A
	SBRS  R16, RXC0
	RJMP WAIT_SWITCH             ;
	LDS  R18, UDR0		         ; reads the data
 
USART_INPUT:
	CALL USART_TRANSMIT
	LDI	 ZH, HIGH(2*CRLF)   	 ; 
	LDI	 ZL, LOW(2*CRLF)
	CALL SENDS
	RJMP WAIT_SWITCH

WAIT_SWITCH_RELEASE:             ; waits for switch release
    IN   R16, PIND               ;
    ANDI R16,0b10000000          ;
    BREQ WAIT_SWITCH_RELEASE     ;

DECISION:
	CPI  R18, 'D'
	BREQ DECREMENTS

INCREMENTS:                      ; counter increments and LED update
	INC  R17                     ;
    OUT  PORTB, R17              ;
    JMP  WAIT_SWITCH             ; jumps to WAIT_SWITCH

DECREMENTS:
	DEC R17
	OUT PORTB, R17
	JMP WAIT_SWITCH


;*********************************************************************
;  Subroutine USART_INIT  
;  Setup for USART: asynch mode, 57600 bps, 1 stop bit, no parity
;  Used registers:
;     - UBRR0 (USART0 Baud Rate Register)
;     - UCSR0 (USART0 Control Status Register B)
;     - UCSR0 (USART0 Control Status Register C)
;*********************************************************************	
USART_INIT:
	LDI	R17, HIGH(BAUD_RATE_57600); sets the baud rate
	STS	UBRR0H, R17
	LDI	R16, LOW(BAUD_RATE_57600)
	STS	UBRR0L, R16
	LDI	R16, (1<<RXEN0)|(1<<TXEN0) ; enables RX and TX

	STS	UCSR0B, R16
	LDI	R16, (0<<USBS0)|(3<<UCSZ00); frame: 8 data bits, 1 stop bit
	STS	UCSR0C, R16            ; no parity bit

	RET

;*********************************************************************
;  Subroutine USART_TRANSMIT  
;  Transmits (TX) R18   
;*********************************************************************
USART_TRANSMIT:
    PUSH R17                     ; saves R17 into stack

WAIT_TRANSMIT:
	LDS	 R17, UCSR0A
	SBRS R17, UDRE0		        ; waits for TX buffer to get empty
	RJMP WAIT_TRANSMIT
	STS	 UDR0, R18	           ; writes data into the buffer

	POP	R17                    ; restores R17
	RET

;*********************************************************************
;  Subroutine SENDS
;  Sends a message pointed by register Z in the FLASH memory
;*********************************************************************
SENDS:
	PUSH	R18

SENDS_REP:
	LPM	 R18, Z+
	CPI	 R18, '$'
	BREQ END_SENDS
	CALL USART_TRANSMIT
	JMP	 SENDS_REP
END_SENDS:
	POP	 R18
	RET

;*********************************************************************
; Hard coded messages
;*********************************************************************
PROMPT1: 
	.DB  "Press I for increasing the counter ", 0x0a, 0x0d, '$'
PROMPT2:
	.DB  "Press D for decreasing the counter ", 0x0a, 0x0d, '$'
CRLF:
	.DB  " ", 0x0a, 0x0d, '$'           ; carriage return & line feed chars             


   .EXIT