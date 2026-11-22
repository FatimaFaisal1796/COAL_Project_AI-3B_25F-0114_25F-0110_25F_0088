; M11 (ENEMIES AND SHELLS)
; Enemy Types
ENEMY_NONE              equ 0
ENEMY_GOOMBA            equ 1
ENEMY_KOOPA             equ 2

; Enemy States
ESTATE_INACTIVE         equ 0   
ESTATE_WALKING          equ 1   
ESTATE_FLAT             equ 2 
ESTATE_SHELL_IDLE       equ 3 
ESTATE_SHELL_SLIDE      equ 4 

; Enemy Speeds 
GOOMBA_SPEED_8_8        equ 0x0080   
KOOPA_SPEED_8_8         equ 0x00C0  
SHELL_SPEED_8_8         equ 0x0300  
ENEMY_GRAVITY_8_8       equ 0x0040  
ENEMY_MAX_FALL_8_8      equ 0x0400  
STOMP_BOUNCE_8_8        equ 0xFD00      ; -3.0 px/frame (normal stomp bounce)
STOMP_HIGH_BOUNCE_8_8   equ 0xFB80      ; -4.5 px/frame (higher bounce when Space held)

; Record layout
ENEMY_REC_SIZE          equ 16
E_TYPE                  equ 0   
E_STATE                 equ 1   
E_DIR                   equ 2   
E_TIMER                 equ 3  
E_X                     equ 4  
E_X_FRAC                equ 6   
E_Y_FRAC                equ 7  
E_Y                     equ 8   
E_VX                    equ 10  
E_VY                    equ 12 
E_RESERVED              equ 14 

; Enemy table storage 
enemy_table             times (MAX_ACTIVE_ENEMIES * ENEMY_REC_SIZE) db 0

; Stomp chain points table 
stomp_points_table      dw 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000

; Name: InitEnemies
; Purpose: Populate enemy_table with level enemies (at least 4 Goombas and 2 Koopas placed across the 60-tile level)
; Inputs: None
; Outputs: enemy_table initialized for level start/reset
; Registers changed: None (preserved)
InitEnemies:
    pushf
    push ax
    push cx
    push di
    push es

    push ds
    pop es

    mov di, enemy_table
    mov cx, MAX_ACTIVE_ENEMIES * ENEMY_REC_SIZE
    xor al, al
    cld
    rep stosb

    ; Goomba at col 10 (x = 160)
    mov di, enemy_table + (0 * ENEMY_REC_SIZE)
    mov byte [di + E_TYPE], ENEMY_GOOMBA
    mov byte [di + E_STATE], ESTATE_INACTIVE
    mov byte [di + E_DIR], 0
    mov word [di + E_X], 160
    mov word [di + E_Y], 144
    mov word [di + E_VX], GOOMBA_SPEED_8_8

    ; Goomba at col 18 (x = 288)
    mov di, enemy_table + (1 * ENEMY_REC_SIZE)
    mov byte [di + E_TYPE], ENEMY_GOOMBA
    mov byte [di + E_STATE], ESTATE_INACTIVE
    mov byte [di + E_DIR], 0
    mov word [di + E_X], 288
    mov word [di + E_Y], 144
    mov word [di + E_VX], GOOMBA_SPEED_8_8

    ; Koopa at col 26 (x = 416)
    mov di, enemy_table + (2 * ENEMY_REC_SIZE)
    mov byte [di + E_TYPE], ENEMY_KOOPA
    mov byte [di + E_STATE], ESTATE_INACTIVE
    mov byte [di + E_DIR], 0
    mov word [di + E_X], 416
    mov word [di + E_Y], 144
    mov word [di + E_VX], KOOPA_SPEED_8_8

    ; Goomba at col 35 (x = 560)
    mov di, enemy_table + (3 * ENEMY_REC_SIZE)
    mov byte [di + E_TYPE], ENEMY_GOOMBA
    mov byte [di + E_STATE], ESTATE_INACTIVE
    mov byte [di + E_DIR], 0
    mov word [di + E_X], 560
    mov word [di + E_Y], 144
    mov word [di + E_VX], GOOMBA_SPEED_8_8

    ; Koopa at col 45 (x = 720)
    mov di, enemy_table + (4 * ENEMY_REC_SIZE)
    mov byte [di + E_TYPE], ENEMY_KOOPA
    mov byte [di + E_STATE], ESTATE_INACTIVE
    mov byte [di + E_DIR], 0
    mov word [di + E_X], 720
    mov word [di + E_Y], 144
    mov word [di + E_VX], KOOPA_SPEED_8_8

    ; Goomba at col 48 (x = 768)
    mov di, enemy_table + (5 * ENEMY_REC_SIZE)
    mov byte [di + E_TYPE], ENEMY_GOOMBA
    mov byte [di + E_STATE], ESTATE_INACTIVE
    mov byte [di + E_DIR], 0
    mov word [di + E_X], 768
    mov word [di + E_Y], 144
    mov word [di + E_VX], GOOMBA_SPEED_8_8

    pop es
    pop di
    pop cx
    pop ax
    popf
    ret

; Name: AwardStompPoints
; Purpose: Increment stomp_chain and award points from stomp_points_table (or +1 life on 11th+ stomp)
; Inputs: None (reads/updates stomp_chain)
; Outputs: Score or lives updated
; Registers changed: None (preserved)
AwardStompPoints:
    pushf
    push ax
    push bx

    inc byte [stomp_chain]
    xor ax, ax
    mov al, [stomp_chain]

    cmp al, 11
    jae .extra_life

    dec al                  
    shl ax, 1               
    mov bx, ax
    mov ax, [stomp_points_table + bx]
    push ax
    call AddScore
    jmp .done

.extra_life:
    call AddLife

.done:
    pop bx
    pop ax
    popf
    ret

; Name: UpdateEnemies
; Purpose: Update all active enemies and shells: activation, movement, wall/enemy/ledge turning, gravity, shell collisions with enemies, and despawning
; Inputs: None
; Outputs: enemy_table updated
; Registers changed: None (preserved)
UpdateEnemies:
    pushf
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, enemy_table
    mov cx, MAX_ACTIVE_ENEMIES

.enemy_loop:
    push cx
    push si

    mov al, [si + E_TYPE]
    cmp al, ENEMY_NONE
    je .next_enemy

    mov bl, [si + E_STATE]
    cmp bl, ESTATE_INACTIVE
    je .handle_inactive

    cmp bl, ESTATE_FLAT
    je .handle_flat

    cmp bl, ESTATE_SHELL_IDLE
    je .handle_shell_idle

    call UpdateMovingEnemy
    jmp .check_shell_kills

.handle_inactive:
    ; Activate when enemy comes within 1 tile (16 px) of screen edges
    mov ax, [camera_x]
    sub ax, TILE_SIZE
    cmp [si + E_X], ax
    jl .next_enemy
    mov ax, [camera_x]
    add ax, SCREEN_WIDTH + TILE_SIZE
    cmp [si + E_X], ax
    jg .next_enemy
    mov byte [si + E_STATE], ESTATE_WALKING
    jmp .next_enemy

.handle_flat:
    cmp byte [si + E_TIMER], 0
    je .remove_enemy
    dec byte [si + E_TIMER]
    jmp .next_enemy

.handle_shell_idle:
    cmp byte [si + E_TIMER], 0
    je .apply_idle_gravity
    dec byte [si + E_TIMER]
.apply_idle_gravity:
    call ApplyEnemyGravity
    jmp .check_despawn

.check_shell_kills:
    cmp byte [si + E_STATE], ESTATE_SHELL_SLIDE
    jne .check_despawn

    cmp byte [si + E_TIMER], 0
    je .scan_victims
    dec byte [si + E_TIMER]

.scan_victims:
    call CheckSlidingShellHits

.check_despawn:
    cmp word [si + E_Y], GAME_VIEW_HEIGHT
    jge .remove_enemy
    mov ax, [camera_x]
    sub ax, 32
    cmp [si + E_X], ax
    jl .remove_enemy
    jmp .next_enemy

.remove_enemy:
    mov byte [si + E_TYPE], ENEMY_NONE
    mov byte [si + E_STATE], ESTATE_INACTIVE

.next_enemy:
    pop si
    pop cx
    add si, ENEMY_REC_SIZE
    dec cx
    jnz .enemy_loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf
    ret

; Name: UpdateMovingEnemy
; Purpose: Move a walking Goomba, walking Koopa, or sliding shell; handles wall turns, Koopa ledge turns (Goombas fall off), enemy-enemy turns, and gravity
; Inputs: SI = pointer to enemy record
; Outputs: Record X, Y, DIR updated
; Registers changed: AX, BX, CX, DX
UpdateMovingEnemy:
    mov ax, [si + E_VX]
    mov bl, [si + E_X_FRAC]
    add bl, al
    mov [si + E_X_FRAC], bl
    mov dl, 0
    adc dl, 0              
    add dl, ah              
    xor dh, dh             

    cmp dx, 0
    je .do_gravity

    cmp byte [si + E_DIR], 1
    je .move_right

    mov ax, [si + E_X]
    sub ax, dx
    js .turn_right          ; Prevent negative X wrap

    ; Check solid wall at (new_x, y + 8)
    mov cx, [si + E_Y]
    add cx, 8
    push dx
    push ax
    push cx
    call GetTile
    push ax
    call IsSolidTile
    pop dx
    cmp al, 1
    je .turn_right

    ; Goombas fall off ledges; only walking Koopas check platform ledge at (new_x, y + 16)
    cmp byte [si + E_TYPE], ENEMY_KOOPA
    jne .commit_left
    cmp byte [si + E_STATE], ESTATE_WALKING
    jne .commit_left

    mov ax, [si + E_X]
    sub ax, dx
    mov cx, [si + E_Y]
    add cx, 16
    push dx
    push ax
    push cx
    call GetTile
    push ax
    call IsSolidTile
    pop dx
    cmp al, 0
    je .turn_right          ; Turn around before walking off ledge

.commit_left:
    sub [si + E_X], dx
    jmp .check_enemy_bump

.turn_right:
    mov byte [si + E_DIR], 1
    jmp .do_gravity

.move_right:
    mov ax, [si + E_X]
    add ax, dx
    add ax, 15              ; Right edge of 16x16 sprite
    mov cx, [si + E_Y]
    add cx, 8
    push dx
    push ax
    push cx
    call GetTile
    push ax
    call IsSolidTile
    pop dx
    cmp al, 1
    je .turn_left

    ; Goombas fall off ledges; only walking Koopas check platform ledge at (new_x + 15, y + 16)
    cmp byte [si + E_TYPE], ENEMY_KOOPA
    jne .commit_right
    cmp byte [si + E_STATE], ESTATE_WALKING
    jne .commit_right

    mov ax, [si + E_X]
    add ax, dx
    add ax, 15
    mov cx, [si + E_Y]
    add cx, 16
    push dx
    push ax
    push cx
    call GetTile
    push ax
    call IsSolidTile
    pop dx
    cmp al, 0
    je .turn_left

.commit_right:
    add [si + E_X], dx
    jmp .check_enemy_bump

.turn_left:
    mov byte [si + E_DIR], 0
    jmp .do_gravity

.check_enemy_bump:
    cmp byte [si + E_STATE], ESTATE_WALKING
    jne .do_gravity
    call TurnIfTouchingOtherEnemy

.do_gravity:
    call ApplyEnemyGravity
    ret

; Name: ApplyEnemyGravity
; Purpose: Apply gravity to enemy SI and snap to solid ground
; Inputs: SI = pointer to enemy record
; Outputs: Record Y and VY updated
; Registers changed: AX, BX, CX, DX
ApplyEnemyGravity:
    mov ax, [si + E_VY]
    add ax, ENEMY_GRAVITY_8_8
    cmp ax, ENEMY_MAX_FALL_8_8
    jle .vy_ok
    mov ax, ENEMY_MAX_FALL_8_8
.vy_ok:
    mov [si + E_VY], ax

    mov bl, [si + E_Y_FRAC]
    add bl, al
    mov [si + E_Y_FRAC], bl
    mov bh, 0
    adc bh, 0

    mov al, ah
    cbw
    add [si + E_Y], ax
    xor dx, dx
    mov dl, bh
    add [si + E_Y], dx

    ; Check solid tile under enemy centre-bottom (x + 8, y + 16)
    mov bx, [si + E_X]
    add bx, 8
    mov cx, [si + E_Y]
    add cx, 16
    push bx
    push cx
    call GetTile
    push ax
    call IsSolidTile
    cmp al, 1
    jne .done

    ; Snap on top of tile
    mov ax, [si + E_Y]
    add ax, 16
    and ax, 0xFFF0
    sub ax, 16
    mov [si + E_Y], ax
    mov byte [si + E_Y_FRAC], 0
    mov word [si + E_VY], 0

.done:
    ret

; Name: TurnIfTouchingOtherEnemy
; Purpose: Reverse direction of walking enemy SI only if moving toward an overlapping active enemy
; Inputs: SI = pointer to current enemy record
; Outputs: E_DIR updated cleanly without jitter
; Registers changed: AX, BX, CX, DI
TurnIfTouchingOtherEnemy:
    mov di, enemy_table
    mov cx, MAX_ACTIVE_ENEMIES
    mov bx, 16

.loop:
    cmp di, si
    je .next
    cmp byte [di + E_TYPE], ENEMY_NONE
    je .next
    cmp byte [di + E_STATE], ESTATE_INACTIVE
    je .next
    cmp byte [di + E_STATE], ESTATE_FLAT
    je .next

    push cx
    push word [di + E_Y]
    push word [di + E_X]
    push bx
    push bx
    push word [si + E_Y]
    push word [si + E_X]
    push bx
    push bx
    call RectOverlap
    pop cx
    cmp al, 1
    jne .next

    ; Only flip if SI is currently moving toward DI
    mov ax, [si + E_X]
    cmp byte [si + E_DIR], 1
    je .moving_right_toward

    ; Moving left: flip to right only if SI is to the right of DI (si.x > di.x)
    cmp ax, [di + E_X]
    jle .next
    mov byte [si + E_DIR], 1
    jmp .done

.moving_right_toward:
    ; Moving right: flip to left only if SI is to the left of DI (si.x < di.x)
    cmp ax, [di + E_X]
    jge .next
    mov byte [si + E_DIR], 0
    jmp .done

.next:
    add di, ENEMY_REC_SIZE
    loop .loop

.done:
    ret

; Name: CheckSlidingShellHits
; Purpose: Sliding shell SI eliminates any Goomba or Koopa it overlaps and awards +500 points per enemy
; Inputs: SI = pointer to sliding shell record
; Outputs: Overlapped Goombas/Koopas removed, +500 added per kill
; Registers changed: AX, BX, CX, DI
CheckSlidingShellHits:
    mov di, enemy_table
    mov cx, MAX_ACTIVE_ENEMIES
    mov bx, 16

.loop:
    cmp di, si
    je .next

    ; Only eliminate Goombas or Koopas
    mov al, [di + E_TYPE]
    cmp al, ENEMY_GOOMBA
    je .check_state
    cmp al, ENEMY_KOOPA
    jne .next

.check_state:
    cmp byte [di + E_STATE], ESTATE_INACTIVE
    je .next
    cmp byte [di + E_STATE], ESTATE_FLAT
    je .next

    push cx
    push word [di + E_Y]
    push word [di + E_X]
    push bx
    push bx
    push word [si + E_Y]
    push word [si + E_X]
    push bx
    push bx
    call RectOverlap
    pop cx
    cmp al, 1
    jne .next

    mov byte [di + E_TYPE], ENEMY_NONE
    mov byte [di + E_STATE], ESTATE_INACTIVE
    push cx
    mov ax, 500
    push ax
    call AddScore
    pop cx

.next:
    add di, ENEMY_REC_SIZE
    loop .loop
    ret

; Name: ResolveMarioEnemyCollisions
; Purpose: Check Mario against all active enemies/shells and apply Stomp, Shell Kick (+400), or Hurt rules
; Inputs: None (reads Mario state & enemy_table)
; Outputs: AL = 1 if Mario took fatal damage (Small Mario hit), 0 otherwise; score/states updated
; Registers changed: AX (AL return); others preserved
ResolveMarioEnemyCollisions:
    pushf
    push bx
    push cx
    push dx
    push si

    xor dx, dx              
    mov si, enemy_table
    mov cx, MAX_ACTIVE_ENEMIES

.loop:
    cmp byte [si + E_TYPE], ENEMY_NONE
    je .next
    cmp byte [si + E_STATE], ESTATE_INACTIVE
    je .next
    cmp byte [si + E_STATE], ESTATE_FLAT
    je .next

    push cx
    mov bx, 16
    push word [si + E_Y]
    push word [si + E_X]
    push bx
    push bx

    push word [mario_world_y]
    mov ax, [mario_world_x]
    add ax, MARIO_HITBOX_X_OFFSET
    push ax
    cmp byte [mario_form], 1
    jne .small_h
    mov ax, MARIO_SUPER_HEIGHT
    push ax
    jmp .push_w
.small_h:
    mov ax, MARIO_SMALL_HEIGHT
    push ax
.push_w:
    mov ax, MARIO_HITBOX_WIDTH
    push ax
    call RectOverlap
    pop cx

    cmp al, 1
    jne .next

    mov bl, [si + E_STATE]

    ; Stationary Shell: touching or stomping kicks it (+400, 8-frame grace)
    cmp bl, ESTATE_SHELL_IDLE
    je .kick_shell

    ; Walking enemy or Sliding Shell: test Stomp vs Side Contact
    mov ax, [mario_vy]
    cmp ax, 0
    jle .not_stomp

    mov ax, [mario_world_y]
    cmp byte [mario_form], 1
    jne .feet_small
    add ax, MARIO_SUPER_HEIGHT
    jmp .check_upper_half
.feet_small:
    add ax, MARIO_SMALL_HEIGHT

.check_upper_half:
    mov bx, [si + E_Y]
    add bx, 10
    cmp ax, bx
    jg .not_stomp

    call AwardStompPoints

    ; Bounce Mario up (higher bounce if Space key is held)
    mov ax, KEY_SPACE
    push ax
    call IsKeyDown
    cmp al, 1
    je .high_stomp_bounce
    mov word [mario_vy], STOMP_BOUNCE_8_8
    jmp .stomp_airborne
.high_stomp_bounce:
    mov word [mario_vy], STOMP_HIGH_BOUNCE_8_8
.stomp_airborne:
    mov byte [on_ground], 0

    cmp byte [si + E_STATE], ESTATE_SHELL_SLIDE
    je .stop_sliding_shell

    cmp byte [si + E_TYPE], ENEMY_GOOMBA
    je .flatten_goomba

    mov byte [si + E_STATE], ESTATE_SHELL_IDLE
    mov word [si + E_VX], 0
    mov byte [si + E_TIMER], 8
    jmp .next

.flatten_goomba:
    mov byte [si + E_STATE], ESTATE_FLAT
    mov word [si + E_VX], 0
    mov byte [si + E_TIMER], 30
    jmp .next

.stop_sliding_shell:
    mov byte [si + E_STATE], ESTATE_SHELL_IDLE
    mov word [si + E_VX], 0
    mov byte [si + E_TIMER], 8
    jmp .next

.kick_shell:
    mov byte [si + E_STATE], ESTATE_SHELL_SLIDE
    mov word [si + E_VX], SHELL_SPEED_8_8
    mov byte [si + E_TIMER], 8

    mov ax, [mario_world_x]
    cmp ax, [si + E_X]
    jg .kick_left
    mov byte [si + E_DIR], 1
    jmp .award_kick
.kick_left:
    mov byte [si + E_DIR], 0
.award_kick:
    push cx
    mov ax, 400
    push ax
    call AddScore
    pop cx
    jmp .next

.not_stomp:
    cmp byte [si + E_STATE], ESTATE_SHELL_SLIDE
    jne .check_invuln
    cmp byte [si + E_TIMER], 0
    ja .next

.check_invuln:
    cmp word [invuln_timer], 0
    ja .next

    cmp byte [mario_form], 1
    je .shrink_super_mario

    mov byte [mario_hp], 0
    mov dl, 1
    jmp .done

.shrink_super_mario:
    ; Super Mario shrinks to Small Mario (feet fixed) + ~2s invulnerability (60 frames)
    mov byte [mario_form], 0
    mov byte [mario_hp], 1
    add word [mario_world_y], 16
    mov word [invuln_timer], 60

.next:
    add si, ENEMY_REC_SIZE
    dec cx
    jnz .loop

.done:
    mov al, dl              
    pop si
    pop dx
    pop cx
    pop bx
    popf
    ret

; Name: DrawEnemies
; Purpose: Render all active enemies and shells into the off-screen frame buffer
; Inputs: None
; Outputs: Visible enemies drawn
; Registers changed: None (preserved)
DrawEnemies:
    pushf
    push ax
    push bx
    push cx
    push dx
    push si

    mov si, enemy_table
    mov cx, MAX_ACTIVE_ENEMIES

.loop:
    cmp byte [si + E_TYPE], ENEMY_NONE
    je .next
    cmp byte [si + E_STATE], ESTATE_INACTIVE
    je .next

    mov ax, [si + E_X]
    sub ax, [camera_x]
    cmp ax, -16
    jle .next
    cmp ax, SCREEN_WIDTH
    jge .next

    xor bx, bx
    cmp byte [si + E_DIR], 0
    jne .choose_sprite
    or bx, SPRITE_FLIP_H

.choose_sprite:
    cmp byte [si + E_TYPE], ENEMY_GOOMBA
    je .goomba_sprite

    cmp byte [si + E_STATE], ESTATE_WALKING
    je .koopa_walk_spr
    mov dx, spr_koopa_shell
    jmp .draw_it

.koopa_walk_spr:
    mov dx, spr_koopa
    jmp .draw_it

.goomba_sprite:
    cmp byte [si + E_STATE], ESTATE_FLAT
    je .goomba_flat_spr
    mov dx, spr_goomba_walk
    jmp .draw_it

.goomba_flat_spr:
    mov dx, spr_goomba_flat

.draw_it:
    push cx
    push bx
    push dx
    push word [si + E_Y]
    push ax
    call DrawSprite
    pop cx

.next:
    add si, ENEMY_REC_SIZE
    loop .loop

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf
    ret

; Name: DrawItemsAndEnemies
; Purpose: Combined wrapper expected by Student 1's main loop to draw active items and enemies in one call
; Inputs: None
; Outputs: Items and enemies drawn to frame buffer
; Registers changed: None (preserved)
DrawItemsAndEnemies:
    pushf
    call DrawItems
    call DrawEnemies
    popf
    ret