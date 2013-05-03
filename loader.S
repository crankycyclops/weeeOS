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

   iOEM:          .asciz  "WeeeeeOS"    # name of the OS
   iBootDrive:    .byte   0             # drive the boot sector came from

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

rebootmsg:  .asciz  "\nPress any key to reboot\r\n"

.func reboot

reboot:

   lea    si, rebootmsg
   call   printStr
   xor    ax, ax           # subfuction 0
   int    0x16             # call bios to wait for key

   ljmp   0xffff:0x0000    #reboot

.endfunc

################################################################################

diskResetFailureMsg: .asciz "Danger, Will Robinson: Failed to init floppy drive!"

.func resetFloppy

resetFloppy:

   mov  dl, iBootDrive     # drive to reset
   xor  ax, ax             # subfunction 0
   int  0x13               # call interrupt 13h
   jc   diskResetFailure   # display error message if carry set (error)

   retw

diskResetFailure:

   # let the user know there was a floppy error and halt the CPU
   lea si, diskResetFailureMsg
   call printStr
   hlt

.endfunc

################################################################################

start:

   # Print the name of the OS
   lea si, iOEM
   call printStr

   # Initialize segment registers
   cli
   mov  iBootDrive, dl  # save what drive we booted from (should be 0x0)
   mov  ax, cs          # CS = 0x0, since that's where boot sector is (0x07c00)
   mov  ds, ax          # DS = CS = 0x0
   mov  es, ax          # ES = CS = 0x0
   mov  ss, ax          # SS = CS = 0x0
   mov  sp, 0x7c00      # Stack grows down from offset 0x7C00 toward 0x0000.
   sti

   # init the floppy disk drive
   call resetFloppy

   # we don't actually do anything yet...
   call reboot

################################################################################

.fill (510-(.-main)), 1, 0   # Pad with nulls up to 510 bytes (excl. boot magic)
BootMagic:  .int 0xAA55      # magic word for BIOS

