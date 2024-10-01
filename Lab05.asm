/**************************************************************************
 *	    File: Lab05.asm
 *  Lab Name: Pardon the Interruption...
 *    Author: Dr. Greg Nordstrom
 *   Created: 02/19/2021
 * Processor: ATmega128A (on the ReadyAVR board)
 *
 * Modified by: <Your name goes here>
 * Modified on: <Date modified goes here>
 *
 * This program...
 *
 *************************************************************************/

 /*********
 * Interrupt Jump Table
 *********/
.org 0x0000                 ; next instruction address is 0x0000
                            ; (the location of the reset vector)
rjmp main					; allow reset to run this program

/**********
* Main code
**********/
.org 0x0020					; Move the "main" to 0x0020 to make room for ISRs
main:                       ; jump here on reset
    ldi R16, HIGH(RAMEND)   ; initialize stack (default RAMEND = 0x10FF)
    out SPH, R16
    ldi R16, low(RAMEND)
    out SPL, R16

	/* Additional Setup before Main Loop */

    ldi R16, (1<<DDC3)      ; set PORTC.3 pin as output via bit 3
    out DDRC, R16           ; in PORTC's data direction register

    sbi PORTC, PORTC3       ; turn LED off (active low) by setting PORTC.3

mainLoop:
    cbi PORTC, PORTC3       ; turn LED on (active low) by clearing PORTC.3

    ; kill some time
    ldi R16, 40             ; R16 is outer loop counter
outer_loop1:
    ldi R24, low(0x4000)     ; load low and high parts of R25:R24 pair with
    ldi R25, high(0x4000)    ; loop count by loading registers separately
    inner_loop1:
        sbiw R24, 1         ; decrement inner loop counter (R25:R24 pair)
        brne inner_loop1    ; loop back if R25:R24 isn't zero
    dec R16                 ; decrement the outer loop counter (R16)
    brne outer_loop1        ; loop back if R16 isn't zero

    sbi PORTC, PORTC3       ; turn LED off (active low) by setting PORTC.3

    ; kill some more time
    ldi R16, 40             ; R16 is outer loop counter
outer_loop2:
    ldi R24, low(0x4000)     ; load low and high parts of R25:R24 pair with
    ldi R25, high(0x4000)    ; loop count by loading registers separately
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
int1_isr: