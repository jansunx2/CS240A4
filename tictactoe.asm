# 8 x 8 Unit Height | 256 x 256 Display Height | 0x10040000 Base address for display

.data
board:  .word 0,0,0,0,0,0,0,0,0

prompt: .asciiz "\nEnter cell (1-9): \n1 | 2 | 3 \n4 | 5 | 6 \n7 | 8 | 9 \n"
bad:    .asciiz "Invalid or occupied cell!\n"
xwin:   .asciiz "\nPlayer 1 (RED) wins!\n"
owin:   .asciiz "\nPlayer 2 (BLUE) wins!\n"
draw:   .asciiz "\nIt's a draw!\n"

.text
.globl main

main:
    li $s0, 1              # Current player
    li $s1, 0              # Number of moves
    jal draw_board

game:
    li $v0, 4
    la $a0, prompt
    syscall

    li $v0, 5
    syscall
    move $t0, $v0

    # Check position 1-9
    blt $t0, 1, invalid
    bgt $t0, 9, invalid

    addi $t0, $t0, -1
    sll $t1, $t0, 2
    la $t2, board
    addu $t2, $t2, $t1

    lw $t3, 0($t2)
    bne $t3, $zero, invalid

    # Save move
    sw $s0, 0($t2)
    addi $s1, $s1, 1

    jal draw_board
    jal check_win

    bne $v0, $zero, winner

    li $t0, 9
    beq $s1, $t0, tie

    # Switch players
    li $t0, 1
    beq $s0, $t0, player2
    li $s0, 1
    j game

player2:
    li $s0, 2
    j game

invalid:
    li $v0, 4
    la $a0, bad
    syscall
    j game

winner:
    li $t0, 1
    beq $s0, $t0, red_wins

    li $v0, 4
    la $a0, owin
    syscall
    j exit

red_wins:
    li $v0, 4
    la $a0, xwin
    syscall
    j exit

tie:
    li $v0, 4
    la $a0, draw
    syscall

exit:
    li $v0, 10
    syscall


# Check all winning combinations
check_win:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)
    la $t0, board

    # Rows
    lw $t1, 0($t0)
    lw $t2, 4($t0)
    lw $t3, 8($t0)
    jal same
    bnez $v0, won

    lw $t1, 12($t0)
    lw $t2, 16($t0)
    lw $t3, 20($t0)
    jal same
    bnez $v0, won

    lw $t1, 24($t0)
    lw $t2, 28($t0)
    lw $t3, 32($t0)
    jal same
    bnez $v0, won

    # Columns
    lw $t1, 0($t0)
    lw $t2, 12($t0)
    lw $t3, 24($t0)
    jal same
    bnez $v0, won

    lw $t1, 4($t0)
    lw $t2, 16($t0)
    lw $t3, 28($t0)
    jal same
    bnez $v0, won

    lw $t1, 8($t0)
    lw $t2, 20($t0)
    lw $t3, 32($t0)
    jal same
    bnez $v0, won

    # Diagonals
    lw $t1, 0($t0)
    lw $t2, 16($t0)
    lw $t3, 32($t0)
    jal same
    bnez $v0, won

    lw $t1, 8($t0)
    lw $t2, 16($t0)
    lw $t3, 24($t0)
    jal same
    bnez $v0, won

    move $v0, $zero
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra

same:
    beq $t1, $zero, no
    bne $t1, $t2, no
    bne $t1, $t3, no
    li $v0, 1
    jr $ra

no:
    move $v0, $zero
    jr $ra

won:
    li $v0, 1
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra


# Draw grid and colored player pixels
draw_board:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

    # Clear 32x32 display units
    li $t0, 0x10040000
    li $t1, 1024
    li $t2, 0

clear_screen:
    sw $t2, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz $t1, clear_screen

    # Draw white grid
    li $t4, 0

grid_y:
    li $t5, 0

grid_x:
    li $t6, 0xFFFFFF

    li $t7, 8
    beq $t5, $t7, grid_pixel
    li $t7, 16
    beq $t5, $t7, grid_pixel
    li $t7, 8
    beq $t4, $t7, grid_pixel
    li $t7, 16
    beq $t4, $t7, grid_pixel
    j grid_next

grid_pixel:
    sll $t7, $t4, 5
    addu $t7, $t7, $t5
    sll $t7, $t7, 2
    li $t8, 0x10040000
    addu $t8, $t8, $t7
    sw $t6, 0($t8)

grid_next:
    addiu $t5, $t5, 1
    li $t7, 24
    blt $t5, $t7, grid_x

    addiu $t4, $t4, 1
    li $t7, 24
    blt $t4, $t7, grid_y

    # Draw occupied cells
    li $s2, 0

mark_loop:
    li $t0, 9
    beq $s2, $t0, draw_done

    sll $t1, $s2, 2
    la $t2, board
    addu $t2, $t2, $t1
    lw $t3, 0($t2)

    beq $t3, $zero, next_mark

    # x = column*8 + 4
    # y = row*8 + 4
    li $t0, 3
    div $s2, $t0
    mflo $t4
    mfhi $t5

    sll $t4, $t4, 3
    addiu $a1, $t4, 4

    sll $t5, $t5, 3
    addiu $a0, $t5, 4

    # Red for player 1, blue for player 2
    li $a2, 0xFF0000
    li $t0, 1
    beq $t3, $t0, put_pixel
    li $a2, 0x0000FF

put_pixel:
    jal draw_pixel

next_mark:
    addiu $s2, $s2, 1
    j mark_loop

draw_done:
    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra


# Draw one bitmap unit
# a0 = x, a1 = y, a2 = color
draw_pixel:
    sll  $t9, $a1, 5
    addu $t9, $t9, $a0
    sll  $t9, $t9, 2

    lui  $t8, 0x1004
    addu $t9, $t9, $t8
    sw   $a2, 0($t9)

    jr   $ra
