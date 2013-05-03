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

   # 3.5" double sided high density floppy

   iSectSize:     .word   0x200         # bytes per sector (0x200h = 512)
   iTrackSect:    .word   18            # sectors per track
   iHeadCnt:      .word   2             # number of read-write heads (2 = double sided)
   

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

bootFailureMsg: .asciz "Failed to boot OS!  Bad juju! :'("

.func bootFailure

bootFailure:

   lea  si, bootFailureMsg
   call printStr
   hlt

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

# Read sector with logical address (LBA) AX into data
# buffer at ES:BX. This function uses interrupt 13h, subfunction ah=2.

.func readSector

readSector:

   xor     cx, cx                      # Set try count = 0

readsect:

   push    ax                          # Store logical block
   push    cx                          # Store try number
   push    bx                          # Store data buffer offset

   # Calculate cylinder, head and sector:
   # Cylinder = (LBA / SectorsPerTrack) / NumHeads
   # Sector   = (LBA mod SectorsPerTrack) + 1
   # Head     = (LBA / SectorsPerTrack) mod NumHeads

   mov     bx, iTrackSect              # Get sectors per track
   xor     dx, dx
   div     bx                          # Divide (dx:ax/bx to ax,dx)
                                       # Quotient (ax) =  LBA / SectorsPerTrack
                                       # Remainder (dx) = LBA mod SectorsPerTrack
   inc     dx                          # Add 1 to remainder, since sector
   mov     cl, dl                      # Store result in cl for int 13h call.

   mov     bx, iHeadCnt                # Get number of heads
   xor     dx, dx
   div     bx                          # Divide (dx:ax/bx to ax,dx)
                                       # Quotient (ax) = Cylinder
                                       # Remainder (dx) = head
   mov     ch, al                      # ch = cylinder                      
   xchg    dl, dh                      # dh = head number

   # Call interrupt 0x13, subfunction 2 to actually
   # read the sector.
   # al = number of sectors
   # ah = subfunction 2
   # cx = sector number
   # dh = head number
   # dl = drive number
   # es:bx = data buffer
   # If it fails, the carry flag will be set.
   mov     ax, 0x0201                  # Subfunction 2, read 1 sector
   mov     dl, iBootDrive              # from this drive
   pop     bx                          # Restore data buffer offset.
   int     0x13
   jc      readfail

   # On success, return to caller.
   pop     cx                          # Discard try number
   pop     ax                          # Get logical block from stack
   ret

   # The read has failed.
   # We will retry four times total, then jump to boot failure.

readfail:   

   pop     cx                          # Get try number             
   inc     cx                          # Next try
   cmp     cx, word ptr 4              # Stop at 4 tries
   je      bootFailure

   # Reset the disk system:
   call resetFloppy

   # Get logical block from stack and retry.
   pop     ax
   jmp     readsect

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

