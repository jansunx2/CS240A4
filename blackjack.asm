# 8 x 8 Unit Height | 256 x 256 Display Height | 0x10040000 Base address for display

.data
playerCards: .word 0,0,0,0,0
dealerCards: .word 0,0,0,0,0

prompt: .asciiz "\n1 = Hit, 2 = Stand: "
playerMsg: .asciiz "\nYour total: "
dealerMsg: .asciiz "\nDealer total: "
invalidMsg: .asciiz "Invalid choice!\n"
bustMsg: .asciiz "\nBust! Dealer wins.\n"
winMsg: .asciiz "\nYou win!\n"
loseMsg: .asciiz "\nDealer wins!\n"
tieMsg: .asciiz "\nPush! Tie.\n"

.text
.globl main

main:
    li $s4, 0              # Player card count
    li $s5, 0              # Dealer card count

    # Deal two cards to player
    jal get_card
    sw $v0, playerCards
    li $s4, 1

    jal get_card
    # Store second player card
    la $t0, playerCards
    sw $v0, 4($t0)
    li $s4, 2

    # Deal two cards to dealer
    jal get_card
    la $t0, dealerCards
    sw $v0, 0($t0)

    jal get_card
    la $t0, dealerCards
    sw $v0, 4($t0)
    li $s5, 2

    jal draw_board

player_turn:
    # Calculate player total
    la $a0, playerCards
    move $a1, $s4
    jal score_hand
    move $s0, $v0

    li $v0, 4
    la $a0, playerMsg
    syscall

    li $v0, 1
    move $a0, $s0
    syscall

    bgt $s0, 21, player_bust

    li $v0, 4
    la $a0, prompt
    syscall

    li $v0, 5
    syscall

    beq $v0, 1, hit
    beq $v0, 2, dealer_turn

    li $v0, 4
    la $a0, invalidMsg
    syscall
    j player_turn

hit:
    # Maximum five visible cards
    bge $s4, 5, dealer_turn

    jal get_card
    la $t0, playerCards
    sll $t1, $s4, 2
    addu $t0, $t0, $t1
    sw $v0, 0($t0)
    addiu $s4, $s4, 1

    jal draw_board
    j player_turn

player_bust:
    li $v0, 4
    la $a0, bustMsg
    syscall
    j exit_game

dealer_turn:
    # Dealer draws until reaching 17
    la $a0, dealerCards
    move $a1, $s5
    jal score_hand
    move $s1, $v0

    bge $s1, 17, compare_scores
    bge $s5, 5, compare_scores

    jal get_card
    la $t0, dealerCards
    sll $t1, $s5, 2
    addu $t0, $t0, $t1
    sw $v0, 0($t0)
    addiu $s5, $s5, 1

    jal draw_board
    j dealer_turn

compare_scores:
    li $v0, 4
    la $a0, dealerMsg
    syscall

    li $v0, 1
    move $a0, $s1
    syscall

    bgt $s1, 21, player_wins
    bgt $s0, $s1, player_wins
    bgt $s1, $s0, dealer_wins

    li $v0, 4
    la $a0, tieMsg
    syscall
    j exit_game

player_wins:
    li $v0, 4
    la $a0, winMsg
    syscall
    j exit_game

dealer_wins:
    li $v0, 4
    la $a0, loseMsg
    syscall

exit_game:
    li $v0, 10
    syscall


# Random card value from 2 through 11
get_card:
    li $a0, 0
    li $a1, 10
    li $v0, 42
    syscall
    addiu $v0, $a0, 2
    jr $ra


# Calculate hand total; Aces count as 1 or 11
# a0 = card array, a1 = card count
# Returns total in v0
score_hand:
    move $t0, $a0
    move $t1, $a1
    li $t2, 0              # Total
    li $t3, 0              # Number of aces
    li $t4, 0              # Index

score_loop:
    beq $t4, $t1, adjust_aces

    lw $t5, 0($t0)
    addu $t2, $t2, $t5

    li $t6, 11
    bne $t5, $t6, score_next
    addiu $t3, $t3, 1

score_next:
    addiu $t0, $t0, 4
    addiu $t4, $t4, 1
    j score_loop

adjust_aces:
    ble $t2, 21, score_done
    beq $t3, $zero, score_done

    addiu $t2, $t2, -10
    addiu $t3, $t3, -1
    j adjust_aces

score_done:
    move $v0, $t2
    jr $ra


# Draw green background and white card rectangles
draw_board:
    addiu $sp, $sp, -4
    sw $ra, 0($sp)

    # Clear 32x32 display units to green
    lui $t0, 0x1004
    li $t1, 1024
    li $t2, 0x00008800

clear_screen:
    sw $t2, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bgtz $t1, clear_screen

    # Dealer cards: blue markers
    move $a0, $s5
    li $a1, 3
    li $a2, 0x000000FF
    jal draw_cards

    # Player cards: red markers
    move $a0, $s4
    li $a1, 18
    li $a2, 0x00FF0000
    jal draw_cards

    lw $ra, 0($sp)
    addiu $sp, $sp, 4
    jr $ra


# Draw white cards with colored center pixels
# a0 = card count, a1 = starting y, a2 = marker color
draw_cards:
    move $t1, $a0           # Number of cards
    move $t2, $a1           # Starting y
    move $t3, $a2           # Marker color
    li $t0, 0               # Card index

card_loop:
    beq $t0, $t1, cards_done

    # x = 1 + card_index * 6
    sll $t4, $t0, 2
    sll $t8, $t0, 1
    addu $t4, $t4, $t8
    addiu $t4, $t4, 1

    li $t5, 0               # y offset

card_y:
    li $t6, 0               # x offset

card_x:
    # Address = base + 4*((y*32)+x)
    addu $t7, $t2, $t5
    sll $t7, $t7, 5
    addu $t7, $t7, $t4
    addu $t7, $t7, $t6
    sll $t7, $t7, 2

    lui $t8, 0x1004
    addu $t7, $t7, $t8

    li $t8, 0x00FFFFFF
    sw $t8, 0($t7)

    addiu $t6, $t6, 1
    blt $t6, 4, card_x

    addiu $t5, $t5, 1
    blt $t5, 7, card_y

    # Colored pixel in center of card
    addiu $t7, $t2, 3
    sll $t7, $t7, 5
    addiu $t8, $t4, 1
    addu $t7, $t7, $t8
    sll $t7, $t7, 2

    lui $t8, 0x1004
    addu $t7, $t7, $t8
    sw $t3, 0($t7)

    addiu $t0, $t0, 1
    j card_loop

cards_done:
    jr $ra
