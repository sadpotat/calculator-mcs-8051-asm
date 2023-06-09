ORG 00H

NUM EQU 1H	;FOR ERRORCHK
NEG EQU 2H	;HIGH IF OUTPUT IS NEGATIVE, TO DISPLAY '-'
IN1 EQU 3H	;HIGH IF INPUT 1 IS BEING ENTERED
IN2 EQU 4H	;HIGH IF INPUT 2 IS BEING ENTERED
SYMB EQU 5H	;HIGH IF OP IS BEING ENTERED
IN1NEG EQU 6H	;HIGH IF INPUT 1 IS NEGATIVE
IN2NEG EQU 7H	;HIGH IF INPUT 2 IS NEGATIVE

SUBTRACT EQU 0AH	;HIGH IF SUBTRACTION WAS SELECTED
SUBNORMAL EQU 0CH	;FOR ADDSUB

FLAG1 EQU 30H	;FOR COUNTING '='
FLAG2 EQU 31H

INI:
	MOV SP, #30H	;SCRATCHPAD RAM AS STACK
	
	CLR NUM
	CLR NEG
	CLR IN1
	CLR IN2
	CLR SYMB
	CLR IN1NEG
	CLR IN2NEG
	CLR SUBTRACT
	CLR SUBNORMAL
	CLR FLAG1
	CLR FLAG2
	
	MOV R0, #50H
	MOV R1, #38
CLEAR:	MOV @R0, #0
	INC R0
	DJNZ R1, CLEAR
	
	MOV R0, #60H 	;STARTING ADDRESS OF INPUT 1
	MOV DPTR, #LCD_IN
	LCALL DISPLAY_COMM
	
	MOV DPTR, #PROMPT1
	LCALL DISPLAY_DATA
	SETB IN1
	
	MOV DPTR, #LCD_LINESKIP
	LCALL DISPLAY_COMM
	LJMP START	
	
INI2:	
	MOV R0,#65H	;STARTING ADDRESS OPERATION SYMBOL
	MOV DPTR, #LCD_CLEAR
	LCALL DISPLAY_COMM
	
	MOV DPTR, #PROMPT2
	LCALL DISPLAY_DATA
	CLR IN1
	SETB SYMB
	
	MOV DPTR, #LCD_LINESKIP
	LCALL DISPLAY_COMM
	LJMP START

INI3:	MOV R0,#67H	;STARTING ADDRESS OF INPUT 2
	MOV DPTR, #LCD_CLEAR
	LCALL DISPLAY_COMM
	
	MOV DPTR, #PROMPT3
	LCALL DISPLAY_DATA
	CLR SYMB
	SETB IN2
	
	MOV DPTR, #LCD_LINESKIP
	LCALL DISPLAY_COMM
	LJMP START

;Keyboard

START:
	MOV A,#0FH
	MOV P2,A
K1: 	MOV P2,#00001111B
	MOV A,P2
	ANL A,#00001111B
	CJNE A,#00001111B,K1

K2: 	ACALL DELAY
	MOV A,P2
	ANL A,#00001111B
	CJNE A,#00001111B,OVER
	SJMP K2

OVER: 	ACALL DELAY
	MOV A,P2
	ANL A,#00001111B
	CJNE A,#00001111B,OVER1
	SJMP K2

OVER1: 	MOV P2,#11101111B
	MOV A,P2
	ANL A,#00001111B
	CJNE A,#00001111B,ROW_0
	MOV P2,#11011111B
	MOV A,P2
	ANL A,#00001111B
	CJNE A,#00001111B,ROW_1
	MOV P2,#10111111B
	MOV A,P2
	ANL A,#00001111B
	CJNE A,#00001111B,ROW_2
	MOV P2,#01111111B
	MOV A,P2
	ANL A,#00001111B
	CJNE A,#00001111B,ROW_3
	LJMP K2
	
ROW_0: 	MOV DPTR,#KCODE0
	SJMP FIND
ROW_1: 	MOV DPTR,#KCODE1
	SJMP FIND
ROW_2: 	MOV DPTR,#KCODE2
	SJMP FIND
ROW_3: 	MOV DPTR,#KCODE3

FIND: 	RRC A
	JNC MATCH
	INC DPTR
	SJMP FIND
	
MATCH: 	CLR A
	MOVC A,@A+DPTR
	
	CJNE A, #'=', REST 
	
	ACALL ERRCHECK
	JB FLAG1, F2	;FLAG1=1 MEANS 2 = 
	SETB FLAG1
	LJMP INI2

F2:	JB FLAG2, F3	;FLAG2=1 MEANS 3 = 
	SETB FLAG2
	LJMP INI3
	
F3:	LJMP CALC
	
REST:	CJNE A, #99H, ON_AC
	MOV A,#01
	ACALL COMNWRT
	ACALL DELAY
	LJMP INI
	
ON_AC:	MOV @R0,A
	INC R0
	ACALL DATAWRT
	ACALL DELAY
	LJMP K1
	
CALC:	MOV DPTR, #LCD_CLEAR
	ACALL DISPLAY_COMM
	
	MOV R0, #60H
	MOV A, @R0
	CJNE A, #'-',IN1_POS
	SETB IN1NEG
	INC R0
IN1_POS:
	ACALL ASCII_TO_HEX
	MOV 55H, 51H	;INPUT 1 IN BCD
	MOV 6BH, 52H	;INPUT 1 IN HEX
	MOV R0, #67H
	MOV A, @R0
	CJNE A, #'-',IN2_POS
	SETB IN2NEG
	INC R0
IN2_POS:
	ACALL ASCII_TO_HEX
	MOV 6CH, 52H	;INPUT 2 IN HEX
	
	JNB IN1NEG, CHK_IN2
	SETB NEG
CHK_IN2:
	JNB IN2NEG, CHK_DONE
	CPL NEG		;1 IF IN ANY ONE INPUT IS NEGATIVE
			;0 IF BOTH OR NONE ARE NEGATIVE
			
CHK_DONE:	
	MOV R0,#65H
	MOV A,@R0

	CJNE A, #'+', S1
	LJMP ADDSUB
	
S1:	CJNE A, #'-', S2
	SETB SUBTRACT
	LJMP ADDSUB
	
S2:	CJNE A, #'*', S3
	LJMP MULTIPLICATION
	
S3:	CJNE A, #'/', ERRORDISP
	LJMP DIVISION

ERRCHECK:
	CLR NUM
	JB IN1, INPUT_1
	JB SYMB, SYMBOL
	JB IN2, INPUT_2
INPUT_1:
	MOV R0, #5FH	;PREVIOUS BYTE TAKEN TO ADJUST FOR INC R0
	SJMP CHK
SYMBOL:
	MOV R0, #64H
	SJMP CHK
INPUT_2:
	MOV R0, #66H
	SJMP CHK	
CHK:
	MOV R7, #0	;SYMBOL COUNT
	MOV R6, #0	;DIGIT COUNT	
NEXTCHK:
	INC R0
	MOV A, @R0	
	CJNE R7, #2, SYM_OK
	SJMP ERRORDISP		;DOUBLE SYMBOL -> ERROR
SYM_OK:
	CJNE R6, #3, DIG_OK
	SJMP ERRORDISP		;TRIPLE DIGIT -> ERROR
DIG_OK:
	JZ ENDCHK
	CJNE A, #'+',CHK1
	INC R7
	SJMP NOT_MINUS
CHK1:	CJNE A, #'-',CHK2
	INC R7
	JB NUM, ERRORDISP
	SJMP NEXTCHK
CHK2:	CJNE A, #'*',CHK3
	INC R7
	SJMP NOT_MINUS
CHK3:	CJNE A, #'/',CHK4
	INC R7
	SJMP NOT_MINUS
CHK4:	INC R6
	JB SYMB, ERRORDISP	;NUMBER IN OP -> ERROR
	SETB NUM		;INDICATES IF A NUMBER HAS ALREADY BEEN ENTERED
	SJMP NEXTCHK
NOT_MINUS:
	JB IN1, ERRORDISP	;ANY SYMBOL OTHER THAN '-' WITH INPUTS -> ERROR
	JB IN2, ERRORDISP
	JB NUM, ERRORDISP	;IF NUM=1 THEN THE SYMBOL WAS ENTERED AFTER A NUMBER -> ERROR
	SJMP NEXTCHK
ENDCHK:
	RET
	

ERRORDISP:
	MOV DPTR, #LCD_CLEAR
	ACALL DISPLAY_COMM
	
	MOV DPTR, #OUTPUT3
	ACALL DISPLAY_DATA
	
	MOV DPTR, #LCD_LINESKIP
	ACALL DISPLAY_COMM
	
	MOV DPTR, #OUTPUT4
	ACALL DISPLAY_DATA
	LJMP DONE

ADDSUB:			
	CLR NEG
	MOV B, 6CH
	JNB IN2NEG, ADDSUB_IN2
	JB SUBTRACT, ADDSUB_IN2_DONE	
	SETB SUBNORMAL		;FLAG FOR SUB_NORMAL
	SJMP ADDSUB_IN2_DONE
ADDSUB_IN2:
	JNB SUBTRACT, ADDSUB_IN2_DONE 
	SETB SUBNORMAL
ADDSUB_IN2_DONE:
	MOV A, 6BH
	JNB IN1NEG, ADDSUB_IN1_DONE	
	JNB SUBNORMAL, ADDSUB_CONT	
	SETB NEG
	SJMP ADD_NORMAL			
ADDSUB_CONT:	;SWAPS INPUTS. -IN1 + IN2 WILL THEN BE IN2-IN1
	MOV R7, A
	MOV A, B
	MOV B, R7
	SJMP SUB_NORMAL
ADDSUB_IN1_DONE:
	JB SUBNORMAL, SUB_NORMAL
ADD_NORMAL:
	ADD A, B
	SJMP ADDSUB_DONE
SUB_NORMAL:
	CLR C
	SUBB A, B
ADDSUB_DONE:
	JNC ADDSUB_RESULT
	CPL A
	INC A
	SETB NEG
ADDSUB_RESULT:	
	MOV 70H, A
	MOV R0, #70H
	ACALL HEX_TO_ASCII
	ACALL DISPLAY_RESULT
	LJMP DONE

MULTIPLICATION:
	MOV R2, 6CH	;COUNTER = 2ND INPUT IN HEX
	CLR A
	MOV R7, #0H
MUL1:	ADD A, 55H 	;ADDS FIRST INPUT IN BCD
	DA A
	JNC MUL2
	INC R7
MUL2:	DJNZ R2, MUL1
	MOV 71H, A	
	;UPPER BYTE IN R7, LOWER BYTE IN A
	MOV R0, #07H 	;ADDRESS OF R7
	ACALL HEX_TO_ASCII
	ACALL DISPLAY_RESULT	;DISPLAYS THE HIGHER BYTE
	MOV A, 71H	;DISPLAYS THE LOWER BYTE
	ANL A, #0F0H
	SWAP A
	ORL A, #30H
	ACALL DATAWRT
	ACALL DELAY
	MOV A, 71H
	ANL A, #0FH
	ORL A, #30H
	ACALL DATAWRT
	ACALL DELAY
	LJMP DONE
	
DIVISION:
MOV A,#0H
CJNE A,6CH,DIV1
LJMP ERRORDISP 

DIV1:
MOV A,6BH
MOV B,6CH

DIV AB

MOV 70H,A
MOV 71H,B

DISPLAY_DIV:
	MOV DPTR, #OUTPUT1
	ACALL DISPLAY_DATA
	JNB NEG, NONEG1
	MOV A, #'-'
	ACALL DATAWRT
	ACALL DELAY
NONEG1:	MOV R0, #70H
	ACALL HEX_TO_ASCII
	MOV A, 55H
	ACALL DATAWRT
	ACALL DELAY
	MOV A, 56H
	ACALL DATAWRT
	ACALL DELAY
	MOV A, 57H
	ACALL DATAWRT
	ACALL DELAY
	MOV DPTR, #LCD_LINESKIP
	ACALL DISPLAY_COMM
	MOV DPTR, #OUTPUT2
	ACALL DISPLAY_DATA
	MOV R0, #71H
	ACALL HEX_TO_ASCII
	MOV A, 55H
	ACALL DATAWRT
	ACALL DELAY
	MOV A, 56H
	ACALL DATAWRT
	ACALL DELAY
	MOV A, 57H
	ACALL DATAWRT
	ACALL DELAY
	LJMP DONE

;CONVERTERS
ASCII_TO_HEX:
	MOV A,@R0
	ANL A,#0FH
	MOV 50H,A
	INC R0
	MOV A,@R0
	JZ A2H_1
	MOV A,50H
	SWAP A
	MOV 50H,A
	MOV A,@R0
	ANL A,#0FH
	ORL A,50H
	SJMP A2H_2
A2H_1:	MOV A,50H	
A2H_2:	MOV 51H,A
	ANL A,#0F0H
	SWAP A
	MOV B,#0AH
	MUL AB
	MOV 52H,A
	MOV A,51H
	ANL A,#0FH
	ADD A,52H
	MOV 52H,A
	RET
	
HEX_TO_ASCII:
	MOV A,@R0 
	MOV B,#10
	DIV AB
	MOV 53H,B	
	MOV B,#10
	DIV AB
	MOV 54H,B
	ANL A,#0FH
	ORL A,#30H
	MOV 55H,A	;MSB
	MOV A,54H
	ANL A,#0FH
	ORL A,#30H
	MOV 56H,A
	MOV A,53H
	ANL A,#0FH
	ORL A,#30H
	MOV 57H,A	;LSB
	RET

DISPLAY_RESULT:
	MOV DPTR, #OUTPUT5
	ACALL DISPLAY_DATA
	JNB NEG, NONEG
	MOV A, #'-'
	ACALL DATAWRT
	ACALL DELAY
NONEG:	MOV A, 55H
	ACALL DATAWRT
	ACALL DELAY
	MOV A, 56H
	ACALL DATAWRT
	ACALL DELAY
	MOV A, 57H
	ACALL DATAWRT
	ACALL DELAY
	RET
		
DISPLAY_COMM:
	CLR A
	MOVC A, @A+DPTR
	JZ END_R
	ACALL COMNWRT
	ACALL DELAY
	INC DPTR
	SJMP DISPLAY_COMM
END_R:	RET

DISPLAY_DATA: 	
	CLR A
	MOVC A, @A+DPTR
	JZ END_W
	ACALL DATAWRT
	ACALL DELAY
	INC DPTR
	SJMP DISPLAY_DATA
END_W:	RET	
	
DONE:			;WAITS FOR USER INPUT
	ACALL DELAY
	MOV P2,#00001111B
DONE3:	MOV A,P2
	ANL A,#00001111B
	CJNE A,#00001111B,DONE2 
	SJMP DONE3
DONE2:	LJMP INI	;RESETS AFTER INPUT

COMNWRT:
	MOV P1,A
        CLR P3.0
        CLR P3.1
        SETB P3.2
        ACALL DELAY
        CLR P3.2
        RET
	
DATAWRT:
        MOV P1,A
        SETB P3.0
        CLR P3.1
        SETB P3.2
        ACALL DELAY
        CLR P3.2
        RET
	
DELAY: 
	MOV R3,#50
	HERE2: MOV R4,#255
	HERE: DJNZ R4,HERE
	DJNZ R3,HERE2
	RET
	
;ASCII LOOK-UP TABLE FOR EACH ROW
KCODE0: DB '/','9','8','7' ;ROW 0
KCODE1: DB '*','6','5','4' ;ROW 1
KCODE2: DB '-','3','2','1' ;ROW 2
KCODE3: DB '+','=','0',99H ;ROW 3

ORG 400H
LCD_IN: DB 38H,0EH,01,06,80H,0
LCD_LINESKIP: DB 0C0H,0
LCD_CLEAR: DB 01, 80H, 0
PROMPT1: DB "First Number:",0  ;user prompts
PROMPT2: DB "Operation:",0
PROMPT3: DB "Second Number:",0
OUTPUT1: DB "Q: ",0
OUTPUT2: DB "REM: ",0
OUTPUT3: DB "Invalid input",0  ;error
OUTPUT4: DB "Please try again",0 
OUTPUT5: DB "Result: ",0
END