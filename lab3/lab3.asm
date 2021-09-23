;************************************************************************
;*   Projeto ATMega2560 TIMER Interrupt                                 *
;*                                                                      *
;*   Compilador:                                                        *
;*   AVRASM: AVR macro assembler 2.1.57 (build 16 Aug 27 2014 16:39:43) *
;*                                                                      *
;*   MCU alvo: Atmel ATmega2560 a 16 MHz com                            *
;*       - Módulos de Leds de 7 segmentos conectados ao portl;          *
;*       - Terminal alfanumérico "TERM0" conectado à USART0.            *
;*                                                                      *
;*   Exemplifica interrupções periódicas do TIMER1 operando             *
;*     no modo 4 (Clear on Terminal Count).  O TIMER1 recebe pulsos     *
;*     da saída Clk=16MHz/1024 do PRESCALER e conta pulsos de           *
;*     0 a 15625, valor com o qual OCR1A é inicializado.  Assim,        *
;*     de 1024 X 15625 = 16000000 em 16000000 pulsos é produzida uma    *
;*     interrupção (uma interrupção por segundo).                       *
;*                                                                      *
;*   Descricao:                                                         *
;*                                                                      *
;*       Inicializa o Stack Pointer com RAMEND;                         *
;*       Configura  portl como saída e emite 0x00;                      *
;*       Configura a USART0 para operar no modo assincrono com          *
;*            9600 bps,                                                 *
;*            1 stop bit,                                               *
;*            sem paridade;                                             *
;*       Inicializa o TIMER1 para operar no Modo 4 para gerar um        *
;          pedido de interrupção por segundo.                           *
;*       Habilita interrupções com "SEI";                               *
;*                                                                      *
;*       A parte principal do programa fica em loop imprimindo o TERM0  *
;*       a mensagem "Hello, World!".                                    *
;*                                                                      *
;*       Quando TIMER1 atinge o valor em OCR1A, o elemento              *
;*       de contagem TCNT1 é zerado, o nível emitido em OC1A (PB5)      * 
;        é comoutado, interrupçao por OCR1A match                       *
;*       é gerada, o Interrupt driver é acionado e:                     *
;*                                                                      *
;*            Incrementa o valor emitido no portl, no qual estão        *
;*              conectados displays de 7 segmentos;                     *
;*            Retorna da interrupção com "RETI".                        * 
;*                                                                      *
;* Created: 07/09/2021 18:33:28 by chiepa                               *
;* Modified: 10/09/2021 10:32:20 by dloubach                            *   
;************************************************************************

;***************
;* Constantes  *
;***************
; Constantes para configurar baud rate (2400:416, 9600:103, 57600:16, 115200:8).

   .equ  BAUD_RATE = 103
   .equ  RETURN = 0x0A          ; Retorno do cursor.
   .equ  LINEFEED = 0x0D        ; Descida do cursor.
   .equ  USART1_RXC1_vect = 0x0048 ; Vetor para atendimento a interrupções RXC1.
   .equ  TIMER1_COMPA_vect = 0x0022  ; Vetor para atendimento a interrupções TIMRE1_COMPA match.
   .equ  CONST_OCR1X = 2999    ; Constante para o registrador OCR1X do TIMER1.
   .equ  CONST_ICR1 = 40000    ; Constante para o registrador ICR1 do TIMER1.
   
;*****************************
; Segmento de código (FLASH) *
;*****************************
   .cseg

; Ponto de entrada para RESET.
   .org  0 
   jmp   RESET

;*************************************************
;  PONTO DE ENTRADA DAS INTERRUPÇÕES DO TIMER1   *
;*************************************************
   .org  TIMER1_COMPA_vect
VETOR_TIMER1_COMPA:
   jmp   TIMER1_COMPA_INTERRUPT

;*************************************************************
;  PONTO DE ENTRADA DAS INTERRUPÇÕES DO RECEPTOR DA USART1   *
;*************************************************************
   .org  USART1_RXC1_vect
VETOR_USART1RX:
   jmp   USART1_RX1_INTERRUPT

   .org  0x100
RESET:
   ldi   r16, low(ramend)       ; Inicializa Stack Pointer.
   out   spl, r16               ; Para ATMega328 RAMEND=08ff.
   ldi   r16, high(ramend)
   out   sph, r16

   call  INIT_PORTS             ; Inicializa portb.
   call  USART1_INIT            ; Inicializa USART0.
   call  TIMER1_INIT_MODE14     ; Inicializa TIMER1.
   sei                          ; Habilita interrupções.


;****************************************************************************************
;*                         PARTE PRINCIPAL DO PROGRAMA                                  *

LOOP_PRINCIPAL:
   jmp   LOOP_PRINCIPAL

;*                         FIM DA PARTE PRINCIPAL DO PROGRAMA                           *
;****************************************************************************************


;****************************************************************************************
;*                        INTERRUPT DRIVER DO do TIMER1_COMPA match                     *
;                                TIMER1_COMPA_INTERRUPT                                 * 
TIMER1_COMPA_INTERRUPT:

; Esta interrupção foi disparada porque a TCNT1 atingiu o valor de ICR1.
; TCNT1 é automaticamente zerado pelo TIMER e a contagem recomeça.
   reti

;*                         FIM DO INTERRUPT DRIVER DO TIMER1                            *
;****************************************************************************************


;****************************************************************************************
;*                        INTERRUPT DRIVER DO RECEPTOR DA USART1                        *
;                                USART1_RX1_INTERRUPT                                   * 
USART1_RX1_INTERRUPT:
   push  r16

; Esta interrupção foi disparada porque a USART1 recebeu um caracter
;   e este já está disponível em UDR1 podendo ser lido imediatamente,
;   sem a necessidade de testar o bit RXC1 do registrador UCSR1A.
   lds   r16,udr1               ; R16 <-- caractere recebido.

   call  USART1_TRANSMIT        ; Imprime caractere recebido.
   call  FSM                    ; Le propriamente com a FSM

   pop   r16
   reti

;*                         FIM DO INTERRUPT DRIVER DO RECEPTOR DA USAR11                *
;****************************************************************************************

;***********************************
;  INIT_PORTS                      *
;  Inicializa PORTB como saída     *
;    em PB5 e entrada nos demais   *
;    terminais.                    *
;  Inicializa portl como saída     *
;    e emite 0x00 em ambos.        *
;***********************************
INIT_PORTS:
   ldi   r16, 0b11100000        ; Para emitir em PB5, PB6 e PB7 as ondas quadradas geradas pelo TIMER1.
   out   ddrb, r16
   ret

;****************************************
;  USART1_INIT                          *
;  Subrotina para inicializar a USART.  *
;****************************************
; Inicializa USART1: modo assincrono, 9600 bps, 1 stop bit, sem paridade.  
; Os registradores são:
;     - UBRR1 (USART1 Baud Rate Register)
;     - UCSR1 (USART1 Control Status Register B)
;     - UCSR1 (USART1 Control Status Register C)
USART1_INIT:
   ldi   r17, high(BAUD_RATE)   ;Estabelece Baud Rate.
   sts   ubrr1h, r17
   ldi   r16, low(BAUD_RATE)
   sts   ubrr1l, r16


;**************************************************************************************************
; ICSRB1 inicializado com interrupções RXCIE1 (interrompe quando recebe caractere) habilitadas.   *
;**************************************************************************************************
   ldi   r16,(1<<rxcie1)|(1<<rxen1)|(1<<txen1)   ;Interrupções do receptor,
                                                 ;  receptor e transmissor.
   sts   ucsr1b,r16
   ldi   r16,(0<<usbs1)|(1<<ucsz11)| (1<<ucsz10)   ;Frame: 8 bits dado, 1 stop bit,
   sts   ucsr1c,r16             ;sem paridade.

   ret

;*************************************
;  USART1_TRANSMIT                   *
;  Subrotina para transmitir R16.    *
;*************************************

USART1_TRANSMIT:
   push  r17                    ; Salva R17 na pilha.

WAIT_TRANSMIT1:
   lds   r17, ucsr1a
   sbrs  r17, udre1             ;Aguarda BUFFER do transmissor ficar vazio.      
   rjmp  WAIT_TRANSMIT1
   sts   udr1, r16              ;Escreve dado no BUFFER.

   pop   r17                    ;Restaura R17 e retorna.
   ret

;*********************************************************************
;  Subroutine SENDS
;  Sends a message pointed by register Z in the FLASH memory
;*********************************************************************
SENDS:
	PUSH r16
SENDS_REP:
	LPM	 r16, Z+
	CPI	 r16, 0
	BREQ END_SENDS
	CALL USART1_TRANSMIT
	JMP	 SENDS_REP
END_SENDS:
	POP	 r16
	RET

;**************************************
; FSM

FSM:
   cpi  r19, 0
   breq S0
   cpi  r19, 1
   breq S1
   cpi  r19, 2
   breq S2
   cpi  r19, 3
   breq S3
   cpi  r19, 4
   breq S4
   cpi  r19, 5
   breq S5
   ret

INIT_S0:
   ldi  r19, 0
   ret
S0:
   cpi  r16, 'S'
   breq INIT_S1
   
   jmp  INVALID_INPUT ; case the usart input is not 'S'

INIT_S1:
   ldi r19, 1
   ret
S1:
   cpi  r16, '0'
   breq SERVO
   cpi  r16, '1'
   breq SERVO
   cpi  r16, '2'
   breq SERVO

   jmp  INVALID_INPUT ; case the usart input is neither '0', '1' or '2'

INIT_S2:
   ldi  r19, 2
   ret
S2:
   cpi  r16, '+'
   breq SET_PLUS
   cpi  r16, '-'
   breq SET_MINUS

   jmp  INVALID_INPUT  ; case the usart input is neither '+' or '-'

INIT_S3:
   ldi  r19, 3
   ret
S3:
   subi r16, '0'
   brmi INVALID_INPUT   ; if received char is lower than '0'
   cpi  r16, 10
   brlo SET_ANGLE_1     ; set if it is lower than 10

   jmp  INVALID_INPUT      


INIT_S4:
   ldi  r19, 4
   ret
S4:
   subi r16, '0'
   brmi INVALID_INPUT
   cpi  r16, 10
   brlo SET_ANGLE_2

   jmp  INVALID_INPUT

INIT_S5:
   ldi  r19, 5
S5:
   cpi  r18, 0
   breq SET_SERVO_A
   cpi  r18, 1
   breq SET_SERVO_B
   cpi  r18, 2
   breq SET_SERVO_C
   
   jmp  INVALID_INPUT

INVALID_INPUT:
   call NEW_INPUT_LINE
   ldi	ZH, HIGH(2*INVALID_MSG)
   ldi	ZL, LOW(2*INVALID_MSG)
   call SENDS
RESET_INPUT:
   call NEW_INPUT_LINE  ; print a new line and go back to state S0
   jmp  INIT_S0

NEW_INPUT_LINE:
   push r16
   ldi  r16, LINEFEED
   call USART1_TRANSMIT
   ldi  r16, RETURN
   call USART1_TRANSMIT
   pop  r16
   ret

SERVO:
   subi r16, '0'
   mov  r18, r16    ; loads r18 with the corresponding servo (0, 1 or 2)
   jmp  INIT_S2

SET_MINUS:
   ldi  r17, 0b10000000
   jmp  INIT_S3
SET_PLUS:
   ldi  r17, 0
   jmp  INIT_S3

SET_ANGLE_1:
   push r17
   ldi  r17, 10
   mul  r16, r17    ; multiplies first digit by 10
   mov  r20, r0     ; stores the result in r20
   pop  r17
   jmp  INIT_S4

SET_ANGLE_2:
   push r17
   add  r20, r16    ; sums the second digit
   sbrc r17, 7      ; skips if angle is positive
   neg  r20
   ldi  r17, 90     ; [-90, 90] to [0, 180]
   add  r20, r17
   pop  r17
   jmp  INIT_S5

SET_SERVO_A:
   call  ANGLE_LOGIC   
   sts   ocr1ah, r21
   sts   ocr1al, r20
   jmp   RESET_INPUT

SET_SERVO_B:
   call  ANGLE_LOGIC   
   sts   ocr1bh, r21
   sts   ocr1bl, r20
   jmp   RESET_INPUT

SET_SERVO_C:
   call  ANGLE_LOGIC   
   sts   ocr1ch, r21
   sts   ocr1cl, r20
   jmp   RESET_INPUT

;**************************************
; angle position [0, 180] stored in R20
; loads OCR1X value in R20, R21
ANGLE_LOGIC:
	ldi  r21, 0
	add  r20, r20                 ; gets double of value (16 bits)
	adc  r21, r21                 ; stores carry in R21
	ldi  ZH, high(angle_table<<1)
	ldi  ZL, low(angle_table<<1)
	add  ZL, r20
	adc  ZH, r21
	lpm  r20, Z+                  ; low
	lpm  r21, Z                   ; high
	
	ret


;**************************************
; TIMER1_INIT_MODE14                  *
; OCR1X=2999, ICR1=40000, PRESCALER/8 *
;**************************************
TIMER1_INIT_MODE14:
   ldi   r16, CONST_OCR1X>>8     ; loads OCR1X
   sts   ocr1ah, r16
   sts   ocr1bh, r16
   sts   ocr1ch, r16
   ldi   r16, CONST_OCR1X & 0xff
   sts   ocr1al, r16
   sts   ocr1bl, r16
   sts   ocr1cl, r16

   ldi   r16, CONST_ICR1>>8      ; loads ICR1
   sts   icr1h, r16
   ldi   r16, CONST_ICR1 & 0xff
   sts   icr1l, r16

; Modo 14, Fast-PWM: (WGM13, WGM12, WGM11, WGM10)=(1,1,1,0)
; Set non-inverting mode output: (COM1X1, COM1X0) = (1, 0)
   ldi   r16, (1<<com1a1) | (0<<com1a0) | (1<<com1b1) | (0<<com1b0) | (1<<com1c1) | (0<<com1c0) | (1<<wgm11) | (0<<wgm10)
   sts   tccr1a, r16

; Modo 14, Fast-PWM: (WGM13, WGM12, WGM11, WGM10)=(1,1,1,0)
; Clock select: (CS12,CS11,CS10)=(0,1,0), PRESCALER/8
; No input capture: (ICNC1) | (0<<ICES1)
   ldi   r16,(0<<icnc1) | (0<<ices1) | (1<<wgm13) | (1<<wgm12) | (0<<cs12) |(1<<cs11) | (0<<cs10)
   sts   tccr1b, r16

; Timer/Counter 1 Interrupt(s) initialization
   ldi   r16, (0<<icie1) | (0<<ocie1c) | (0<<ocie1b) | (0<<ocie1a) | (0<<toie1)
   sts   timsk1, r16

   ret

   .org  0x200
;*********************************************************************
; Hard coded messages
;*********************************************************************
INVALID_MSG:
   .db "Invalid input. ",0
;************************************
; Lookup Table with timer constants *
; for each integer angle in [0, 180]*
;************************************
angle_table:
   .dw 1999,2010,2021,2032,2043,2055,2066,2077,2088,2099,2110,2121,2132,2143,2155,2166,2177,2188,2199,2210,2221,2232,2243,2255,2266
   .dw 2277,2288,2299,2310,2321,2332,2343,2355,2366,2377,2388,2399,2410,2421,2432,2443,2455,2466,2477,2488,2499,2510,2521,2532,2543
   .dw 2555,2566,2577,2588,2599,2610,2621,2632,2643,2655,2666,2677,2688,2699,2710,2721,2732,2743,2755,2766,2777,2788,2799,2810,2821
   .dw 2832,2843,2855,2866,2877,2888,2899,2910,2921,2932,2943,2955,2966,2977,2988,2999,3010,3021,3032,3043,3055,3066,3077,3088,3099
   .dw 3110,3121,3132,3143,3155,3166,3177,3188,3199,3210,3221,3232,3243,3255,3266,3277,3288,3299,3310,3321,3332,3343,3355,3366,3377
   .dw 3388,3399,3410,3421,3432,3443,3455,3466,3477,3488,3499,3510,3521,3532,3543,3555,3566,3577,3588,3599,3610,3621,3632,3643,3655
   .dw 3666,3677,3688,3699,3710,3721,3732,3743,3755,3766,3777,3788,3799,3810,3821,3832,3843,3855,3866,3877,3888,3899,3910,3921,3932
   .dw 3943,3955,3966,3977,3988,3999

;*****************************
; Finaliza o programa fonte  *
;*****************************
   .exit
