needsUpdateSprite .equ  $22
SPRITE_DMA_PAGE .equ    $02     ; スプライト DMA に使用するページ
SPRITE_Y        .equ    $0200   ; y座標
SPRITE_TILE     .equ    $0201   ; タイルインデックス
SPRITE_STATUS   .equ    $0202   ; ステータス (パレットと属性)
SPRITE_X        .equ    $0203   ; x座標


;;; sprite情報ををDMA領域にセット
;;; IN  x: sprite番号
;;;     <$00: X座標
;;;     <$01: Y座標
;;;     <$02: タイルインデックス
;;; USE a
SetSprite:
        txa
        pha                     ; x 退避

        asl     a               ; 4バイトずつ
        asl     a
        tax

        lda     <$00
        sta     SPRITE_X, x

        lda     <$01
        sta     SPRITE_Y, x

        lda     <$02
        sta     SPRITE_TILE, x

        pla                     ; x 復帰
        tax

        lda     #1
        sta     needsUpdateSprite

        rts

SpriteDMA:
        lda     needsUpdateSprite
        beq     .return
        lda     #SPRITE_DMA_PAGE
        sta     $4014
        lda     #0
        sta     needsUpdateSprite
.return
        rts


SetVRAMAddress
        lda     <$00
        sta     $2006
        lda     <$01
        sta     $2006
        rts

ClearScreen:
        lda     #SPRITE_DMA_PAGE
        jsr     ZeroFill
        lda     #SPRITE_DMA_PAGE
        sta     $4014

        lda     #$20
        sta     $2006
        lda     #$00
        sta     $2006
        ldx     #4
        ldy     #0
.clear
        sta     $2007
        iny
        bne     .clear
        dex
        bne     .clear
        rts

SetScroll:
        lda     $2002
        lda     #$e0
        sta     $2005
        lda     #$20
        sta     $2005
        rts

ScreenOff:
        lda     #%00000110
        sta     $2001
        rts
ScreenOn:
        lda     #%00011110
        sta     $2001
        rts

InitScreen:
        jsr     ScreenOff
        jsr     InitPalette
        jsr     ClearScreen
        jsr     SetScroll
        jsr     ScreenOn
        rts

InitPalette:   
        ldx     #$3F            ; PPU $3F00
        stx     $2006
        ldx     #$00
        stx     $2006
.loop
        lda     PALETTE_DATA, x
        sta     $2007
        inx
        cpx     #$20
        bne     .loop
        rts

PALETTE_DATA:
        .incbin "mine.pal"

DIGITS:
DIGIT0: .byte   $03, $06, $0b, $0c, $11, $14, 0, 0
DIGIT1: .byte   $00, $05, $07, $0c, $07, $12, 0, 0
DIGIT2: .byte   $01, $06, $08, $0d, $11, $13, 0, 0
DIGIT3: .byte   $01, $06, $09, $0e, $10, $14, 0, 0
DIGIT4: .byte   $02, $05, $0a, $0e, $07, $12, 0, 0
DIGIT5: .byte   $03, $04, $0a, $0f, $10, $14, 0, 0
DIGIT6: .byte   $03, $04, $15, $0f, $11, $14, 0, 0
DIGIT7: .byte   $01, $06, $07, $0c, $07, $12, 0, 0
DIGIT8: .byte   $03, $06, $15, $0e, $11, $14, 0, 0
DIGIT9: .byte   $03, $06, $0a, $0e, $10, $14, 0, 0
