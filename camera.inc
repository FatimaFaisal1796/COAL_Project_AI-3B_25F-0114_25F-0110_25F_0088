; module06_camera.inc - Module 6: camera and scrolling (Section 5.3 update rule)
; Procedure: UpdateCamera

UpdateCamera:
        push ax
        mov ax, [mx_int]
        sub ax, [camera_x]          ; 1. screen x
        cmp ax, 160
        jle near .lim               ; 2. only follow past the middle
        mov ax, [mx_int]
        sub ax, 160
        cmp ax, MAX_CAM             ; 3. stop at the end of the level
        jle near .nc
        mov ax, MAX_CAM
.nc:    cmp ax, [camera_x]          ; 4. never move back
        jle near .lim
        mov [camera_x], ax
.lim:   mov ax, [camera_x]          ; 5. left wall
        cmp [mx_int], ax
        jge near .o
        mov [mx_int], ax
        mov byte [mx_frac], 0
        mov word [vx], 0
.o:     pop ax
        ret
