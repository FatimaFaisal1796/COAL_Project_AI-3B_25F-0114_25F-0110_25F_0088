; Module 6 (Camera & Scrolling)

UpdateCamera:
    push ax
    push bx

    ; Calculate Mario screen position
    mov ax, [mario_world_x]
    mov bx, [camera_x]
    sub ax, bx

    ; Check if Mario passed the middle
    cmp ax, CAMERA_FOLLOW_X
    jle .check_left_wall

    mov ax, [mario_world_x]
    sub ax, CAMERA_FOLLOW_X

    ; Check camera maximum position
    cmp ax, CAMERA_MAX_X
    jle .no_backtrack
    mov ax, CAMERA_MAX_X

.no_backtrack:
    ; Camera should not move backward
    cmp ax, [camera_x]
    jle .check_left_wall
    mov [camera_x], ax

.check_left_wall:
    ; Check left wall
    mov ax, [mario_world_x]
    mov bx, [camera_x]
    cmp ax, bx
    jge .check_right_wall

    mov [mario_world_x], bx
    mov byte [mario_x_frac], 0
    mov word [mario_vx], 0

.check_right_wall:
    ; Check right wall
    mov ax, [mario_world_x]
    cmp ax, MARIO_MAX_X
    jle .done

    mov word [mario_world_x], MARIO_MAX_X
    mov byte [mario_x_frac], 0
    mov word [mario_vx], 0

.done:
    pop bx
    pop ax
    ret


; Convert world X to screen X

WorldToScreenX:
    push bp
    mov bp, sp

    mov ax, [bp+4]
    sub ax, [camera_x]

    pop bp
    ret 2


; Check if sprite is on screen

IsOnScreen:
    push bp
    mov bp, sp
    push bx

    mov ax, [bp+4]
    mov bx, [bp+6]
    neg bx

    ; Check left side
    cmp ax, bx
    jle .hidden

    ; Check right side
    cmp ax, SCREEN_WIDTH
    jge .hidden

    mov al, 1
    jmp .done

.hidden:
    xor al, al

.done:
    xor ah, ah
    pop bx
    pop bp
    ret 4
