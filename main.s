;****************** main.s ***************
; Program written by: put your names here
; Date Created: 1/24/2015 
; Last Modified: 1/24/2015 
; Section 1-2pm     TA: Wooseok Lee
; Lab number: 4
; Brief description of the program
;   If the switch is presses, the LED toggles at 8 Hz
; Hardware connections
;  PE0 is switch input  (1 means pressed, 0 means not pressed)
;  PE1 is LED output (1 activates external LED on protoboard) 
;Overall functionality of this system is the similar to Lab 3, with four changes:
;1-  activate the PLL to run at 80 MHz (12.5ns bus cycle time) 
;2-  initialize SysTick with RELOAD 0x00FFFFFF 
;3-  add a heartbeat to PF2 that toggles every time through loop 
;4-  add debugging dump of input, output, and time
; Operation
;	1) Make PE1 an output and make PE0 an input. 
;	2) The system starts with the LED on (make PE1 =1). 
;   3) Wait about 62 ms
;   4) If the switch is pressed (PE0 is 1), then toggle the LED once, else turn the LED on. 
;   5) Steps 3 and 4 are repeated over and over


SWITCH                  EQU 0x40024004  ;PE0
LED                     EQU 0x40024008  ;PE1
SYSCTL_RCGCGPIO_R       EQU 0x400FE608
SYSCTL_RCGC2_GPIOE      EQU 0x00000010   ; port E Clock Gating Control
SYSCTL_RCGC2_GPIOF      EQU 0x00000020   ; port F Clock Gating Control
GPIO_PORTE_DATA_R       EQU 0x400243FC
GPIO_PORTE_DIR_R        EQU 0x40024400
GPIO_PORTE_AFSEL_R      EQU 0x40024420
GPIO_PORTE_PUR_R        EQU 0x40024510
GPIO_PORTE_DEN_R        EQU 0x4002451C
GPIO_PORTF_DATA_R       EQU 0x400253FC
GPIO_PORTF_DIR_R        EQU 0x40025400
GPIO_PORTF_AFSEL_R      EQU 0x40025420
GPIO_PORTF_DEN_R        EQU 0x4002551C
GPIO_PORTF_PUR_R 		EQU	0x40025510
GPIO_PORTF_CR_R			EQU	0x40025524
NVIC_ST_CTRL_R          EQU 0xE000E010
NVIC_ST_RELOAD_R        EQU 0xE000E014
NVIC_ST_CURRENT_R       EQU 0xE000E018
           THUMB
           AREA    DATA, ALIGN=4
SIZE       EQU    50
;You MUST use these two buffers and two variables
;You MUST not change their names
;These names MUST be exported
           EXPORT DataBuffer  
           EXPORT TimeBuffer  
           EXPORT DataPt [DATA,SIZE=4] 
           EXPORT TimePt [DATA,SIZE=4]
DataBuffer SPACE  SIZE*4
TimeBuffer SPACE  SIZE*4
DataPt     SPACE  4
TimePt     SPACE  4

    
      ALIGN          
      AREA    |.text|, CODE, READONLY, ALIGN=2
      THUMB
      EXPORT  Start
      IMPORT  TExaS_Init


Start BL   TExaS_Init  			; running at 80 MHz, scope voltmeter on PD3
; initialize Port E
PortE_Init
	LDR	R1, =SYSCTL_RCGCGPIO_R	; Activate clock for port E
	LDR	R0, [R1]
	ORR	R0, #0x10				; Set bit 4 to turn on clock
	STR	R0, [R1]
	NOP
	NOP
	NOP
	NOP							; Let clock stabilize
	LDR	R1, =GPIO_PORTE_DIR_R 	; Set direction register
	LDR	R0, [R1]
	ORR	R0, #0x02			; PE1 output
	STR R0, [R1]
	LDR R1, =GPIO_PORTE_DEN_R   ; Enable Port F digital port
	LDR	R0, [R1]
	ORR	R0, #0x03				; 1 = digital I/O
	STR	R0, [R1]
; initialize Port F
PortF_Init
	LDR	R1, =SYSCTL_RCGCGPIO_R	; Activate clock for port F
	LDR	R0, [R1]
	ORR	R0, #0x20				; Set bit 5 to turn on clock
	STR	R0, [R1]
	NOP
	NOP
	NOP
	NOP							; Let clock stabilize
	LDR	R1, =GPIO_PORTF_DIR_R 	; Set direction register
	LDR	R0, [R1]
	ORR	R0, #0x04			; PF2 output
	STR R0, [R1]
	LDR R1, =GPIO_PORTF_DEN_R   ; Enable Port F digital port
	LDR	R0, [R1]
	ORR	R0, #0x04				; 1 = digital I/O
	STR	R0, [R1]
	LDR	R1, =GPIO_PORTF_CR_R	; Enable commit for Port F
	LDR	R0, [R1]
	ORR	R0, #0x04				; allow access to PF2 and PF4
	STR	R0, [R1]
	LDR	R1, =GPIO_PORTF_PUR_R   ; Pull-up resistors for PF2, PF4
	LDR	R0, [R1]
	ORR	R0, R1, #0x04			; enable PF4
	STR	R0, [R1]
; initialize debugging dump, including SysTick
	BL Debug_Init
	CPSIE  I    ; TExaS voltmeter, scope runs on interrupts
;main
loop  
; delay
	BL DELAY
;input PE0 test output PE1
STEADY
	; not the heartbeat
	LDR	R2,	=GPIO_PORTE_DATA_R  ; R2 has address of Port F data
	LDR	R3, [R2]				; R3 has Port E data
	ORR	R3, #0x02				; Set PE1 output on (Turn LED on)
	STR	R3, [R2]				; Store data at R2
	
LOOP1
	BL DELAY					; Delay
	;dump
	BL   Debug_Capture
	;heartbeat
	LDR R1, =GPIO_PORTF_DATA_R
	LDR R0, [R1]
	MOV R5, R0
	EOR R5, #0xFF				; NOT everything such that bit 0 changes and everything else is 1 (preserve data register contents) 
	AND R5, #0x04 				; AND with original data register contents, everything else is preserved and bit 0 is changed
	MOV R0, R5
	STR R0, [R1]				; store new data back in to PORTF_DATA_R
	LDR R2,	=GPIO_PORTE_DATA_R 	; R2 has address of Port E data
	LDR	R3, [R2]				; R3 has Port E data
	ANDS R4, R3, #0x01			; Just see the input bit PE0
	BEQ STEADY					; If PE0 is not pressed, go back to steady flashing
	MOV R5, R3
	EOR R5, #0xFF				; NOT everything such that bit 0 changes and everything else is 1 (preserve data register contents) 
	AND R5, #0x02 				; AND with original data register contents, everything else is preserved and bit 0 is changed
	MOV R3, R5
	STR R3, [R2]				; store new data back in to PORTE_DATA_R
	B LOOP1
	B loop
; 1 ms delay function
; assumptions: R3 still holds unchanged Port F data, R0-R1, R4-R5 are not being used for anything else
DELAY
	MOV R0, #310
DELAY1 	
	AND R1, #0x00
	ADD R1, #4000
SBT 
	ADDS R1, #-1
	BPL SBT
	ADDS R0, #-1
	BPL DELAY1
	BX LR 


;------------Debug_Init------------
; Initializes the debugging instrument
; Input: none
; Output: none
; Modifies: none
; Note: push/pop an even number of registers so C compiler is happy
Debug_Init
;init data
	MOV R2, #50						; because we have 50 locations in the array
	LDR R0, =DataBuffer				; R0 holds the address of the data buffer
Data_Init
	MOV R1, #0xFFFFFFFF				; show that each location is empty
	STR R1, [R0]
	ADD R0, R0, #4					; because each element in the array is 4 bytes long
	ADDS R2, #-1					; decrement counter
	BNE Data_Init
;init time
	MOV R2, #50						; repeat same process as above 
	LDR R0, =TimeBuffer
Time_Init
	MOV R1, #0xFFFFFFFF				; show that each location is empty
	STR R1, [R0]
	ADD R0, R0, #4
	ADDS R2, #-1
	BNE Time_Init
;init pointers
	LDR R0, =DataBuffer
	LDR R1, =DataPt					; see below	
	STR R0, [R1]
	LDR R0, =TimeBuffer
	LDR R1, =TimePt					; initialize pointer to the location of the first element in the array
	STR R0, [R1]
; init SysTick
	LDR R1, =NVIC_ST_CTRL_R			
	MOV R0, #0						; turn off the enable bit
	STR R0, [R1]
	LDR R1, =NVIC_ST_RELOAD_R
	LDR R0, =0x00FFFFFF				; set the reload register
	STR R0, [R1]
	LDR R1, =NVIC_ST_CTRL_R			; clear the counter, write the desired mode
	MOV R0, #0x05	
	STR R0, [R1]
    BX LR
;------------Debug_Capture------------
; Dump Port E and time into buffers
; Input: none
; Output: none
; Modifies: none
; Note: push/pop an even number of registers so C compiler is happy
Debug_Capture
	PUSH {R4-R11}
	LDR	R6, =DataPt					; R6 has Data Pointer
	LDR R10, [R6]
	LDR	R7, =TimePt					; R7 has Time Pointer
	LDR	R9, =DataBuffer
	ADD	R9, #200					; Check to see if at end of array
	CMP	R10, R9
	BEQ	CapDone
	LDR R0, =GPIO_PORTE_DATA_R
	LDR	R3,	=NVIC_ST_CURRENT_R
	LDR	R9, [R6]					; R9 has Data Pointer address
	LDR	R10, [R7]					; R10 has Time Pointer address
	LDR	R4, [R3]					; R4 has NVIC_ST_CURRENT_R 
	LDR	R2, [R0]					; R2 has PE data
	AND	R2, #0x02					; R2 only has PE1
	LSR	R2, #1						; Shift to 0 bit position
	LDR	R1, [R0]					; R1 has PE data
	AND	R1, #0x01					; R1 only has PE0
	LSL	R1, #4						; Shift to 4 bit position
	ORR	R1, R2						; R1 has PE data in correct position
	STR	R1, [R9]					; Save PE data to array
	STR	R4, [R10]					; Save NVIC_ST_CURRENT_R to array
	ADD	R9, #4						; Increment Pointers
	ADD	R10, #4
	STR R9, [R6]					; update pointers
	STR R10, [R7]			
CapDone	
	POP {R4-R11}
    BX LR

    ALIGN                           ; make sure the end of this section is aligned
    END                             ; end of file

