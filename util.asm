!zone util {

!addr chrout = $ffd2
current_line = $d1
current_pos = $24

!macro pointer .pointer, .address {
    ldx #<.address
    stx .pointer
    ldx #>.address
    stx .pointer+1
}

; ---------------------------------------------------------------------------

!macro rts_to .addr {
    lda #<.addr
    sta rts_to_addr
    lda #>.addr
    sta rts_to_addr+1

    +decw rts_to_addr

    ldx #$ff
    txs
    lda rts_to_addr+1
    pha
    lda rts_to_addr
    pha
    rts
}

rts_to_addr: !byte $00, $00

; ---------------------------------------------------------------------------

!macro decw .addr {
    dec .addr
    cmp #$ff
    bne .done
    dec .addr+1
.done
}

; ---------------------------------------------------------------------------

!macro add_four_to .addr {
    lda .addr
    clc
    adc #4
    sta .addr
    bcc .done
    inc .addr+1
.done
}

; ---------------------------------------------------------------------------

!macro scan .k {
    sei
    lda .k
	sta $dc00
	lda $dc01
	and .k+1
	cmp .k+1
    cli
}

; ---------------------------------------------------------------------------

wait_any_key:
-   +scan key_none
    bne -
-   +scan key_none
    beq -
    rts

; ---------------------------------------------------------------------------

yes_or_no: !zone yes_or_no {
    jsr wait_any_key

.scan:
    +scan key_yes
    bne .yes

    +scan key_no
    bne .no

    jmp .scan

.yes:
    clc
    rts

.no:
    sec
    rts
}

; ---------------------------------------------------------------------------

clrhome !zone clrhome {
    lda #$93
    jsr chrout
    rts
}

; ---------------------------------------------------------------------------

!macro plot .x, .y {
    ldy #.x
    ldx #.y
    clc
    jsr $fff0
}

start_of_line:
    sec
    jsr $fff0
    ldy #$00
    clc
    jsr $fff0
    rts

!zone safe_restore_cursor_pos {
save_cursor_pos:
    sec
    jsr $fff0
    stx .x
    sty .y
    rts

restore_cursor_pos:
    ldx .x
    ldy .y
    clc
    jsr $fff0
    rts

.x: !byte $00
.y: !byte $00
}

; ---------------------------------------------------------------------------

!macro fill .addr, .byte, .len {
    +pointer zp1, .addr
    ldy #.len
    dey
    lda #.byte

-   sta (zp1),y
    dey
    bne -
    sta (zp1),y
}

; ---------------------------------------------------------------------------

!macro strlen .addr {
    ; for strlen < 255, result in X
    ldx #$00
-   lda .addr,x
    beq .done
    inx
    bne -
.done
}

; ---------------------------------------------------------------------------

!macro copy_string .src, .dst {
    +pointer zp1, .src
    +pointer zp2, .dst

    ldy #$00
-   lda (zp1),y
    sta (zp2),y
    beq .done
    iny
    jmp -

.done
}

; ---------------------------------------------------------------------------

!macro print .addr {
    ldx #<.addr
    ldy #>.addr
    jsr print
}

; ---------------------------------------------------------------------------

!macro print_ascii .addr {
    ldx #<.addr
    ldy #>.addr
    jsr print_ascii
}

; ---------------------------------------------------------------------------

print !zone print {
    stx zp2
    sty zp2+1
    ldy #$00

.loop
    lda (zp2),y
    beq .done
    jsr chrout
    inc zp2
    bne .loop
    inc zp2+1
    jmp .loop

.done
    rts
}

; ---------------------------------------------------------------------------

print_ascii !zone print_ascii {
    stx zp2
    sty zp2+1
    ldy #$00

.loop
    lda (zp2),y
    beq .done
    tax
    lda ascii2petscii,x
    jsr chrout
    inc zp2
    bne .loop
    inc zp2+1
    jmp .loop

.done
    rts
}

; ---------------------------------------------------------------------------

print_dec !zone print_dec {
    cmp #$00
    bne .not_zero

    lda #'0'
    jsr $ffd2
    rts

.not_zero:
   sta .value
   ldy #$01
   sta .nonzero_digit_printed

.hundreds:
    ldx #$00
-   sec
    sbc #100
    bcc .print_hundreds
    sta .value
    inx
    jmp -

.print_hundreds:
    jsr .print_digit_in_x

.tens:
    lda .value
    ldx #$00
-   sec
    sbc #10
    bcc .print_tens
    sta .value
    inx
    jmp -

.print_tens:
    jsr .print_digit_in_x

.print_ones:
    lda .value
    tax
    jsr .print_digit_in_x

    rts

.print_digit_in_x:
    cpx #$00
    bne +

    lda .nonzero_digit_printed
    beq +

    rts

+   lda .digits,x
    jsr $ffd2

    lda #$00
    sta .nonzero_digit_printed
    rts

.value: !byte $00
.nonzero_digit_printed: !byte $01
.digits: !pet "0123456789"
}

; ---------------------------------------------------------------------------

lowercase:
    lda #$0e
    jsr chrout
    rts

; ---------------------------------------------------------------------------

reverse_off:
    lda #$92
    jsr chrout
    rts

; ---------------------------------------------------------------------------

!macro newline {
    lda #$0d
    jsr chrout
}

; ---------------------------------------------------------------------------

!macro paragraph {
    lda #$0d
    jsr chrout
    jsr chrout
}

; ---------------------------------------------------------------------------

dot:
    lda #'.'
    jsr chrout
    rts

; ---------------------------------------------------------------------------

dash:
    lda #'-'
    jsr chrout
    rts

; ---------------------------------------------------------------------------

green:
    lda #$05
    sta $0286
    rts

; ---------------------------------------------------------------------------

red:
    lda #$02
    sta $0286
    rts

; ---------------------------------------------------------------------------

grey:
    lda #$0b
    sta $0286
    rts

; ---------------------------------------------------------------------------

cyan:
    lda #$03
    sta $0286
    rts

; ---------------------------------------------------------------------------

yellow:
    lda #$07
    sta $0286
    rts

; ---------------------------------------------------------------------------

!zone spinner {
.spinner_install:
sei
    ; stop all cia interrupts
    lda #$7f
    sta $dc0d
    sta $dd0d

    ; clear cia interrupt flags
    lda $dc0d
    lda $dd0d

    ; save previous irq vector
    lda $0314
    sta .previous_irq
    lda $0315
    sta .previous_irq+1

    ; setup irq vector
    lda #<spinner_spin
    sta $0314
    lda #>spinner_spin
    sta $0315

    ; setup rasterline $018
    lda #$18
    sta $d012

    lda $d011
    and #$7f
    sta $d011

    ; enable raster irq
    lda $d01a
    ora #$01
    sta $d01a
    rts

spinner_spin:
    inc .spinner_frames
    lda #$08
    bit .spinner_frames
    beq +

    lda .spinner_index
    and #$03
    tax
    lda .spinner_sequence,x
    ldy #$00
    sta (current_pos),y

    inc .spinner_index

    lda #$00
    sta .spinner_frames

+   lda #$ff
    sta $d019
    jmp $ea81

spinner_start:
    jsr .spinner_install

    ; get current screen memory position
    sec
    jsr $fff0
    lda $00
    tya
    clc
    adc current_line
    sta current_pos
    lda #$00
    adc current_line+1
    sta current_pos+1

    inc wic64_dont_disable_irqs
    cli
    rts

spinner_stop:
    lda #$20
    ldy #$00
    sta (current_pos),y

    dec wic64_dont_disable_irqs

    sei

    ; restore previous irq vector
    lda .previous_irq
    sta $0314
    lda .previous_irq+1
    sta $0315

    ; disable raster irq
    lda $d01a
    and #!$01
    sta $d01a

    cli
    rts

.spinner_index: !byte $00
.spinner_sequence: !byte $7b, $7e, $7c ,$6c
.spinner_frames: !word $0000
.previous_irq
}

ascii2petscii:
!for i, 0, 255 { !byte i }

* = ascii2petscii+65, overlay
!for i, 1, 26 {!byte *-ascii2petscii + 128}

* = ascii2petscii+97, overlay
!for i, 1, 26 {!byte *-ascii2petscii - 32}

; ---------------------------------------------------------------------------

;         PA               PB
key_none  !byte %00000000, %11111111
key_one   !byte %01111111, %00000001
key_two   !byte %01111111, %00001000
key_three !byte %11111101, %00000001
key_four  !byte %11111101, %00001000
key_f5    !byte %11111110, %01000000
key_esc   !byte %01111111, %00000010
key_stop  !byte %01111111, %10000000
key_yes   !byte %11110111, %00000010
key_no    !byte %11101111, %10000000

}