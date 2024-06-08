;--------------------------------------------------------------------------
;  bcd.s
;
;  Copyright (C) 2024, Michel Iwaniec
;
;  This library is free software; you can redistribute it and/or modify it
;  under the terms of the GNU General Public License as published by the
;  Free Software Foundation; either version 2, or (at your option) any
;  later version.
;
;  This library is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License 
;  along with this library; see the file COPYING. If not, write to the
;  Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
;   MA 02110-1301, USA.
;
;  As a special exception, if you link this library with other files,
;  to produce an executable, this library does not by itself cause the 
;  resulting executable to be covered by the GNU General Public License.
;  This exception does not however invalidate any other reasons why the
;  executable file might be covered by the GNU General Public License.
;--------------------------------------------------------------------------

.module bcd

.area OSEG (PAG, OVR)
_bcd2text_bcd:
_bcd2text_tile_offset:
_bcd2text_PARM_2::      .ds 1
_bcd2text_buffer:
_bcd2text_PARM_3::      .ds 2
_bcd2text_BCD:          .ds 4
_bcd_sub_PARM_2::
_uint2bcd_PARM_2::
_bcd_add_PARM_2::       .ds 4

.area   _HOME

; void uint2bcd(uint16_t i, BCD * value) __naked
_uint2bcd::
    .define tmp     "REGTEMP+2"
    .define losub   "REGTEMP+4"
    .define hisub   "REGTEMP+5"
    .define v       "REGTEMP+6"
    ;.define value   "_uint2bcd_PARM_2"

    sta *tmp
    stx *tmp+1
    ; First two digits are always for uint16 -> BCD conversion
    ldy #3
    lda #0
    sta [*_uint2bcd_PARM_2],y
    dey
    lda #0xFF
    sta *v
    tax
    jmp 4$
1$:
    inc *v
    lda *tmp
    sec
    sbc *losub
    sta *tmp
    lda *tmp+1
    sbc *hisub
    sta *tmp+1
    bcs 1$
    ; Undo last sub. This should be faster on average
    lda *tmp
    adc *losub
    sta *tmp
    lda *tmp+1
    adc *hisub
    sta *tmp+1
    ; Check odd/even x to determine if upper/lower nibble completed.
    txa
    lsr
    lda *v
    bcc 3$
    ; Upper digit completed. Shift value to upper nibble.
    asl
    asl
    asl
    asl
    adc #0xFF
    sta *v
    jmp 4$
3$:
    ; Lower digit completed. Write value, move index and re-initialize v.
    sta [*_uint2bcd_PARM_2],y
    lda #0xFF
    sta *v
    dey
    beq 5$
4$:
    inx
    lda losub_tab,x
    sta *losub
    lda hisub_tab,x
    sta *hisub
    jmp 1$
5$:
    ; Switch to single-byte mode for second-last digit
    ldx #0xFF
    lda *tmp
6$:
    inx
    sec
    sbc #10
    bcs 6$
    ; Undo last sub
    adc #10
    ; Combine last digit with second-last
    and #0x0F
    sta *tmp
    txa
    asl
    asl
    asl
    asl
    ora *tmp
    ; Write combined result
    sta [*_uint2bcd_PARM_2],y
    rts

losub_tab:
.db <10000
.db <1000
.db <100

hisub_tab:
.db >10000
.db >1000
.db >100

;void bcd_add(BCD * sour, BCD * value) __naked
_bcd_add::
    .define sour    "REGTEMP"
    .define value   "_bcd_add_PARM_2"
    ;.define tmp     "REGTEMP+2"
    .define .c      "REGTEMP+3"
    .define .n      "REGTEMP+4"
    sta *sour
    stx *sour+1
    ldy #0
    lda #4
    sta *.n
    clc
1$:
    lda [*sour],y
    adc [*value],y
    ror *.c
    tax
    eor [*sour],y
    eor [*value],y
    and #0x10
    ; Add 0x06 if half-carry was set
    bne 2$
    ; ...or if low nibble result >= 0xA
    txa
    and #0x0F
    cmp #0x0A
    txa
    bcc 3$
2$:
    txa
    clc
    adc #0x06
3$:
    ; Add 0x60 if carry was set
    bit *.c
    bmi 4$
    ; ...or if high nibble result >= 0xA
    cmp #0xA0
    bcc 5$
4$:
    clc
    adc #0x60
    sec
5$:
    sta [*sour],y
    iny
    dec *.n
    bne 1$
    rts

; void bcd_sub(BCD * sour, BCD * value) __naked
_bcd_sub::
    .define sour    "REGTEMP"
    .define value   "_bcd_add_PARM_2"
    .define tmp     "REGTEMP+2"
    .define .c      "REGTEMP+3"
    .define .n      "REGTEMP+4"
    sta *sour
    stx *sour+1
    ldy #0
    lda #4
    sta *.n
    sec
1$:
    lda [*sour],y
    sbc [*value],y
    ror *.c
    tax
    eor [*sour],y
    eor [*value],y
    and #0x10
    ; Add 0x06 if half-carry was set
    bne 2$
    ; ...or if low nibble result >= 0xA
    txa
    and #0x0F
    cmp #0x0A
    txa
    bcc 3$
2$:
    txa
    clc
    adc #0x06
3$:
    ; Add 0x60 if carry was *clear*
    bit *.c
    bpl 4$
    ; ...or if high nibble result >= 0xA
    cmp #0xA0
    bcc 5$
4$:
    clc
    adc #0x60
    clc
    bcc 6$
5$:
    sec
6$:
    sta [*sour],y
    iny
    dec *.n
    bne 1$
    rts

;uint8_t bcd2text(BCD * bcd, uint8_t tile_offset, uint8_t * buffer) __naked
_bcd2text::
    sta *REGTEMP
    stx *REGTEMP+1
    
    ldy #3
0$:
    lda [*REGTEMP],y
    sta *_bcd2text_BCD,y
    dey
    bpl 0$
    
    ldy #0
    ldx #3
1$:
    lda *_bcd2text_BCD,x
    pha
    lsr
    lsr
    lsr
    lsr
    clc
    adc *_bcd2text_tile_offset
    sta [*_bcd2text_buffer],y
    iny
    pla
    and #0x0F
    clc
    adc *_bcd2text_tile_offset
    sta [*_bcd2text_buffer],y
    iny
    dex
    bpl 1$
    ; Store 0 at end
    lda #0
    sta [*_bcd2text_buffer],y
    ; Return length of string as 8
    lda #8
    rts
