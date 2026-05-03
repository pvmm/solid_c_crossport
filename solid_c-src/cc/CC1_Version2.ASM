; Last revision 20.01.2004
;


; Macro definition ds xx
%imacro ds 1
times %1 db 0
%endmacro

; Macro definition ds xx,yy
%imacro ds 2
times %1 db %2
%endmacro

; Macro definition for comments
%idefine .comment  0

%idefine yes	1
%idefine no	0



;
; SOLID C Compiler 1st Pass (C Preprocessor)
;
;
;
; Notes about limitations:
; ~~~~~~~~~~~~~~~~~~~~~~~~~
;  - For the "nested" pass the -k option is required.
;
;  - In particular: -dNAME, -jN, -oNAME and -rP:S:H are not yet supported.
;
;  - 80 characters - max total path+file.ext length for files.
;     For current file, also include-files, and for function "found_first"
;     should fit in 256 bytes. Not guaranteed for the latter.
;
;  - File "file.err" is created always in the current directory of source .c file.
;
;  - Only option "-iPATH" is supported. Format of include-file search is only:
;        #include <file.ext>  - search file only in .\INCLUDE
;                               directory specified internally.
;        #include "file.ext"  - search file only in directory
;                               of source .c file.
;     Trailing slash in directory path not supported !. Default "INCLUDE"
;     is reserved.
;
;  - 4 - max nesting level for include-files.
;  - Replace call "call" A4F02 with "jp".
;  - Replace call "call" A06C7 with "jp".
;  - Replace call "call" A4F27 with "jp".
;  - Set two flags "mode", called "mode1" and "mode2".
;  - Remove "test_Esc" because of bug in file processing (namely,
;     cell "D76C1" is used for both .c and include-files).
;
;
; Program exit codes:
;   00h  - Ok
;   0FFh - Errors/warnings detected, error message written to output files.
;



; Predefined macros:
;   __SOLIDC__, __Z80__, _CHAR_UNSIGNED, MSXDOS, __LINE__, __FILE__
;




true	equ	1
false	equ	0

; Memory pages
PAGE_0	equ	82h
PAGE_1	equ	0A2h
PAGE_3	equ	0E2h

Stack	equ	0FFF0h			; Stack start



; Unknown constants ?
L0000	equ	0000h
L0029	equ	0029h
L0032	equ	0032h
L0033	equ	0033h
L003D	equ	003Dh
L0040	equ	0040h
L0098	equ	0098h



	org	100h

	jp	start


; Compare strings hl,de
A0103:	ld	c,(hl)
	inc	hl
	ld	a,(de)
	inc	de
	cp	c
	jr	nz,.loc1
	inc	c
	dec	c
	jr	nz,A0103
	ld	a,true
	ret
.loc1:	xor	a			; false
	ret


isupper:cp	"A"
	jr	c,.loc1
	cp	"Z"+1
	jr	nc,.loc1
	ld	a,true
	ret
.loc1:	xor	a			; false
	ret


islower:cp	"a"
	jr	c,.loc1
	cp	"z"+1
	jr	nc,.loc1
	ld	a,true
	ret
.loc1:	xor	a			; false
	ret


toupper:cp	"a"
	ret	c
	cp	"z"+1
	ret	nc
	sub	20h
	ret


A0136:	ld	c,a
	call	isupper
	or	a
	ret	nz			; true, is letter
	ld	a,c
	jp	islower


isdigit:cp	"0"
	jr	c,.loc1
	cp	"9"+1
	jr	nc,.loc1
	ld	a,true
	ret
.loc1:	xor	a			; false
	ret


; negate hl
A014D:	inc	h
	dec	h
	ret	p
	ld	a,l
	cpl
	ld	l,a
	ld	a,h
	cpl
	ld	h,a
	inc	hl
	ret


;6
; ix=file descriptor
A03B0:	ld	(ix+4),0		; clear number of read bytes
	ld	(ix+5),0
	bit	2,(ix+1)		; 1024 ?
	jr	z,A03C2			; no
	ld	a,-1
	ret
A03C2:	ld	c,(ix+10)
	ld	b,(ix+11)		; bc=number of bytes to read
	ld	e,(ix+6)
	ld	d,(ix+7)		; de=buffer address
	ld	l,(ix+8)
	ld	h,(ix+9)		; hl=address in table "L064E" file descriptor (FCB)
	push	ix
	call	read_file		; read bytes from file
	pop	ix
	ld	(ix+4),l		; hl=number of read bytes
	ld	(ix+5),h
	ld	a,l
	or	h
	jr	nz,A03ED		; Ok
	set	2,(ix+1)		; error, set bit 2 (i.e. 1024)
	ld	a,-1
	ret
A03ED:	xor	a
	jp	A04F7


A03F1:	ld	c,(ix+10)		; number of bytes to write
	ld	b,(ix+11)
	jp	A04D8			; write to file


;7
; Routine for creating a file
; Input:
;   hl=file name address
;   de=address of string "r" or "w"
;   a="R"/"W" - read or write mode
;   bc=index (in table L064E):
;        0 - for .c file
;     1..4 - for include-files
;        5 - for .tmc file
;        6 - for .err file
;
A03FA:	;ld	(D75AC),hl
	ld	(A0445+1),hl
	ld	l,c
	ld	h,b
	;ld	(D75AE),hl		; index in table "L064E"
	ld	(A0442+1),hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	bc,L064E		; table of file descriptors
	add	hl,bc
	;ld	(D75B0),hl
	ld	(A04AC+1),hl
	push	hl
	inc	hl
	inc	hl
	;ld	(D75B2),de		; save string "r/w"
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	af,af'
	xor	a
	ld	(de),a
	ex	af,af'
	pop	hl
	push	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,6
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	;ld	hl,(D75B2)		; string "r" or "w"
	;ld	a,(hl)
	;call	toupper
	pop	hl
	cp	"R"			; file to read
	jr	z,A0441
	cp	"W"			; file to write
	jr	z,A0467
	jr	A04A1
	;
	; file to read
A0441:	push	de
A0442:	ld	de,0			; index in table "L064E"
	;ld	de,(D75AE)
A0445:	ld	hl,0			; file name 8.3
	;ld	hl,(D75AC)
	call	open_file		; open file
	pop	de
	inc	a
	jr	nz,A0455		; Ok
	ld	hl,0			; error
	ret
	;
A0455:	ld	hl,1
	add	hl,de
	ld	(hl),1			; mark 256-byte ?
	ld	hl,4
	add	hl,de
	ld	(hl),0
	inc	hl
	ld	(hl),0
	jr	A04A1
	;
	; create file for writing
A0467:	push	hl
	push	de
	;ld	de,(D75AE)		; index in table "L064E"
	ld	de,(A0442+1)
	;ld	hl,(D75AC)
	ld	hl,(A0445+1)		; file name
	call	create_file		; create .tmc (.err) file
	pop	de
	pop	hl
	inc	a
	jr	nz,A047D		; Ok
	ld	hl,0			; error
	ret
	;
A047D:	push	hl
	ld	hl,1
	add	hl,de
	ld	(hl),2			; mark 512-byte ?
	pop	hl
	ld	bc,6
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,4
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,6
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,2
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	;
A04A1:	ld	hl,8
	add	hl,de
;*	push	de
	;ld	de,(D75AE)		; index in table "L064E"
	ld	bc,(A0442+1)
	ld	(hl),c
	inc	hl
	ld	(hl),b
A04AC:	ld	hl,0
	;ld	hl,(D75B0)
	ld	bc,6
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
;*	pop	de
	ld	hl,10
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ex	de,hl
	ret


; Close file
; Input: ix=file descriptor
A04C2:	ld	a,(ix+0)
	or	a
	ret	nz
	ld	c,(ix+4)		; number of written bytes
	ld	b,(ix+5)
	ld	l,(ix+10)		; number of bytes to write
	ld	h,(ix+11)
	or	a
	sbc	hl,bc
	ld	c,l			; bc=number of bytes to write
	ld	b,h
A04D8:	ld	l,(ix+8)		; hl=address in table "L064E" file descriptor (FCB)
	ld	h,(ix+9)
	ld	e,(ix+6)		; de=buffer address
	ld	d,(ix+7)
	push	ix
	call	write_file		; write bytes to file
	pop	ix
	ld	c,(ix+10)		; number of bytes to write
	ld	b,(ix+11)
	ld	(ix+4),c		; number of written bytes
	ld	(ix+5),b
A04F7:	ld	c,(ix+6)		; de=buffer address
	ld	b,(ix+7)
	ld	(ix+2),c
	ld	(ix+3),b
	ret


; Flush buffer (if needed) and close file
A0504:	ld	a,l
	or	h
	jr	nz,A050B
	xor	a
	ret
A050B:	ld	e,0
	ld	a,(hl)
	push	hl
	or	a
	jr	nz,A0528
	pop	ix
	push	ix
	bit	1,(ix+1)		; 512 ?
	call	nz,A04C2		; yes, write buffer to file
	ld	l,(ix+8)
	ld	h,(ix+9)		; hl=address in table "L064E" file descriptor (FCB)
	call	close_file		; close file
	ld	e,a
A0528:	pop	hl
	inc	hl
	ld	(hl),0			; clear flag (ix+1)
	ld	a,e
	ret


A052E:	ld	a,(hl)
	inc	hl
	or	a
	ret	z
	push	hl
	push	de
	call	A0572
	pop	de
	pop	hl
	jr	A052E


; Input: hl=file descriptor
A053C:	push	hl
	pop	ix
	ld	a,(ix+4)		; number of read bytes ?
	or	(ix+5)			;
	jr	nz,A0553
	call	A03B0			; read next file block
	inc	a
	jr	nz,A0553
	ld	hl,-1
	ret
A0553:	ld	l,(ix+4)
	ld	h,(ix+5)
	dec	hl
	ld	(ix+4),l
	ld	(ix+5),h
	ld	l,(ix+2)		; current pointer in buffer
	ld	h,(ix+3)
	ld	a,(hl)			; read byte from buffer
	inc	hl
	ld	(ix+2),l
	ld	(ix+3),h
	ld	l,a
	ld	h,0
	ret


; Input: de=? (also file descriptor)
A0572:	cp	0Ah
	jr	nz,A057F
	push	de
	ld	a,0Dh
	call	A0572
	pop	de
	ld	a,0Ah
A057F:	;ld	(D75A9),a
	ld	(A05A9+1),a;
	ld	a,(de)
	or	a
	jr	z,A058C
	dec	a
	jr	z,A05B7
	ret
A058C:	push	de
	pop	ix
	ld	a,(ix+4)
	or	(ix+5)
	call	z,A03F1			; flush file buffer
	ld	l,(ix+4)
	ld	h,(ix+5)
	dec	hl
	ld	(ix+4),l
	ld	(ix+5),h
	ld	l,(ix+2)
	ld	h,(ix+3)
A05A9:	ld	a," "
	;ld	a,(D75A9)
	ld	(hl),a
	inc	hl
	ld	(ix+2),l
	ld	(ix+3),h
	ret
A05B7:	ld	a,(A05A9+1)
	;ld	a,(D75A9)
	cp	0Dh
	ret	z
	jp	A015E			; output "a" to screen


; Output string (for fprintf)
A05C0:	ld	de,L0642		; structure file descriptor .err
	jp	A052E			; output string "hl" to file


; Output "a" (for fprintf)
A05C6:	ld	de,L0642		; structure file descriptor .err
	jp	A0572			; output byte to file




; Error exit with status
abort:	ld	b,-1			; error status
; Standard exit with status
A05E2:	push	bc			; save return status
	ld	a,0Dh
	call	A015E			; output "a" to screen
	;
	ld	hl,(D76C1)		; file *.c     =L05FA
	call	A0504			; close file
	;
	ld	hl,(D76C3)		; file *.tmc   =L0636
	call	A0504			; flush buffer (if needed) and close file
	;
	ld	hl,(D76C5)		; file *.err   =L0642
	call	A0504			; flush buffer (if needed) and close file
	pop	bc			; restore return status
	jp	Exit


; 6 file descriptors (72 bytes)
; ...



A0686:	call	L18A7
	call	A1651
	call	A5790
	ld	a,(D76CE)		; false/true displays memory usage statistics
	or	a
	call	nz,info			; display statistics about table usage
	ld	a,(D76C7)		; false/true flag for error detection during compilation
	or	a
	jr	z,A06A5
	ld	hl,T06AE		; "errors detected"
	call	A0170			; output string to screen
	jp	abort			; exit with error
	;
A06A5:	ld	hl,T06BE		; "complete"
	call	A0170			; output string to screen
	ld	b,0			; error code (Ok)
	jp	A05E2			; close files and exit



A06C7:	push	de
	call	A0170			; output string to screen
	pop	hl
	call	A0170
	ld	a,"]"
	call	A015E			; output "a" to screen
	jp	abort			; exit with error



A06E6:	push	af
	call	A0136
	pop	bc
	or	a
	ret	nz
	ld	a,b
	cp	"_"			; 5Fh
	jr	nz,A06E4
	ld	a,true
	ret
A06E4:	xor	a			; false
	ret


A06F5:	cp	"\"			; 5Ch
	ret	nz
	call	A0E3E
	ld	(D77D2),a
	call	isdigit
	or	a
	jr	z,A0737
	ld	a,(D77D2)
	sub	"0"
	ld	(D77D3),a
	ld	b,2
A070E:	push	bc
	call	A0E3E
	pop	bc
	ld	(D77D2),a
	sub	"0"
	jr	c,A072E
	cp	8
	jr	nc,A072E
	ld	c,a
	ld	a,(D77D3)
	add	a,a
	add	a,a
	add	a,a
	add	a,c
	ld	(D77D3),a
	djnz	A070E
	jp	A07B9
	;
A072E:	ld	a,(D77D2)
	call	A0F0F
	jp	A07B9
	;
A0737:	ld	a,(D77D2)
	ld	hl,T074B
	ld	bc,9
	cpir
	ret	nz
	add	hl,bc
	add	hl,bc
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jp	(hl)


T074B:	db	"ntbrfvaxX"
	;
	dw	L077B			; X
	dw	L077B			; x
	dw	L0775			; a
	dw	L0772			; v
	dw	L076F			; f
	dw	L0769			; r
	dw	L076C			; b
	dw	L0778			; t
	dw	L0766			; n


L0766:	ld	a,0Ah
	ret

L0769:	ld	a,0Dh
	ret

L076C:	ld	a,8
	ret

L076F:	ld	a,0Ch
	ret

L0772:	ld	a,0Bh
	ret

L0775:	ld	a,7
	ret

L0778:	ld	a,9
	ret

L077B:	call	A0E3E
	ld	(D77D2),a
	xor	a
	ld	(D77D3),a
	ld	b,2
A0787:	push	bc
	ld	a,(D77D2)
	call	toupper
	pop	bc
	sub	"0"
	jr	c,A07B3
	cp	9+1
	jr	c,A079D
	sub	7
	cp	10h
	jr	nc,A07B3
A079D:	ld	c,a
	ld	a,(D77D3)
	add	a,a		; 1+1=2
	add	a,a		; 2+2=4
	add	a,a		; 4+4=8
	add	a,a		; 8+8=16
	add	a,c		; 16+1=17
	ld	(D77D3),a
	push	bc
	call	A0E3E
	pop	bc
	ld	(D77D2),a
	djnz	A0787
A07B3:	ld	a,(D77D2)
	call	A0F0F
A07B9:	ld	a,(D77D3)
	ret


A07BD:	ld	l,a
	ld	a,e
	cp	0FBh
	jr	nz,A07C7
	ld	a,true
	ret
	;
A07C7:	ld	a,e
	cp	0FAh
	jr	nz,A07E4
	ld	a,l
	push	hl
	call	A06E6
	pop	hl
	or	a
	jr	nz,A07E2
	ld	a,l
	call	isdigit
	or	a
	jr	nz,A07E2
	ld	a,true
	ret
A07E2:	xor	a			; false
	ret
A07E4:	ld	a,l
	cp	e
	jr	nz,A07EC		; optimized
	ld	a,true
	ret
A07EC:	xor	a			; false
	ret


A07EE:	ex	de,hl
	ld	hl,0
A07F2:	ld	a,(de)
	or	a
	ret	z
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	inc	de
	ld	c,a
	ld	b,0
	add	hl,bc
	jr	A07F2
	;
A0802:	ld	(D77D5),hl
	push	hl
	ld	hl,(D77D7)
	ld	(D77D9),hl
	pop	hl
	call	A07EE
	ld	de,(D77D7)
	call	A750B
	ld	(D77DB),de
A081D:	ex	de,hl
	add	hl,hl
	add	hl,hl
	ex	de,hl
	ld	hl,(D77DD)
	add	hl,de
	ld	a,(hl)
	inc	hl
	or	(hl)
	dec	hl
	ret	z
	push	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,(D77D5)
	call	A0103			; compare strings hl/de
	pop	hl
	or	a
	ret	nz			; true
	ld	hl,(D77D9)
	dec	hl
	ld	(D77D9),hl
	ld	a,l
	or	h
	ld	a,0			; error string "hash table"
	jp	z,A4F02			; abort
	ld	de,(D77D7)
	ld	hl,(D77DB)
	ld	c,l
	ld	b,h
	ld	hl,5
	add	hl,bc
	call	A750B
	ld	(D77DB),de
	jr	A081D


A085F:	push	de
	ld	de,(D77E7)
	ld	hl,(D77E9)
	scf
	sbc	hl,de
	jr	c,A08A8
	ld	(de),a
	inc	de
	pop	hl
A0870:	ld	(D77ED),hl
	ld	hl,(D77E9)
	scf
	sbc	hl,de
	jr	c,A08A8
	ld	hl,(D77ED)
	ld	a,(hl)
	inc	hl
	ld	(de),a
	inc	de
	or	a
	jr	nz,A0870
	ld	hl,(D77E7)
	push	de
	call	A0802
	pop	de
	ld	a,(hl)
	inc	hl
	or	(hl)
	dec	hl
	ret	nz
	push	hl
	ld	bc,(D77E7)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	(D77E7),de
	pop	hl
	ret
A08A8:	ld	a,1			; error string "pool"
	jp	A4F02			; abort


A08AD:	ld	(D77EF),a
	xor	a
	ld	(D77F0),a
	ld	hl,(D77E7)
	ld	(D77F1),hl
A08BA:	ld	hl,(D77E9)
	ld	de,(D77F1)
	scf
	sbc	hl,de
	jp	c,A08A8			; overflow
	ld	a,(D77F0)
	inc	a
	cp	" "			; 20h
	jr	nc,A08DC
	ld	(D77F0),a
	ld	a,(D77EF)
	ld	(de),a
	inc	de
	ld	(D77F1),de
A08DC:	call	A0E3E
	ld	(D77EF),a
	cp	"_"			; 5Fh
	jr	z,A08BA
	cp	"0"
	jr	c,A08FE
	cp	"9"+1
	jr	c,A08BA
	cp	"A"
	jr	c,A08FE
	cp	"Z"+1
	jr	c,A08BA
	cp	"a"
	jr	c,A08FE
	cp	"z"+1
	jr	c,A08BA
A08FE:	call	A0F0F
	xor	a
	ld	hl,(D77F1)
	ld	(hl),a
	inc	hl
	ld	(D77F1),hl
D090A:	ld	hl,(D77E7)
	call	A0802
	ld	(D77FD),hl
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	nz,A0928
	ld	de,(D77E7)
	ld	hl,(D77FD)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D77F1)
	ld	(D77E7),hl
A0928:	ld	a,true
	ret



A0934:	ld	hl,D78A8
	ld	(hl),0
	ld	hl,A7880
	ld	(hl),a
	inc	hl
	ld	(hl),0
	cp	"0"
	jr	nz,A095D
	push	hl
	call	A0E3E
	ld	(D77D2),a
	pop	hl
	cp	"."
	jp	z,A09F1
	cp	"X"
	jr	z,A0959
	cp	"x"
	jr	nz,A0962
A0959:	ld	a,"X"
	ld	(hl),a
	inc	hl
A095D:	push	hl
	call	A0E3E
	pop	hl
A0962:	ld	(D77D2),a
	cp	"0"
	jr	c,A0988
	cp	"9"+1
	jr	c,A0983
	ld	c,a
	ld	a,(A7880+1)
	cp	"X"
	jr	nz,A0988
	ld	a,c
	call	toupper
	cp	"A"
	jr	c,A0988
	cp	"F"+1
	jr	nc,A0988
	sub	7
A0983:	ld	(hl),a
	inc	hl
	jr	A095D
	;
A0988:	ld	a,(D77D2)
	cp	"."
	jr	z,A09F1
	push	hl
	call	A0136
	pop	hl
	or	a
	jr	nz,A09A4
	ld	a,(D77D2)
	push	hl
	call	A0F0F
	pop	hl
	xor	a
	jp	A0A6A
	;
A09A4:	ld	a,(D77D2)
	call	toupper
	cp	"U"
	jr	z,A09BB
	cp	"E"
	jr	z,A0A0D
	ld	a,(D77D2)
	push	hl
	call	A0F0F
	pop	hl
A09BB:	push	hl
	call	A0E3E
	pop	hl
	cp	"L"
	jp	z,A0A6A
	cp	"l"
	jp	z,A0A6A
	push	hl
	call	A0136
	pop	hl
	or	a
	jp	z,A0A6A
	call	A0F0F
A09D6:	ld	hl,(D77CC)		; column number
	push	hl
	ld	hl,(D77CA)		; line number
	push	hl
	ld	hl,T092B		; "XBnumber"
	push	hl
	call	fprintf			; output string to screen or output file
	pop	bc
	pop	bc
	pop	bc
	ld	hl,0
	ld	(D77FD),hl
	ld	a,2
	ret
A09F1:	ld	(hl),a
	inc	hl
	push	hl
	call	A0E3E
	ld	(D77D2),a
	pop	hl
	cp	"0"
	jr	c,A0A2D
	cp	"9"+1
	jr	c,A09F1
	cp	"E"
	jr	z,A0A0D
	cp	"e"
	jr	nz,A0A2D
A0A0D:	ld	a,"E"
	ld	(hl),a
	inc	hl
	push	hl
	call	A0E3E
	pop	hl
	cp	"+"
	jr	z,A0A1E
	cp	"-"
	jr	nz,A0A25
A0A1E:	ld	(hl),a
	inc	hl
	push	hl
	call	A0E3E
	pop	hl
A0A25:	cp	"0"
	jr	c,A0A2D
	cp	"9"+1
	jr	c,A0A1E
A0A2D:	ld	(hl),0
	call	A0F0F
	ld	a,(A7880+1)
	cp	"X"
	;jr	z,A09D6
	jr	A09D6
	; ??
;	ld	hl,A7880		; !  ds 40
;	ld	de,LF586		; !
;	ld	bc,40
;	ldir
	;
;	call	LF560			; !  read/write from T0B3E, 50 bytes, not moved
;	ld	de,(D77E7)
;	push	de
;	ld	a,(LF663)		; ! 0C41
;	ld	c,a
;	cp	8
;	ld	a,23h			; "#"
;	jr	nz,A0A59
;	ld	a,21h			; "!"
;A0A59:	ld	(de),a
;	inc	de
;	ld	b,0			; +c=counter
;	ldir
;	ld	(D77E7),de
;	pop	hl
;	ld	(D77FD),hl
;	ld	a,3
;	ret

A0A6A:	and	5Fh
	ld	(D78A8),a
	ld	(hl),0
	ld	hl,A7880
	ld	de,0
	exx
	ld	hl,0
	exx
	ld	a,(hl)
	cp	"0"
	jr	nz,A0AB1
	inc	hl
	ld	a,(hl)
	cp	"X"
	jr	z,A0AE6
A0A89:	ld	a,(hl)
	sub	"0"
	jp	c,A0B0E
	cp	8
	jp	nc,A0B0E
	inc	hl
	ex	de,hl
	add	hl,hl
	exx
	adc	hl,hl
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	ld	c,a
	ld	b,0
	add	hl,bc
	jr	nc,A0AAE
	exx
	inc	hl
	exx
A0AAE:	ex	de,hl
	jr	A0A89
	;
A0AB1:	sub	"0"
	ld	e,a
A0AB4:	inc	hl
	ld	a,(hl)
	sub	"0"
	jp	c,A0B0E
	cp	0Ah
	jp	nc,A0B0E
	ex	de,hl
	ld	c,l
	ld	b,h
	add	hl,hl
	exx
	ld	c,l
	ld	b,h
	adc	hl,hl
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	add	hl,bc
	exx
	adc	hl,bc
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	ld	b,0
	ld	c,a
	add	hl,bc
	jr	nc,A0AE2
	exx
	inc	hl
	exx
A0AE2:	ex	de,hl
	jr	A0AB4
	;
A0AE6:	inc	hl
	ld	a,(hl)
	sub	"0"
	jr	c,A0B0E
	ex	de,hl
	add	hl,hl
	exx
	adc	hl,hl
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	ld	c,a
	ld	b,0
	add	hl,bc
	jr	nc,A0B0B
	exx
	inc	hl
	exx
A0B0B:	ex	de,hl
	jr	A0AE6
	;
A0B0E:	ex	de,hl
	ld	(D77FD),hl
	exx
	ld	a,h
	or	l
	ld	(D77FF),hl
	jr	nz,A0B22
	ld	a,(D78A8)
	cp	"L"			; 4Ch
	ld	a,2
	ret	nz
A0B22:	ld	de,(D77E7)
	ld	hl,D77FD
	push	de
	ld	a,"%"			; 25h
	ld	(de),a
	inc	de
	ld	bc,4
	ldir
	ld	(D77E7),de
	pop	hl
	ld	(D77FD),hl
	ld	a,3
	ret



A0B6D:	call	A4F68
A0B70:	call	A0E3E
	cp	22h			; "
	jr	z,A0B88
	cp	0Ah
	jr	z,A0B88
	cp	1Ah
	jr	z,A0B88
	call	A06F5
	call	A4F87
	jr	A0B70
	;
A0B88:	cp	22h			; "
	jr	z,A0BA1
	call	A0F0F
	ld	hl,(D77CC)		; column number
	push	hl
	ld	hl,(D77CA)		; line number
	push	hl
	ld	bc,T0B65
	push	bc
	call	fprintf			; output string to screen or to output file
	pop	bc
	pop	bc
	pop	bc
A0BA1:	xor	a
	call	A4F87
	call	A4FC2
	ld	(D77FD),hl
	ld	a,5
	ret


A0BC6:	ld	hl,(D77F7)		; column number
	push	hl
	ld	hl,(D77F9)		; line number
	push	hl
	ld	bc,T0BAE
	push	bc
	call	fprintf			; output string to screen or to output file
	pop	bc
	pop	bc
	pop	bc
	jp	abort			; exit to DOS


A0BF3:	ld	de,(D77E9)
	ld	hl,(D77EB)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A0C2D
	ld	hl,(D77E9)
	ld	a,(hl)
	inc	hl
	inc	hl
	inc	hl
	ld	(D77E9),hl
	push	af
	dec	hl
	ld	a,(hl)
	dec	hl
	ld	l,(hl)
	ld	h,a
	ld	(D77FD),hl
	pop	af
	cp	0C9h
	ret	nz
	ld	hl,(D77F7)		; column number
	push	hl
	ld	hl,(D77F9)		; line number
	push	hl
	ld	bc,T0BDB
	push	bc
	call	fprintf			; output string to screen or to output file
	pop	bc
	pop	bc
	pop	bc
	jr	A0BF3
	;
A0C2D:	call	A0E3E
	ld	(D78AA),a
	cp	" "
	jr	z,A0C2D
	cp	9			; Tab
	jr	z,A0C2D
	ld	hl,(D77CA)
	ld	(D77F9),hl		; line number
	ld	hl,(D77CC)
	ld	(D77F7),hl		; column number
	call	A06E6
	or	a
	jr	z,A0C56
	ld	a,(D78AA)
	jp	A08AD
	;
A0C56:	ld	a,(D78AA)
	call	isdigit
	or	a
	jr	z,A0C66
	ld	a,(D78AA)
	jp	A0934
	;
A0C66:	ld	a,(D78AA)
	cp	27h			; '
	jr	nz,A0C9A
	call	A0E3E
	call	A06F5
	ld	l,a
	ld	h,0
	ld	(D77FD),hl
	call	A0E3E
	cp	27h			; '
	jr	z,A0C97
	call	A0F0F
	ld	hl,(D77CC)		; column number
	push	hl
	ld	hl,(D77CA)		; line number
	push	hl
	ld	bc,T0BDF
	push	bc
	call	fprintf			; output string to screen or to output file
	pop	bc
	pop	bc
	pop	bc
A0C97:	ld	a,4
	ret
A0C9A:	cp	22h			; "
	jr	nz,A0CA2
	jp	A0B6D
	;
A0CA2:	cp	"."
	jr	nz,A0CC6
	call	A0E3E
	cp	"0"
	jr	c,A0CBE
	cp	"9"+1
	jr	nc,A0CBE
	call	A0F0F
	ld	a,"."
	call	A0F0F
	ld	a,"0"
	jp	A0934
	;
A0CBE:	call	A0F0F
	ld	a,"."
	ld	(D78AA),a
A0CC6:	cp	1Ah
	jr	nz,A0CCE
	ld	a,0FAh			; token ?
	ret
A0CCE:	cp	0Ah
	jr	nz,A0CD6
	ld	a,0F8h			; end of line ?
	ret
A0CD6:	cp	"/"
	jr	nz,A0CF8
	call	A0E3E
	cp	"/"
	jr	nz,A0CF0
A0CE1:	call	A0E3E
	cp	1Ah
	jp	z,A0C2D
	cp	0Ah
	jr	nz,A0CE1
	jp	A0C2D
	;
A0CF0:	call	A0F0F
;-	ld	a,2Fh			; "/"  ??
	jr	A0D12
	;
A0CF8:	cp	"\"
	jr	nz,A0D12
	ld	hl,(D77F7)		; column number
	push	hl
	ld	hl,(D77F9)		; line number
	push	hl
	ld	bc,T0BE7
	push	bc
	call	fprintf			; output string to screen or to output file
	pop	bc
	pop	bc
	pop	bc
	jp	A0C2D
	;
A0D12:	ld	bc,0
A0D15:	ld	hl,L1B2A
	add	hl,bc
	ld	a,(hl)
	ld	hl,L1B29
	add	hl,bc
	sub	(hl)
	ld	l,a
	ld	h,0
	ld	(D78AE),hl
	ld	hl,L1B29
	add	hl,bc
	ld	l,(hl)
	ld	h,0
	ld	(D78AC),hl
A0D2F:	ld	hl,(D78AE)
	dec	hl
	ld	(D78AE),hl
	inc	hl
	ld	a,l
	or	h
	jr	nz,A0D51
	ld	hl,(D77F7)		; column number
	push	hl
	ld	hl,(D77F9)		; line number
	push	hl
	ld	bc,T0BE7
	push	bc
	call	fprintf			; output string to screen or to output file
	pop	bc
	pop	bc
	pop	bc
	jp	A0C2D
	;
A0D51:	ld	hl,(D78AC)
	ld	c,l
	ld	b,h
	inc	bc
	ld	l,c
	ld	h,b
	ld	(D78AC),hl
	ld	hl,L1A97
	add	hl,bc
	ld	e,(hl)
	ld	a,(D78AA)
	call	A07BD
	or	a
	jr	z,A0D2F
	ld	bc,(D78AC)
	dec	bc
	ld	hl,L1A98
	add	hl,bc
	ld	a,(D78AA)
	cp	(hl)
	jr	nz,A0D87
	push	bc
	call	A0E3E
	ld	(D78AA),a
	pop	bc
	jr	A0D15
	;
A0D87:	ld	hl,L1B29
	add	hl,bc
	ld	l,(hl)
	ld	h,0
	ld	bc,L1A98
	add	hl,bc
	ld	l,(hl)
	ld	h,0
	ld	a,l
	sub	0F9h
	or	h
	jr	z,A0DA6
	ld	a,(D78AA)
	push	hl
	call	A0F0F
	pop	hl
	ld	a,l
	ret
	;
A0DA6:	ld	a,(D76CA)		; true/false  flag for comment nesting
	or	a
	jr	z,A0E07
	ld	a,1
	ld	(D78AB),a
A0DB2:	ld	a,(D78AA)
	cp	1Ah			; code end of file ?
	jr	z,A0DC7
	cp	"*"
	jr	z,A0DCA
	cp	"/"
	jr	z,A0DE0
	jr	A0DF3
	;
A0DC7:	call	A0BC6
A0DCA:	call	A0E3E
	ld	(D78AA),a
	cp	"/"
	jr	nz,A0DF9
	ld	hl,(D78AB)
	dec	l
	ld	a,l
	ld	(D78AB),a
	jr	A0DF3
	;
A0DE0:	call	A0E3E
	ld	(D78AA),a
	cp	"*"
	jr	nz,A0DF9
	ld	hl,(D78AB)
	inc	l
	ld	a,l
	ld	(D78AB),a
A0DF3:	call	A0E3E
	ld	(D78AA),a
A0DF9:	ld	hl,(D78AB)
	inc	l
	dec	l
	jr	nz,A0DB2
	call	A0F0F
	jp	A0C2D
	;
A0E07:	ld	a,(D78AA)
	cp	"*"
	jr	nz,A0E1D
	call	A0E3E
	cp	"/"
	jp	z,A0C2D
	call	A0F0F
	jr	A0E25
	;
A0E1D:	cp	1Ah			; code end of file ?
	jr	nz,A0E25
	call	A0BC6
A0E25:	call	A0E3E
	ld	(D78AA),a
	jr	A0E07


A0E2E:	ld	hl,(D76C1)		; file descriptor
	call	A053C			; read byte from file
	ld	a,l
	ld	(D78A9),a
	cp	0Dh
	jr	z,A0E2E
	ret


A0E3E:	ld	hl,(D77AA)
	ld	bc,A77AC
	ld	a,c
	sub	l
	ld	a,b
	sbc	a,h
	jr	nc,A0E59
	ld	hl,(D77AA)
	dec	hl
	ld	(D77AA),hl
	ld	a,(hl)
	ld	(D78A9),a
	jp	A0EFD
	;
A0E59:	call	A0E2E
	ld	hl,(D77CC)
	inc	hl
	ld	(D77CC),hl
	;ld	a,(D78A9)
	inc	a
	jr	z,A0E72
	;ld	a,(D78A9)
	dec	a;
	cp	1Ah
	jr	nz,A0EB6
A0E72:	ld	hl,(index)		; index file descriptor
	ld	a,l
	or	h
	jr	z,A0EAE			; index initial *.C file
	ld	hl,(D76C1)		; include-file
	call	A0504			; write last block (if needed) and close file
	ld	hl,(index)		; index file descriptor
	dec	hl
	ld	(index),hl
	add	hl,hl
	ld	c,l
	ld	b,h
	add	hl,hl		; 1+1=2
	add	hl,bc		; 2+1=3
	ld	bc,A7852		; ds 40
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	(D77CA),de
	ld	(D1A86),de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	(D77CC),de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D76C1),de
	jr	A0E59
	;
A0EAE:	ld	a,1Ah
	ld	(D78A9),a
	jr	A0EFD
	;
A0EB6:	ld	a,(D78A9)
	cp	0Ah
	jr	nz,A0ED1
	ld	hl,(D77CA)
	inc	hl
	ld	(D77CA),hl
	ld	(D1A86),hl
	ld	hl,-1
	ld	(D77CC),hl
	jr	A0EFD
	;
A0ED1:	ld	a,(D78A9)
	cp	5Ch			; \
	jr	nz,A0EFD
	call	A0E2E
	cp	0Ah
	jr	nz,A0EF4
	ld	hl,(D77CA)
	inc	hl
	ld	(D77CA),hl
	ld	(D1A86),hl
	ld	hl,-1
	ld	(D77CC),hl
	jp	A0E59
	;
A0EF4:	ld	a,(D78A9)
	call	A0F0F
	ld	a,5Ch
	ret
A0EFD:	ld	a,(D78A9)
	cp	1Ah
	jr	nz,A0F0B
	ld	a,(D78A9)
	call	A0F0F
A0F0B:	ld	a,(D78A9)
	ret
	;
A0F0F:	ld	hl,(D77AA)
	ld	(hl),a
	inc	hl
	ld	(D77AA),hl
	ret


A0F18:	call	A0E3E
	cp	0Ah
	jr	nz,A0F18
	ret


A0F20:	xor	a
	ld	(D787F),a
	call	A0F18
A0F27:	call	A0BF3
	ld	(D77FB),a
	cp	0C9h			; token ?
	jr	z,A0F40
	ld	a,(D77FB)
	cp	0FAh			; end of line ?
	jr	nz,A0F27
	call	A5473
	jr	A0F27
	;
A0F40:	ld	hl,(D77F7)		; column number
	ld	a,l
	or	h
	jr	nz,A0F27
	call	A0BF3
	dec	a
	jr	nz,A0F27
	ld	de,(D77FD)
	ld	hl,(D780A)
	ld	a,e
	cp	l
	jr	nz,A0F5F
	ld	a,d
	cp	h
	jr	z,A0F6C
A0F5F:	ld	hl,(D780C)
	ld	a,e
	cp	l
	jr	nz,A0F76
	ld	a,d
	cp	h
	jr	nz,A0F76
A0F6C:	ld	a,(D787F)
	inc	a
	ld	(D787F),a
	jr	A0F27
	;
A0F76:	ld	de,(D77FD)
	ld	hl,(D7810)
	ld	a,e
	cp	l
	jr	nz,A0F84
	ld	a,d
	cp	h
A0F84:	jr	nz,A0F95
	ld	a,(D787F)
	dec	a
	ld	(D787F),a
	inc	a
	jp	nz,A0F27
	jp	A0F18			;A0FAD
	;
A0F95:	ld	de,(D77FD)
	ld	hl,(D780E)
	ld	a,e
	cp	l
	jr	nz,A0FA3
	ld	a,d
	cp	h
A0FA3:	jp	nz,A0F27
	ld	a,(D787F)
	or	a
	jp	nz,A0F27
	jp	A0F18


A0FBF:	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,(D77F7)		; column number
	push	hl
	ld	hl,(D77F9)		; line number
	push	hl
	ld	bc,T0FB0
	push	bc
	call	fprintf			; output string to screen or to output file
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	jp	A0F18


A0FD9:	ld	c,l
	ld	b,h
	ld	(D787D),hl
A0FDE:	ld	a,(bc)
	cp	0FAh
	jr	z,A0FEA
	dec	bc
	dec	bc
	dec	bc
	jr	A0FDE
	;
A0FEA:	ld	hl,1
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,(bc)
	push	bc
	call	A50B5
	pop	bc
	inc	bc
	inc	bc
	inc	bc
	ld	hl,-3
	add	hl,bc
	ld	de,(D787D)
	ld	a,l
	cp	e
	jr	nz,A0FEA
	ld	a,h
	cp	d
	jr	nz,A0FEA
	ld	hl,(D79FB)
	ret


A1036:	ld	hl,-20
	add	hl,sp
	ld	sp,hl
	xor	a
	ld	(D787A),a
	call	A0BF3
	dec	a
	jr	z,A104F
	ld	hl,(D7804)
	call	A0FBF
	jp	A1197
	;
A104F:	ld	hl,(D77F7)		; column number
	call	A50EB
	ld	(D787B),hl
	ex	de,hl
	ld	hl,1
	add	hl,de
	push	hl
	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	push	de
	call	A0E3E
	pop	hl
	cp	28h
	jp	nz,A1100
A107C:	call	A0BF3
	ld	(D77FB),a
	cp	0F8h
	jr	z,A10EC
	ld	a,(D77FB)
	cp	10h
	jr	z,A10EC
	ld	a,(D77FB)
	cp	0FAh
	jr	z,A10EC
	ld	a,(D77FB)
	dec	a
	jp	nz,A1182
	ld	a,(D787A)
	cp	0Ah
	jr	c,A10BB
	ld	hl,(D77F7)		; column number
	push	hl
	ld	hl,(D77F9)		; line number
	push	hl
	ld	bc,T1010		; "Xtoo much parameters"
	push	bc
	call	fprintf			; output string to screen or to output file
	pop	bc
	pop	bc
	pop	bc
	jp	A1194
	;
A10BB:	inc	a
	ld	(D787A),a
	dec	a
	ld	l,a
	ld	h,0
	add	hl,hl
	ex	de,hl
	ld	hl,0
	add	hl,sp
	add	hl,de
	ld	de,(D77FD)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	call	A0BF3
	ld	(D77FB),a
	cp	10h
	jr	nz,A10E1
	jr	A10EC
	;
A10E1:	ld	a,(D77FB)
	cp	0B8h
	jr	z,A107C
	jp	A1182
	;
A10EC:	ld	a,(D77FB)
	cp	10h
	jp	nz,A1182
	ld	a,(D787A)
	inc	a
	inc	a
	ld	hl,(D787B)
	ld	(hl),a
	jr	A1108
	;
A1100:	push	hl
	call	A0F0F
	ld	a,1
	pop	hl
	ld	(hl),a
A1108:	push	hl
	call	A5142
	ld	a,0FAh
	ld	(D77FB),a
	call	A5153
	ld	a,1			; true ?
	ld	(D77A8),a
A1119:	call	A0BF3
	ld	(D77FB),a
	cp	0F8h
	jr	z,A1167
	ld	a,(D77FB)
	dec	a
	jr	nz,A1161
	ld	c,0
A112D:	ld	a,c
	ld	hl,(D787A)
	cp	l
	jr	nc,A1161
	ld	l,c
	ld	h,0
	add	hl,hl
	ex	de,hl
	ld	hl,2
	add	hl,sp
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,(D77FD)
	ld	a,l
	cp	e
	jr	nz,A114C
	ld	a,h
	cp	d
A114C:	jr	nz,A115D
	ld	a,7
	ld	(D77FB),a
	ld	l,c
	ld	h,0
	ld	(D77FD),hl
	jr	A1161
	;
A115D:	inc	c
	jr	A112D
	;
A1161:	call	A5153
	jr	A1119
	;
A1167:	ld	hl,(D79F1)
	dec	hl
	dec	hl
	dec	hl
	call	A0FD9
	ex	de,hl
	pop	hl
	inc	hl
	inc	hl
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D79EF)
	ld	(D77E5),hl
	xor	a			; false ?
	ld	(D77A8),a
	jr	A1197
	;
A1182:	ld	hl,(D77F7)		; column number
	push	hl
	ld	hl,(D77F9)		; line number
	push	hl
	ld	bc,T1025		; 
	push	bc
	call	fprintf			; output string to screen or to output file
	pop	bc
	pop	bc
	pop	bc
A1194:	call	A0F18
A1197:	ld	hl,20
	add	hl,sp
	ld	sp,hl
	ret


A119D:	call	A0BF3
	dec	a
	jr	z,A11AA
	ld	hl,(D7806)
	jp	A0FBF
	;
A11AA:	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,l
	or	h
	ret	z
	ld	a,(hl)
	or	a
	ret	z
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ret


;T11DB:	db	"R",0			; file for reading (include-file)


; Open include-file
; input: hl=address of include-file name
A11DD:	push	hl
	ld	de,(D77CA)
[...]
