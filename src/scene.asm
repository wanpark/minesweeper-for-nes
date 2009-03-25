cursorX:        .equ    $26     ; カーソルの盤上のX位置
cursorY:        .equ    $27     ; カーソルの盤上のY位置

pressState      .equ    $28
NONE_PRESS_STATE:       .equ    0
ONE_PRESS_STATE:        .equ    1
NINE_PRESS_STATE:       .equ    2

keyResponseIntervalCount: .equ    $29 ; キーが押され続けているフレーム数をカウント
FIRST_KEY_RESPONSE_INTERVAL:  .equ    $10 ; 1度目のカーソルキー押され続けに反応するフレーム間隔
KEY_RESPONSE_INTERVAL:        .equ    $06 ; 2度目以降

BeginTitle:
        jsr     ScreenOff
        jsr     ClearData
        jsr     ClearScreen

        ;; 爆弾描く
        lda     #$22
        sta     <$00
        lda     #$2a
        sta     <$01
        jsr     SetVRAMAddress
        lda     #$08
        sta     $2007
        lda     #$09
        sta     $2007
        lda     #$20
        jsr     Add16
        jsr     SetVRAMAddress
        lda     #$18
        sta     $2007
        lda     #$19
        sta     $2007

        lda     #$23
        sta     $2006
        lda     #$e2
        sta     $2006
        lda     #%11111111
        sta     $2007

        jsr     SetScroll
        jsr     ScreenOn

        lda     #TITLE_SCENE
        sta     scene
        rts

Title:
        lda     keydata
        eor     lastKeydata
        and     lastKeydata
        beq     .return
        ;; 任意のキーが離されたら
        jsr     BeginMain
.return
        rts


BeginGameOver:
        lda     #GAME_OVER_SCENE
        sta     scene
        rts

GameOver:
        jsr     RenderCells
        jsr     SetScroll

        lda     keydata
        eor     lastKeydata
        and     lastKeydata
        and     #KEY_START
        beq     .return
        ;; start が離されたら
        jsr     BeginTitle
        jsr     BeginMain
.return
        rts


BeginMain:
        jsr     ScreenOff

        jsr     CreateBoard
        jsr     SetBoardNameTable
        jsr     RenderBoard
        jsr     SetScroll

        lda     #1
        sta     cursorX
        lda     #1
        sta     cursorY
        jsr     SetCursor

        jsr     ScreenOn

        lda     #MAIN_SCENE
        sta     scene
        rts


Main:
        jsr     RenderCells
        jsr     SpriteDMA
        jsr     SetScroll

        lda     bombed
        bne     .bombed

        jsr     HandleKeyEvent
        rts

.bombed
        cmp     #1
        bne     .return
        jsr     SetBoardNameTable
        jsr     SetBoardAttributeTable
        lda     #0
        sta     renderLine
        jsr     BeginGameOver

.return

        rts

;;; ここから長々とmainのキーイベントハンドラ
HandleKeyEvent:
        lda     keydata
        eor     lastKeydata
        and     keydata         ; a = 今押されたキー
        beq     .checkKeyPress
        jsr     KeyDown
        jmp     .checkKeyUp

.checkKeyPress
        lda     keydata
        and     #KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
        bne     .press            ; カーソルのみ押され続けに反応
        lda     #0
        sta     keyResponseIntervalCount
        jmp     .checkKeyUp

.press
        inc     keyResponseIntervalCount
        lda     keyResponseIntervalCount
        bmi     .secondPress ; keyResponseIntervalCount の最上位 bit on の時は
                             ; 既に1度以上pressに反応している
.firstPress
        cmp     #FIRST_KEY_RESPONSE_INTERVAL
        bcc     .return
        lda     #%10000000
        sta     keyResponseIntervalCount
        lda     keydata
        and     #KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
        jsr     KeyPress
        jmp     .return

.secondPress
        and     #%01111111
        cmp     #KEY_RESPONSE_INTERVAL
        bne     .return
        lda     #%10000000
        sta     keyResponseIntervalCount
        lda     keydata
        and     #KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT
        jsr     KeyPress
        jmp     .return

.checkKeyUp
        lda     keydata
        eor     lastKeydata
        and     lastKeydata     ; a = 今離されたキー
        beq     .return
        jsr     KeyUp

.return
        rts


KeyUp:
        sta     <$00
        and     #KEY_START
        bne     .upStart
        lda     <$00
        and     #KEY_A
        bne     .upAorB
        lda     <$00
        and     #KEY_B
        bne     .upAorB
        rts
.upStart
        jsr     BeginTitle
        jsr     BeginMain
        rts
.upAorB
        lda     pressState
        cmp     #ONE_PRESS_STATE
        beq     Control_OpenCell
        cmp     #NINE_PRESS_STATE
        beq     Control_OpenCells
        rts


KeyDown:
        pha
.checkA
        and     #KEY_A
        beq     .checkB
        lda     keydata
        and     #KEY_B
        bne     .downBA
        jsr     Control_PressCell
        jmp     .checkB
.downBA
        jsr     Control_PressCells
.checkB
        pla
        pha
        and     #KEY_B
        beq     .checkCursor
        lda     keydata
        and     #KEY_A
        bne     .downAB
        jsr     Control_MarkCell
        jmp     .checkCursor
.downAB
        jsr     Control_PressCells
.checkCursor
        pla
        jsr     KeyPress

        rts

Control_OpenCell:
        lda     #NONE_PRESS_STATE
        sta     pressState
        jsr     CellAtCursor
        jsr     OpenCell
        rts
Control_OpenCells:
        lda     #NONE_PRESS_STATE
        sta     pressState
        jsr     CellAtCursor
        jsr     ClearPressedCells
        jsr     OpenCells
        rts
Control_PressCell:
        lda     #ONE_PRESS_STATE
        sta     pressState
        jsr     CellAtCursor
        jsr     PressCell
        rts
Control_PressCells:
        lda     #NINE_PRESS_STATE
        sta     pressState
        jsr     CellAtCursor
        jsr     PressCells
        rts
Control_ClearPressedCells:
        lda     #NONE_PRESS_STATE
        sta     pressState
        jsr     CellAtCursor
        jsr     ClearPressedCells
        rts
Control_MarkCell:
        jsr     CellAtCursor
        jsr     MarkCell
        rts


KeyPress:
.lastCursorX    .equ    $10
.lastCursorY    .equ    $11
.moved  .equ    $12

        ldx     #0
        stx     .moved
        ldx     cursorX
        stx     .lastCursorX
        ldx     cursorY
        stx     .lastCursorY

        pha
.checkUp
        and     #KEY_UP
        beq     .checkDown
        jsr     .Up
.checkDown
        pla
        pha
        and     #KEY_DOWN
        beq     .checkLeft
        jsr     .Down
.checkLeft
        pla
        pha
        and     #KEY_LEFT
        beq     .checkRight
        jsr     .Left
.checkRight
        pla
        and     #KEY_RIGHT
        beq     .checkMoved
        jsr     .Right

.checkMoved
        lda     .moved
        beq     .return

        lda     pressState
        cmp     #NONE_PRESS_STATE
        beq     .cursor

        jsr     CellAtPosition
        jsr     ClearPressedCells

        lda     pressState
        cmp     #ONE_PRESS_STATE
        beq     .onePressed
.ninePressed
        jsr     Control_PressCells
        jmp     .cursor
.onePressed
        jsr     Control_PressCell

.cursor
        jsr     SetCursor

.return
        rts

.Up
        ldx     cursorY
        dex
        beq     .return
        stx     cursorY
        jmp     .move

.Down
        ldx     cursorY
        inx
        cpx     #HEIGHT-1
        bcs     .return
        stx     cursorY
        jmp     .move

.Left
        ldx     cursorX
        dex
        beq     .return
        stx     cursorX
        jmp     .move

.Right
        ldx     cursorX
        inx
        cpx     #WIDTH-1
        bcs     .return
        stx     cursorX
        jmp     .move

.move
        lda     #1
        sta     .moved
        rts

;;; cursorX, cursorY にあわせてカーソルを表示する
SetCursor:
        lda     cursorX
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     #$1f
        sta     <$00            ; <$00 = X座標

        lda     cursorY
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     #$1e
        sta     <$01            ; <$01 = Y座標

        lda     #$02
        sta     <$02            ; <$02 = タイルインデックス


        ;; 左上
        ldx     #0
        jsr     SetSprite

        ;; 右上
        inx
        lda     <$00
        clc
        adc     #$0a
        sta     <$00
        inc     <$02
        jsr     SetSprite

        ;; 左下
        inx
        lda     <$00
        sec
        sbc     #$0a
        sta     <$00
        lda     <$01
        clc
        adc     #$0a
        sta     <$01
        lda     <$02
        clc
        adc     #$0f
        sta     <$02
        jsr     SetSprite

        ;; 右下
        inx
        lda     <$00
        clc
        adc     #$0a
        sta     <$00
        inc     <$02
        jsr     SetSprite

        rts
