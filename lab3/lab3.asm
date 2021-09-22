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
   .equ  TIMER1_COMPA_vect = 0x0022  ; Vetor para atendimento a interrupções TIMRE1_COMPA match.
   .equ  CONST_OCR1X = 1999    ; Constante para o registrador OCR1A do TIMER1.
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


   .org  0x100
RESET:
   ldi   r16, low(ramend)       ; Inicializa Stack Pointer.
   out   spl, r16               ; Para ATMega328 RAMEND=08ff.
   ldi   r16, high(ramend)
   out   sph, r16

   call  INIT_PORTS             ; Inicializa portb.
   call  USART1_INIT            ; Inicializa USART0.
   call  TIMER1_INIT_MODE4      ; Inicializa TIMER1.
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
   push   r16
   lds    r16, sreg
   push   r16

; Esta interrupção foi disparada porque a TCNT1 atingiu o valor de OCR1A.
; TCNT1 é automaticamente zerado pelo TIMER e a contagem recomeça.
; Retorna.
   reti

;*                         FIM DO INTERRUPT DRIVER DO TIMER1                            *
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

;*******************************************
;  USART1_RECEIVE                           *
;  Subrotina                               *
;  Aguarda a recepção de dado pela USART   *
;  e retorna com o dado em R16.            *
;*******************************************

USART1_RECEIVE:
   push  r17                    ; Salva R17 na pilha.

WAIT_RECEIVE1:
   lds   r17,ucsr1a
   sbrs  r17,rxc1
   rjmp  WAIT_RECEIVE1          ;Aguarda chegada do dado.
   lds   r16,udr1               ;Le dado do BUFFER e retorna.

   pop   r17                    ;Restaura R17 e retorna.
   ret

;**************************************
; TIMER1_INIT_MODE4                   *
; OCR1X=2000, ICR1=40000, PRESCALER/8 *
;**************************************
TIMER1_INIT_MODE4:
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

;************************************
; Segmento de dados (RAM)           *
; Mostra como alocar espaço na RAM  *
; para variaveis.                   *
;   - NÃO USADAS NESTE PROGRAMA -   *
;************************************
.dseg
   .org  0x200
CARACTERE:
   .byte 1

;*****************************
; Finaliza o programa fonte  *
;*****************************
   .exit
