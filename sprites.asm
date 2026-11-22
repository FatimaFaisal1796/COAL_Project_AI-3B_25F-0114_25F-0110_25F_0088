; M4 (SPRITES AND BITMAP RENDERING)
; Sprite Flags (word passed to DrawSprite):
;   Bit 0 (1): SPRITE_FLIP_H  (1 = mirror horizontally / face left)
;   Bit 1 (2): SPRITE_TALL    (1 = 16x32 Super Mario; 0 = 16x16)
;   Bit 2 (4): SPRITE_BLINK   (1 = invulnerability blink on alternate frames)

SPRITE_FLIP_H   equ 0x0001
SPRITE_TALL     equ 0x0002
SPRITE_BLINK    equ 0x0004

; Name: DrawSprite
; Purpose: Draw a 16x16 or 16x32 sprite into the off-screen frame buffer with transparency (0), horizontal mirroring, 4-edge clipping, and blink support.
; Inputs: flags, address, y, x (words on stack, pushed right-to-left: [bp+4]=x, [bp+6]=y, [bp+8]=address, [bp+10]=flags)
; Outputs: Sprite pixels written to fb_segment
; Registers changed: None (preserved)
DrawSprite:
    push bp
    mov bp, sp
    sub sp, 6               

    pushf
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    ; Check blink flag (skip drawing on odd ticks when blinking)
    mov ax, [bp+10]
    test ax, SPRITE_BLINK
    jz .no_blink_skip
    mov bx, [tick_counter]
    test bx, 1
    jz .no_blink_skip
    jmp .done              

.no_blink_skip:
    ; Ensure ES = fb_segment
    mov ax, [fb_segment]
    cmp ax, 0
    jne .es_ok
    call InitFrameBuffer
    mov ax, [fb_segment]
.es_ok:
    mov es, ax

    ; Determine sprite height (16 or 32)
    mov word [bp-2], 16
    mov ax, [bp+10]
    test ax, SPRITE_TALL
    jz .check_bounds
    mov word [bp-2], 32

.check_bounds:
   ; Quick reject if completely off-screen horizontally
    mov ax, [bp+4]          
    cmp ax, SCREEN_WIDTH
    jl .check_left_bound
    jmp .done
.check_left_bound:
    cmp ax, -16
    jg .check_vert_bounds
    jmp .done

.check_vert_bounds:
    ; Quick reject if completely off-screen vertically
    mov ax, [bp+6]         
    cmp ax, GAME_VIEW_HEIGHT
    jl .check_top_bound
    jmp .done
.check_top_bound:
    mov bx, [bp-2]
    neg bx
    cmp ax, bx
    jg .init_row_loop
    jmp .done

.init_row_loop:
    mov word [bp-6], 0      
    mov ax, [bp+6]
    mov [bp-4], ax          

.row_loop:
    mov cx, [bp-6]
    cmp cx, [bp-2]
    jb .check_row_clip
    jmp .done

.check_row_clip:
    mov ax, [bp-4]
    cmp ax, 0
    jl .next_row
    cmp ax, GAME_VIEW_HEIGHT
    jl .draw_row
    jmp .done              

.draw_row:
 
    mov dx, ax
    mov cl, 8
    shl ax, cl
    mov cl, 6
    shl dx, cl
    add ax, dx
    mov di, ax              

    mov si, [bp+8]
    mov ax, [bp-6]
    mov cl, 4
    shl ax, cl
    add si, ax

    xor bx, bx             

.col_loop:
    cmp bx, 16
    jae .next_row

    mov dx, [bp+4]
    add dx, bx

    cmp dx, 0
    jl .next_col
    cmp dx, SCREEN_WIDTH
    jge .next_col

    push bx
    mov ax, [bp+10]
    test ax, SPRITE_FLIP_H
    jz .no_flip
    mov ax, 15
    sub ax, bx
    mov bx, ax
.no_flip:
    mov al, [si + bx]       ; Read pixel colour from bitmap
    pop bx

    ; Skip transparent colour (0)
    cmp al, TRANSPARENT_COLOR
    je .next_col

    push di
    add di, dx
    mov [es:di], al
    pop di

.next_col:
    inc bx
    jmp .col_loop

.next_row:
    inc word [bp-6]
    inc word [bp-4]
    jmp .row_loop

.done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf

    mov sp, bp
    pop bp
    ret 8

; Name: DrawMario
; Purpose: Helper called by main loop to select Mario's sprite based on form, pose, facing direction and invuln_timer
; Inputs: None (reads mario_world_x, mario_world_y, camera_x, mario_form, mario_pose, mario_facing, invuln_timer)
; Outputs: Mario sprite drawn into frame buffer
; Registers changed: None (preserved)

DrawMario:
    pushf
    push ax
    push bx
    push cx

    ; Convert world_x to screen_x
    mov ax, [mario_world_x]
    sub ax, [camera_x]      

    ; Build flags in BX
    xor bx, bx
    cmp byte [mario_facing], 0
    jne .check_blink
    or bx, SPRITE_FLIP_H

.check_blink:
    cmp word [invuln_timer], 0
    je .select_form
    or bx, SPRITE_BLINK

.select_form:
    cmp byte [mario_form], 1
    je .super_mario

    ; Small Mario (16x16)
    mov cx, spr_small_mario_stand
    cmp byte [mario_pose], 1
    jne .check_small_jump
    mov cx, spr_small_mario_run
    jmp .draw_now
.check_small_jump:
    cmp byte [mario_pose], 2
    jne .draw_now
    mov cx, spr_small_mario_jump
    jmp .draw_now

.super_mario:
    or bx, SPRITE_TALL
    mov cx, spr_super_mario_stand
    cmp byte [mario_pose], 1
    jne .check_super_jump
    mov cx, spr_super_mario_run
    jmp .draw_now
.check_super_jump:
    cmp byte [mario_pose], 2
    jne .draw_now
    mov cx, spr_super_mario_jump

.draw_now:
    push bx                 ; flags
    push cx                 ; sprite address
    push word [mario_world_y] ; y
    push ax                 ; screen_x
    call DrawSprite

    pop cx
    pop bx
    pop ax
    popf
    ret

; ORIGINAL 16x16 AND 16x32 SPRITE BITMAPS (Colour 0 = Transparent)
; Palette: 1=Blue, 2=Green, 4=Red, 6=Brown, 10=Light Green, 12=LightRed, 14=Yellow, 15=White

; Small Mario Standing (16x16) 
spr_small_mario_stand:
    db 0,0,0,0,0,4,4,4,4,4,0,0,0,0,0,0
    db 0,0,0,0,4,4,4,4,4,4,4,4,4,0,0,0
    db 0,0,0,0,6,6,6,14,14,6,14,0,0,0,0,0
    db 0,0,0,6,14,6,14,14,14,6,14,14,14,0,0,0
    db 0,0,0,6,14,6,6,14,14,14,6,14,14,14,0,0
    db 0,0,0,6,6,14,14,14,14,6,6,6,6,0,0,0
    db 0,0,0,0,0,14,14,14,14,14,14,14,0,0,0,0
    db 0,0,0,0,4,4,1,4,4,4,0,0,0,0,0,0
    db 0,0,0,4,4,4,1,4,4,1,4,4,4,0,0,0
    db 0,0,4,4,4,4,1,1,1,1,4,4,4,4,0,0
    db 0,0,14,14,4,1,14,1,1,14,1,4,14,14,0,0
    db 0,0,14,14,14,1,1,1,1,1,1,14,14,14,0,0
    db 0,0,14,14,1,1,1,1,1,1,1,1,14,14,0,0
    db 0,0,0,0,1,1,1,0,0,1,1,1,0,0,0,0
    db 0,0,0,6,6,6,0,0,0,0,6,6,6,0,0,0
    db 0,0,6,6,6,6,0,0,0,0,6,6,6,6,0,0

; Small Mario Running (16x16) 
spr_small_mario_run:
    db 0,0,0,0,0,4,4,4,4,4,0,0,0,0,0,0
    db 0,0,0,0,4,4,4,4,4,4,4,4,4,0,0,0
    db 0,0,0,0,6,6,6,14,14,6,14,0,0,0,0,0
    db 0,0,0,6,14,6,14,14,14,6,14,14,14,0,0,0
    db 0,0,0,6,14,6,6,14,14,14,6,14,14,14,0,0
    db 0,0,0,6,6,14,14,14,14,6,6,6,6,0,0,0
    db 0,0,0,0,0,14,14,14,14,14,14,14,0,0,0,0
    db 0,0,0,4,4,4,1,4,4,1,4,0,0,0,0,0
    db 0,0,4,4,4,4,1,1,1,1,4,14,14,0,0,0
    db 0,14,14,4,4,1,14,1,1,14,1,14,14,0,0,0
    db 0,14,14,0,1,1,1,1,1,1,1,0,0,0,0,0
    db 0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0
    db 0,0,1,1,1,0,0,0,0,1,1,1,6,0,0,0
    db 0,6,6,6,0,0,0,0,0,0,6,6,6,0,0,0
    db 0,6,6,0,0,0,0,0,0,0,0,6,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

;  Small Mario Jumping (16x16) 
spr_small_mario_jump:
    db 0,0,0,0,0,0,0,0,0,0,0,0,14,14,14,0
    db 0,0,0,0,0,4,4,4,4,4,0,0,14,14,14,0
    db 0,0,0,0,4,4,4,4,4,4,4,4,4,4,4,0
    db 0,0,0,0,6,6,6,14,14,6,14,0,4,4,0,0
    db 0,0,0,6,14,6,14,14,14,6,14,14,14,0,0,0
    db 0,0,0,6,14,6,6,14,14,14,6,14,14,14,0,0
    db 0,0,0,6,6,14,14,14,14,6,6,6,6,0,0,0
    db 0,0,0,0,0,14,14,14,14,14,14,14,0,0,0,0
    db 0,4,4,4,4,4,1,4,4,4,1,4,0,0,0,0
    db 14,14,4,4,4,4,1,1,1,1,1,0,0,0,0,0
    db 14,14,0,0,1,1,14,1,1,14,1,1,0,0,0,0
    db 0,0,0,1,1,1,1,1,1,1,1,1,1,6,0,0
    db 0,0,1,1,1,1,1,1,1,1,1,1,1,6,0,0
    db 0,6,6,1,1,1,0,0,0,0,1,1,6,6,0,0
    db 0,6,6,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; Super Mario Standing (16x32) 
spr_super_mario_stand:
    db 0,0,0,0,0,4,4,4,4,4,4,0,0,0,0,0
    db 0,0,0,0,4,4,4,4,4,4,4,4,4,4,0,0
    db 0,0,0,0,6,6,6,14,14,6,14,0,0,0,0,0
    db 0,0,0,6,14,6,14,14,14,6,14,14,14,0,0,0
    db 0,0,0,6,14,6,6,14,14,14,6,14,14,14,0,0
    db 0,0,0,6,6,14,14,14,14,6,6,6,6,0,0,0
    db 0,0,0,0,0,14,14,14,14,14,14,14,0,0,0,0
    db 0,0,0,0,0,14,14,14,14,14,14,0,0,0,0,0
    db 0,0,0,0,4,4,1,4,4,4,1,4,0,0,0,0
    db 0,0,0,4,4,4,1,4,4,4,1,4,4,0,0,0
    db 0,0,4,4,4,4,1,4,4,4,1,4,4,4,0,0
    db 0,0,4,4,4,4,1,1,1,1,1,4,4,4,0,0
    db 0,0,4,4,4,1,1,1,1,1,1,1,4,4,0,0
    db 0,0,14,14,4,1,14,1,1,1,14,1,4,14,14,0
    db 0,0,14,14,14,1,1,1,1,1,1,1,14,14,14,0
    db 0,0,14,14,14,1,1,1,1,1,1,1,14,14,14,0
    db 0,0,14,14,0,1,1,1,1,1,1,1,0,14,14,0
    db 0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,0
    db 0,0,0,0,1,1,1,1,1,1,1,1,1,0,0,0
    db 0,0,0,0,1,1,1,1,0,1,1,1,1,0,0,0
    db 0,0,0,0,1,1,1,1,0,1,1,1,1,0,0,0
    db 0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0
    db 0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0
    db 0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0
    db 0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0
    db 0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0
    db 0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0
    db 0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0
    db 0,0,0,6,6,6,6,0,0,0,6,6,6,6,0,0
    db 0,0,6,6,6,6,6,0,0,0,6,6,6,6,6,0
    db 0,0,6,6,6,6,6,0,0,0,6,6,6,6,6,0
    db 0,0,6,6,6,6,6,0,0,0,6,6,6,6,6,0

;  Super Mario Running (16x32) 
spr_super_mario_run:
    db 0,0,0,0,0,4,4,4,4,4,4,0,0,0,0,0
    db 0,0,0,0,4,4,4,4,4,4,4,4,4,4,0,0
    db 0,0,0,0,6,6,6,14,14,6,14,0,0,0,0,0
    db 0,0,0,6,14,6,14,14,14,6,14,14,14,0,0,0
    db 0,0,0,6,14,6,6,14,14,14,6,14,14,14,0,0
    db 0,0,0,6,6,14,14,14,14,6,6,6,6,0,0,0
    db 0,0,0,0,0,14,14,14,14,14,14,14,0,0,0,0
    db 0,0,0,0,0,14,14,14,14,14,14,0,0,0,0,0
    db 0,0,0,4,4,4,1,4,4,1,4,0,0,0,0,0
    db 0,0,4,4,4,4,1,4,4,1,4,14,14,0,0,0
    db 0,14,14,4,4,1,1,1,1,1,1,14,14,0,0,0
    db 0,14,14,4,4,1,14,1,1,14,1,0,0,0,0,0
    db 0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0
    db 0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0
    db 0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0
    db 0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0
    db 0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0
    db 0,0,1,1,1,1,1,0,0,1,1,1,1,1,0,0
    db 0,0,1,1,1,1,0,0,0,0,1,1,1,1,0,0
    db 0,0,1,1,1,0,0,0,0,0,0,1,1,1,6,0
    db 0,0,1,1,1,0,0,0,0,0,0,1,1,1,6,0
    db 0,6,6,6,0,0,0,0,0,0,0,0,6,6,6,0
    db 0,6,6,6,0,0,0,0,0,0,0,0,6,6,6,0
    db 0,6,6,0,0,0,0,0,0,0,0,0,0,6,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

;  Super Mario Jumping (16x32) 
spr_super_mario_jump:
    db 0,0,0,0,0,0,0,0,0,0,0,0,14,14,14,0
    db 0,0,0,0,0,4,4,4,4,4,4,0,14,14,14,0
    db 0,0,0,0,4,4,4,4,4,4,4,4,4,4,4,0
    db 0,0,0,0,6,6,6,14,14,6,14,0,4,4,0,0
    db 0,0,0,6,14,6,14,14,14,6,14,14,14,0,0,0
    db 0,0,0,6,14,6,6,14,14,14,6,14,14,14,0,0
    db 0,0,0,6,6,14,14,14,14,6,6,6,6,0,0,0
    db 0,0,0,0,0,14,14,14,14,14,14,14,0,0,0,0
    db 0,4,4,4,4,4,1,4,4,4,1,4,0,0,0,0
    db 14,14,4,4,4,4,1,4,4,4,1,0,0,0,0,0
    db 14,14,4,4,4,1,1,1,1,1,1,0,0,0,0,0
    db 0,0,0,0,1,1,14,1,1,14,1,1,0,0,0,0
    db 0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0
    db 0,0,0,0,1,1,1,1,1,1,1,1,0,0,0,0
    db 0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0
    db 0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0
    db 0,0,1,1,1,1,1,0,0,1,1,1,1,1,6,0
    db 0,6,6,1,1,1,0,0,0,0,1,1,1,1,6,0
    db 0,6,6,1,1,1,0,0,0,0,1,1,6,6,6,0
    db 0,6,6,0,0,0,0,0,0,0,0,0,6,6,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

;  Goomba Walking (16x16) 
spr_goomba_walk:
    db 0,0,0,0,0,0,6,6,6,6,0,0,0,0,0,0
    db 0,0,0,0,0,6,6,6,6,6,6,0,0,0,0,0
    db 0,0,0,0,6,6,6,6,6,6,6,6,0,0,0,0
    db 0,0,0,6,6,6,6,6,6,6,6,6,6,0,0,0
    db 0,0,6,6,0,0,6,6,6,6,0,0,6,6,0,0
    db 0,6,6,6,15,0,6,6,6,6,0,15,6,6,6,0
    db 0,6,6,6,15,0,6,6,6,6,0,15,6,6,6,0
    db 6,6,6,6,15,15,6,6,6,6,15,15,6,6,6,6
    db 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
    db 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
    db 0,0,0,0,14,14,14,14,14,14,14,14,0,0,0,0
    db 0,0,0,14,14,14,14,14,14,14,14,14,14,0,0,0
    db 0,0,0,14,14,14,14,14,14,14,14,14,14,0,0,0
    db 0,0,0,0,14,14,14,14,14,14,14,14,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; Goomba Flattened (16x16, bottom-aligned) 
spr_goomba_flat:
    times 11*16 db 0
    db 0,0,6,6,6,6,6,6,6,6,6,6,6,6,0,0
    db 6,6,6,15,0,6,6,6,6,6,6,0,15,6,6,6
    db 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
    db 0,0,0,14,14,14,14,14,14,14,14,14,14,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

;  Koopa Troopa (16x16) 
spr_koopa:
    db 0,0,0,0,0,0,14,14,14,0,0,0,0,0,0,0
    db 0,0,0,0,0,14,14,15,14,14,0,0,0,0,0,0
    db 0,0,0,0,0,14,14,0,14,14,0,0,0,0,0,0
    db 0,0,0,0,0,0,14,14,14,0,0,0,0,0,0,0
    db 0,0,0,0,0,2,2,14,14,0,0,0,0,0,0,0
    db 0,0,0,0,2,2,10,2,2,14,0,0,0,0,0,0
    db 0,0,0,2,2,10,10,2,2,2,14,0,0,0,0,0
    db 0,0,0,2,10,2,2,10,2,2,14,0,0,0,0,0
    db 0,0,0,2,2,2,2,2,2,2,14,0,0,0,0,0
    db 0,0,0,15,15,15,15,15,15,15,15,0,0,0,0,0
    db 0,0,0,0,15,15,15,15,15,15,0,0,0,0,0,0
    db 0,0,0,0,14,14,0,0,14,14,0,0,0,0,0,0
    db 0,0,0,0,14,14,0,0,14,14,0,0,0,0,0,0
    db 0,0,0,14,14,14,0,14,14,14,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

;  Koopa Shell 
spr_koopa_shell:
    times 4*16 db 0
    db 0,0,0,0,0,2,2,2,2,2,2,0,0,0,0,0
    db 0,0,0,2,2,10,10,2,2,10,10,2,2,0,0,0
    db 0,0,2,2,10,10,2,2,2,2,10,10,2,2,0,0
    db 0,0,2,10,2,2,2,10,10,2,2,2,10,2,0,0
    db 0,0,2,2,2,2,2,2,2,2,2,2,2,2,0,0
    db 0,15,15,15,15,15,15,15,15,15,15,15,15,15,15,0
    db 0,15,15,0,15,15,15,15,15,15,15,15,0,15,15,0
    db 0,0,15,15,15,15,15,15,15,15,15,15,15,15,0,0
    db 0,0,0,0,15,15,15,15,15,15,15,15,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; Power-up Mushroom (16x16)
spr_mushroom:
    db 0,0,0,0,0,4,4,4,4,4,4,0,0,0,0,0
    db 0,0,0,4,4,4,15,15,15,15,4,4,4,0,0,0
    db 0,0,4,4,4,15,15,15,15,15,15,4,4,4,0,0
    db 0,4,4,4,4,15,15,15,15,15,15,4,4,4,4,0
    db 0,4,15,15,4,4,15,15,15,15,4,4,15,15,4,0
    db 4,15,15,15,15,4,4,4,4,4,4,15,15,15,15,4
    db 4,15,15,15,15,4,4,4,4,4,4,15,15,15,15,4
    db 4,4,15,15,4,4,4,4,4,4,4,4,15,15,4,4
    db 4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4
    db 0,4,4,4,14,14,14,14,14,14,14,14,4,4,4,0
    db 0,0,0,14,14,14,0,14,14,0,14,14,14,0,0,0
    db 0,0,0,14,14,14,0,14,14,0,14,14,14,0,0,0
    db 0,0,0,14,14,14,14,14,14,14,14,14,14,0,0,0
    db 0,0,0,0,14,14,14,14,14,14,14,14,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

; Coin (16x16)
spr_coin:
    db 0,0,0,0,0,0,14,14,14,14,0,0,0,0,0,0
    db 0,0,0,0,0,14,15,14,14,14,14,0,0,0,0,0
    db 0,0,0,0,14,15,14,14,14,14,6,14,0,0,0,0
    db 0,0,0,0,14,15,14,6,6,14,6,14,0,0,0,0
    db 0,0,0,0,14,15,14,6,6,14,6,14,0,0,0,0
    db 0,0,0,0,14,15,14,6,6,14,6,14,0,0,0,0
    db 0,0,0,0,14,15,14,6,6,14,6,14,0,0,0,0
    db 0,0,0,0,14,15,14,6,6,14,6,14,0,0,0,0
    db 0,0,0,0,14,15,14,6,6,14,6,14,0,0,0,0
    db 0,0,0,0,14,15,14,6,6,14,6,14,0,0,0,0
    db 0,0,0,0,14,15,14,14,14,14,6,14,0,0,0,0
    db 0,0,0,0,0,14,14,14,14,6,14,0,0,0,0,0
    db 0,0,0,0,0,0,14,14,14,14,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0