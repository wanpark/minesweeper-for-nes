WIDTH:  .equ    11
HEIGHT: .equ    11
SIZE:   .equ    121

NUM_MINE:       .equ    10

BOARD_NAME_L:   .equ    $00
BOARD_NAME_H:   .equ    $21

BORAD_ATTR_L:   .equ    $d0
BORAD_ATTR_H:   .equ    $23

NUMBER_MASK: .equ       %00000111
MINE_MASK:   .equ       %00001000
OPEN_MASK:   .equ       %00010000
MARK_MASK:   .equ       %00100000
PRESS_MASK:  .equ       %01000000
FRAME_MASK:  .equ       %10000000


bombed: .equ    $25

cells:  .equ    $40

nameTableBuffer:        .equ    $0300   ; $10 * $0f (cellと同じ 2x2 chr)
attributeTableBuffer:   .equ    $0400   ; $08 * $08 (4x4 chr)
renderLine:             .equ    $0440


;;; board 作成
CreateBoard:
        jsr     .CreateFrame
        jsr     .CreateMines
        rts

;;; frame 作成
.CreateFrame
        ldy     #0

        ;; 左上隅
        lda     #FRAME_MASK
        sta     cells, y
        iny

        ;; 上
        lda     #FRAME_MASK|1
.top
        sta     cells, y
        iny
        cpy     #WIDTH-1
        bcc     .top

        ;; 右上隅
        lda     #FRAME_MASK|2
        sta     cells, y
        iny

        ;; 左
        ldx     #1              ; x = Y座標
.left
        lda     #FRAME_MASK|3
        sta     cells, y
        tya                     ; yを1行increment
        clc
        adc     #WIDTH
        tay
        inx
        txa
        cmp     #HEIGHT-1
        bcc     .left

        ;; 左下隅
        lda     #FRAME_MASK|4
        sta     cells, y
        iny

        ;; 下
        lda     #FRAME_MASK|6
.bottom
        sta     cells, y
        iny
        cpy     #SIZE-1
        bcc     .bottom

        ;; 右下隅
        lda     #FRAME_MASK|7
        sta     cells, y

        ;; 右
.right
        tya
        sec
        sbc     #WIDTH          ; y -= #WIDTH
        cmp     #WIDTH+1
        bcc     .endCreateFrame ; return if y <= #WIDTH
        tay
        lda     #FRAME_MASK|5
        sta     cells, y
        jmp     .right

.endCreateFrame
        rts

;;; mine 作成
.CreateMines
        ldx     #NUM_MINE
.add
        lda     #SIZE
        sta     <$00
        jsr     NextRandom
        jsr     Modulus

        tay

        lda     cells, y
        and     #FRAME_MASK
        bne     .add            ; frameならやりなおし

        lda     cells, y
        and     #MINE_MASK
        bne     .add            ; 既にmineならやりなおし

        jsr     .AddMine

        dex
        bne     .add
        
        rts

;;; mine を埋めて、周囲の cell の数字をインクリメント
;;; IN  y: 対象 cell の offset
.AddMine
        ;; 元の x, y を退避
        txa
        pha
        tya
        pha

        ;; 周囲の cell の数字をインクリメント
        sec
        sbc     #WIDTH
        jsr     .IncrementCellValueInRow ; 上の行
        clc
        adc     #WIDTH
        jsr     .IncrementCellValueInRow ; 真ん中の行
        clc
        adc     #WIDTH
        jsr     .IncrementCellValueInRow ; 下の行

        ;; 元の x, y を復帰
        pla
        tay
        pla
        tax

        ;; mine cell の値セット
        lda     #MINE_MASK
        sta     cells, y

        rts     

;;; 指定cellとその両隣,計3cellsの値をincrement
;;; IN  a: 対象cellのoffset
;;; USE y
.IncrementCellValueInRow
        tay
        dey
        jsr     .Increment
        iny
        jsr     .Increment
        iny
        jsr     .Increment
        dey
        tya                     ; a を元に戻す
        rts

;;; 指定cellがmineかframeでなければ値increment
;;; IN  y: 対象cellのoffset
.Increment
        lda     cells, y
        and     #MINE_MASK
        bne     .endIncrement   ; mine チェック
        lda     cells, y
        and     #FRAME_MASK
        bne     .endIncrement   ; frame チェック
        ;; increment
        lda     cells, y
        clc
        adc     #1
        sta     cells, y
.endIncrement
        rts

SetBoardNameTable:
.x      .equ    $00

        ldx     #0              ; x = nameTableBuffer offset
        ldy     #0              ; y = cell offset

.row
        txa
        pha                     ; 行頭の nameTableBuffer offset 退避

        lda     #WIDTH
        sta     .x              ; .x = #WIDTH - cellのX座標

.cell
        jsr     CellTileIndex
        sta     nameTableBuffer, x

        inx
        iny
        dec     .x
        bne     .cell

        pla                     ; 行頭の nameTableBuffer offset 復帰
        clc
        adc     #$10
        tax

        cpy     #SIZE
        bne     .row

        rts


;;; 指定cellのBG画像インデックス
;;; IN  y: 対象cellのoffset
;;; OUT a: 対象cellのCHRの左上
;;; (右上: a + #$01, 左下: a + #$10, 右下: a + #$11)
CellTileIndex:
        lda     cells, y
        and     #FRAME_MASK
        bne     .frame
        lda     cells, y
        and     #OPEN_MASK
        beq     .closed
        lda     cells, y
        and     #MINE_MASK
        bne     .mine
.number
        lda     cells, y
        and     #NUMBER_MASK
        asl     a
        clc
        adc     #$20
        rts
.frame
        lda     cells, y
        and     #%00000111
        asl     a
        clc
        adc     #$40
        rts
.closed
        lda     bombed
        bne     .bombed
        lda     cells, y
        and     #MARK_MASK
        bne     .marked
        lda     cells, y
        and     #PRESS_MASK
        bne     .pressed
        lda     #$2c
        rts
.marked
        lda     #$2e
        rts
.pressed
        lda     #$20
        rts
.bombed                 ; 爆発後の closed cell
        lda     cells, y
        and     #MARK_MASK
        bne     .bombedMark
        lda     cells, y
        and     #MINE_MASK
        bne     .bombedMine
        lda     #$2c
        rts
.bombedMark
        lda     cells, y
        and     #MINE_MASK
        beq     .failureMark
        lda     #$2e
        rts
.failureMark
        lda     #$0c
        rts
.bombedMine
        lda     #$0e            ; 爆発後の closed mine
        rts
.mine
        lda     #$0a            ; 爆発した mine
        rts


SetBoardAttributeTable:
        ldx     #0              ; x = 属性テーブルの offset
        ldy     #0              ; y = cell offset

        lda     #0
        sta     <$01            ; <$01 = cellのY座標
        stx     <$03            ; <$03 = 行頭の属性テーブルの offset
.row
        lda     #0
        sta     <$00            ; <$00 = cellのX座標
.square
.topLeftCell
        jsr     CellPalette
        lsr     a
        lsr     a
        sta     <$02            ; <$02 = 属性値
.topRightCell
        iny
        jsr     CellPalette
        ora     <$02
        lsr     a
        lsr     a
        sta     <$02
.bottomLeftCell
        dey
        tya
        clc
        adc     #WIDTH
        tay
        jsr     CellPalette
        ora     <$02
        lsr     a
        lsr     a
        sta     <$02
.bottomRightCell
        iny
        jsr     CellPalette
        ora     <$02
        sta     <$02

        ;; 属性テーブルバッファに書き込み
        lda     <$02
        sta     attributeTableBuffer, x
        inx

        lda     <$00
        clc
        adc     #2
        cmp     #WIDTH
        bcs     .nextRow
.nextSquare:
        sta     <$00
        tya
        sec
        sbc     #WIDTH-1
        tay
        jmp     .square

.nextRow:
        lda     <$01
        clc
        adc     #2
        cmp     #HEIGHT
        bcs     .return

        sta     <$01
        lda     #0
        sta     <$00
        lda     <$03
        clc
        adc     #$08
        sta     <$03
        tax
        jmp     .square
        
        
.return:
        rts

;;; 指定cellのパレットインデックス
;;; IN  y: 対象cellのoffset
;;; OUT a: 対象cellのパレット (上位2bit)
CellPalette:
        lda     cells, y
        and     #FRAME_MASK
        bne     .frame
        lda     cells, y
        and     #OPEN_MASK
        beq     .closed
        lda     cells, y
        and     #MINE_MASK
        bne     .mine
.number
        ;; 0 -> 00
        ;; 1 -> 01
        ;; 2 -> 01
        ;; 3 -> 02
        ;; 4 -> 02
        lda     cells, y
        clc
        adc     #1
        lsr     a
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        rts      
.frame
        lda     #%00000000
        rts
.closed
        lda     bombed
        bne     .bombed
        lda     #%00000000
        rts
.bombed                 ; 爆発後の closed cell
        lda     cells, y
        and     #MARK_MASK
        bne     .bombedMark
        lda     cells, y
        and     #MINE_MASK
        bne     .bombedMine
        lda     #%00000000
        rts
.bombedMark
        lda     cells, y
        and     #MINE_MASK
        beq     .failureMark
        lda     #%00000000
        rts
.failureMark
        lda     #%11000000
        rts
.bombedMine
        lda     #%11000000   ; 爆発後の closed mine
        rts
.mine
        lda     #%11000000
        rts

OpenCell:
.x      .equ    $10
.y      .equ    $11

        lda     cells, y
        and     #OPEN_MASK
        bne     .return

        lda     cells, y
        and     #FRAME_MASK
        bne     .return

        lda     cells, y
        and     #MARK_MASK
        bne     .return

        ;; open flag 付与
        lda     cells, y
        ora     #OPEN_MASK
        sta     cells, y

        ;; 描画
        jsr     UpdateCell

        lda     cells, y
        and     #MINE_MASK
        bne     .bomb

        lda     cells, y
        and     #NUMBER_MASK
        bne     .return

        ;; 数字0の時は周囲のマスもopen
        lda     #low(.openCell)
        sta     <$05
        lda     #high(.openCell)
        sta     <$06
        jsr     TraverseAroundCell

.return
        rts

.bomb
        ;; mine踏んだ
        lda     #1
        sta     bombed
        rts

.openCell:
        jsr     OpenCell
        jmp     returnTraverseAroundCell


TraverseAroundCell:
.x      .equ    $10
.y      .equ    $11
.address_l:     .equ    $05
.address_h:     .equ    $06

        tya
        pha

        jsr     .TraverseInRow

        tya
        sec
        sbc     #WIDTH
        tay
        dec     .y
        jsr     .TraverseInRow

        tya
        clc
        adc     #WIDTH+WIDTH
        tay
        inc     .y
        inc     .y
        jsr     .TraverseInRow
        dec     .y

        pla
        tay
        rts

.TraverseInRow:
        dey
        dec     .x
        lda     #high(.left)
        pha
        lda     #low(.left)
        pha
        jmp     [.address_l]
.left
        iny
        inc     .x
        lda     #high(.center)
        pha
        lda     #low(.center)
        pha
        jmp     [.address_l]
.center
        iny
        inc     .x
        lda     #high(.right)
        pha
        lda     #low(.right)
        pha
        jmp     [.address_l]
.right
        dey
        dec     .x
        rts

returnTraverseAroundCell:
        pla
        sta     <$00
        pla
        sta     <$01
        jmp     [$00]

MarkCell:
        lda     cells, y
        eor     #MARK_MASK
        sta     cells, y
        jsr     UpdateCell
        rts


OpenCells:
.numMark .equ   $02
        ;; return unless (open && !mine && number != 0)
        lda     cells, y
        and     #OPEN_MASK
        beq     .return
        lda     cells, y
        and     #MINE_MASK
        bne     .return
        lda     cells, y
        and     #NUMBER_MASK
        beq     .return

        ;; 旗を数える
        lda     #0
        sta     .numMark
        lda     #low(.countMark)
        sta     <$05
        lda     #high(.countMark)
        sta     <$06
        jsr     TraverseAroundCell

        lda     cells, y
        and     #NUMBER_MASK
        cmp     .numMark
        bne     .return

        ;; open
        lda     #low(.open)
        sta     <$05
        lda     #high(.open)
        sta     <$06
        jsr     TraverseAroundCell
.return
        rts

.countMark
        lda     cells, y
        and     #OPEN_MASK
        bne     returnTraverseAroundCell
        lda     cells, y
        and     #MARK_MASK
        beq     returnTraverseAroundCell
        inc     .numMark
        jmp     returnTraverseAroundCell

.open
        jsr     OpenCell
        jmp     returnTraverseAroundCell


PressCell:
        lda     cells, y
        ora     #PRESS_MASK
        sta     cells, y
        jsr     UpdateCell
        rts


PressCells:
        lda     #low(.pressCell)
        sta     <$05
        lda     #high(.pressCell)
        sta     <$06
        jsr     TraverseAroundCell
        rts

.pressCell
        jsr     PressCell
        jmp     returnTraverseAroundCell


ClearPressedCells:
        lda     #low(.clearPressCell)
        sta     <$05
        lda     #high(.clearPressCell)
        sta     <$06
        jsr     TraverseAroundCell
        rts

.clearPressCell
        jsr     ClearPressedCell
        jmp     returnTraverseAroundCell

ClearPressedCell:
.x      .equ    $10
.y      .equ    $11
        lda     cells, y
        and     #PRESS_MASK
        beq     .return
        eor     #%11111111
        and     cells, y
        sta     cells, y
        jsr     UpdateCell
.return
        rts

CellAtCursor:
.x      .equ    $10
.y      .equ    $11
        lda     cursorX
        sta     .x
        lda     cursorY
        sta     .y
        jsr     CellAtPosition

CellAtPosition:
.x      .equ    $10
.y      .equ    $11
        lda     .x
        ldx     .y
.down
        clc
        adc     #WIDTH
        dex
        bne     .down
        tay
        rts


UpdateCell:
.x      .equ    $10
.y      .equ    $11

        jsr     UpdateCellNameTable
        jsr     UpdateCellAttributeTable

        lda     $11
        lsr     a
        cmp     renderLine
        bcs     .return
        sta     renderLine
.return
        rts

UpdateCellNameTable:
.x      .equ    $10
.y      .equ    $11

        lda     .y
        asl     a
        asl     a
        asl     a
        asl     a
        clc
        adc     .x
        tax                     ; x = .y * $10 + .x
        ldx     .y

        tax
        jsr     CellTileIndex
        sta     nameTableBuffer, x

        rts

UpdateCellAttributeTable:
.x      .equ    $10
.y      .equ    $11

        ;; 属性テーブル先頭からのoffset計算
        ;; (int)(y / 2) * 8 + (int)(x / 2)
        lda     .y
        lsr     a
        asl     a
        asl     a
        asl     a
        sta     <$00
        lda     .x
        lsr     a
        clc
        adc     <$00
        tax                     ; x = 属性テーブル先頭からのoffset

        jsr     CellPalette
        sta     <$00            ; <$00 = パレットインデックス
        lda     #%11000000
        sta     <$01            ; <$01 = パレットマスク

        lda     <.y
        and     #1
        bne     .checkX
.shiftY
        lsr     <$00
        lsr     <$00
        lsr     <$00
        lsr     <$00
        lsr     <$01
        lsr     <$01
        lsr     <$01
        lsr     <$01
.checkX
        lda     .x
        and     #1
        bne     .set
.shiftX
        lsr     <$00
        lsr     <$00
        lsr     <$01
        lsr     <$01
.set
        lda     <$01
        eor     #%11111111
        sta     <$01            ; パレットマスク反転

        lda     attributeTableBuffer, x
        and     <$01            ; cellの位置のbitをクリア
        ora     <$00
        sta     attributeTableBuffer, x

        rts

RenderBoard:
        lda     #$00
        sta     renderLine
.line
        jsr     RenderCells
        lda     renderLine
        cmp     #(HEIGHT-1)/2+1
        bcc     .line
        rts

RenderCells:
        lda     needsUpdateSprite
        bne     .return         ; spriteを転送するフレームはパス

        lda     renderLine
        cmp     #(HEIGHT-1)/2+1
        bcs     .return

        ;; 属性テーブル
        asl     a
        asl     a
        asl     a
        tax                     ; x = attribute table の offset

        ldy     #0
        lda     #BORAD_ATTR_H
        sta     $2006
        txa
        clc
        adc     #BORAD_ATTR_L
        sta     $2006
.attribute
        lda     attributeTableBuffer, x
        sta     $2007
        inx
        iny
        cpy     #$08
        bcc     .attribute

        ;; ネームテーブル
        lda     renderLine
        asl     a
        asl     a
        asl     a
        asl     a
        asl     a
        tax                     ; x = nameTableBuffer の offset

        sta     <$01
        lda     #0
        sta     <$00
        jsr     Asl16
        jsr     Asl16           ; $00 $01 = name table の offset

        lda     <$01
        clc
        adc     #BOARD_NAME_L
        sta     <$01
        lda     <$00
        adc     #BOARD_NAME_H
        sta     <$00            ; $00 $01 = name table の address

        jsr     .RenderCellsInLine
        cpx     #$10*HEIGHT
        bcs     .finish
        jsr     .RenderCellsInLine

.finish
        inc     renderLine

.return
        rts


.RenderCellsInLine
        txa
        pha                     ; push 行頭の nameTableBuffer offset

        ;; 上部描画
        jsr     SetVRAMAddress
        lda     #$20
        jsr     Add16

        ldy     #0
.top
        lda     nameTableBuffer, x
        sta     $2007
        clc
        adc     #1
        sta     $2007

        inx
        iny
        cpy     #WIDTH
        bcc     .top

        pla                     ; pop 行頭の nameTableBuffer offset
        pha
        tax

        ;; 下部描画
        jsr     SetVRAMAddress
        lda     #$20
        jsr     Add16

        ldy     #0
.bottom
        lda     nameTableBuffer, x
        clc
        adc     #$10
        sta     $2007
        clc
        adc     #1
        sta     $2007

        inx
        iny
        cpy     #WIDTH
        bcc     .bottom

        pla
        clc
        adc     #$10
        tax

        rts
