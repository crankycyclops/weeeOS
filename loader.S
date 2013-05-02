.code16
.intel_syntax noprefix
.text
.org 0x0                   # Passing -Ttext 0x7c00 to ld

.global main

main:

   jmp short start
   nop

################################################################################

data:

   iOEM:   .asciz "WeeeeeOS"

################################################################################

.func printStr

printStr:

   lodsb                   # load byte at ds:si into al (advancing si)
   or     al, al           # test if character is 0 (end of null-terminated string)
   jz     printStr_done    # jump to end if 0.
 
   mov    ah, 0xe          # Subfunction 0xe of int 10h (video teletype output)
   mov    bx, 9            # Set bh (page nr) to 0, and bl (attribute) to white (9)
   int    0x10             # call BIOS interrupt.
 
   jmp    printStr         # Repeat for next character.

printStr_done:

   retw

.endfunc

################################################################################

start:

   # Print the name of the OS
   lea si, iOEM
   call printStr

   # disable interrupts and halt the CPU
   cli
   hlt

################################################################################

.fill (510-(.-main)), 1, 0   # Pad with nulls up to 510 bytes (excl. boot magic)
BootMagic:  .int 0xAA55      # magic word for BIOS

