; Debugging bootloader for compiler.
; Loads uncompressed compiler code and runs it.
;



; Macro definition ds xx
%imacro ds 1
times %1 db 0
%endmacro



; Data from file "cc.bin"
dss_page equ	802Ah			; Address of cell "page_dss"
_size	 equ	1006h			; File remainder: file - (3F00h+4000h)


; Memory page ports
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
	; Save memory page numbers DSS
	in	a,(PAGE_0)
	ld	(page_dss),a
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
	ld	hl,no_space		; no memory
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
	ld	a,(page0)
	out	(PAGE_3),a
	;
	; Clear region #0000..#0100
	ld	hl,0C000h
loop:	xor	a
	ld	(hl),a
	inc	hl
	ld	a,h
	cp	0C1h
	jr	nz,loop
	;
	ld	hl,4DEDh		; "reti"
	;ld	hl,00C9h		; "ret"
	ld	(0C038h),hl
	; Load into page0 block 0100..3FFF from file
	ld	hl,0C100h
	ld	de,3F00h		; block length
	ld	a,(hFile)
	ld	c,13h			; read file
	rst	10h
	jp	c,disk_error
	; Load into page1 block 4000..7FFF from file
	ld	a,(page1)
	out	(PAGE_3),a
	ld	hl,0C000h
	ld	de,4000h		; block length
	ld	a,(hFile)
	ld	c,13h
	rst	10h
	jp	c,disk_error
	; Load file remainder into this memory page
	ld	hl,8000h
	ld	de,_size		; remainder size
	ld	a,(hFile)
	ld	c,13h
	rst	10h
	jp	c,disk_error
	; Close file
	ld	a,(hFile)
	ld	c,12h
	rst	10h
	di
	; Close port 89h
	ld	a,0C0h
	out	(89h),a
	; Switch memory pages
	ld	a,(page0)
	out	(PAGE_0),a		; block 0100..3FFF
	ld	a,(page1)
	out	(PAGE_1),a		; block 4000..7FFF
	ld	a,(page2)
	out	(PAGE_3),a		; pages in 0C000h
	; Copy handle memory pages
	ld	hl,page_dss
	ld	de,dss_page		; address of cell page_dss in "ccc.bin"
	ld	bc,9
	ldir
	; Transfer to program
L0080:	ld	hl,0			; address command string
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


; Order cell must not change
page_dss:
	db	-1			; save memory page number Estex
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
	db	"Based on SOLiD C compiler v1.00  (c) 1995 SolidSoft Inc."
	db	0Dh,0Ah,0Ah,0

no_space:
	db	"Not enough memory to load program !",0Dh,0Ah,0

load_err:
	db	"Disk loading error !",0Dh,0Ah,0

; End of bootloader
end_loader:



module:
	incbin "cc.bin"
