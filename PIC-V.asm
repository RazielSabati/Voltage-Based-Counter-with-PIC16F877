	LIST 	P=PIC16F877
	include	P16f877.inc
 __CONFIG _CP_OFF & _WDT_OFF & _BODEN_OFF & _PWRTE_OFF & _HS_OSC & _WRT_ENABLE_ON & _LVP_OFF & _DEBUG_OFF & _CPD_OFF

	org			0x00
 reset:	goto		start
 
	org		0x04
	goto	psika

	org	0x10
start:
	bcf	STATUS, RP0
	bcf	STATUS, RP1			; Bank0 <------
	clrf	INTCON				; Disable all interrupts to configure them in an orderly manner
	clrf	PORTA 				; Setting up the voltage converter; input voltage will be read on PORTA, so we initialize it
	clrf	PORTE				; Screen output
	clrf   PORTD				; Screen output

	bsf	STATUS, RP0			; Bank1 <------

	bsf	PIE1, TMR1IE			; Enable TIMER1 interrupt at the minimum level

;************************ Initializing the voltage converter
	bsf	PIE1, ADIE			; Enable ADC Interrupt at the minimum level

	movlw	0x02
	movwf	ADCON1			   ; all A analog; all E digital 
								   ; format : 6 lower bits of ADRESL = 0
								   ; 0 is left-justified for bit 7 (page 114)
	movlw	0xff
	movwf	TRISA			; porta input, setting PORTA as input because it reads voltage

	clrf	TRISE				; Clearing these ports for screen interaction
	clrf	TRISD				; portD output

;*****************************************************
	bcf		STATUS, RP0			; Bank0 <------

;********** TIMER 1 initialization **********
	movlw	0x30                			; 00110000, set 1:8 ratio
	movwf	T1CON				; internal clock source with 1:8 prescaler
									; Bit 1 = 0, using only internal clock (page 53)
	movlw	0xdc					
	movwf	TMR1L
	movlw	0x0b
	movwf	TMR1H				; TMR1H:TMR1L = 0x0bdc	 = 3036d

									; Td = 200ns*(2^16- TMR1H:TMR1L )*PS = 200ns*(2^16-3036)*8  = 100,000,000ns = 0.1s

	clrf	PIR1					; Clear peripheral interrupt flags, reset leftover interrupt flags

;************************ Additional initialization for ADC
	movlw	0x81				; B'10000001'
	movwf	ADCON0			; Fosc/32, channel_0, ADC on
	call		d_20				; Delay TACQ, wait for ADC initialization (page 113)

;*****************************************************
	bsf	INTCON, PEIE		; Enable peripheral interrupts
	bsf	INTCON, GIE			; Enable global interrupts
	bsf	T1CON, TMR1ON		; Start TIMER1 increment
	call	init 					; Initialize communication with the screen with delay loops

;***************************************

	movlw d'15'   				; Initializing values for the counter
	movwf   0x7e 				; Counting occurs on this register
	clrf 0x7c 					; This register determines the voltage range
	clrf 0x7d 					; Register counts to 10 to mark one second

main: 

								; Voltage range check to determine whether to print
	btfsc 0x7c ,0 				; If in the range 0.5--1.5V, register will be 1
	goto counterUp
	

	btfsc 0x7c ,1 				; If in the range 1.8--2.3V, register will be 2
	goto counterDown
		
	call checkTimer1			; If not in the up/down voltage range, check the timer delay

	goto main					 ; Return to main loop if voltage is not in range (register will be 4)

								; Increment counter by 1; if 250 is reached, reset to 0 by checking zero flag
								; After checking, proceed to print
counterUp: 
	incf 0x7e,1
	movlw d'251'
	subwf  0x7e,0
	btfsc STATUS , Z
	clrf 0x7e
		
	call divideCounter 			; Function divides the counter into 3 digits in separate registers
								; Indicator for print stage
	goto printUp


								; Check for negative overflow in counter by adding 1 after decrement
counterDown:
	bcf  STATUS , Z			 ; Prevent false flags by clearing zero bit
	decfsz 0x7e,1
	incf 0x7e,0
	btfsc STATUS , Z
	call initD  				; Call function to set counter to 250
	call divideCounter
		
	goto printDown
		

initD
	movlw d'250' 
	movwf 0x7e
	return

		; Function triggers every second
		; Moves 10 into W and subtracts from the second counter; if 0, one second passed
		; Function is called for every counter change to delay one second between prints
checkTimer1
	bcf STATUS , Z
	movlw 0x0a
	subwf 0x7d,0             			; Timer 1 interrupt increments this register every 0.1s; when it reaches 10, a second has passed
	btfss STATUS , Z 
	goto checkTimer1
	bsf	ADCON0, GO 			; Enable ADC read after 1 second
	clrf 0x7d
	return
				
		; Function splits content of register 0x7E into hundreds, tens, and units
divideCounter:
	movf 0x7e,0 
	movwf 0x60
	clrf 0x61
	clrf 0x62
	clrf 0x63 
	clrw
	addlw d'100'
      
decH:
	subwf 0x60
	incf 0x63,1
	btfsc STATUS,C
	goto decH
	addwf 0x60
	decf 0x63,1
	clrw  
	addlw d'10'
decD:    
	subwf 0x60
	incf 0x62,1
	btfsc STATUS,C
	goto decD
	addwf 0x60
	decf 0x62,1 
	movf 0x60,0
	movwf 0x61 
	return

;*********************************** Display routines

printCounter:
	movlw	B'10000000'  
	movwf	0x20			; Set upper-left display position
	call 	lcdc
	call	mdel

	; Add 0x30 (hex) to reach ASCII values
	movlw  0x30
	addwf 0x61,1
	addwf 0x62,1
	addwf 0x63,1
		
		
	movf	0x63,0			; CHAR (data) for hundreds place
	movwf	0x20
	call 	lcdd
	call	mdel

	movf	0x62,0			; CHAR (data) for tens place
	movwf	0x20
	call 	lcdd
	call	mdel
	
	movf	0x61,0			; CHAR (data) for units place
	movwf	0x20
	call 	lcdd
	call	mdel

	return
;----------------------------------
printUp:
		; If switching from down to up, clear the screen, indicator at register 0x65
	btfsc 0x65 , 0
	call displayClear
		
	call  printCounter
	movlw	B'11000000' 			 ; Set LCD position
	movwf	0x20
	call 	lcdc
	call	mdel

	movlw	0x55					; CHAR "U"
	movwf	0x20
	call 	lcdd
	call	mdel

	movlw	0x50					; CHAR "P"
	movwf	0x20
	call 	lcdd
	call	mdel

	call checkTimer1 				 ; 1-second delay between prints
	goto main 					; Return to main loop to check for voltage changes
;----------------------------------

printDown:
	call  printCounter
	movlw	B'11000000' 			 ; Move display to next row
	movwf	0x20
	call 	lcdc
	call	mdel

	movlw	0x44					; CHAR "D"
	movwf	0x20
	call 	lcdd
	call	mdel

	movlw	0x4f					; CHAR "O"
	movwf	0x20
	call 	lcdd
	call	mdel

	movlw	0x57					; CHAR "W"
	movwf	0x20
	call 	lcdd
	call	mdel

	movlw	0x4e					; CHAR "N"
	movwf	0x20
	call 	lcdd
	call	mdel

	call checkTimer1				; 1-second delay between prints	
	goto main 					; Return to main loop to check for voltage changes

; Subroutines to handle delay, LCD commands, and ADC conversion go here

psika:
	movwf	0x7A				; Store W register in register 0x7A
	swapf	STATUS, w
	movwf	0x7B				; Store STATUS in register 0x7B

	btfsc	PIR1, TMR1IF		; Check if TIMER1 overflowed
	goto	Timer1				; If so, go to TIMER1 handler

	btfsc	PIR1, ADIF			; Check if ADC finished conversion
	goto	ADCInterrupt

errorHandler: goto errorHandler	; If unknown interrupt, loop indefinitely

ADCInterrupt:
	bcf	PIR1, ADIF 			; Clear ADC flag
	bcf	ADCON0, GO 			; Disable ADC to avoid false triggers
	movf	ADRESH, w
	movwf	0x30				; Store ADC result in register 0x30

backFromPsika:
	call	d_4				; Delay for conversion stability
	goto	restore

Timer1:
	bcf	T1CON, TMR1ON		; Stop TIMER1
	incf	0x7d				; Increment overflow count for one second
	movlw	0xdc					; Reinitialize TIMER1
	movwf	TMR1L
	movlw	0x0b
	movwf	TMR1H
	bcf	PIR1, TMR1IF		; Clear interrupt flag
	bsf	T1CON, TMR1ON		; Restart TIMER1

restore:
	swapf	0x7B, w
	movwf	STATUS				; Restore STATUS
	swapf	0x7A, f
	swapf	0x7A, w				; Restore W
	retfie



; Subroutine to initialize the LCD
init        movlw   0x30            ; Send initialization command (0x30)
            movwf   0x20
            call    lcdc
            call    del_41

            movlw   0x30            ; Repeat initialization sequence
            movwf   0x20
            call    lcdc
            call    del_01

            movlw   0x30            ; Final part of the initialization sequence
            movwf   0x20
            call    lcdc
            call    mdel

            movlw   0x01            ; Clear display
            movwf   0x20
            call    lcdc
            call    mdel

            movlw   0x06            ; Set entry mode (increment, no shift)
            movwf   0x20
            call    lcdc
            call    mdel

            movlw   0x0C            ; Display ON, cursor OFF, blink OFF
            movwf   0x20
            call    lcdc
            call    mdel

            movlw   0x38            ; 8-bit interface, 2 lines, 5x8 dots font
            movwf   0x20
            call    lcdc
            call    mdel
            return

; Subroutine to send a command to the LCD
lcdc        movlw   0x00            ; Set E=0, RS=0 (command mode)
            movwf   PORTE
            movf    0x20, w         ; Load command from register 0x20
            movwf   PORTD
            movlw   0x01            ; Set E=1, RS=0 to enable command
            movwf   PORTE
            call    sdel            ; Small delay
            movlw   0x00            ; Reset E=0, RS=0
            movwf   PORTE
            return

; Subroutine to send data to the LCD
lcdd        movlw   0x02            ; Set E=0, RS=1 (data mode)
            movwf   PORTE
            movf    0x20, w         ; Load data from register 0x20
            movwf   PORTD
            movlw   0x03            ; Set E=1, RS=1 to enable data mode
            movwf   PORTE
            call    sdel            ; Small delay
            movlw   0x02            ; Reset E=0, RS=1
            movwf   PORTE
            return

; Subroutines for delay loops
del_41      movlw   0xCD            ; Long delay
            movwf   0x23
lulaa6      movlw   0x20
            movwf   0x22
lulaa7      decfsz  0x22, 1
            goto    lulaa7
            decfsz  0x23, 1
            goto    lulaa6
            return

del_01      movlw   0x20            ; Short delay
            movwf   0x22
lulaa8      decfsz  0x22, 1
            goto    lulaa8
            return

sdel        movlw   0x19            ; Small delay for timing adjustment
            movwf   0x23
lulaa2      movlw   0xFA
            movwf   0x22
lulaa1      decfsz  0x22, 1
            goto    lulaa1
            decfsz  0x23, 1
            goto    lulaa2
            return

mdel        movlw   0x0A            ; Medium delay
            movwf   0x24
lulaa5      movlw   0x19
            movwf   0x23
lulaa4      movlw   0xFA
            movwf   0x22
lulaa3      decfsz  0x22, 1
            goto    lulaa3
            decfsz  0x23, 1
            goto    lulaa4
            decfsz  0x24, 1
            goto    lulaa5
            return

; Interrupt service routine
psika       movwf   0x7A            ; Save W register
            swapf   STATUS, w
            movwf   0x7B            ; Save STATUS register

            ; Check which interrupt occurred
            btfsc   PIR1, TMR1IF     ; Check Timer1 interrupt flag
            goto    Timer1

            btfsc   PIR1, ADIF       ; Check ADC interrupt flag
            goto    AtD

ERR         goto    ERR             ; Unknown interrupt error

; ADC interrupt handling
AtD         bcf     PIR1, ADIF      ; Clear ADC flag
            bcf     ADCON0, GO      ; Stop ADC conversion
            movf    ADRESH, w
            movwf   0x30            ; Store ADC result in 0x30

            ; Voltage range checks for indication
            movlw   d'25'
            subwf   0x30, 0
            btfss   STATUS, C
            goto    noVolage
            movlw   d'77'
            subwf   0x30, 0
            btfsc   STATUS, C
            goto    keepcheck
            movlw   0x01            ; Indicate "UP" range
            movwf   0x7C
            goto    backFromI

keepcheck   movlw   d'92'
            subwf   0x30, 0
            btfss   STATUS, C
            goto    noVolage
            movlw   d'117'
            subwf   0x30, 0
            btfsc   STATUS, C
            goto    noVolage
            movlw   0x02            ; Indicate "DOWN" range
            movwf   0x7C
            movlw   0x01            ; Clear display indication register
            movwf   0x65
            goto    backFromI

noVolage    movlw   0x04            ; Indicate "No Voltage" range
            movwf   0x7C

backFromI   call    d_4             ; ADC conversion delay
            goto    backFI

; Timer1 interrupt handling
Timer1      bcf     T1CON, TMR1ON   ; Stop Timer1
            incf    0x7D            ; Increment a counter (for a 1-second interval)
            movlw   0xDC
            movwf   TMR1L
            movlw   0x0B
            movwf   TMR1H
            bcf     PIR1, TMR1IF     ; Clear Timer1 flag
            bsf     T1CON, TMR1ON   ; Restart Timer1

; Restore registers after interrupt
backFI      swapf   0x7B, w
            movwf   STATUS
            swapf   0x7A, f
            swapf   0x7A, w
            retfie

; Functions for short delays
d_20        movlw   0x20
            movwf   0x26
lulaa10     decfsz  0x26, 1
            goto    lulaa10
            return

d_4         movlw   0x06
            movwf   0x26
lulaa20     decfsz  0x26, 1
            goto    lulaa20
            return

; Function to clear LCD display
displayClear
            clrf    0x65            ; Clear display indication register
            movlw   0x01            ; Send display clear command
            movwf   0x20
            call    lcdc
            call    mdel
            return