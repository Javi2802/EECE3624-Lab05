/*****************************************************************************
*  Lab Name: Pardon the Interruption...
*    Author: Dr. Greg Nordstrom
*   Created: 9/15/12
*  Modified: 12/7/17
* Processor: ATmega128A (on the ReadyAVR board)
*
* This program, written to run on the ReadyAVR, blinks the on-board "Boot"
* LED (PORTA.7) at a frequency of 1-15 Hz as determined by the user.
* Initially this frequency is 1Hz, and can be increased or decreased by 
* pressing the joystick up or down. The blink frequency (1-15) is
* displayed IN BINARY on the on-board LEDs attached to PORTC.0 (LSB)
* through PORTC.3 (MSB).
*
* The on-board up and down joystick buttons are physically connected to
* PORTB.3 (up) and PORTB.1 (down). However, neither of these pins is capable
* of generating a processor interrupt. Instead, processor pins PORTD.3 (up)
* and PORTD.1 (down) are used to generate the interrupts, and as such, must
* be connected EXTERNALLY to pins PORTB.3 and PORTB.1 respectively. ENSURE
* THAT BOTH PAIRS OF PINS ARE PROPERLY CONFIGURED AS INPUTS. Also, note that
* when setting up the ISR vectors, it appears that INT1addr must be written
* before INT3addr (throws a compiler error if order is reversed. Hmmm...)
*
*****************************************************************************/

.def BlinkFreq        = R20 ; holds the current blink freq (1-15)
.equ BlinkFreqMin     = 1
.equ BlinkFreqMax     = 15
.equ InitialBlinkFreq = BlinkFreqMin

; initialize the reset vector
.org 0x0000	                ; next instruction will be written at addr 0x0000
rjmp main                   ; set reset vector to point to the main code entry point

; initialize PORTD.1 ("down") and PORTD.3 ("up") interrupt service routine vectors
; NB: Joystick is physically connected to PORTB.1 ("down") and PORTB.3 ("up"), and
;     those two pins must be externally connected to PORTD.1 and .3 respectively,
;     since PORTB pins 1 and 3 cannot generate interrupts on the ATmega128A.
.org INT1addr               ; INT1 addr (PD1) defined in m128Adef.inc file
rjmp ISRJoystickDown        ; point to joystick "down" ISR
.org INT3addr               ; INT3 addr (PD3) defined in m128Adef.inc file
rjmp ISRJoystickUp          ; point to joystick "up" ISR

main:		                ; jump here on reset

; initialize the stack (RAMEND = 0x10FF by default for the ATmega128A)
ldi r16, high(RAMEND)
out SPH, r16
ldi r16, low(RAMEND)
out SPL, r16

; configure PORTA pin 7 as output (blinking LED)
ldi R16, (1<<DDA7)  ; <- this is the preferred way to say: ldi R16, 0b10000000
out DDRA, R16

; configure PORTB bits 3 (joystick up) and 1 (joystick down) as inputs
ldi R16, 0
out DDRB, R16

; configure PORTD bits 3 (up) and 1 (down) as inputs (used to trigger ISRs)
out DDRD, R16

; configure PORTC pins 3:0 as outputs (4-bit binary frequency indicator)
ldi R16, (1<<DDC3 | 1<<DDC2 | 1<<DDC1 | 1<<DDC0)
out DDRC, R16

; enable internal pull-up resistors on PORTB pins 1 and 3 (active low)
; (writing a 1 to an input pin enables its pull-up resistor)
ldi R16, (1<<PORTB3) | (1<<PORTB1)
out PORTB, R16

; set INT1 and INT3 interrupts to activate on RISING edge (i.e. on button release)
; (NB: must write to EICRA using "sts" instead of "out" since EICRA=0x6a > 0x3f, the limite for "out")
ldi R16, ((1<<ISC31) | (1<<ISC30) | (1<<ISC11) | (1<<ISC10))
sts EICRA, R16

; initialize BlinkFreq
ldi BlinkFreq, InitialBlinkFreq

; initially, display blink freq (needed since joystick ISRs
; update the freq display only if/when a button is pressed)
ldi R17, 0x0F
eor R17, BlinkFreq
out PORTC, R17

; enable INT1 and INT3 interrupts
ldi R16, ((1<<INT3) | (1<<INT1))
out EIMSK, R16

; finally, enable interrupts globally
sei

mainLoop:
    ; mainLoop is an infinite loop that:
    ;   1. turns the blink LED on
    ;   2. waits an amount of time governed by the blink frequency
    ;   3. turns the blink LED off
    ;   4. waits an amount of time governed by the blink frequency
    ;   5. goes back to 1.

    ; turn on LED (clear bit 7 of PORTA)
	cbi PORTA, PORTA7

    ; calculate loop delay value and put into R16 (R16 = 16 - BlinkFreq)
    ldi R16, 0x10
    sub R16, BlinkFreq
	outer_loop1:
		ldi R24, low($FFFF)			; R25:R24 (16-bit value used by brne instruction)
		ldi R25, high($FFFF)		; is the inner loop counter
		inner_loop1:
			sbiw R24, 1				; subtract 1 from R25:R24 (i.e. "decrement R25:R24")
			brne inner_loop1		; loop until inner loop counter (R25:R24) reaches zero
		dec R16						; decrement the outer loop counter
		brne outer_loop1			; loop until outer loop counter (R16) reaches zero

    ; turn off LED (set bit 7 of PORTA)
	sbi PORTA, PORTA7

    ; calculate loop delay value and put into R16 (R16 = 16 - BlinkFreq)
    ldi R16, 0x10
    sub R16, BlinkFreq
	outer_loop2:
		ldi R24, low($FFFF)         ; R24:R25 (16-bit value used by brne instruction)
		ldi R25, high($FFFF)		;  is the inner loop counter
		inner_loop2:
			sbiw R24, 1				; subtract 1 from R24:R25 (i.e. "decrement R25:R24")
			brne inner_loop2		; loop until inner loop counter (R24:R25) reaches zero
		dec R16						; decrement the outer loop counter
		brne outer_loop2			; loop until outer loop counter (R16) reaches zero
	rjmp mainLoop					; play it again, Sam...

debounceDelay:
	push R16
    push R24
	push R25
	ldi R16, 0x03
	delay_loop1:
		ldi R24, low($FFFF)         ; R24:R25 (16-bit value used by brne instruction)
		ldi R25, high($FFFF)		;  is the inner loop counter
		delay_loop2:
			sbiw R24, 1				; subtract 1 from R24:R25 (i.e. "decrement R25:R24")
			brne delay_loop2
		dec R16						; loop until inner loop counter (R24:R25) reaches zero
		brne delay_loop1
	pop R25
	pop R24
	pop R16
	ret

/**************************************************************************
* Interrupt Service Routines
**************************************************************************/
ISRJoystickUp:
	; joystick "up" button is active low, so this routine fires on the
    ; rising edge ensuring the button RELEASE activates the ISR. If the
    ; frequency hasn't reached 15 yet, BlinkFreq is incremented, else it
    ; remains at 15.

	cpi BlinkFreq, BlinkFreqMax     ; BlinkFreq already at maximum?
	breq byeUp                      ; if so, leave
	inc BlinkFreq                   ; else, increment by one...
    ldi R17, 0x0F
    eor R17, BlinkFreq              ; bitwise exclusive-OR
    out PORTC, R17                  ; ...and update display
	call debounceDelay
byeUp:
	reti                            ; return from this ISR

ISRJoystickDown:
	; joystick "down" button is active low, so this routine fires on the
    ; rising edge ensuring the button RELEASE activates the ISR. If the
    ; frequency hasn't reached 1 yet, BlinkFreq is decremented, else it
    ; remains at 1.

	cpi BlinkFreq, BlinkFreqMin     ; BlinkFreq already at minimum?
	breq byeDown                    ; if so, leave
	dec BlinkFreq                   ; else, decrement by one...
    ldi R17, 0x0F
    eor R17, BlinkFreq              ; bitwise exclusive-OR
    out PORTC, R17                  ; ...and update display
	call debounceDelay
byeDown:
	reti                            ; return from this ISR