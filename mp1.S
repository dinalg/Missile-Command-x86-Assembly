
# mp1.S - missile-command version
# Good luck, and have fun!

.data
	
    # Constants for accessing the fields of a struct missile, 
    # struct missile is defined in rtc.h and mp1.h

	NEXT 	  = 0
	X	  = 4
	Y	  = 8
	VX	  = 12
	VY	  = 16
	DEST_X	  = 20
	DEST_Y	  = 24
	EXPLODED  = 28
	C	  = 32

    # Character to draw for an explosion - '@'

	EXPLOSION = 64

	BIT_SHIFT_AMOUNT = 16

	X_SCREEN_BOUND = 79
	Y_SCREEN_BOUND = 24

	ROW_SCALE = 160
	COLUMN_SCALE = 2

	CROSSHAIR_CHAR = 43

	START_X = 40
	START_Y = 12

	ALIVE_START = 0x00FFFFFF

	MALLOC_SIZE = 33

# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list:	.long 0x0	# Head of list pointer
base_alive:		.long 0x0	# Array of 3 bytes, plus a padding byte
mp1_score:		.long 0x0	# Player's current score


# Data private to this  file

base_pic:     	    .string "/^^^\\"	# Picture of a live base
dead_base_pic: 	    .string "xxxxx"	# Picture of a dead base
crosshairs_x:		.long 0x0	# X-position of the crosshairs
crosshairs_y:		.long 0x0	# Y-position of the crosshairs

.text

# void mp1_poke(void);
# You can use this function to write to video memory.
#
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX

mp1_poke:
		movl    vmem_base_addr(,1),%edx
		movb    %cl,(%edx,%eax,1)
		ret

#   ----------------- Exported functions ---------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#	(1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#	(2) Redraw the bases - they may have been overwritten with missiles
#	(3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet
mp1_rtc_tasklet:
	pushl %ebp
	movl %esp, %ebp

	pushl %eax
	pushl %ebx #holds current missile
	pushl %ecx #holds current missile's on-screen X position
	pushl %edx #holds current missile's on-screen Y position
	pushl %esi #holds current missile's X velocity
	pushl %edi #holds current missile's Y velocity

	call update_missiles

	popl %edi
	popl %esi
	popl %edx
	popl %ecx
	popl %ebx
	popl %eax


	pushl %eax
	pushl %ebx
	pushl %ecx
	pushl %edx
	pushl %esi
	pushl %edi

	call redraw_cities

	popl %edi
	popl %esi
	popl %edx
	popl %ecx
	popl %ebx
	popl %eax


	pushl %eax
	pushl %ebx
	pushl %ecx
	pushl %edx
	pushl %esi
	pushl %edi

	call redraw_crosshairs

	popl %edi
	popl %esi
	popl %edx
	popl %ecx
	popl %ebx
	popl %eax
		ret

# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function 
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

.globl mp1_ioctl
mp1_ioctl:
	movl 8(%esp), %eax	
	cmpl $4, %eax
	jg OTHER
	cmpl $0, %eax
	jl OTHER
	jmp *jump_table(,%eax,4) 
	jmp END

	OTHER:
		movl $-1, %eax

	END:
		ret


# ----------------- Functions private to this file -------------------

update_missiles:
	pushl %ebp
	movl %esp, %ebp

	movl mp1_missile_list, %ebx #puts head of linked list into ebx
	TRAVERSE_LINKED_LIST:
		pushl %ebx
		cmpl $0, %ebx #jumps to new subroutine if current missile is null
		je NO_MORE_MISSILES
		cmpl $0, EXPLODED(%ebx) #if exploded != 0, stop moving
		jne EXPLODE_MISSILE
		popl %ebx
		pushl %ebx
		movl X(%ebx), %ebx
		shrl BIT_SHIFT_AMOUNT, %ecx	#put missile's X position into ecx
		popl %ebx
		pushl %ebx
		movl Y(%ebx), %ebx
		shrl BIT_SHIFT_AMOUNT, %edx	#put missile's Y position into edx
		popl %ebx
		cmpl $0, %ecx	#checking if missile is within X bounds
		jl MISSILE_OUT	
		cmpl X_SCREEN_BOUND, %ecx
		jg MISSILE_OUT
		cmpl $0, %edx	#checking if missile is within Y bounds
		jl MISSILE_OUT
		cmpl Y_SCREEN_BOUND, %edx
		jg MISSILE_OUT
		cmpl %ecx, DEST_X(%ebx)	#checking if missile is at X destination
		je Y_DEST_MATCH
		jmp MOVE_MISSILE	#missile is free to move

	Y_DEST_MATCH:
		cmpl %edx, DEST_Y(%ebx)	#checking if missile is at Y destination
		je EXPLODE_MISSILE
		jmp MOVE_MISSILE	#missile is free to move

	MOVE_MISSILE:
		movl VX(%ebx), %esi	#puts X and Y velocities into registers
		movl VY(%ebx), %edi
		movl X(%ebx), %ecx
		movl Y(%ebx), %edx
		shrl BIT_SHIFT_AMOUNT, %ecx	#puts X and Y missile positions into registers
		shrl BIT_SHIFT_AMOUNT, %edx
		imull ROW_SCALE, %edx
		imull COLUMN_SCALE, %ecx
		addl %ecx, %eax	#loads eax with the offset from the start of video memory
		addl %edx, %eax
		movb $0, %cl	#loads NUL character to draw missile
		pushl %edx
		call mp1_poke	#draws NUL
		popl %edx
		addl %esi, X(%ebx)	#adding X and Y velocities to X and Y positions to "move" missile
		addl %edi, Y(%ebx)
		movl X(%ebx), %ecx
		movl Y(%ebx), %edx
		shrl BIT_SHIFT_AMOUNT, %edx
		shrl BIT_SHIFT_AMOUNT, %ecx
		imull ROW_SCALE, %ecx
		imull COLUMN_SCALE, %edx
		addl %ecx, %eax	#loads eax with the offset from the start of video memory
		addl %edx, %eax
		movb C(%ebx), %cl	#loads character to draw missile
		pushl %edx
		call mp1_poke	#draws character
		popl %edx

	PRINT_EXPLOSION:
		decl EXPLODED(%ebx)
		cmpl $0, EXPLODED(%ebx)	#decrement exploded value until it reaches 0
		jle NOT_EXPLODING
		movl X(%ebx), %ecx
		movl Y(%ebx), %edx
		shrl BIT_SHIFT_AMOUNT, %ecx
		shrl BIT_SHIFT_AMOUNT, %edx
		imull ROW_SCALE, %edx
		imull COLUMN_SCALE, %ecx
		addl %ecx, %eax	#loads eax with the offset from the start of video memory
		addl %edx, %eax
		movb EXPLOSION, %cl
		pushl %edx
		call mp1_poke	#draw missile explosion character
		popl %edx
		movl NEXT(%ebx), %ebx	#traverse to next missile
		jmp NEXT_MISSILE

	NOT_EXPLODING:
		movl X(%ebx), %ecx
		movl Y(%ebx), %edx
		shrl BIT_SHIFT_AMOUNT, %ecx
		shrl BIT_SHIFT_AMOUNT, %edx
		imull ROW_SCALE, %edx
		imull COLUMN_SCALE, %ecx
		addl %ecx, %eax	#loads eax with the offset from the start of video memory
		addl %edx, %eax
		movb $0, %cl
		pushl %edx
		call mp1_poke	#draw NUL on screen
		popl %edx
		jmp MISSILE_OUT	#remove missile

	EXPLODE_MISSILE:
		pushl %eax	#save all registers
		pushl %ebx
		pushl %ecx
		pushl %edx
		pushl %esi
		pushl %edi
		call missile_explode
		popl %edi	#restore registers
		popl %esi
		popl %edx
		popl %ecx
		popl %ebx
		popl %eax
		cmpl $0, %eax	#
		je PRINT_EXPLOSION
		call mp1_notify_user

	MISSILE_OUT:
		pushl %eax	#save all registers
		pushl %ebx
		pushl %ecx
		pushl %edx
		pushl %esi
		pushl %edi
		call mp1_missile_remove	#remove missile from screen
		popl %edi	#restore registers
		popl %esi
		popl %edx
		popl %ecx
		popl %ebx
		popl %eax
		jmp NEXT_MISSILE	#continue to next missile in list

	NEXT_MISSILE:
		cmpl $0, %ebx	#check if next missile is null, if not traverse list
		jne TRAVERSE_LINKED_LIST

	NO_MORE_MISSILES:	#linked list over
		leave
		ret

mp1_missile_remove:
	pushl %ebp
	movl %esp, %ebp
	movl mp1_missile_list, %ecx	#put start of linked list into ecx
	cmpl %ebx, %ecx
	jne FIND_MISSILE	#traverse list until we find the current missile in the linked list if first node isn't it
	jmp REMOVE_HEAD_OF_LIST

	FIND_MISSILE:
		movl NEXT(%ecx), %edx	#edx holds next missile in the list
		cmpl %ebx, %edx
		je REMOVE	#remove this missile if it matches ebx
		movl %edx, %ecx
		jmp FIND_MISSILE	#otherwise recurse until correct missile is found

	REMOVE_HEAD_OF_LIST:
		movl NEXT(%ebx), %edi
		movl %edi, mp1_missile_list
		movl mp1_missile_list, %ebx
		pushl %eax	#save all registers
		pushl %ebx
		pushl %ecx
		pushl %edx
		pushl %esi
		pushl %edi
		call mp1_free	#free the missile
		popl %edi	#restore registers
		popl %esi
		popl %edx
		popl %ecx
		popl %ebx
		popl %eax
		jmp DONE_REMOVING

	REMOVE:
		movl NEXT(%edx), %ebx
		movl %ebx, NEXT(%ecx)
		pushl %eax	#save all registers
		pushl %ebx
		pushl %ecx
		pushl %edx
		pushl %esi
		pushl %edi
		call mp1_free	#free the missile
		popl %edi	#restore registers
		popl %esi
		popl %edx
		popl %ecx
		popl %ebx
		popl %eax 
		jmp DONE_REMOVING

	DONE_REMOVING:
		leave
		ret

redraw_cities:
	pushl %ebp
	movl %esp, %ebp

		ret
		
redraw_crosshairs:
	pushl %ebp
	movl %esp, %ebp
	movl crosshairs_x, %ecx	#load X and Y positions of crosshair into registers
	movl crosshairs_x, %edx
	imull ROW_SCALE, %edx
	imull COLUMN_SCALE, %ecx
	addl %ecx, %eax	#scale up coordinates and add to offset (eax)
	addl %edx, %eax
	movb CROSSHAIR_CHAR, %cl
	pushl %edx
	call mp1_poke	#draws crosshair character, "+"
	popl %edx
		leave
		ret

mp1_ioctl_startgame:
	movl $0, mp1_missile_list
	movl ALIVE_START, base_alive
	movl $0, mp1_score
	movl START_X, crosshairs_x
	movl START_Y, crosshairs_y
		ret

mp1_ioctl_addmissile:
	pushl %ebp
	movl %esp, %ebp

	pushl %edx
	movl 8(%ebp), %ecx
	pushl MALLOC_SIZE
	call mp1_malloc
	addl $4, %esp
	movl %eax, %edx
	cmpl $0, %edx
	je FAILED
	pushl MALLOC_SIZE
	pushl %ecx
	pushl %edx
	call mp1_copy_from_user
	addl $12, %esp
	cmpl $0, %eax
	jne FAILED
	movl mp1_missile_list, %eax
	movl %eax, next(%ebx)
	movl %ebx, mp1_missile_list
	movl $0, %eax
	jmp ADDED

	FAILED:
		pushl %eax	#save all registers
		pushl %ebx
		pushl %ecx
		pushl %edx
		pushl %esi
		pushl %edi
		call mp1_free	#free the missile
		popl %edi	#restore registers
		popl %esi
		popl %edx
		popl %ecx
		popl %ebx
		popl %eax
		movl $-1, %eax
		addl $4, %esp

	ADDED:
		popl %edx
		leave
		ret


mp1_ioctl_movexhairs:
	movl 4(%esp), %esi
	shll BIT_SHIFT_AMOUNT, %esi
	sarl BIT_SHIFT_AMOUNT, %esi
	movl 4(%esp), %edi
	sarl BIT_SHIFT_AMOUNT, %edi
	movl crosshairs_x, %ecx
	movl crosshairs_y, %edx
	imull ROW_SCALE, %edx
	imull COLUMN_SCALE, %ecx
	addl %ecx, %eax
	addl %edx, %eax
	movb $0, %cl
	pushl %edx
	call mp1_poke
	popl %edx
	addl %esi, crosshairs_x
	addl %edi, crosshairs_y

	CHECK_BOUNDS:
	cmpl $0, crosshairs_x
	jl X_LOW_BOUND
	cmpl $0, crosshairs_y
	jg Y_LOW_BOUND
	cmpl $79, crosshairs_x
	jl X_HIGH_BOUND
	cmpl $24, crosshairs_y
	jg Y_HIGH_BOUND
	jmp REDRAW_DONE
	
	X_LOW_BOUND:
	movl $0, crosshairs_x
	jmp CHECK_BOUNDS
	Y_LOW_BOUND:
	movl $0, crosshairs_y
	jmp CHECK_BOUNDS
	X_HIGH_BOUND:
	movl $79, crosshairs_x
	jmp CHECK_BOUNDS
	Y_HIGH_BOUND:
	movl $24, crosshairs_y
	
	REDRAW_DONE:
		movl $0, %eax	#returns 0
		ret

mp1_ioctl_getstatus:
		ret

mp1_ioctl_endgame:
	movl mp1_missile_list, %edx

	TRAVERSE_LIST:
		cmpl $0, %edx
		jne CONTINUE
		ret

	CONTINUE:
		movl NEXT(%edx), %edx
		pushl mp1_missile_list
		pushl %eax	#save all registers
		pushl %ebx
		pushl %ecx
		pushl %edx
		pushl %esi
		pushl %edi
		call mp1_free	#free the missile
		popl %edi	#restore registers
		popl %esi
		popl %edx
		popl %ecx
		popl %ebx
		popl %eax 
		popl mp1_missile_list
		movl %edx, mp1_missile_list
		cmpl $0, mp1_missile_list
		jne TRAVERSE_LIST

jump_table:
	.long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame