/**************************************************************************
 *	    File: Lab05.asm
 *  Lab Name: Pardon the Interruption...
 *    Author: Dr. Greg Nordstrom
 *   Created: 02/19/2021
 * Processor: ATmega128A (on the ReadyAVR board)
 *
 * Modified by: John Hutton
 * Modified on: 09/30/22
 *
 * This program utilizes interepts to perform some simple functions.
 * We setup the joystick "up" and "down" to perform interupts to the 
 * processor.  These interupts increase or decrease the blink rate of the
 * onboard LED.  We also power four other LEDs to show the 1-15 settings
 * in binary.
 *
 *************************************************************************/ 

 ;; Initial Assembler directives
.def BlinkFreq = R20		; holds current blink rate (1-15 Hz)
.equ C_BlinkFreqMin = 1
.equ C_BlinkFreqMax = 15
.equ C_InitialBlinkFreq = C_BlinkFreqMin

.org 0x0000                 ; next instruction address is 0x0000
                            ; (the location of the reset vector)
rjmp main                   ; allow reset to run this program
.org 0x0002					; INT0 vector
; empty
.org 0x0004					; INT1 vector
rjmp int1_isr
.org 0x0006					; INT2 vector
; empty
.org 0x0008					; INT3 vector
rjmp int3_isr

/**********
* Main code
**********/
.org 0x0100					; Move the "main" to 0x0100 to make room for ISRs
main:                       ; jump here on reset
	; initialize stack (default RAMEND = 0x10FF)
    ldi R16, HIGH(RAMEND)   
    out SPH, R16
    ldi R16, low(RAMEND)
    out SPL, R16

	; Setup the output pins
    LDI  R16,(1<<DDA7)		; Set the mask to make Port A.7 an output
	OUT  DDRA,R16			; Load bitmask to PORTA register
	LDI  R16,0b00001111		; Set bitmask to make Port C.3:0 outputs
	OUT	 DDRC,R16			; Load bitmask to PORTC register
	LDI  R16,0b00001110     ; turn LEDs 3:1 off (active low) by setting PORTC.3:0
	OUT  PORTC,R16          ; Load to portC

	; Setup the input pins (interupts)
	CLR  R16				; Zero the R16 register
	OUT	 DDRB,R16			; Set all of port B to input
	LDI  R16,(1<<DDB3)|(1<<DDB1)  ; Bitmask for pin 1 and 3 to high
	OUT  PORTB,R16			; Set pullup for pins

	; Enable a low-to-high interupt by setting a 0b11 to the EIRCA reg
	LDI  R16,(1<<ISC31)|(1<<ISC30)|(1<<ISC11)|(1<<ISC10)
	STS  EICRA,R16

	; Unmask the INT1 and INT3
	LDI  R16,(1<<INT3)|(1<<INT1)
	OUT  EIMSK,R16

	; Enable global interupts
	SEI

	; Set initial blink default
	LDI  BlinkFreq,C_InitialBlinkFreq	; Set the starting BlinkFreq to Initial (1)
	
mainLoop:
    CBI  PORTA, PORTC7       ; turn LED on (active low) by clearing PORTC.3

    ; kill some time
	LDI R16,C_BlinkFreqMax+1	; Set the outer loop to Max+1
	SUB R16,BlinkFreq			; R16-BlinkFreq to get outer loop
								; If BlinkFreq=1, then Loop=Max
 
outer_loop1:
	LDI R24, low(0xFFFF)    ; load low and high parts of R25:R24 pair with
    LDI R25, high(0xFFFF)   ; loop count by loading registers separately
							; Note FFFF was called out by lab notes for 1 Hz
    inner_loop1:
        sbiw R24, 1         ; decrement inner loop counter (R25:R24 pair)
        brne inner_loop1    ; loop back if R25:R24 isn't zero
    dec R16                 ; decrement the outer loop counter (R16)
    brne outer_loop1        ; loop back if R16 isn't zero

    sbi PORTA, PORTC7       ; turn LED off (active low) by setting PORTC.3

    ; kill some more time
	LDI R16,C_BlinkFreqMax+1	; Set the outer loop to Max+1
	SUB R16,BlinkFreq			; R16-BlinkFreq to get outer loop
								; If BlinkFreq=1, then Loop=Max

outer_loop2:
    ldi R24, low(0xFFFF)     ; load low and high parts of R25:R24 pair with
    ldi R25, high(0xFFFF)    ; loop count by loading registers separately
    inner_loop2:
        sbiw R24, 1         ; decrement inner loop counter (R25:R24 pair)
        brne inner_loop2    ; loop back if R25:R24 isn't zero
    dec R16                 ; decrement the outer loop counter (R16)
    brne outer_loop2        ; loop back if R16 isn't zero

    rjmp mainLoop           ; play it again, Sam...

/**********
* ISR code
**********/
.org 0x0200							; Load the ISR code higher than main code

; The BlinkFreq is for Frequency, but we are adjusting period in our timing loops.
; This means that "DOWN" drops the frequency, but we can't go below the min.
int1_isr:							; "DOWN" joystick
	PUSH R16						; Save R16 on the stack
	IN   R16,SREG					; Save the SREG
	PUSH R16
	CPI  BlinkFreq,C_BlinkFreqMin	; Compare current Blink frequency and the min
	BREQ end_int1_isr				; Do nothing if already at min
	DEC  BlinkFreq					; "else" decrement the outer loop target
	LDI  R16,0xFF					; Set R16 to 0x00
	EOR  R16,BlinkFreq				; Do and XOR with BlinkFreq
									; We will drive LEDs with "0"s
	OUT  PORTC,R16					; Write the BlinkFreq to the 4 LEDs
end_int1_isr:
	POP	 R16						; Restore the SREG
	OUT  SREG,R16
	POP  R16						; Restore R16 from the stack
	RETI

int3_isr:							; "UP" joystick
	PUSH R16						; Save R16 on the stack
	IN   R16,SREG					; Save the SREG
	PUSH R16
	CPI BlinkFreq,C_BlinkFreqMax	; Compare current Blink frequency and the max
	BREQ end_int3_isr				; Do nothing if already at max
	INC  BlinkFreq					; "else" increment the out loop target
	LDI  R16,0xFF					; Set R16 to 0x00
	EOR  R16,BlinkFreq				; Do and XOR with BlinkFreq
									; We will drive LEDs with "0"s
	OUT  PORTC,R16					; Write the BlinkFreq to the 4 LEDs
end_int3_isr:
	POP	 R16						; Restore the SREG
	OUT  SREG,R16
	POP  R16						; Restore R16 from the stack
	POP  R16						; Restore R16 from the stack
	RETI