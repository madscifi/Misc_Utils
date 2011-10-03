// pic32 project, ubw32 board

#include "plib.h"
#include "sdram.h"

//#include "HardwareProfile.h"
typedef unsigned char uint8;
typedef signed char int8;
typedef unsigned short int uint16;
typedef signed short int int16;
typedef unsigned int uint32;
typedef signed int int32;
//typedef unsigned char bool;
    #define DEMO_BOARD UBW32

    /** LED ************************************************************/
    #define mInitAllLEDs()      LATE |= 0x000F; TRISE &= 0xFFF0;
    
    #define mLED_1              LATEbits.LATE3
    #define mLED_2              LATEbits.LATE2
    #define mLED_3              LATEbits.LATE1
    #define mLED_4              LATEbits.LATE0

    #define mGetLED_1()         mLED_1
    #define mGetLED_USB()       mLED_1
    #define mGetLED_2()         mLED_2
    #define mGetLED_3()         mLED_3
    #define mGetLED_4()         mLED_4

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
    
    #define mLED_1_Toggle()     mLED_1 = !mLED_1;
    #define mLED_USB_Toggle()   mLED_1 = !mLED_1;
    #define mLED_2_Toggle()     mLED_2 = !mLED_2;
    #define mLED_3_Toggle()     mLED_3 = !mLED_3;
    #define mLED_4_Toggle()     mLED_4 = !mLED_4;
    
    /** SWITCH *********************************************************/
    #define mInitSwitch2()      TRISEbits.TRISE7=1;
    #define mInitSwitch3()      TRISEbits.TRISE6=1;
    #define mInitAllSwitches()  mInitSwitch2();mInitSwitch3();
    #define swProgram           PORTEbits.RE7
    #define swUser              PORTEbits.RE6

// NOTE THAT BECAUSE WE USE THE BOOTLOADER, NO CONFIGURATION IS NECESSARY
// THE BOOTLOADER PROJECT ACTUALLY CONTROLS ALL OF OUR CONFIG BITS

// Let compile time pre-processor calculate the CORE_TICK_PERIOD
#define SYS_FREQ 				(80000000L)
#define TOGGLES_PER_SEC			1000
#define CORE_TICK_RATE	       (SYS_FREQ/2/TOGGLES_PER_SEC)

__longramfunc__ void dummy()
{
        mLED_2_On();  
        mLED_2_Off();  
}

// Decriments every 1 ms.
volatile static uint32 OneMSTimer;

volatile uint64_t data_out[64];
volatile uint64_t data_in[64];

#define rwcount 8

void FillOut()
{
  for( int i = 0; i < rwcount; i++ )
  {
    data_out[i] = i;
  }
}

bool IsEqual()
{
  for( int i =0; i < rwcount; i++ )
  {
    if( data_out[i] != data_in[i] ) return false;
  }
  return true;
}

void CopyToSdram()
{
      sdram_bank(0);
      sdram_active(0);
      volatile uint64_t* p = data_out;
      for( int i = 0; i < rwcount*8; i += 8 )
      {
          sdram_write( i, *p++ );
      }
      sdram_precharge();
      sdram_precharge_all();
      sdram_sleep();
}

void CopyFromSdram()
{
      INTDisableInterrupts();
      sdram_wake();
      sdram_bank(0);
      sdram_active(0);
      volatile uint64_t* p = data_in;
      for( int i = 0; i < rwcount*8; i += 8 )
      {
          *p++ = sdram_read( i );
      }
      sdram_precharge();
      sdram_precharge_all();
      sdram_sleep();
      INTEnableInterrupts();
}

#define BLOCK_SIZE 512

#define RAM_COLS 512
#define RAM_ROWS 4096
#define RAM_BANKS 4

// RAM_BURST_COUNT MUST be 8 at present
#define RAM_BURST_COUNT 8
#define RAM_BURST_GROUP_COUNT 8  

#define BLOCKS_PER_ROW ( RAM_COLS / BLOCK_SIZE )
  // must be a power of 2
  
volatile int gDummy;

bool ReadBlockFromSdram( volatile uint64_t* dest, unsigned int blockNumber )
{
  if( blockNumber < 0 || blockNumber >= RAM_ROWS * RAM_BANKS * BLOCKS_PER_ROW ) return false;

  int startColumn = ( ( blockNumber & ( BLOCKS_PER_ROW - 1 ) ) * BLOCK_SIZE ) / RAM_BURST_COUNT;
  int rowAndBank = blockNumber / BLOCKS_PER_ROW;
  int row = rowAndBank & ( RAM_ROWS - 1 );
  int bank = rowAndBank / RAM_ROWS;
  
  int col = startColumn;
  while( col < startColumn + BLOCK_SIZE/RAM_BURST_COUNT )
  {
      INTDisableInterrupts();
      sdram_wake();
      sdram_bank(bank);
      sdram_active(row);
      //sdram_active(row);
      for( int i = 0; i < RAM_BURST_GROUP_COUNT; i++ )
      {
          *dest++ = sdram_read( col );
          col += 1; //RAM_BURST_COUNT;
      }
      sdram_precharge();
      sdram_precharge_all();
      sdram_sleep();
      INTEnableInterrupts();
      
      gDummy++;
      gDummy++;
      gDummy++;
      gDummy++;
      gDummy++;
      gDummy++;
  } 
  return true; 
}

bool WriteBlockToSdram( volatile uint64_t* src, unsigned int blockNumber )
{
  if( blockNumber < 0 || blockNumber >= RAM_ROWS * RAM_BANKS * BLOCKS_PER_ROW ) return false;

  int startColumn = ( ( blockNumber & ( BLOCKS_PER_ROW - 1 ) ) * BLOCK_SIZE ) / RAM_BURST_COUNT;
  int rowAndBank = blockNumber / BLOCKS_PER_ROW;
  int row = rowAndBank & ( RAM_ROWS - 1 );
  int bank = rowAndBank / RAM_ROWS;
  
  int col = startColumn;
  while( col < startColumn + BLOCK_SIZE/RAM_BURST_COUNT )
  {
      INTDisableInterrupts();
      sdram_wake();
      sdram_bank(bank);
      sdram_active(row);
      for( int i = 0; i < RAM_BURST_GROUP_COUNT; i++ )
      {
          sdram_write( col, *src++ );
          col += 1; //RAM_BURST_COUNT;
      }
      sdram_precharge();
      sdram_precharge_all();
      sdram_sleep();
      INTEnableInterrupts();
      
      gDummy++;
      gDummy++;
      gDummy++;
      gDummy++;
      gDummy++;
      gDummy++;
  } 
  return true; 
}

bool IsBlockEqual( volatile uint64_t* p1, volatile uint64_t* p2 )
{
  for( int i = 0; i < 64; ++i )
  {
    if( *p1++ != *p2++ ) return false;
  }
  return true;
}
//uint64_t data_out[64];
//uint64_t data_in[64];
#define JCM2 

#define usecol 1

#define userow2 1

int main(void)
{   
	// This is in ms, and is how long we wait between blinks
	uint32	BlinkTime = 1000;

	// Set all analog pins to be digital I/O
        AD1PCFG = 0xFFFF;
    
        // Configure the proper PB frequency and the number of wait states
	SYSTEMConfigPerformance(80000000L);

	// Turn off JTAG so we get the pins back
 	mJTAGPortEnable(0);

        ODCB = 0;
        
    //Initialize all of the LED pins
	mInitAllLEDs();

      dummy();
      FillOut();
      
      //unsigned int i = (int)&sdram_init;
      //if( i > 0xa0000000 && i < 0xa00000000 + 0x20000)
      //{
        //mLED_1_On();  
      //}
      
      INTDisableInterrupts();
      sdram_init();
      sdram_bank(0);
      sdram_active(0);
      sdram_write(0, 0xabcd123455556669 );
      sdram_write(usecol, 0x1111111155555555 );
      sdram_write(2, 0x8987672309887002 );
      sdram_write(3,0x9287983457987543 );
      sdram_write(4,0x7667456765766634 );
      
      sdram_precharge();
      sdram_precharge_all();
      /*
      sdram_active(userow2);
      sdram_write(0, 0xabc6645567567359 );
//      sdram_write(1, 0x3657345646747856 );
      sdram_write(2, 0x7956756735698363 );
//      sdram_write(3, 0x7686737568787965 );
      
      sdram_precharge();
      sdram_precharge_all();
      */
      sdram_sleep();
      
	// Open up the core timer at our 1ms rate
      OpenCoreTimer(CORE_TICK_RATE);

    // set up the core timer interrupt with a prioirty of 2 and zero sub-priority
      mConfigIntCoreTimer((CT_INT_ON | CT_INT_PRIOR_2 | CT_INT_SUB_PRIOR_0));

    // enable multi-vector interrupts
      INTEnableSystemMultiVectoredInt();

      
      INTEnableInterrupts();
      
      for(int j = 0; j<2048*2*4; ++j )
      {
        for( int i = 0; i < 64; i++ )
        {
          data_out[i] = i + j * 0xffff;
        }
        WriteBlockToSdram( data_out, j );
      }

        mLED_1_On();
        mLED_2_On();
        mLED_3_On();
        mLED_4_On();

    while(1)
    {
       //PORTB = 0x4;
       
	    // What we're going to do is blink an LED on and off
	    // The rate we use will be determind by the user pushing
	    // the User button.
	    mLED_2_On();
	    
	    OneMSTimer = BlinkTime;
	    while (OneMSTimer);
	    
	    mLED_2_Off();
	    
	    OneMSTimer = BlinkTime;
	    while (OneMSTimer);
	    

      //CopyFromSdram();
       //ReadBlockFromSdram( data_in, swUser?0:1 );
       data_in[0] = data_in[1] = data_in[2] = data_in[3] = data_in[4] = 99;
       
       int blk = swUser ? 0 : 1;
       
       //ReadBlockFromSdram( data_in, blk );
      
      mLED_4_On();
      
      for(int j = 0; j<2048*2*4; ++j )
      {
        for( int i = 0; i < 64; i++ )
        {
          data_out[i] = i + j * 0xffff;
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
      data_in[0] = sdram_read( 0 );
      data_in[1] = sdram_read( usecol );  // ~1 b3
      data_in[2] = sdram_read( 2 );  // ~1 b3
      data_in[3] = sdram_read( 3 );  // ~1 b3
      data_in[4] = sdram_read( 4 );  // ~1 b3
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

