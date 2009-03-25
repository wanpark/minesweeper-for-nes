KEY_A:      .equ %10000000
KEY_B:      .equ %01000000
KEY_SELECT: .equ %00100000
KEY_START:  .equ %00010000
KEY_UP:     .equ %00001000
KEY_DOWN:   .equ %00000100
KEY_LEFT:   .equ %00000010
KEY_RIGHT:  .equ %00000001

keydata:        .equ    $23     ; 押されているキー. a/b/select/start/up/down/left/right
lastKeydata:    .equ    $24     ; 前回押されていたキー

;;; コントローラ情報を読む
ReadKey:
        lda     keydata
        sta     lastKeydata

        ;; 初期化
        lda     #$01
        sta     $4016
        lda     #$00
        sta     $4016
        sta     keydata

        ;; ボタンを1個読んではshift
        ldx     #$08
.readButton
        lda     $4016
        and     #$01
        asl     keydata
        ora     keydata
        sta     keydata
        dex
        bne     .readButton
        
        rts
