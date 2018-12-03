	
;;; input_handling.S <date> <maintainerName(s)>
;;; File to handle the input (interrupts and timers!)
;;; REFERENCES:
;;; TODO
#define __SFR_OFFSET 0
	#include <avr/io.h>
	#include "7segment.S"

    CPU_FREQ = 16000000
	TICKS_PER_SEC = CPU_FREQ / (256 * 1024)

	DOT = TICKS_PER_SEC / 5                    ; 200ms
	INTERSIGNAL_GAP = TICKS_PER_SEC / 10	   ; 100ms
	INTERLETTER_GAP = 4 * TICKS_PER_SEC / 5   ; 700ms

	DECISION_LIMIT = TICKS_PER_SEC / 5 ; 200ms
	TIMEOUT = 2 * TICKS_PER_SEC / 5	   ; 400ms

	BUTTON = 0

	.global timer1_compa_isr  ; export symbol to overwrite weak
				; definition in init.S
	
timer1_compa_isr:			

	push r16	
	in r16, SREG		; save the status register.
	push r16

	;; check whether we are waiting for a button press or release:
	lds r16, TCCR1B
	sbrs r16, ICES1 	; skip if waiting for postive edge (ie for button release)
	rjmp awaiting_press

awaiting_release:
	;;  make sure also an overly long press is always recognised
	;;  as a long press, irrespective of a timer overrun:

	ser r19 		; using r19 as a flag to indicate a
				; timer overflow has occured.
    
	rjmp 1f

awaiting_press:	
	;; if we are waiting for a button press, then more time than
	;; TIME-OUT has elasped since the last release -- in this case
	;; we switch on the yellow led and the other off.
				; off, pull-up for button stays on.
	ldi r18, 0
	ldi r20, 0
    ldi r16, ALL_SEGS
	out PORTD, r16
	
1:	pop r16
	out SREG, r16 		; restore status register
	pop r16
	
	reti


;;; This interrupt service routine times the duration of button
;;; presses. It is also involved in timing button releases as it
;;; always resets timer1 when called.
;;; It is called whenever the signal at ICP1 (PORTB0) changes in a
;;; certain direction. If we are called for a negative edge (button
;;; has just been depressed), we go on waiting for a positive edge
;;; (button will be released) and vice-versa.
	
	.global timer1_cpt_isr

timer1_cpt_isr:

	push r8

	in r8, SREG 		; save the status register.
	push r8

	lds r8, ICR1L		; get the timer count when the capture event happened.
	lds r8, ICR1H           ; we discard the low part, only
				; interested in the high part, but
				; reading low byte is necessary to get
				; a correct high byte in ICR1H, see
				; documentation [ATmega328p] Section 15.3 p106
	push r17				


	or r17, r8

	mov r17,r19		;  debounce. If there is no timer overflow and
	or r17,r8		;  ICR1H is still zero, then 
				;  less than 16ms have elapsed since
				;  last release or press
	breq debounce		;  and we do nothing



	clr r17
	sts TCNT1H, r17 	; reset timer, first writing the high byte to the latch
	sts TCNT1L, r17		; then the low byte -- Section 15.11.4 of [ATmega328p] p130.

	;; check whether we were looking for a positive or a negative edge:
	lds r17, TCCR1B
	sbrs  r17, ICES1	; skip next instruction if positive edge dedection.
	
	rjmp pressed		; we have a negative edge ie button
				; has been pressed

	;; positive edge, button has been released
	rcall released

	andi r17, ~(_BV(ICES1)) ; we have had positive edge, so next
				; time looking for negative edge
	rjmp end_isr

	
pressed:
	;; call depressed ; more code to exexcute, perhaps for the coursework?
	ori r17, _BV(ICES1)	; next time detect positive edge, ie a
				; button release.

end_isr:
	sts TCCR1B, r17 	; write r17 to TCCR1B to activate the
				; change in edge detection.
	
debounce:
	pop r17
	pop r8
	out SREG, r8		; restore status register
	pop r8

	reti

;;; This subroutine handles the detection of the end of a morse
;;; signal.
;;; It expects the durations of button presses in 16ms ticks in r8


released:

	push r16

	tst r19 		; Did we have a timer overflow
				; (ldi r16, _BV(SEG_D)
	out PORTD, r16	;ie more than TIMEOUT time since the
				; last released of the button?
	brne long_press		; if yes, then signal is a long
				; press in any case

	;; is the signal longer then DECISION_LIMIT?
	ldi r16, DECISION_LIMIT
	cp r8,r16
	brcs short_press		; if it is shorter jump to label short
	
long_press:
	inc r18
	lsl r20
	inc r20
	ldi r16, CHAR_T | _BV(BUTTON)
	rjmp 1f

short_press:
	inc r18
	lsl r20
	ldi r16, CHAR_E | _BV(BUTTON)			; 0 for dot

1:	out PORTD, r16		; switch on new LED.
	
	pop r16
	clr r19			; clear overflow flag in case it was set

	cpi r18, 1
	breq length_1

	cpi r18, 2
	breq length_2

	cpi r18, 3
	breq length_3

	cpi r18, 4
	breq length_4

	cpi r18, 5
	brge error
	ret

error:
	ldi r16, ERROR
	out PORTD, r16
	ret

length_1:
	ldi r16, CHAR_E
	cpi r20, 0
	breq display_letter2

	ldi r16, CHAR_T
	cpi r20, 1
	breq display_letter2

	ret

length_2:
	ldi r16, CHAR_I
	cpi r20, 0
	breq display_letter2

	ldi r16, CHAR_A
	cpi r20, 1
	breq display_letter2
	
	ldi r16, CHAR_N
	cpi r20, 2
	breq display_letter2

	ldi r16, CHAR_M
	cpi r20, 3
	breq display_letter2

	ret

display_letter2:
	out PORTD, r16
	ret

length_3:
	ldi r16, CHAR_S
	cpi r20, 0
	breq display_letter

	ldi r16, CHAR_U
	cpi r20, 1
	breq display_letter

	ldi r16, CHAR_R
	cpi r20, 2
	breq display_letter

	ldi r16, CHAR_W
	cpi r20, 3
	breq display_letter

	ldi r16, CHAR_D
	cpi r20, 4
	breq display_letter

	ldi r16, CHAR_K
	cpi r20, 5
	breq display_letter

	ldi r16, CHAR_G
	cpi r20, 6
	breq display_letter

	ldi r16, CHAR_O
	cpi r20, 7
	breq display_letter

	ret

length_4:
	ldi r16, CHAR_H
	cpi r20, 0
	breq display_letter

	ldi r16, CHAR_V
	cpi r20, 1
	breq display_letter

	ldi r16, CHAR_F
	cpi r20, 2
	breq display_letter

	ldi r16, CHAR_L
	cpi r20, 4
	breq display_letter

	ldi r16, CHAR_P
	cpi r20, 6
	breq display_letter

	ldi r16, CHAR_J
	cpi r20, 7
	breq display_letter

	ldi r16, CHAR_B
	cpi r20, 8
	breq display_letter

	ldi r16, CHAR_X
	cpi r20, 9
	breq display_letter

	ldi r16, CHAR_C
	cpi r20, 10
	breq display_letter

	ldi r16, CHAR_Y
	cpi r20, 11
	breq display_letter

	ldi r16, CHAR_Z
	cpi r20, 12
	breq display_letter

	ldi r16, CHAR_Q
	cpi r20, 13
	breq display_letter

	ret


display_letter:
	out PORTD, r16
	ret


