;************************************************************************
;*   Projeto ATMega2560 Lab 3                                           *
;*                                                                      *
;*   Compilador:                                                        *
;*   AVRASM: AVR macro assembler 2.1.57 (build 16 Aug 27 2014 16:39:43) *
;*                                                                      *
;*   MCU alvo: Atmel ATmega2560 a 16 MHz com                            *
;*       - 3 servo-motores conectados aos terminais PB5-PB7;            *
;*       - Terminal alfanumérico "TERM1" conectado à USART1.            *
;*                                                                      *
;*   O TIMER1 recebe pulsos da saída Clk=16MHz/8 do PRESCALER e conta   *
;*   pulsos de 0 a 39999 (TOP), valor com o qual ICR1 é inicializado    *
;*   (equivalente a um período de 20ms). Quando o contador atinge o TOP *
;*   produz um pulso em OC1X com largura determinada por OCR1X, que é   *
;*   definido entre 1999 (1ms) e 3999 (2ms). Esse pulso determina o     *
;*   ângulo dos servos (entre -90 graus e +90 graus). Os servos         *
;*   inicializam em 0 graus. Os ângulos são controlados via USART,      *
;*   segundo o protocolo: SXsAA, com:                                   *
;*       - S(fixo);                                                     *
;*       - X={0,1,2}: servos A, B e C, respectivamente;                 *
;*       - s={-,+}: sinal;                                              *
;*       - AA={00-90}: ângulo.                                          *
;*                                                                      *
;*   Descricao:                                                         *
;*                                                                      *
;*       Inicializa o Stack Pointer com RAMEND;                         *
;*       Configura  portb como saída                                    *
;*       Configura a USART1 para operar no modo assincrono com          *
;*            9600 bps,                                                 *
;*            1 stop bit,                                               *
;*            sem paridade;                                             *
;*       Inicializa o TIMER1 para operar no Modo 14 para gerar os       *
;        sinais de controle para os servos.                             *
;*       Habilita interrupções com "SEI";                               *
;*                                                                      *
;*       A parte principal do programa fica em loop infinito.           *
;*                                                                      *
;*       Quando o programa é interrompido por um input na USART1, é     * 
;*       é chamada a rotina FSM, que implemente uma máquina de estado   *
;*       finita, que verifica se a entrada segue o protocolo. Se não,   *
;*       uma mensagem de erro é transmitida ao terminal e aguarda-se    *
;*       um novo input.                                                 *
;*                                                                      *
;* Author: samuelv8                                                     *   
;************************************************************************

;***************
;* Constantes  *
;***************
; Constantes para configurar baud rate (2400:416, 9600:103, 57600:16, 115200:8).

   .equ  BAUD_RATE = 103
   .equ  RETURN = 0x0A         ; Retorno do cursor.
   .equ  LINEFEED = 0x0D       ; Descida do cursor.
   .equ  USART1_RXC1_vect = 0x0048 ; Vetor para atendimento a interrupções RXC1.
   .equ  TIMER1_COMPA_vect = 0x0022  ; Vetor para atendimento a interrupções TIMRE1_COMPA match.
   .equ  CONST_OCR1X = 2999    ; Constante para o registrador OCR1X do TIMER1 (inicializa em 0 graus).
   .equ  CONST_ICR1 = 39999    ; Constante para o registrador ICR1 do TIMER1.
   
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
   out   spl, r16              
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
; e este já está disponível em UDR1 podendo ser lido imediatamente
   lds   r16,udr1               ; Carrega r16 com o caractere recebido
   call  USART1_TRANSMIT        ; Imprime caractere
   call  FSM                    ; Chama a máquina de estados para processar o input
   pop   r16
   reti
;*                         FIM DO INTERRUPT DRIVER DO RECEPTOR DA USAR11                *
;****************************************************************************************

;***********************************
;  INIT_PORTS                      *
;  Inicializa PORTB como saída     *
;  em PB5-PB7 e entrada nos demais *
;  terminais.                      *
;***********************************
INIT_PORTS:
   ldi   r16, 0b11100000        ; Em PB5, PB6 e PB7 as ondas quadradas geradas pelo TIMER1 serão emitidas
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
;  SENDS
;  Subrotina para enviar uma mensagem apontada pelo registrador Z
;*********************************************************************
SENDS:
	push r16
SENDS_REP:
	lpm	 r16, Z+
	cpi	 r16, 0
	breq END_SENDS
	call USART1_TRANSMIT
	jmp	 SENDS_REP
END_SENDS:
	pop	 r16
	ret

;*******************************************************************
; FSM
; Subrotina que implementa a lógica de uma máquina de estados
; finita, com estados de S0 a S9. O estado atual é guardado em
; r19. A máquina executa a lógica de próximo estado e retorna.
; Estados:
;    - S0: inicial (nenhum input relevante, espera por S)
;    - S1: foi lido S e verifica o input X
;    - S2: foi lido X e verifica o input s
;    - S3: foi lido s e verifica o input A
;    - S4: foi lido A e verifica o segundo input A
;    - S5: todo o protocolo foi lido e executa o respectivo comando 
;*******************************************************************
FSM:
   cpi  r19, 0  ; verifica qual o estado atual
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
   ret          ; se nenhum estado válido é verificado, retorna

SET_S0:
   ldi  r19, 0
   ret
; Verifica se recebeu 'S'
S0:
   cpi  r16, 'S'
   breq SET_S1  ; se sim, vai para o estado S1
   
   jmp  INVALID_INPUT

SET_S1:
   ldi r19, 1
   ret
; Verifica se recebeu '0', '1' ou '2'
S1:
   cpi  r16, '0'
   breq SERVO
   cpi  r16, '1'
   breq SERVO
   cpi  r16, '2'
   breq SERVO

   jmp  INVALID_INPUT

SET_S2:
   ldi  r19, 2
   ret
; Verifica se recebeu '+' ou '-'
S2:
   cpi  r16, '+'
   breq SET_PLUS
   cpi  r16, '-'
   breq SET_MINUS

   jmp  INVALID_INPUT

SET_S3:
   ldi  r19, 3
   ret
; Verifica se recebeu um dígito entre '0' e '9' para o primeiro
S3:
   subi r16, '0'
   brmi INVALID_INPUT   ; sai se for menor que '0'
   cpi  r16, 10
   brlo SET_ANGLE_1     ; entra se for menor que '10'

   jmp  INVALID_INPUT      

SET_S4:
   ldi  r19, 4
   ret
; Verifica se recebeu um dígito entre '0' e '9' para o segundo
S4:
   subi r16, '0'
   brmi INVALID_INPUT
   cpi  r16, 10
   brlo SET_ANGLE_2

   jmp  INVALID_INPUT

SET_S5:
   ldi  r19, 5
; Configura o servo de acordo com o input
S5:
   cpi  r18, 0
   breq SET_SERVO_A
   cpi  r18, 1
   breq SET_SERVO_B
   cpi  r18, 2
   breq SET_SERVO_C
   
   jmp  INVALID_INPUT

; Imprime uma mensagem de erro caso o input não esteja dentro do protocolo
INVALID_INPUT:
   call NEW_INPUT_LINE
   ldi	ZH, HIGH(2*INVALID_MSG)
   ldi	ZL, LOW(2*INVALID_MSG)
   call SENDS
RESET_INPUT:
   call NEW_INPUT_LINE ; imprime uma nova linha
   jmp  SET_S0         ; volta para o estado S0

NEW_INPUT_LINE:
   push r16
   ldi  r16, LINEFEED
   call USART1_TRANSMIT
   ldi  r16, RETURN
   call USART1_TRANSMIT
   pop  r16
   ret

; Carrega r18 com o número correspondente ao servo
SERVO:
   subi r16, '0'
   mov  r18, r16
   jmp  SET_S2    ; vai para o estado S2

; Carrega o MSB de r17 para guardar se o número é positivo (0) ou negativo (1)
SET_MINUS:
   ldi  r17, 0b10000000
   jmp  SET_S3    ; vai para o estado S3
SET_PLUS:
   ldi  r17, 0
   jmp  SET_S3

; Carrega o valor correspondente ao primeiro dígito (r16) em r20
SET_ANGLE_1:
   push r17
   ldi  r17, 10
   mul  r16, r17    ; multiplica por 10
   mov  r20, r0     
   pop  r17
   jmp  SET_S4
; Soma o valor do segundo dígito (r16) com o primeiro em r20 e mapeia no no intervalo [0, 180]
SET_ANGLE_2:
   push r17
   add  r20, r16
   sbrc r17, 7      ; verifica se o ângulo é negativo
   neg  r20         ; se for, é complementado
   ldi  r17, 90     ; mapeia no intervalo de interesse
   add  r20, r17
   pop  r17
   jmp  SET_S5      ; vai para o estado S5

; Define o valor de OCR1X com base no input dado
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
; ANGLE_LOGIC
; Subrotina para obter o valor de contagem OCR1X para obter o ângulo desejado (em r20),
; consultando o valor na lookup table. O resultado é armazenado em r21 (H) e r20 (L)
ANGLE_LOGIC:
	ldi  r21, 0
	add  r20, r20                 ; pega o dobro do valor (lookup table com words)
	adc  r21, r21                 ; guarda o carry em r21
	ldi  ZH, high(angle_table<<1)
	ldi  ZL, low(angle_table<<1)
	add  ZL, r20
	adc  ZH, r21
	lpm  r20, Z+                  ; parte baixa
	lpm  r21, Z                   ; parte alta
	ret

;**************************************
; TIMER1_INIT_MODE14                  *
; OCR1X=2999, ICR1=39999, PRESCALER/8 *
;**************************************
TIMER1_INIT_MODE14:
   ldi   r16, CONST_OCR1X>>8     
   sts   ocr1ah, r16
   sts   ocr1bh, r16
   sts   ocr1ch, r16
   ldi   r16, CONST_OCR1X & 0xff
   sts   ocr1al, r16
   sts   ocr1bl, r16
   sts   ocr1cl, r16

   ldi   r16, CONST_ICR1>>8  
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

   ret

   .org  0x200
;************************************
; Mensagens hardcoded
;************************************
INVALID_MSG:
   .db "Invalid input. ",0
;****************************************************************
; Lookup Table com os valores de OCR1X TIMER1 (16MHz/8 PRESCALER) 
; para cada ângulo inteiro no intervalo [-90, 90]
;****************************************************************
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
