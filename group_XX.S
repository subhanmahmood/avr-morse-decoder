;;;  YOUR CODE SHOULD GO INTO THIS FILE.
;;;	PLEASE ADD YOUR OWN COMMENTED HEADER

	CPU_FREQ = 16000000
	TICKS_PER_SEC = CPU_FREQ / (256 * 1024)

	DOT = TICKS_PER_SEC / 5                    ; 200ms
	INTERSIGNAL_GAP = TICKS_PER_SEC / 10	   ; 100ms
	INTERLETTER_GAP = 4 * TICKS_PER_SEC / 5   ; 700ms

	DECISION_LIMIT = TICKS_PER_SEC / 5 ; 200ms
	TIMEOUT = 4 * TICKS_PER_SEC / 5	   ; 400ms


;;; just including the standard symbol definitions of all ports:
#define __SFR_OFFSET 0
#include <avr/io.h>
#include "letters.S"
	

;;; user code starts from here, as init.S ends with jmp main:

BUTTON = 0

	.global main 		; declaring main global, so it can be used in other files
main:
	;; output setup

	;; make these pins output:
	ldi r16, ALL_SEGS
	out DDRD, r16           ;
	
	;; setup for button, DDRB0 is automatically an input.
	sbi PORTB, BUTTON 	; switch on the pull-up. Released
				; button is 1, depressed button read as 0.

	;; setup the timer ([ATmega328p], Section 15.11.1, p126)

	clr r16
	sts TCCR1A, r16 	; setting timer output mode: no output
				; pin used, normal counting up. 

	ldi r16, TIMEOUT	        ; time in 16ms ticks to detect a TIMEOUT,
				; about 400ms.
				; long and short button presses. 
	sts OCR1AH, r16		; move into high byte of compare match
				; register A
	
	clr r16			; low byte of compare match is just 0.
	sts OCR1AL, r16         ; note 16bit registers always have to
				; be written high byte first, see
				; [ATmega328p], Chapter 15.3, p 106

	;; enable input capture interrupt (to time button presses) and
	;; compare match interrupt (the time-out to switch on the
	;; yellow LED:
	ldi r16, _BV(ICIE1) | _BV(OCIE1A)
	sts TIMSK1, r16

	;; enable noise canceller, set prescaler to 1024, and start
	;; timer in CTC mode, [ATmega328p] section  15.11.2, p128
 
	ldi r16,  _BV(ICNC1) | _BV(CS12) | _BV(CS10) | _BV(WGM12)
	sts TCCR1B, r16

	clr r19			; reset overflow flag to defined state

	sei			; enable interrupts globally.
	ldi r16, STANDBY
	out PORTD, r16

wait:
	rjmp wait 		; do nothing :-) just wait for the
				; interrupts to occur -- forever.

