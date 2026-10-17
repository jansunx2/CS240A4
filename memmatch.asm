# 4 x 8 Unit Height | 256 x 128 Display Height | 0x10008000 Base address for display
.data
.align 2
first:  .word -1
second: .word -1
pairs:  .word 0

# 6 cards: 3 matching pairs
# 0 = Red, 1 = Blue, 2 = Green
cards: .word 0, 1, 2, 1, 0, 2

# 0 = unmatched, 1 = matched
matched: .space 24

# Colors in RGB format
colors: .word 0x00FF0000   # Red
        .word 0x000000FF   # Blue
        .word 0x0000FF00   # Green

hiddenColor: .word 0x00404040
background:  .word 0x00202020

msg1: .asciiz "\n=== MEMORY MATCHING GAME ===\n"
msg2: .asciiz "Find 3 matching pairs!\n"
msg3: .asciiz "Choose a card (0-5): "
msg4: .asciiz "Enter an integer to hide cards and continue: "
msg5: .asciiz "Match! Well done!\n"
msg6: .asciiz "Not a match!\n"
msg7: .asciiz "Invalid position. Try again.\n"
msg8: .asciiz "You won! All pairs matched!\n"

.text
.globl main

main:
    # Initialize all 6 cards as unmatched
    la $t0, matched
    li $t1, 6

init_loop:
    sw $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bnez $t1, init_loop

    # Initialize selections and pair counter
    li $t0, -1
    sw $t0, first
    sw $t0, second
    sw $zero, pairs

    li $v0, 4
    la $a0, msg1
    syscall

    li $v0, 4
    la $a0, msg2
    syscall

    jal draw_board

game_loop:
    # Ask for first card
    li $v0, 4
    la $a0, msg3
    syscall

    li $v0, 5
    syscall
    move $s0, $v0

    # Check position range
    bltz $s0, invalid_first
    li $t0, 5
    bgt $s0, $t0, invalid_first

    # Check if first card is already matched
    la $t0, matched
    sll $t1, $s0, 2
    addu $t0, $t0, $t1
    lw $t2, 0($t0)
    bnez $t2, invalid_first

    sw $s0, first
    li $t0, -1
    sw $t0, second

    # Reveal first card
    jal draw_board

ask_second:
    li $v0, 4
    la $a0, msg3
    syscall

    li $v0, 5
    syscall
    move $s1, $v0

    # Check position range
    bltz $s1, invalid_second
    li $t0, 5
    bgt $s1, $t0, invalid_second

    # Cannot select the same card twice
    beq $s0, $s1, invalid_second

    # Check if second card is already matched
    la $t0, matched
    sll $t1, $s1, 2
    addu $t0, $t0, $t1
    lw $t2, 0($t0)
    bnez $t2, invalid_second

    sw $s1, second

    # Reveal second card
    jal draw_board

    # Get first card color ID
    la $t0, cards
    sll $t1, $s0, 2
    addu $t0, $t0, $t1
    lw $t2, 0($t0)

    # Get second card color ID
    la $t0, cards
    sll $t1, $s1, 2
    addu $t0, $t0, $t1
    lw $t3, 0($t0)

    # Compare colors
    beq $t2, $t3, found_match

    # No match
    li $v0, 4
    la $a0, msg6
    syscall

    li $v0, 4
    la $a0, msg4
    syscall

    li $v0, 5
    syscall

    # Hide both cards on the next redraw
    li $t0, -1
    sw $t0, first
    sw $t0, second

    jal draw_board
    j game_loop

found_match:
    # Mark first card as matched
    la $t0, matched
    sll $t1, $s0, 2
    addu $t0, $t0, $t1
    li $t2, 1
    sw $t2, 0($t0)

    # Mark second card as matched
    la $t0, matched
    sll $t1, $s1, 2
    addu $t0, $t0, $t1
    sw $t2, 0($t0)

    # Increase matched pair count
    lw $t0, pairs
    addiu $t0, $t0, 1
    sw $t0, pairs

    li $v0, 4
    la $a0, msg5
    syscall

    # Clear selections
    li $t0, -1
    sw $t0, first
    sw $t0, second

    jal draw_board

    # check 3 pairs
    lw $t0, pairs
    li $t1, 3
    beq $t0, $t1, game_won

    j game_loop

invalid_first:
    li $v0, 4
    la $a0, msg7
    syscall
    j game_loop

invalid_second:
    li $v0, 4
    la $a0, msg7
    syscall
    j ask_second

game_won:
    li $v0, 4
    la $a0, msg8
    syscall

    li $v0, 10
    syscall


# ------------------------------------------------
# Draw the 6 cards in a 3-column by 2-row layout.
#
# MARS Bitmap Display settings:
# Unit width: 8
# Unit height: 8
# Display width: 512
# Display height: 256
# Base address: 0x10008000
# ------------------------------------------------
draw_board:
    addiu $sp, $sp, -8
    sw $ra, 4($sp)
    sw $s0, 0($sp)

    # Clear display
    li $t0, 0x10008000
    lw $t1, background
    li $t2, 2048

clear_screen:
    sw $t1, 0($t0)
    addiu $t0, $t0, 4
    addiu $t2, $t2, -1
    bnez $t2, clear_screen

    li $s0, 0

draw_card_loop:
    # Stop after 6 cards
    li $t0, 6
    beq $s0, $t0, draw_done

    # Check whether this card is matched
    la $t0, matched
    sll $t1, $s0, 2
    addu $t0, $t0, $t1
    lw $t2, 0($t0)
    bnez $t2, show_color

    # Check first selection
    lw $t2, first
    beq $s0, $t2, show_color

    # Check second selection
    lw $t2, second
    beq $s0, $t2, show_color

    # Hidden card
    lw $s5, hiddenColor
    j card_position

show_color:
    # Load card's color ID
    la $t0, cards
    sll $t1, $s0, 2
    addu $t0, $t0, $t1
    lw $t2, 0($t0)

    # Load RGB color
    la $t0, colors
    sll $t1, $t2, 2
    addu $t0, $t0, $t1
    lw $s5, 0($t0)

card_position:
    # Column = index % 3
    li $t1, 3
    div $s0, $t1
    mfhi $t0

    # Horizontal spacing = 20 units
    li $t1, 20
    mul $t0, $t0, $t1
    addiu $t0, $t0, 2

    # Row = index / 3
    li $t1, 3
    div $s0, $t1
    mflo $t1

    # Vertical spacing = 8 units
    li $t2, 8
    mul $t1, $t1, $t2
    addiu $t1, $t1, 2

    # Draw a rectangle 10 units wide, 5 units tall
    li $t2, 0

row_loop:
    li $t3, 5
    beq $t2, $t3, next_card

    li $t3, 0

col_loop:
    li $t4, 10
    beq $t3, $t4, next_row

    # Pixel x = card_x + column
    addu $t5, $t0, $t3

    # Pixel y = card_y + row
    addu $t6, $t1, $t2

    # Address = base + ((y * 64 + x) * 4)
    sll $t7, $t6, 6
    addu $t7, $t7, $t5
    sll $t7, $t7, 2

    li $t8, 0x10008000
    addu $t7, $t7, $t8

    sw $s5, 0($t7)

    addiu $t3, $t3, 1
    j col_loop

next_row:
    addiu $t2, $t2, 1
    j row_loop

next_card:
    addiu $s0, $s0, 1
    j draw_card_loop

draw_done:
    lw $s0, 0($sp)
    lw $ra, 4($sp)
    addiu $sp, $sp, 8
    jr $ra
    
