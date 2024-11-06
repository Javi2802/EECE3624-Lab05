/**************************************************************************
 *	    File: Lab05.asm
 *  Lab Name: Pardon the Interruption...
 *    Author: Dr. Greg Nordstrom
 *   Created: 02/19/2021
 * Processor: ATmega128A (on the ReadyAVR board)
 *
 * Modified by: Javier Gutierrez
 * Modified on: 10/07/2024
 *
 * This program blinks the “BOOT” LED (connected to PORTA.7) at a rate of 1 
 to 15 Hz. This is adjustable in 15 steps, as the joystick is toggled up (faster) or down
(slower), and that the blink rate is displayed in 4-bit binary on LEDs 0-3, which
are connected to PORTC.0 (LSB) through PORTC.3 (MSB).

The blink rate and the display only update after the joystick is released
 *
 *************************************************************************/
 .def BlinkFreq = R20		; holds current blink rate (1-15 Hz)
.equ BlinkFreqMin = 1		; Minimum Blink Frequency 1 Hz
.equ BlinkFreqMax = 15		; Maximum Blink Frequency 15 Hz
.equ InitialBlinkFreq = BlinkFreqMin

.org 0x0000                 ; next instruction address is 0x0000
	rjmp main				; Jump to the main and allow reset to run this program
.org 0x0004					; next instruction address is 0x0004
;This is the program adress of the External Interrupt 1
	RJMP ISRJoystickDown		; Jymp to ISR subroutine when Joystick is pressed down
.org 0x0008					; next instruction address is 0x0008
;This is the program address of the External Interrupt 3
	RJMP ISRJoystickUp		; Jump to ISR subroutine when Joystick is pressed up

/**********
* Main code setup
**********/
.org 0x0020					; Move the "main" to 0x0020 to make room for ISRs
main:                       ; jump here on reset
    ldi R16, HIGH(RAMEND)   ; initialize stack (default RAMEND = 0x10FF)
    out SPH, R16
    ldi R16, low(RAMEND)
    out SPL, R16

	/* Additional Setup before Main Loop */
	ldi R16, (1<<DDA7)
	; set PORTA.7 pin as output via bit 7 and PORTC3:0 pins as output via bit 3,2,1,0
    out DDRA, R16           ; in PORTA's data direction register

	; Using DDRC set pins 3:0 as outputs (blink rate LEDs)
	ldi R16, (1<<DDC3)|(1<<DDC2)|(1<<DDC1)|(1<<DDC0)		;
	out DDRC, R16			; in PORTC's data direction register

	sbi PORTA, PORTA7		; turn BOOT off (active low) by setting PORTA.7
	; Initialize PORTC3:0 as output
	ldi R16, (1<<PORTC3) | (1<<PORTC2) | (1<<PORTC1)| (1<<PORTC0)
	out PORTC, R16			

	; Using DDRB, set pins 1 and 3 as inputs (up/down joystick)
	; enable internal pull-up resistors on PORTB pins 1 and 3 (active low)
	ldi R16, 0
	out DDRB, R16
	ldi R16, (1<< PORTB1) | (1<<PORTB3)
	out PORTB, R16

	; Using DDRD  set pins 1 and 3 as inputs (to trigger ISRs):
	ldi R16, 0
	out DDRD, R16

	; Initally the Blink Frequency will be display
	; This frequency will be updated only when the joystick is pressed up or down
	; initialize the Blink Frequency
	ldi BlinkFreq, InitialBlinkFreq
/*********
 * Interrupt Jump Table
 *********/
	ldi R16, (1<<ISC11) | (0<<ISC10)| (1<<ISC31) | (0<<ISC30);  set INT1 and INT3 to activate on FALLING edge
	sts EICRA, R16						; EICRA instruction configuration
	ldi R16, (1<<INT1) | (1<<INT3)		;  allow INT1 and INT3 to generate interrupts
	out EIMSK, R16						; EIMSK instruction configuration
	sei									; Allow ISRs to be interrupted by setting the interrupts

	 /*********
 * Main Code
 *********/
mainLoop:
    cbi PORTA, PORTA7		; turn BOOT on (active low) by clearing PORTA.7
	; kill some time
     ; Calculate delay based on BlinkFreq (16 - BlinkFreq)
    ldi R16, 0x10           ; Start with a base value
    sub R16, BlinkFreq      ; Subtract the BlinkFreq to adjust delay
    ; Set up the outer loop counter
	ldi R17, 0
outer_loop1:
    ldi R24, low(0xFFFF)     ; load low and high parts of R25:R24 pair with
    ldi R25, high(0xFFFF)    ; loop count by loading registers separately
    inner_loop1:
        sbiw R24, 1         ; decrement inner loop counter (R25:R24 pair)
        brne inner_loop1    ; loop back if R25:R24 isn't zero
    dec R16                 ; decrement the outer loop counter (R16)
    brne outer_loop1        ; loop back if R16 isn't zero

    sbi PORTA, PORTA7       ; turn LED off (active low) by setting PORTA.7

    ; kill some more time
     ; Calculate delay based on BlinkFreq
    ldi R16, 0x10           ; Start with a base value
    sub R16, BlinkFreq      ; Subtract the BlinkFreq to adjust delay
    ; Set up the outer loop counter
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
; This subroutine starts on the falling edge when the joystick button is pressed up
; This increments the blink rate
ISRJoystickUp: 
	sbi PORTD1, 1	; PORTD1 pull-up activated
	sbi PORTD3, 1	; PORTD3 pull-up activated
	CPI BlinkFreq, BlinkFreqMax		; Compare the Blink Frequency with the max Blink Frequency
	BRLT lessthan	; Branch if the Blink Frequency is less than the max Blink Frequency
lessthan: 
	INC BlinkFreq		; Increment Blink Frequency
	MOV R17, BlinkFreq	; Move the Blink Frequency value to a temporary Register R17
	LDI R18, 0x0F		; Load the inmediate value 00001111 in temporary Register 17
	;This is done for toggling Port PC3:0
	EOR R17, R18		; XOR the values in register R17 and R18
	OUT PORTC, R17		; Send the information to PORTC to toggle it
	RETI				; Return Interrupt
	; The “I” bit is set when RETI is executed

ISRJoystickDown:
; This subroutine starts on the falling edge when the joystick button is pressed down
; This decrements the blink rate
	sbi PORTD1, 1	; PORTD1 pull-up activated
	sbi PORTD3, 1	; PORTD3 pull-up activated
	CPI BlinkFreq, BlinkFreqMax		; Compare the Blink Frequency with the max Blink Frequency
	BRSH greaterthan	; Branch if the Blink Frequency is greater than the max Blink Frequency
greaterthan: 
	DEC BlinkFreq		; Decrement Blink Frequency
	MOV R17, BlinkFreq	; Move the Blink Frequency value to a temporary Register R17
	LDI R18, 0x0F		; Load the inmediate value 00001111 in temporary Register 17
	;This is done for toggling Port PC3:0
	EOR R17, R18		; XOR the values in registers 
	; Send the information to PORTC to toggle it
	OUT PORTC, R17		; Send the information to PORTC to toggle it
	RETI				; Return Interrupt
	; The “I” bit is set when RETI is executed
	






