; Compiler bootloader for loading and running compiler.
; Loads compressed compiler code and runs it.
;



; Macro definition ds xx
%imacro ds 1
times %1 db 0
%endmacro



; Data from file "cc.bin"
dss_page equ	802Ah			; Address of cell page_dss


; Memory pages
PAGE_0	equ	82h
PAGE_1	equ	0A2h
PAGE_3	equ	0E2h



	org	0A200h

	db	"EXE"			; exe ID
	db	0			; exe version
	dw	512			; 512, byte size unit
	dw	0			; stat size unit
	dw	end_loader - entry	; end-beg, primary bootloader
	dw	0,0,0			; reserved
	dw	entry			; address bootload code
	dw	entry			; address control transfer
	dw	0BF00h			; stack address
	ds	490


entry:	; Clear keyboard buffer
	ld	bc,3135h
	rst	10h
	; Save current memory pages DSS
	in	a,(PAGE_0)
	ld	(_dss),a
	in	a,(PAGE_1)
	ld	(portA2),a
	in	a,(PAGE_3)
	ld	(portE2),a
	in	a,(89h)
	ld	(port89),a
	;
	ld	(L0080+1),ix		; save command string address
	ld	a,(ix-3)
	ld	(hFile),a		; save current descriptor
	ld	hl,Title		; program title
	ld	c,5Ch
	rst	10h
	; Allocate 3 blocks of memory
	ld	bc,033Dh
	rst	10h
	jr	nc,next1		; Ok
no_mem:	ld	hl,no_space		; no memory
	ld	c,5Ch
	rst	10h
	ld	bc,0FF41h		; exit
	rst	10h

next1:	ld	(block),a		; handle allocated memory block
	; Get list of memory pages
	ld	hl,page0
	ld	c,0C5h
	rst	08h
	;
	; Allocate 1 block of memory
	ld	bc,013Dh
	rst	10h
	jr	c,no_mem		; no memory
	ld	(tmp_page),a
	; Switch it to #C000
	out	(PAGE_3),a
	;
	; Close port #89
	ld	a,0C0h
	out	(89h),a
	;------------------------- 1 -----------------------------------
	; Load 1st part
	ld	hl,0C000h		; where
	ld	de,part2-part1		; block size
	ld	a,(hFile)
	ld	c,13h			; read file
	rst	10h
	jp	c,disk_error
	; Switch page 0 to #4000
	ld	a,(page0)
	out	(PAGE_1),a
	; Clear region #0000..#0100
	ld	hl,4000h
loop:	xor	a
	ld	(hl),a
	inc	hl
	ld	a,h
	cp	41h
	jr	nz,loop
	;
	ld	hl,4DEDh		; "reti"
	;ld	hl,00C9h		; "ret"
	ld	(4038h),hl
	; Decompress 1st part
	ld	hl,0C000h		; from where
	ld	de,4100h		; to where
	call	dehrust
	;------------------------- 2 -----------------------------------
	ld	hl,0C000h		; where
	ld	de,part3-part2		; block size
	ld	a,(hFile)
	ld	c,13h			; read file
	rst	10h
	jp	c,disk_error
	; Switch page 1 to #4000
	ld	a,(page1)
	out	(PAGE_1),a
	; Decompress 2nd part
	ld	hl,0C000h		; from where
	ld	de,4000h		; to where
	call	dehrust
	;------------------------- 3 -----------------------------------
	ld	hl,0C000h		; where
	ld	de,endpart-part3	; block size
	ld	a,(hFile)
	ld	c,13h			; read file
	rst	10h
	jp	c,disk_error
	; Decompress 3rd part (file remainder)
	ld	hl,0C000h		; from where
	ld	de,8000h		; to where
	call	dehrust

	; Close file
	ld	a,(hFile)
	ld	c,12h
	rst	10h
	; Free temporary memory page
	ld	a,(tmp_page)
	ld	c,3Eh
	rst	10h
	di
	; Switch memory pages
	ld	a,(page0)
	out	(PAGE_0),a		; block 0100..3FFF
	ld	a,(page1)
	out	(PAGE_1),a		; block 4000..7FFF
	ld	a,(page2)
	out	(PAGE_3),a		; pages in 0C000h
	; Copy DSS page memory pages
	ld	hl,_dss
	ld	de,dss_page		; address of cell page_dss in "ccc.bin"
	ld	bc,9
	ldir
	; Transfer to program
L0080:	ld	hl,0			; command string address
	jp	0100h


disk_error:
	ld	a,(block)
	ld	c,3Eh			; free allocated memory block
	rst	10h
	ld	a,(hFile)
	ld	c,12h			; close file
	rst	10h
	ld	hl,load_err
	ld	c,5Ch
	rst	10h
	ld	bc,0FF41h
	rst	10h			; exit


hFile:	db	0			; descriptor file

tmp_page:
	db	-1			; memory pages for unpacking file


; Order cell should not change
_dss:	db	-1			; save memory pages Estex
block:	db	-1			; descriptor allocated memory block
	;
page0:	db	-1
page1:	db	-1
page2:	db	-1
	db	-1
	;
port89:	db	-1
portA2:	db	-1
portE2:	db	-1



Title:	db	"SOLID C Optimizing Compiler v0.01b (pass 1)  Ported by Vasil Ivanov",0Dh,0Ah
	db	"Based on SOLiD C compiler v1.00  Copyright (c) 1995 SolidSoft "
	db	"Inc.",0Dh,0Ah,0Ah,0

no_space:
	db	"Not enough memory to load program !",0Dh,0Ah,0

load_err:
	db	"Disk loading error !",0Dh,0Ah,0



; Format of packed file:
;  +0 (word) "HR" - signature
;  +2 (word) - source file length
;  +4 (word) - packed file length
;
; Decompressor
;  hl=from where
;  de=to where
dehrust:
	ld	ix,-12
	add	ix,sp
	push	de
	ld	sp,hl
	pop	bc
	ex	de,hl
	pop	bc
	dec	bc
	add	hl,bc
	ex	de,hl
	pop	bc
	dec	bc
	add	hl,bc
	sbc	hl,de
	add	hl,de
	jr	c,loc1
	ld	d,h
	ld	e,l
loc1:	lddr
	ex	de,hl
	ld	d,(ix+11)
	ld	e,(ix+10)
	ld	sp,hl
	pop	hl
	pop	hl
	pop	hl
	ld	b,6
loc2:	dec	sp
	pop	af
	ld	(ix+6),a
	inc	ix
	djnz	loc2
	exx
	ld	d,0BFh
	ld	bc,1010h
	pop	hl
loc3:	dec	sp
	pop	af
	exx
loc4:	ld	(de),a
	inc	de
loc5:	exx
loc6:	add	hl,hl
	djnz	loc7
	pop	hl
	ld	b,c
loc7:	jr	c,loc3
	ld	e,1
loc8:	ld	a,80h
loc9:	add	hl,hl
	djnz	loc10
	pop	hl
	ld	b,c
loc10:	rla
	jr	c,loc9
	cp	3
	jr	c,loc11
	add	a,e
	ld	e,a
	xor	c
	jr	nz,loc8
loc11:	add	a,e
	cp	4
	jr	z,loc26
	adc	a,0FFh
	cp	2
	exx
loc12:	ld	c,a
loc13:	exx
	ld	a,0BFh
	jr	c,loc17
loc14:	add	hl,hl
	djnz	loc15
	pop	hl
	ld	b,c
loc15:	rla
	jr	c,loc14
	jr	z,loc16
	inc	a
	add	a,d
	jr	nc,loc18
	sub	d
loc16:	inc	a
	jr	nz,loc20
	ld	a,0EFh
loc17:	rrca
	cp	a
loc18:	add	hl,hl
	djnz	loc19
	pop	hl
	ld	b,c
loc19:	rla
	jr	c,loc18
loc20:	exx
	ld	h,0FFh
	jr	z,loc21
	ld	h,a
	dec	sp
	inc	a
	jr	z,loc24
	pop	af
loc21:	ld	l,a
	add	hl,de
	ldir
loc22:	jr	loc5
	;
loc23:	exx
	rrc	d
	jr	loc6
	;
loc24:	pop	af
	cp	0E0h
	jr	c,loc21
	rlca
	xor	c
	inc	a
	jr	z,loc23
	sub	10h
loc25:	ld	l,a
	ld	c,a
	ld	h,0FFh
	add	hl,de
	ldi
	dec	sp
	pop	af
	ld	(de),a
	inc	hl
	inc	de
	ld	a,(hl)
	jr	loc4
	;
loc26:	ld	a,80h
loc27:	add	hl,hl
	djnz	loc28
	pop	hl
	ld	b,c
loc28:	adc	a,a
	jr	nz,loc31
	jr	c,loc27
	ld	a,0FCh
	jr	loc32
	;
loc29:	dec	sp
	pop	bc
	ld	c,b
	ld	b,a
	ccf
	jr	loc13
	;
loc30:	cp	0Fh
	jr	c,loc29
	jr	nz,loc12
	add	a,0F4h
	ld	sp,ix
	jr	loc34
	;
loc31:	sbc	a,a
	ld	a,0EFh
loc32:	add	hl,hl
	djnz	loc33
	pop	hl
	ld	b,c
loc33:	rla
	jr	c,loc32
	exx
	jr	nz,loc25
	bit	7,a
	jr	z,loc30
	sub	0EAh
loc34:	ex	de,hl
loc35:	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	dec	a
	jr	nz,loc35
	ex	de,hl
	jr	nc,loc22
	ret

; End of bootloader
end_loader:



; Packed program parts
part1:
	incbin "cc1"
part2:
	incbin "cc2"
part3:
	incbin "cc3"
endpart:
