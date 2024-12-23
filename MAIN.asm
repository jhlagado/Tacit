; *************************************************************************
;
;       TACIT Programming Language Z80 v1.0 
;
;       by John Hardy 2024
;
;       GNU GENERAL PUBLIC LICENSE                   Version 3, 29 June 2007
;       see the LICENSE file in this repo for more information 
;
;       incorporates code by Craig Jones and Ken Boak
;
; *****************************************************************************
    TRUE        EQU -1		
    FALSE       EQU 0
    UNLIMITED   EQU -1		

    CTRL_C      equ 3
    CTRL_H      equ 8

    BSLASH      equ $5c

.macro LITDAT,len
    db len
.endm

.macro REPDAT,len,data			; compress the command tables
    
    db (len | $80)
    db data
.endm

.macro ENDDAT
    db 0
.endm

; **************************************************************************
; Page 0  Initialisation
; **************************************************************************		

	.ORG ROMSTART + $180		; 0+180 put TACIT code from here	

iOpcodes:
    LITDAT 15
    db    lsb(bang_)        ;   !            
    db    lsb(dquote_)      ;   "
    db    lsb(hash_)        ;   #
    db    lsb(dollar_)      ;   $            
    db    lsb(percent_)     ;   %            
    db    lsb(amper_)       ;   &
    db    lsb(quote_)       ;   '
    db    lsb(lparen_)      ;   (        
    db    lsb(rparen_)      ;   )
    db    lsb(star_)        ;   *            
    db    lsb(plus_)        ;   +
    db    lsb(comma_)       ;   ,            
    db    lsb(minus_)       ;   -
    db    lsb(dot_)         ;   .
    db    lsb(slash_)       ;   /	

    REPDAT 10, lsb(num_)	; 10 x repeat lsb of add to the num routine 

    LITDAT 7
    db    lsb(colon_)       ;    :        
    db    lsb(semi_)        ;    ;
    db    lsb(lt_)          ;    <
    db    lsb(eq_)          ;    =            
    db    lsb(gt_)          ;    >            
    db    lsb(question_)    ;    ?   
    db    lsb(at_)          ;    @    

    REPDAT 26, lsb(call_)	; call a command a, B ....Z

    LITDAT 6
    db    lsb(lbrack_)      ;    [
    db    lsb(bslash_)      ;    \
    db    lsb(rbrack_)      ;    ]
    db    lsb(caret_)       ;    ^
    db    lsb(underscore_)  ;    _   
    db    lsb(grave_)       ;    `   ; for printing `hello`        

    REPDAT 26, lsb(var_)	; a b c .....z

    LITDAT 4
    db    lsb(lbrace_)      ;    {
    db    lsb(pipe_)        ;    |            
    db    lsb(rbrace_)      ;    }            
    db    lsb(tilde_)       ;    ~ ( a b c -- b c a ) rotate            

iAltCodes:

    LITDAT 26
    db     lsb(aNop_)       ;A      
    db     lsb(aNop_)       ;B        
    db     lsb(aNop_)       ;C      
    db     lsb(aNop_)       ;D      
    db     lsb(aNop_)       ;E      
    db     lsb(aNop_)       ;F      
    db     lsb(aNop_)       ;G      
    db     lsb(aNop_)       ;H
    db     lsb(aNop_)       ;I      
    db     lsb(aNop_)       ;J
    db     lsb(aNop_)       ;K      
    db     lsb(aNop_)       ;L      
    db     lsb(aNop_)       ;M
    db     lsb(aNop_)       ;N      
    db     lsb(aNop_)       ;O      
    db     lsb(aNop_)       ;P      
    db     lsb(aNop_)       ;Q
    db     lsb(aNop_)       ;R
    db     lsb(aNop_)       ;S      
    db     lsb(aNop_)       ;T      
    db     lsb(aNop_)       ;U      
    db     lsb(aNop_)       ;V      
    db     lsb(aNop_)       ;W      
    db     lsb(aNop_)       ;X       
    db     lsb(aNop_)       ;Y
    db     lsb(aNop_)       ;Z      
    ENDDAT 

backSpace:
    ld a,c
    or b
    jr z, interpret2
    dec bc
    call printStr
    .cstr "\b \b"
    jr interpret2
    
start:
    ld SP,DSTACK		; start of TACIT
    call init		    ; setups
    call printStr		; prog count to stack, put code line 235 on stack then call print
    .cstr "TACIT1.0\r\n"

interpret:
    call prompt

    ld bc,0                 ; load bc with offset into TIB, decide char into tib or execute or control         
    ld (vTIBPtr),bc

interpret2:                 ; calc nesting (a macro might have changed it)
    ld E,0                  ; initilize nesting value
    push bc                 ; save offset into TIB, 
                            ; bc is also the count of chars in TIB
    ld hl,TIB               ; hl is start of TIB
    jr interpret4

interpret3:
    ld a,(hl)               ; A = char in TIB
    inc hl                  ; inc pointer into TIB
    dec bc                  ; dec count of chars in TIB
    call nesting            ; update nesting value

interpret4:
    ld a,C                  ; is count zero?
    or B
    jr NZ, interpret3       ; if not loop
    pop bc                  ; restore offset into TIB

waitchar:   
    call getchar            ; loop around waiting for character from serial port
    cp $20			        ; compare to space
    jr NC,waitchar1		    ; if >= space, if below 20 set cary flag
    cp $0                   ; is it end of string? null end of string
    jr Z,waitchar4
    cp '\r'                 ; carriage return? ascii 13
    jr Z,waitchar3		    ; if anything else its macro/control 
    cp CTRL_H
    jr z,backSpace
    jr interpret2

waitchar1:
    ld hl,TIB
    add hl,bc
    ld (hl),A               ; store the character in textbuf
    inc bc
    call putchar            ; echo character to screen
    call nesting
    jr  waitchar            ; wait for next character

waitchar3:
    ld hl,TIB
    add hl,bc
    ld (hl),"\r"            ; store the crlf in textbuf
    inc hl
    ld (hl),"\n"            
    inc hl                  ; ????
    inc bc
    inc bc
    call crlf               ; echo character to screen
    ld a,E                  ; if zero nesting append and ETX after \r
    or A
    jr NZ,waitchar
    ld (hl),$03             ; store end of text ETX in text buffer 
    inc bc

waitchar4:    
    ld (vTIBPtr),bc
    ld bc,TIB               ; Instructions stored on heap at address HERE, we pressed enter
    dec bc

NEXT:                           
    inc bc                  ; Increment the IP
    ld a,(bc)               ; Get the next character and dispatch
    or a                    ; is it NUL?       
    jr z,exit
    cp CTRL_C
    jr z,etx
    sub "!"
    jr c,NEXT
    ld L,A                  ; Index into table
    ld H,msb(opcodes)       ; Start address of jump table         
    ld L,(hl)               ; get low jump address
    ld H,msb(page4)         ; Load H with the 1st page address
    jp (hl)                 ; Jump to routine

exit:
    inc bc			        ; store offests into a table of bytes, smaller
    ld de,bc                
    call rpop               ; Restore Instruction pointer
    ld bc,hl
    EX de,hl
    jp (hl)

etx:                                
    ld hl,-DSTACK           ; check if stack pointer is underwater
    add hl,SP
    jr NC,etx1
    ld SP,DSTACK
etx1:
    jp interpret

init:                           
    ld IX,RSTACK
    ld IY,NEXT		        ; IY provides a faster jump to NEXT

    ld hl,vars              
    ld de,hl
    inc de
    ld (hl),0
    ld bc,VARS_SIZE * 3     ; init vars, defs and altVars
    LDIR

    ld hl,dStack
    ld (vStkStart),hl
    ld hl,65
    ld (vLastDef),hl
    ld hl,HEAP
    ld (vHeapPtr),hl

initOps:
    ld hl, iOpcodes
    ld de, opcodes
    ld bc, $80-32-1-1+26

initOps1:
    ld a,(hl)
    inc hl
    SLA A                     
    ret Z
    jr C, initOps2
    SRL A
    ld C,A
    ld B,0
    LDIR
    jr initOps1
    
initOps2:        
    SRL A
    ld B,A
    ld a,(hl)
    inc hl
initOps2a:
    ld (de),A
    inc de
    DJNZ initOps2a
    jr initOps1

lookupRef0:
    ld hl,defs
    sub "A"
    jr lookupRef1        
lookupRef:
    sub "a"
lookupRef1:
    add a,a
    add a,l
    ld l,a
    ld a,0
    ADC a,h
    ld h,a
    XOR a
    or e                    ; sets Z flag if A-Z
    ret

printhex:                           
                            ; Display hl as a 16-bit number in hex.
    push bc                 ; preserve the IP
    ld a,H
    call printhex2
    ld a,L
    call printhex2
    pop bc
    ret
printhex2:		                    
    ld	C,A
	RRA 
	RRA 
	RRA 
	RRA 
    call printhex3
    ld a,C
printhex3:		
    and	0x0F
	add	a,0x90
	DAA
	ADC	a,0x40
	DAA
	jp putchar

; **************************************************************************             
; calculate nesting value
; A is char to be tested, 
; E is the nesting value (initially 0)
; E is increased by ( and [ 
; E is decreased by ) and ]
; E has its bit 7 toggled by `
; limited to 127 levels
; **************************************************************************             

nesting:                        
    cp '`'
    jr NZ,nesting1
    ld a,$80
    xor e
    ld e,a
    ret
nesting1:
    BIT 7,E             
    ret NZ             
    cp ':'
    jr Z,nesting2
    cp '['
    jr Z,nesting2
    cp '('
    jr NZ,nesting3
nesting2:
    inc E
    ret
nesting3:
    cp ';'
    jr Z,nesting4
    cp ']'
    jr Z,nesting4
    cp ')'
    ret NZ
nesting4:
    dec E
    ret 

prompt:                            
    call printStr
    .cstr "\r\n> "
    ret

crlf:                               
    call printStr
    .cstr "\r\n"
    ret

printStr:                           
    EX (SP),hl		        ; swap			
    call putStr		
    inc hl			        ; inc past null
    EX (SP),hl		        ; put it back	
    ret

putStr0:                            
    call putchar
    inc hl
putStr:
    ld a,(hl)
    or A
    jr NZ,putStr0
    ret

rpush:                              
    di
    dec IX                  
    ld (IX+0),H
    dec IX
    ld (IX+0),L
    ei
    ret

rpop:                               
    di
    ld L,(IX+0)         
    inc IX              
    ld H,(IX+0)
    inc IX                  
    ei
    ret

writeChar:                          
    ld (hl),A
    inc hl
    jp putchar

enter:                              
    ld hl,bc
    call rpush              ; save Instruction Pointer
    pop bc
    dec bc
    jp (iy)                    

carry:                              
    ld hl,0
    rl l
    ld (vCarry),hl
    jp (iy)              

setByteMode:
    ld a,$FF
    jr assignByteMode
resetByteMode:
    xor a
assignByteMode:
    ld (vByteMode),a
    ld (vByteMode+1),a
    jp (iy)

false_:
    ld hl,FALSE
    jr true1

true_:
    ld hl,TRUE
true1:
    push hl
    jp (iy)

; **********************************************************************			 
; Page 4 primitive routines 
; **********************************************************************
    .align $100
page4:

quote_:                     ; Discard the top member of the stack
at_:
underscore_: 
bslash_:
var_:
bang_:                      ; Store the value at the address placed on the top of the stack
amper_:        
pipe_: 		 
caret_:		 
tilde_:                               
plus_:                      ; add the top 2 members of the stack
call_:
dot_:       
comma_:                     ; print hexadecimal
dquote_:        
eq_:    
percent_:  
semi_:
gt_:    
lbrace_:   
rbrace_:    
lt_:    
dollar_:        
minus_:       		        ; Subtract the value 2nd on stack from top of stack 
grave_:                         
lbrack_:
num_:   
rparen_: 
rbrack_:
colon_:   
lparen_: 
question_:
hash_:
star_:   
slash_:   
alt_:                       
    jp (iy)

; **************************************************************************
; Page 6 Alt primitives
; **************************************************************************
    .align $100
page6:

aNop_:
    jp (iy)    

falsex_:
    jp false_

printChar_:
    pop hl
    ld a,L
    call putchar
    jp (iy)

truex_:
    jp true_

;*******************************************************************
; Subroutines
;*******************************************************************

; hl = value
printDec:    
    bit 7,h
    jr z,printDec2
    ld a,'-'
    call putchar
    xor a  
    sub l  
    ld l,a
    sbc a,a  
    sub h  
    ld h,a
printDec2:        
    push bc
    ld c,0                      ; leading zeros flag = false
    ld de,-10000
    call printDec4
    ld de,-1000
    call printDec4
    ld de,-100
    call printDec4
    ld e,-10
    call printDec4
    inc c                       ; flag = true for at least digit
    ld e,-1
    call printDec4
    pop bc
    ret
printDec4:
    ld b,'0'-1
printDec5:	    
    inc b
    add hl,de
    jr c,printDec5
    sbc hl,de
    ld a,'0'
    cp b
    jr nz,printDec6
    xor a
    or c
    ret z
    jr printDec7
printDec6:	    
    inc c
printDec7:	    
    ld a,b
    jp putchar

;*******************************************************************
; Page 5 primitive routines continued
;*******************************************************************

num:
	ld hl,$0000				    ; Clear hl to accept the number
	ld a,(bc)				    ; Get numeral or -
    cp '-'
    jr nz,num0
    inc bc                      ; move to next char, no flags affected
num0:
    ex af,af'                   ; save zero flag = 0 for later
num1:
    ld a,(bc)                   ; read digit    
    sub "0"                     ; less than 0?
    jr c, num2                  ; not a digit, exit loop 
    cp 10                       ; greater that 9?
    jr nc, num2                 ; not a digit, exit loop
    inc bc                      ; inc IP
    ld de,hl                    ; multiply hl * 10
    add hl,hl    
    add hl,hl    
    add hl,de    
    add hl,hl    
    add a,l                     ; add digit in a to hl
    ld l,a
    ld a,0
    adc a,h
    ld h,a
    jr num1 
num2:
    dec bc
    ex af,af'                   ; restore zero flag
    jr nz, num3
    ex de,hl                    ; negate the value of hl
    ld hl,0
    or a                        ; jump to sub2
    sbc hl,de    
num3:
    push hl                     ; Put the number on the stack
    jp (iy)                     ; and process the next character


; *******************************************************************************
; *********  END OF MAIN   ******************************************************
; *******************************************************************************
; *******************************************************************************
