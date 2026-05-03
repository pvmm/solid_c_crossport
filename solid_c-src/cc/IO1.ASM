; SOLID C Compiler 1st Pass
;
; I/O Functions
;




; Call DSS function
int10:	ld	(save_stack),sp
	ld	sp,stack1
	ex	af,af'
	in	a,(PAGE_0)
	push	af
	ld	a,(page_dss)
	out	(PAGE_0),a
	ex	af,af'
	push	ix
	push	iy
	ei
	rst	10h
	di
	pop	iy
	pop	ix
	ex	af,af'
	pop	af
	out	(PAGE_0),a
	ld	a,0C0h
	out	(89h),a			; close port 89h
	ex	af,af'
	ld	sp,(save_stack)
	ret



; Cell order must not change
page_dss:
	db	-1			; save memory page number Estex

block:	db	-1			; descriptor allocated memory block

page0:	db	-1			; page 0
page1:	db	-1			; page 1
page3:	db	-1			; page 3
	db	-1


port89:	db	-1
portA2:	db	-1
portE2:	db	-1

L0080:	dw	0			; address of command string


	ds	80
stack1:	db	0			; stack address for DSS call

save_stack:
	dw	0			; save current stack



; File extensions by convention
T7E66:	db	".C",0
T7E6B:	db	".TMC",0		; also correct for ".tco"
T7E72:	db	".ERR",0




; Output "a" to screen
A015E:	cp	0Ah			; unix-style line ending
	jr	nz,A016B
	ld	a,0Dh
	ld	c,5Bh
	call	int10
	ld	a,0Ah
A016B:	ld	c,5Bh			; output character to screen
	jp	int10



; Output string to screen
A0170:	ld	a,(hl)
	or	a
	ret	z
	inc	hl
	push	hl
	call	A015E			; output "a" to screen
	pop	hl
	jr	A0170



;mess_abort:
;	db	0Dh,0Ah,9
;	db	"Pause... <Esc> to Quit or <AnyKey> to Continue",0Ah,0

; Guard - because of incorrect sequence closing files
; Check for pressing <Esc>
;test_Esc:
;	push	bc
;	push	de
;	call	_esc
;	pop	de
;	pop	bc
;	ret

;_esc:	ld	c,31h			; query keyboard status without waiting
;	call	int10
;	ret	z			; key not pressed
;	bit	7,d			; is one key pressed ?
;	ret	nz			; no
;	ld	hl,mess_abort
;	ld	c,5Ch
;	call	int10
;	ld	c,30h			; wait for input character
;	call	int10
;	ld	hl,011Bh		; position in ascii table <Esc> key
;	and	a
;	sbc	hl,de			; Esc ?
;	ret	nz
;	jp	abort			; close all files and exit to DOS



	; Exit to DOS
Exit:	push	bc
	call	restore_path		; restore current path
	pop	bc
	ld	a,(page_dss)
	out	(PAGE_0),a
	ld	a,(portA2)
	out	(PAGE_1),a
	ld	a,(portE2)
	out	(PAGE_3),a
	ld	a,(port89)
	out	(89h),a
	ld	sp,0BFFFh
	ei
	push	bc
	; free allocated memory block
	ld	a,(block)
	ld	c,3Eh
	rst	10h
	; clear keyboard buffer
	ld	bc,3135h
	rst	10h
	pop	bc
	ld	c,41h
	rst	10h
	ret


; Save current path
save_path:
	ld	c,2			; get current disk
	call	int10
	ld	(disk),a
	ld	hl,dir
	ld	c,1Eh			; get current directory
	jp	int10


; Restore current path
restore_path:
	ld	a,(disk)
	ld	c,1			; set disk
	call	int10
	ld	hl,dir
	ld	c,1Dh			; set directory
	jp	int10




; Find file
; in: hl=file name (disk+path)
found_first:
	push	hl
	push	de
	ld	de,f_path		; work buffer 65 bytes
	ld	bc,0119h		; DSS format
	ld	a,20h			; "archive"
	call	int10
	pop	de
	pop	hl
	ret



; Open source file
; input: de=index in table "L064E" descriptor (FCB) file
;        hl=address of file name
open_file:
	push	hl
	ex	de,hl
	ld	(indx1+1),hl
	add	hl,hl			; 1+1=2
	add	hl,hl			; 2+2=4
	add	hl,hl			; 4+4=8
	ld	bc,L064E		; table of buffers and FCB files
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)			; de=file descriptor
	pop	hl			; file name
	;call	PR1			; output file name
	; DOS version
	push	de			; de=L75B6 for .c file
	call	found_first		; find file
	ld	a,1			; for reading
	ld	c,11h			; open file
	call	int10
open1:	pop	de
	ld	b,a
	ld	a,-1
	ret	c			; error
	ld	a,b
	ld	(de),a			; save descriptor
	;
indx1:	ld	hl,0
	ld	bc,dirs			; beginning of buffers
	add	hl,hl		; 1+1=2
	ld	e,l
	ld	d,h
	add	hl,hl		; 2+2=4
	add	hl,hl		; 4+4=8
	add	hl,hl		; 8+8=16
	add	hl,hl		; 16+16=32
	add	hl,hl		; 32+32=64
	add	hl,de		; 64+2=66
	add	hl,bc
	push	hl
	ld	c,2			; get current disk
	call	int10
	ld	(hl),a			; disk number
	pop	hl
	inc	hl			; hl=path string
	ld	c,1Eh			; get current directory
	call	int10
	call	restore_path		; restore current path
	xor	a
	ret




; Create .tmc (.err) file
;
; input: hl=file name
;        de=index in table "L064E" descriptor (FCB) file
;        (5 for *.tmc, 6 for *.err)
create_file:
	push	hl
	ex	de,hl
	ld	(indx1+1),hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	bc,L064E		; table of buffers and FCB files
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)			; de=file descriptor
	pop	hl			; file name
	;call	PR1			; output file name
	; DOS version
	push	de
	ld	c,0Ah			; create file
	ld	a,20h			; attribute "archive"
	call	int10
	jr	open1




; Close file
; input: hl=index in table "L064E" descriptor (FCB) file
close_file:
	push	hl
	call	set_path
	pop	hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	bc,L064E		; table of buffers and FCB files
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)			; de=file descriptor
	; DOS version
	ld	a,(de)			; descriptor file
	ld	c,12h			; close file
	call	int10
	ld	a,-1			; error
	ret	c
	xor	a
	ret

set_path:
	add	hl,hl		; 1+1=2
	ld	e,l
	ld	d,h
	add	hl,hl		; 2+2=4
	add	hl,hl		; 4+4=8
	add	hl,hl		; 8+8=16
	add	hl,hl		; 16+16=32
	add	hl,hl		; 32+32=64
	add	hl,de		; 64+2=66
	ld	de,dirs			; beginning of buffers
	add	hl,de
	push	hl
	ld	a,(hl)			; disk number
	ld	c,1			; set disk
	call	int10
	pop	hl
	inc	hl			; hl=path string
	ld	c,1Dh			; set directory
	jp	int10




; Read block from file
; input: hl=index in table "L064E" descriptor (FCB) file
;        bc=number of bytes
;        de=buffer address
read_file:
	push	bc
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	bc,L064E		; table of buffers and FCB files
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)			; bc=file descriptor
	ex	de,hl			; hl=buffer for *.TMC file
	pop	de			; de=number of read bytes
	; DOS version
	ld	a,(bc)			; descriptor file
	ld	c,13h			; read file
	call	int10
	ex	de,hl			; hl=number of read bytes
	ret




; Write block to file
; input: hl=index in table "L064E" descriptor (FCB) file
;        bc=number of bytes
;        de=buffer address
write_file:
	push	bc
	ld	(indx2+1),hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	bc,L064E		; table of buffers and FCB files
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)			; bc=file descriptor
	ex	de,hl			; hl=data buffer
	pop	de			; de=number of write bytes
	; DOS version
	ld	a,(bc)			; descriptor file
	push	bc
	ld	c,14h			; write file
	call	int10
	pop	bc
	ret	nc
	; write error
	push	af
	push	bc
indx2:	ld	hl,0
	call	set_path
	pop	bc
	ld	a,(bc)			; descriptor file
	ld	c,12h			; close file
	call	int10
	pop	af
	ld	hl,disk_full
	cp	0Ah			; error code "disk full"
	jr	z,_full
	ld	hl,write_error
_full:	call	A0170			; output string to screen
	ld	b,-1			; error code
	jp	Exit			; exit to DOS

disk_full:
	db	0Ah,"Disk full !",0Ah,0
write_error:
	db	0Ah,"Write error !",0Ah,0











%if .comment
PR:	push	af
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	;call	HEXHL
	push	hl
	ld	a,(hl)
	add	a,"A"
	call	SYMB
	pop	hl
	inc	hl
	call	A0170			; output string
	ld	a,"-"
	call	SYMB
	call	nline
	pop	iy
	pop	ix
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret

PR1:	push	af
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	ld	a,(hl)
	cp	" "
	jr	nc,.loc1
	ld	a,"#"
	call	SYMB
.loc1:	call	A0170			; output string
	call	nline
	pop	iy
	pop	ix
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret


HEXA:	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	push	af
	call	HEX1
	call	nline
	pop	af
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
	ret


HEXHL:	ld	a,h
	push	hl
	call	HEX1
	pop	hl
	ld	a,l
HEX1:	push	af
	rra
	rra
	rra
	rra
	call	HEX2
	pop	af
HEX2:	and	0Fh
	add	a,90h
	daa
	adc	a,40h
	daa
SYMB:	ld	c,5Bh			; output character to screen
	jp	int10


nline:	push	af
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	ld	a,0Dh
	call	SYMB
	ld	a,0Ah
	call	SYMB
	pop	iy
	pop	ix
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret
%endif
