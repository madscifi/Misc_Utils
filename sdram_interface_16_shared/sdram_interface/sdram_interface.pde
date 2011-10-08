// pic32 project, ubw32 board

#include "plib.h"
#include "sdram.h"
#include <stdint.h>

    #define DEMO_BOARD UBW32

    /** LED ************************************************************/
    #define mInitAllLEDs()      LATE |= 0x000F; TRISE &= 0xFFF0;
    
    #define mLED_1              LATEbits.LATE3
    #define mLED_2              LATEbits.LATE2
    #define mLED_3              LATEbits.LATE1
    #define mLED_4              LATEbits.LATE0

/*
    #define mGetLED_1()         mLED_1
    #define mGetLED_USB()       mLED_1
    #define mGetLED_2()         mLED_2
    #define mGetLED_3()         mLED_3
    #define mGetLED_4()         mLED_4
*/
    #define mLED_1_On()         mLED_1 = 0;
    #define mLED_USB_On()       mLED_1 = 0;
    #define mLED_2_On()         mLED_2 = 0;
    #define mLED_3_On()         mLED_3 = 0;
    #define mLED_4_On()         mLED_4 = 0;
    
    #define mLED_1_Off()        mLED_1 = 1;
    #define mLED_USB_Off()      mLED_1 = 1;
    #define mLED_2_Off()        mLED_2 = 1;
    #define mLED_3_Off()        mLED_3 = 1;
    #define mLED_4_Off()        mLED_4 = 1;
/*
    #define mLED_1_Toggle()     mLED_1 = !mLED_1;
    #define mLED_USB_Toggle()   mLED_1 = !mLED_1;
    #define mLED_2_Toggle()     mLED_2 = !mLED_2;
    #define mLED_3_Toggle()     mLED_3 = !mLED_3;
    #define mLED_4_Toggle()     mLED_4 = !mLED_4;
*/ 
    /** SWITCH *********************************************************/
    #define mInitSwitch2()      TRISEbits.TRISE7=1;
    #define mInitSwitch3()      TRISEbits.TRISE6=1;
    #define mInitAllSwitches()  mInitSwitch2();mInitSwitch3();
    #define swProgram           PORTEbits.RE7
    #define swUser              PORTEbits.RE6

// NOTE THAT BECAUSE WE USE THE BOOTLOADER, NO CONFIGURATION IS NECESSARY
// THE BOOTLOADER PROJECT ACTUALLY CONTROLS ALL OF OUR CONFIG BITS

// Let compile time pre-processor calculate the CORE_TICK_PERIOD
#define SYS_FREQ 		(80000000L)
#define TOGGLES_PER_SEC		1000
#define CORE_TICK_RATE	       (SYS_FREQ/2/TOGGLES_PER_SEC)


#define BLOCK_SIZE_BYTES 512
#define RAM_WIDTH_BYTES 2

#define RAM_COLS 512
#define RAM_ROWS 4096

// NOTE: Only bank 0 works at present.
#define RAM_BANKS 4

#define RAM_BURST_COUNT 4
#define RAM_BURST_GROUP_COUNT 8  

#define BLOCK_SIZE_COLS ( BLOCK_SIZE_BYTES / RAM_WIDTH_BYTES )
#define BLOCKS_PER_ROW ( RAM_COLS / BLOCK_SIZE_COLS )

#if RAM_COLS < BLOCK_SIZE_BYTES / RAM_WIDTH_BYTES
#error unsupported configuration - a single block must fit into a single RAM row
#endif


#if 0
// The original sdram functions mentioned the necessity of
// a dummy ram function in order to get the loader to put
// the asm functions in ram. This does not appear necessary
// in this environment.
__longramfunc__ void dummy_ram_function()
{
}
#endif

// Decriments every 1 ms.
volatile static uint32_t OneMSTimer;

uint32_t data_out[128];
uint32_t data_in[128];

bool IsEqual()
{
  for( int i =0; i < 128; i++ )
  {
    if( data_out[i] != data_in[i] ) return false;
  }
  return true;
}

volatile int gWasteTime;

bool ReadBlockFromSdram( void* dest, unsigned int blockNumber )
{
  char * pDest = (char *)dest;
  
  if( blockNumber < 0 || blockNumber >= RAM_ROWS * RAM_BANKS * BLOCKS_PER_ROW ) return false;

  int startColumn = ( ( blockNumber & ( BLOCKS_PER_ROW - 1 ) ) * BLOCK_SIZE_COLS );
  int rowAndBank = blockNumber / BLOCKS_PER_ROW;
  int row = rowAndBank & ( RAM_ROWS - 1 );
  int bank = rowAndBank / RAM_ROWS;
  
  int col = startColumn;
  while( col < startColumn + BLOCK_SIZE_COLS )
  {
      INTDisableInterrupts();
      sdram_wake();
      sdram_bank(bank);
      sdram_active(row);
      for( int i = 0; i < RAM_BURST_GROUP_COUNT; i++ )
      {
          sdram_read( col, pDest );
          col += RAM_BURST_COUNT; 
          pDest += RAM_BURST_COUNT * RAM_WIDTH_BYTES;
      }
      sdram_precharge();
      sdram_precharge_all();
      sdram_sleep();
      INTEnableInterrupts();
      
      gWasteTime++;
      gWasteTime++;
      gWasteTime++;
  } 
  return true; 
}

bool WriteBlockToSdram( const void* src, unsigned int blockNumber )
{
  char * pSrc = (char *)src;
  
  if( blockNumber < 0 || blockNumber >= RAM_ROWS * RAM_BANKS * BLOCKS_PER_ROW ) return false;

//  int startColumn = ( ( blockNumber & ( BLOCKS_PER_ROW - 1 ) ) * BLOCK_SIZE_COLS );
  unsigned int startColumn = ( blockNumber & 1 ) << 8;
  int rowAndBank = blockNumber / BLOCKS_PER_ROW;
  int row = rowAndBank & ( RAM_ROWS - 1 );
  int bank = rowAndBank / RAM_ROWS;
  
  int col = startColumn;
  while( col < startColumn + BLOCK_SIZE_COLS )
  {
      INTDisableInterrupts();
      sdram_wake();
      sdram_bank(bank);
      sdram_active(row);
      for( int i = 0; i < RAM_BURST_GROUP_COUNT; i++ )
      {
          LATB = 0x101;
          LATB = 0x100;
          LATB = 0x001;
          LATB = 0x000;
          LATB = 0x001;
          LATB = 0x100;
          LATB = 0x101;
          LATB = col;
          sdram_write( col, pSrc );
          col += RAM_BURST_COUNT; 
          pSrc += RAM_BURST_COUNT * RAM_WIDTH_BYTES;
      }
      sdram_precharge();
      sdram_precharge_all();
      sdram_sleep();
      INTEnableInterrupts();
      
      gWasteTime++;
      gWasteTime++;
      gWasteTime++;
      gWasteTime++;
  } 
  return true; 
}


bool IsBlockEqual( uint32_t* p1, uint32_t* p2 )
{
  for( int i = 0; i < 128; ++i )
  {
    if( *p1++ != *p2++ ) return false;
  }
  return true;
}

//#define IJF (0x10000<<((j+i)%16))|(0x1<<(i%16))
#define IJF (0x10000<<(j%13))|(0x1<<(i%11))

int main(void)
{   
    // This is in ms, and is how long we wait between blinks
    uint32_t	BlinkTime = 1000;

    // Set all analog pins to be digital I/O
    AD1PCFG = 0xFFFF;
    
    // Configure the proper PB frequency and the number of wait states
    SYSTEMConfigPerformance(80000000L);

    // Turn off JTAG so we get the pins back
    mJTAGPortEnable(0);

    ODCB = 0;
        
    //Initialize all of the LED pins
    mInitAllLEDs();

    INTDisableInterrupts();
      
    sdram_init();
    sdram_bank(0);
    sdram_active(0);
    //sdram_write(8,        &data_out[4] );
    sdram_precharge();
    sdram_precharge_all();
    sdram_sleep();

    // Open up the core timer at our 1ms rate
    OpenCoreTimer(CORE_TICK_RATE);

    // set up the core timer interrupt with a prioirty of 2 and zero sub-priority
    mConfigIntCoreTimer((CT_INT_ON | CT_INT_PRIOR_2 | CT_INT_SUB_PRIOR_0));

    // enable multi-vector interrupts
    INTEnableSystemMultiVectoredInt();

    INTEnableInterrupts();

    // Write Memory
    for(int j = 0; j<BLOCKS_PER_ROW*RAM_ROWS/**RAM_BANKS*/; ++j )
    {
        for( int i = 0; i < 128; i++ )
        {
            data_out[i] = IJF;
        }
        WriteBlockToSdram( data_out, j );
    }

    mLED_1_On();
    mLED_2_On();
    mLED_3_On();
    mLED_4_On();

    while(1)
    {
	mLED_2_On();

    	// What we're going to do is blink an LED on and off
    	// The rate we use will be determind by the user pushing
    	// the User button.
    	    
    	OneMSTimer = BlinkTime;
    	while (OneMSTimer);
    	    
        mLED_2_Off();
    	OneMSTimer = BlinkTime;
    	while (OneMSTimer);
	    
        data_in[0] = data_in[1] = data_in[2] = data_in[3] = data_in[4] = 99;
        mLED_4_On();
      
        for(int j = 0; j<BLOCKS_PER_ROW*RAM_ROWS/**RAM_BANKS*/; ++j )
        {
            for( int i = 0; i < 128; i++ )
            {
                data_out[i] = IJF;
            }
            ReadBlockFromSdram( data_in, j );
            if( !IsBlockEqual( data_out, data_in ) )
            {
                mLED_1_Off();
                mLED_3_Off();
            }
            else
            {
                mLED_3_On();
            }
        }
        mLED_4_Off();

#if 0
        INTDisableInterrupts();
        sdram_wake();
        sdram_bank(0);
        sdram_active(0);
        sdram_read( 0, &data_in[0] );
        sdram_read( 4, &data_in[2] );
        sdram_precharge();
        sdram_precharge_all();
        sdram_sleep();
        INTEnableInterrupts();
#endif  

	// Look for a button press to switch between the two speeds
	if (swUser)
	{
            BlinkTime = 20;		// 1second
        }
        else
        {
	    BlinkTime = 200;		// 100ms
        } 
    }
}

extern "C" 
{
  void __ISR(_CORE_TIMER_VECTOR, ipl2) CoreTimerHandler(void)
  {
    // clear the interrupt flag
    mCTClearIntFlag();

    if (OneMSTimer)
    {
      OneMSTimer--;
    }

    // update the period
    UpdateCoreTimer(CORE_TICK_RATE);
  }
}

