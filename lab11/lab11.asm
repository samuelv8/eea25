;*************************************************************************
; LAB11		                                                         *
;                                                                        *
;    Programa teste para as instruções:                                  *
;	- FILLBLOCK	                                                 *
;	- MOVBLOCK	                                                 *
;	- LONGSUB	                                                 *
;	- LONGADD	                                                 *
;                                                                        *
;    As quais nao fazem parte do conjunto instrucoes do 8080/8085.       *
;                                                                        *
;    FILLBLOCK é codificada com o byte [08H]                             *
;       Preenche BC posicoes da memoria, a partir do endereco HL         *
;       com a constante A.                                               *
;       Nao deixa efeitos colaterais em PSW,BC,DE e HL.                  *
;                                                                        *
;    MOVBLOCK é codificada com o byte [10H].                             *
;       Copiar BC bytes a partir do endereco DE para o endereco HL.      *
;       Nao deixa efeitos colaterais em PSW,BC,DE e HL.                  *
;                                                                        *
;    LONGADD é codifivada com o byte [18H].                              *
;      Soma os numeros de C bytes apontados por HL e DE                  *
;      e coloca o resultado a partir do endereço HL.                     *
;      Os numeros são armazenados do byte mais significativo             *
;      para o menos significativo. Afeta apenas CARRY.                   *
;                                                                        *
;    LONGSUB é codifivada com o byte [20H].                              *
;      Subtrai o numero de C bytes apontado por DE                       *
;      do numero de C bytes apontado por HL e coloca o                   *
;      o resultado a partir do endereço HL.                              *
;      Os numeros são armazenados do byte mais significativo             *
;      para o menos significativo. Afeta apenas CARRY.                   *
;                                                                        *
;    O programa assume um hardware dotado dos seguintes elementos:       *
;                                                                        *
;    - Processador MP8 (8080/8085 simile);                               *
;    - ROM de 0000H a 1FFFh;                                             *
;    - RAM de E000h a FFFFh;                                             *
;    - UART 8250A vista nos enderecos 08H a 0Fh;                         *
;    - PIO de entrada vista no endereço 00h;                             *
;    - PIO de saída vista no endereço 00h.                               *
;                                                                        *
;    Para compilar e "linkar" o programa, pode ser usado o assembler     *
;    "zmac", com a linha de comando:                                     *
;                                                                        *
;         "zmac -8 --oo lst,hex lab11.asm".                              *
;                                                                        *
;    zmac produzirá na pasta zout o arquivo "lab11.hex", imagem do       *
;    código executável a ser carregado no projeto Proteus e também       *
;    e também o arquivo de listagem "lab11.lst".                         *
;                                                                        *
;*************************************************************************

; Define origem da ROM e da RAM (este programa tem dois segmentos).
; Diretivas nao podem comecar na primeira coluna.

CODIGO		EQU	0000H

DADOS		EQU	0E000H

TOPO_RAM	EQU	0FFFFH

;*******************************************
; Definicao de macros par que zmac reconheca
; novos mnemonicos de instrucao.
;*******************************************

FILLBLOCK	MACRO
		DB	08H
		ENDM	

MOVBLOCK	MACRO
		DB	10H
		ENDM	

LONGADD		MACRO
		DB	18H
		ENDM	

LONGSUB		MACRO
		DB	20H
		ENDM	

;********************
; Início do código  *
;********************
	ORG	CODIGO

INICIO:         
; Carrega os primeiros 8 bytes da RAM com FFH cada
		LXI	B,8	; todas as operacoes serao feitas com blocos de 8 bytes
		LXI	H,PARCELA1
		MVI	A,0FFH
		FILLBLOCK

; Carrega os 16 bytes (H e L) de PARCELA2 e os 8 últimos bytes de PARCELA1 com CONSTANTE2
		LXI	D,CONSTANTE2
		LXI	H,PARCELA2
		MOVBLOCK

		LXI	H,PARCELA2+8
		MOVBLOCK

		LXI	H,PARCELA1+8
		MOVBLOCK

; Efetua Mem[HL..HL+7]<--Mem[DE..DE+7]+Mem[HL..HL+7] e Mem[HL+8..HL+15]<--Mem[DE..DE+7]-Mem[HL+8..HL+15]
		LXI	D,PARCELA1
		LXI	H,PARCELA2
		LONGADD

		LXI	H,PARCELA2+8
		LONGSUB

;********************
; Fim do programa   *
;********************
		JMP	$

	
;********************
; Constantes        *
;********************
CONSTANTE2:	DB	00H,00H,00H,00H,00H,00H,00H,0FH


;********************
; Início dos dados  *
;********************
	ORG	DADOS
PARCELA1:	DS	16
	 	DS	16
PARCELA2:	DS	16

        END	INICIO

