random:         .equ    $20     ; ここから2byte

;;; <$00をhigher byte, <$01をlower byte として、a を足す
Add16:
        clc
        adc     <$01
        sta     <$01
        bcc     .return
        inc     <$00
.return
        rts

Asl16:
        asl     <$00
        asl     <$01
        bcc     .return
        inc     <$00
.return
        rts

;;; a = a % <$00
Modulus:
.mod:   .equ   $00
        sec
.sub
        sbc     <.mod
        bcs     .sub
.return
        adc     <.mod
        rts
       
NextRandom:
        lda     random
        eor     #$aa
        clc
        adc     #73
        sta     random
        rts
        rts
