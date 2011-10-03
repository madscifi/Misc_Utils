/*
 * SDRAM Access Routines for PIC32.
 * 
 * Retromaster - 10.05.2010
 * 
 * This file is in the public domain. You can use, modify, and distribute the source code
 * and executable programs based on the source code. This file is provided "as is" and 
 * without any express or implied warranties whatsoever. Use at your own risk!
 *
 * Additional changes implemented by JMcGee. 
 */


/* Also see the accompanying C header file to find out about all exposed functions and their parameters. 
 */
 
/* SDRAM Pin to PIC32 Pin Mapping:
 * 
 * SDRAM	              PIC32
 * ------	              ------
 *     A0(23), DQ0(2)	  RB0
 *     A1(24), DQ2(5)	  RB1
 *     A2(25), DQ4(8)     RB2
 *     A3(26), DQ6(11)    RB3
 *     A4(29), DQ9(44)    RB4
 *     A5(30), DQ11(47)   RB5
 *     A6(31), DQ13(50)   RB6
 *     A7(32), DQ15(53)   RB7
 *     A8(33), DQ1(4)     RB8
 *     A9(34), DQ3(7)     RB9
 *    A10(22), DQ5(10)    RB10
 *    A11(35), DQ7(13)    RB11
 *    A12(??), DQ8(42)    RB12
 *    BA0(20), DQ10(45)   RB13
 *    BA1(21), DQ12(48)   RB14
 *             DQ14(51)   RB15
 *
 *    CLK(38)	          OC4-RD3
 *    CKE(37)	          A10
 *     CS(19)	          RF4
 *     WE(16)	          RF0
 *    CAS(17)	          RF1
 *    RAS(18)             RF5
 *
 * Remarks: The mapping above was primarily chosen in order to allow the
 * same pcb board to be used with either 8 or 16 bit SDRAM chips in the 
 * TSOP II (54 pin) form. Note that sharing the data and address lines
 * means that 1 out of every 4 or 8 (depending on the burst length) words
 * is not useable. If you only intend to use 16 bit SDRAM chips the 
 * connections between the address and DQ pins can be scrambled with
 * issue (although the connections between the A and BA pins and the PIC
 * must remain as shown.
 *
 * As coded, 4 word bursts are used. It is the responsibility of the caller
 * to make certain the row and column addresses are valid for the SDRAM
 * chip in question.
 *
 * NOTE: This code has not been tested yet. I need to rewire my testbed first.
 * Also, the C code included has not been modified for this version of the
 * code (it is based on a version that assumes separate data and address lines).
 */


// ----------------------

#define NOP_OP_OFFSET 0x0
#define CLR_OP_OFFSET 0x4
#define SET_OP_OFFSET 0x8
#define INV_OP_OFFSET 0xc

#define TRIS_OFFSET   0x0
#define PORT_OFFSET   0x10
#define LAT_OFFSET    0x20
#define ODCF_OFFSET   0x30

#define SDR_OFFSET_A 0
#define SDR_OFFSET_B 0x40
#define SDR_OFFSET_C 0x80
#define SDR_OFFSET_D 0xc0
#define SDR_OFFSET_E 0x100
#define SDR_OFFSET_F 0x140
#define SDR_OFFSET_G 0x180


/* SDR_ADDRESS_IO should be set to the SDR_OFFSET_X representing the 
   port to be used for the address/data lines. The address lines
   must start at bit 0 and they must be continous. */
   
#define SDR_ADDRESS_IO SDR_OFFSET_B
#define ADDRESS_MASK 0x1fff
#define ADDRESS_PRECHARGE_CONTROL_BIT 10

#define SDR_BANK_IO SDR_OFFSET_B
#define BANK_0_BIT 13
#define BANK_1_BIT 14


#define SDR_CONTROL_IO SDR_OFFSET_F
#define CONTROL_WE_BIT 0
#define CONTROL_CAS_BIT 1
#define CONTROL_CS_BIT 4
#define CONTROL_RAS_BIT 5



#define SDR_CKE_IO SDR_OFFSET_A
#define CKE_BIT 10

#define CONTROL_ALL_MASK ( (1<<CONTROL_CS_BIT) | (1<<CONTROL_RAS_BIT) | (1<<CONTROL_CAS_BIT) | (1<<CONTROL_WE_BIT) )
#define BANK_ALL_MASK ( (1 << BANK_1_BIT) | ( 1 << BANK_0_BIT ) )



#include <p32xxxx.h>

    /* Global Symbols */
    .globl sdram_init
    .globl sdram_read
    .globl sdram_write
    .globl sdram_active
    .globl sdram_auto_refresh
    .globl sdram_precharge
    .globl sdram_precharge_all
    .globl sdram_sleep
    .globl sdram_wake
    .globl sdram_bank
	
	.type sdram_init, @function
	.type sdram_read, @function
	.type sdram_write, @function
	.type sdram_active, @function
	.type sdram_auto_refresh, @function
	.type sdram_precharge, @function
	.type sdram_precharge_all, @function
	.type sdram_sleep, @function
	.type sdram_wake, @function
	.type sdram_bank, @function

    /* All SDRAM access functions must run from the RAM.
     * Flash memory wait states may interfere with the 
     * precise timing required.
     */
    /*.section .ramfunc.*,"ax",@progbits*/
    .section .ramfunc,"ax",@progbits

    /* No instruction reordering */
    .set noreorder

#define clock4 \
    nop;nop;nop;nop
#define clock3 \
    nop;nop;nop
#define clock2 \
    nop;nop
#define clock1 \
    nop

/* The SDRAM clock is output from the output compare unit. 
 * This macro synchronizes with that clock so that we are
 * sure to have at least two clock cycles to issue control 
 * line changes and access the data bus before the rising
 * edge.
 */
 
#if 0
#define sync_clock \
	la	t8, TMR2; \
	la  v0, 1f; \
	lw	v1, (t8); \
	and V1, 0x3; \
	sll v1, 2; \
	sub v0, v1; \
	jr	v0; \
	nop; \
	nop; \
	nop; \
	nop; \
	nop; \
1:	nop; 
#endif


#define sync_clock \
    la		t8, TMR2;      \
    li 		v0, 2;	        \
    lw 		v1, (t8);     \
    bge 	v1, v0, 1f;   \
    nop;	                \
    nop;	                \
    nop;	                \
1:      	                \
    nop;							 



	
	/*.ent sdram_init*/
/* Initializes the SDRAM. */
sdram_init:

    /* Initialize address lines */
	la		t0, TRISA	/* base of io addresses */
	li		t1, ADDRESS_MASK
	sw		t1, SDR_ADDRESS_IO + TRIS_OFFSET + CLR_OP_OFFSET(t0)
	
    li 		t1, 0xFFFF
    sw 		t1, AD1PCFGSET
	
    li 		t1, BANK_ALL_MASK 
    sw 		t1, SDR_BANK_IO + TRIS_OFFSET + CLR_OP_OFFSET(t0)  

    /* All address lines low */
	li		t1, ADDRESS_MASK
    sw 		t1, SDR_ADDRESS_IO + LAT_OFFSET + CLR_OP_OFFSET(t0)
	
    li 		t1, BANK_ALL_MASK 
    sw 		t1, SDR_BANK_IO + LAT_OFFSET + CLR_OP_OFFSET(t0)

    /* Initialize data lines */
//    li 		t1, 0xFF
//    sw 		t1, SDR_DATA_IO + TRIS_OFFSET + SET_OP_OFFSET(t0)

    /* Initialize SDRAM control lines */
    li 		t1, CONTROL_ALL_MASK 
    sw 		t1, SDR_CONTROL_IO + TRIS_OFFSET + CLR_OP_OFFSET(t0)

    /* Command Inhibit */
    li 		t1, CONTROL_ALL_MASK 
    sw 		t1, SDR_CONTROL_IO + LAT_OFFSET + SET_OP_OFFSET(t0)

    /* Initialize CKE line */
    li 		t1, (1<<CKE_BIT) 
    sw 		t1, SDR_CKE_IO + TRIS_OFFSET + CLR_OP_OFFSET(t0)
    
    /* CKE low */
    li 		t1, (1<<CKE_BIT) 
    sw 		t1, SDR_CKE_IO + LAT_OFFSET + CLR_OP_OFFSET(t0)

    /* SDRAM clock output */
    
    /* Initialize Timer2 */
    sw 		zero, T2CON
    sw 		zero, TMR2
    li		t1, 3
    sw		t1, PR2	
    li		t1, 0x8000
    sw 		t1, T2CONSET	

    /* Initialize OC4 */
    sw 		zero, OC4CON		
    li		t1, 1
    sw		t1, OC4RS		
    li		t1, 3
    sw		t1, OC4R		
    li		t1, 0x8005
    sw 		t1, OC4CON		

    /* Clock output starts here */

    /* SD-RAM initialization delay */
    li		t2, 500
    move	t1, zero
        
sdram_init_delay_1:
    addi	t1, t1, 1
    bne		t1, t2, sdram_init_delay_1
    nop

    /* CKE high */
    li 		t1, (1<<CKE_BIT) 
    sw 		t1, SDR_CKE_IO + LAT_OFFSET + SET_OP_OFFSET(t0)

    /* Delay some more */
    li		t2, 3000
    move	t1, zero
        
sdram_init_delay_2:
    addi	t1, t1, 1
    bne		t1, t2, sdram_init_delay_2
    nop

    /* Get ready for the commands we are about to issue. */
    li 		t4, (1<<CONTROL_CAS_BIT) 	
    li 		t5, (1<<CONTROL_WE_BIT) 
    li 		t6, 0x22			/* Mode Register: CL:2, BL:4 (0x22) */
    li 		t7, CONTROL_ALL_MASK 
    li 		a0, (1<<ADDRESS_PRECHARGE_CONTROL_BIT)	/* A10 */

    sw		a0, SDR_ADDRESS_IO + LAT_OFFSET + SET_OP_OFFSET(t0) /* A10 = 1 for Precharge ALL */

    sync_clock
	
	.set nomacro

    /* Precharge All */
    sw		t7, SDR_CONTROL_IO + LAT_OFFSET + CLR_OP_OFFSET(t0) /* LLLL */
    sw		t4, SDR_CONTROL_IO + LAT_OFFSET + SET_OP_OFFSET(t0) /* LLHL */
    clock2
    /* Auto Refresh 1 */
    sw		t4, SDR_CONTROL_IO + LAT_OFFSET + CLR_OP_OFFSET(t0) /* LLLL */
    sw		t5, SDR_CONTROL_IO + LAT_OFFSET + SET_OP_OFFSET(t0) /* LLLH */
    clock2
    /* Auto Refresh 2 */
    clock4
    /* Auto Refresh 3 */
    clock4
    /* Auto Refresh 4 */
    clock4
    /* Auto Refresh 5 */
    clock4
    /* Auto Refresh 6 */
    clock4
    /* Auto Refresh 7 */
    clock4
    /* Auto Refresh 8 */
	li		t4, ADDRESS_MASK
	sw		t4, SDR_ADDRESS_IO + LAT_OFFSET + CLR_OP_OFFSET(t0)
	clock2
    /* Load Mode Register */
	sw		t6, SDR_ADDRESS_IO + LAT_OFFSET + SET_OP_OFFSET(t0)
	sw		t7, SDR_CONTROL_IO + LAT_OFFSET + CLR_OP_OFFSET(t0)
    clock2
    /* Command Inhibit */
	sw		t7, SDR_CONTROL_IO + LAT_OFFSET + SET_OP_OFFSET(t0)
    clock3 
    /* Command Inhibit */
    clock4
	
	.set macro
	
    /* Return */
    jr		ra
    nop

	/*.end sdram_init*/


/* Sends ACTIVE command */
sdram_active:

    /* Get ready. */
    la 		t0, TRISA		/* Port Base */
    li 		t7, (1<<CONTROL_CS_BIT)|(1<<CONTROL_RAS_BIT) 

    /* Set row */
	//output_address
	lw      t1, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)
	and     t1, ADDRESS_MASK
	or      t1, a0
	sw      t1, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)
	
    sync_clock
	
	.set nomacro 
	
    /* Active */
    sw		t7, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0)
    clock3
    /* Command Inhibit */
    sw		t7, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0)
    clock3
    /* Command Inhibit */
    clock4

	.set macro
	
    /* Return */
    jr		ra
    nop
	

/* Sends WRITE command */
sdram_write:

    /* Get ready. */
    la 		t0, TRISA		/* Port Base */
    li 		t4, 0xFF
    li 		t7, (1<<CONTROL_CS_BIT) | (1<<CONTROL_CAS_BIT) | (1<<CONTROL_WE_BIT) 

    /* Set column */
	//output_column
	lw      v0, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)
	and     v0, ADDRESS_MASK
	or      v0, a0
	sw      v0, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)

    /* Set data lines */
    //srl 	t5, a2, 24
    //sb		t5, SDR_DATA_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)
	
    sync_clock	
	
	.set nomacro 
	
    /* Write */
    sw		t7, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0) /* LHLL */
    //srl 	t5, a2, 16
    //clock2
	clock3
    /* Command Inhibit */
    sw		t7, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0) /* HHHH */
    sh		a2, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)    /* 2 */
    srl 	t5, a2, 16
    clock1
    /* Command Inhibit */
    sh		t5, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)    /* 3 */
    clock3
    /* Command Inhibit */
    sh		a3, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)    /* 4 */
    //srl 	t5, a3, 16
    clock3
	
	#if 0
    /* Command Inhibit */
    sb		t5, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)    /* 5 */
    srl 	t5, a3, 16
    clock2
    /* Command Inhibit */
    sb		t5, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)    /* 6 */
    srl 	t5, a3, 8
    clock2
    /* Command Inhibit */
    sb		t5, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)    /* 7 */
    clock3
    /* Command Inhibit */
    sb		a3, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)    /* 8 */
    clock3
	#endif
	
	sw      v0, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)	/* restore address lines */

	.set macro
	
    /* Return */
    jr		ra
    nop


/* Sends READ command */
sdram_read:

    /* Get ready. */
    la 		t0, TRISA		/* Port Base */
	li		t1, 0xffff
    li 		t7, (1<<CONTROL_CS_BIT) | (1<<CONTROL_CAS_BIT) 

    /* Set column */
	//output_column
	lw      v0, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)
	and     v0, ADDRESS_MASK
	or      v0, a0
	sw      v0, SDR_ADDRESS_IO + LAT_OFFSET + NOP_OP_OFFSET(t0)

    sync_clock

	.set nomacro 
	
    /* Read */
    sw		t7, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0) /* LHLH */
    clock3
    /* Command Inhibit */
	sw		t1, SDR_ADDRESS_IO + TRIS_OFFSET + INV_OP_OFFSET(t0) /* make all address lines input */
    sw		t7, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0) /* HHHH */
    clock2
    /* Command Inhibit */
    //clock3                                                             /* 1 - ignore as it contains the col address */
    //lbu		v0, SDR_ADDRESS_IO + PORT_OFFSET + NOP_OP_OFFSET(t0)       /* 1 */
	clock4 /* 1 - ignore as it contains the column address, not any useful data */
    /* Command Inhibit */
    clock3
    lhu		v0, SDR_ADDRESS_IO + PORT_OFFSET + NOP_OP_OFFSET(t0)       /* 2 */
    /* Command Inhibit */
    //sll		v0, v0, 8
    //or		v0, v0, t5
    //clock1
	clock3
    lhu		t5, SDR_ADDRESS_IO + PORT_OFFSET + NOP_OP_OFFSET(t0)       /* 3 */
    /* Command Inhibit */
    sll		t5, t5, 16
    or		v0, v0, t5
    clock1
    lhu		v1, SDR_ADDRESS_IO + PORT_OFFSET + NOP_OP_OFFSET(t0)       /* 4 */
	#if 0
    /* Command Inhibit */
    sll		v0, v0, 8
    or		v0, v0, t5
    clock1
    lbu		v1, SDR_ADDRESS_IO + PORT_OFFSET + NOP_OP_OFFSET(t0)       /* 5 */	
    /* Command Inhibit */
    clock3
    lbu		t5, SDR_ADDRESS_IO + PORT_OFFSET + NOP_OP_OFFSET(t0)       /* 6 */	
    /* Command Inhibit */
    sll		v1, v1, 8
    or		v1, v1, t5
    clock1
    lbu		t5, SDR_ADDRESS_IO + PORT_OFFSET + NOP_OP_OFFSET(t0)       /* 7 */	
    /* Command Inhibit */
    sll		v1, v1, 8
    or		v1, v1, t5
    clock1
    lbu		t5, SDR_ADDRESS_IO + PORT_OFFSET + NOP_OP_OFFSET(t0)       /* 8 */		
    /* Command Inhibit */
    sll		v1, v1, 8
    or		v1, v1, t5
	#endif
	nop
	sw		t1, SDR_ADDRESS_IO + TRIS_OFFSET + INV_OP_OFFSET(t0)    /* make all address lines output again */

	.set macro 
	
    /* Return */
    jr		ra
    nop


/* Sends PRECHARGE ALL command */
sdram_precharge_all:

    /* Get ready. */
    la 		t0, TRISA		/* Port Base */
    li 		t3, (1<<ADDRESS_PRECHARGE_CONTROL_BIT)		/* A10 */
    li 		t4, (1<<CONTROL_CS_BIT) | (1<<CONTROL_RAS_BIT) | (1<<CONTROL_WE_BIT)

    sw		t3, SDR_ADDRESS_IO + LAT_OFFSET + SET_OP_OFFSET(t0) /* A10 = 1 for Precharge ALL */

    sync_clock
	
	.set nomacro
	
    /* Precharge All */
    sw		t4, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0) /* LLHL */
    clock3
    /* Command Inhibit */
    sw		t4, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0) /* LLLL */
    clock3

	.set macro 
	
    /* Return */
    jr		ra
    nop


/* Sends PRECHARGE command */
sdram_precharge:
    
    /* Get ready. */
    la 		t0, TRISA		/* Port Base */
    li 		t3, (1<<ADDRESS_PRECHARGE_CONTROL_BIT)		/* A10 */
    li 		t4, (1<<CONTROL_CS_BIT) | (1<<CONTROL_RAS_BIT) | (1<<CONTROL_WE_BIT) 

    sw		t3, SDR_ADDRESS_IO + LAT_OFFSET + CLR_OP_OFFSET(t0) /* A10 = 0 for Precharge */

    sync_clock
	
	.set nomacro
	
    /* Precharge All */
    sw		t4, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0) /* LLHL */
    clock3
    /* Command Inhibit */
    sw		t4, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0) /* LLLL */
    clock3

	.set macro
	
    /* Return */
    jr		ra
    nop


/* Sends AUTO REFRESH command */
/* All banks must be in PRECHARGEd state */
sdram_auto_refresh:

    /* Get ready. */
    la 		t0, TRISA		/* Port Base */
    li 		t4, (1<<CONTROL_CS_BIT)|(1<<CONTROL_RAS_BIT)|(1<<CONTROL_CAS_BIT) 

    sync_clock
	
	.set nomacro 
	
    /* Auto Refresh */
    sw		t4, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0) /* LLLH */
    clock3
    /* Command Inhibit */
    sw		t4, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0) /* LLLL */
    clock3

	.set macro
	
    /* Return */
    jr		ra
    nop

/* Puts the SDRAM into the self refresh mode. */
/* SDRAM retains data in this state. */
sdram_sleep:

    /* Get ready. */
    la 		t0, TRISA		/* Port Base */
    li 		t1, (1<<CKE_BIT) 
    li 		t4, (1<<CONTROL_CS_BIT)|(1<<CONTROL_RAS_BIT)|(1<<CONTROL_CAS_BIT) 

    sync_clock
	
	.set nomacro
	
    /* Auto Refresh */
    sw		t4, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0) /* LLLH */
    sw 		t1, SDR_CKE_IO + LAT_OFFSET + CLR_OP_OFFSET(t0)     /* CKE low */
    clock2
    /* Command Inhibit */
    sw		t4, SDR_CONTROL_IO + LAT_OFFSET + INV_OP_OFFSET(t0) /* LLLL */
    clock3

	.set macro
	
    /* Return */
    jr		ra
    nop

/* Takes the SDRAM out of the self refresh mode. */
sdram_wake:

    /* Get ready. */
    la 		t0, TRISA		/* Port Base */
    li 		t1, (1<<CKE_BIT) 

    sync_clock
	
	.set nomacro
	
    /* Command Inhibit */
    sw 		t1, SDR_CKE_IO + LAT_OFFSET + SET_OP_OFFSET(t0) /* CKE low */
    clock3
    /* Command Inhibit */
    clock4
    /* Command Inhibit */
    clock4

	.set macro
	
    /* Return */
    jr		ra
    nop


/* Selects the bank to which commands are issued */
sdram_bank:
    
    la 		t0, TRISA			/* Port Base */
	lw		t1, SDR_BANK_IO + LAT_OFFSET + NOP_OP_OFFSET(t0);
	and		t1, ~BANK_ALL_MASK
	sll     t2, a0, BANK_0_BIT
	or      t1, t2
	sw      t1, SDR_BANK_IO + LAT_OFFSET + NOP_OP_OFFSET(t0);
	
    /* Return */
    jr		ra
    nop
