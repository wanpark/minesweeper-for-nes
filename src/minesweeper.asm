        .inesprg 1
        .ineschr 1
        .inesmir 0              ; 水平ミラーリング
        .inesmap 0

        .bank   0
        .org    $8000

scene:           .equ   $30
TITLE_SCENE:     .equ   0
MAIN_SCENE:      .equ   1
GAME_OVER_SCENE: .equ   2

nmiMutex:        .equ   $31     ; nmi が重複して呼ばれないようにフラグ

        .include        "math.asm"
        .include        "graphic.asm"
        .include        "key.asm"
        .include        "board.asm"
        .include        "scene.asm"

Start:
        ;; 初期化中は割り込み禁止
        sei                     ; IRQ
        lda     #%00001000      ; NMI
        sta     $2000
        
        cld                     ; デシマルモードクリア
        ldx     #$ff            ; スタック初期化
        txs

        jsr     Vwait           ; VBlank待ち

        jsr     InitScreen

        jsr     BeginTitle

        lda     #%10001000      ; NMI割り込み許可
        sta     $2000
.loop
        jmp     .loop


;;; VBlank のタイミングで呼ばれる
Nmi:
        pha
        txa
        pha
        tya
        pha

        lda     nmiMutex
        bne     .skip
        inc     nmiMutex

        jsr     ReadKey

        ;; シーン実行
        lda     scene
        cmp     #MAIN_SCENE
        beq     .main
        cmp     #GAME_OVER_SCENE
        beq     .gameOver
.title
        jsr     Title
        jmp     .end
.main
        jsr     Main
        jmp     .end
.gameOver
        jsr     GameOver
        jmp     .end

.end
        jsr     NextRandom
        lda     #0
        sta     nmiMutex

.skip
        pla
        tay
        pla
        tax
        pla
        rti


Irq:
        rti

;;; VBlank 待ち
Vwait:
.wait:
        lda     $2002
        bpl     .wait
        rts

ClearData:
        ;; ランダムseed 以外初期化
        lda     random
        pha
        lda     random+1
        pha
        jsr     ZeroFillAll
        pla
        sta     random+1
        pla
        sta     random
        rts

;;; 0000 - 00ff, 0200 - 07ff をゼロで埋める
ZeroFillAll:
        lda     #$00
        jsr     ZeroFill
        ldx     #$02
.fill
        txa
        jsr     ZeroFill
        inx
        cpx     #$08
        bne     .fill
        rts

;;; a 00 - a ff をゼロで埋める
ZeroFill:
        sta     <$01
        lda     #0
        sta     <$00
        ldy     #0
.fill
        sta     [$00], y
        iny
        cpy     #$ff
        bne     .fill
        rts


        .bank   1
        .org $fffa
        .dw Nmi, Start, Irq


        .bank 2
        .incbin "mine.chr"