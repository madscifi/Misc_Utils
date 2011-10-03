/*
 * SDRAM Access Routines for PIC32.
 * 
 * Retromaster - 10.05.2010
 * 
 * This file is in the public domain. You can use, modify, and distribute the source code
 * and executable programs based on the source code. This file is provided "as is" and 
 * without any express or implied warranties whatsoever. Use at your own risk!
 */
 
#ifndef SDRAM_H
#define SDRAM_H

#include <inttypes.h>

extern "C" {
extern __longramfunc__ void sdram_init();
extern __longramfunc__ void sdram_active(uint16_t addr);
extern __longramfunc__ void sdram_write(uint16_t addr, uint64_t val);
extern __longramfunc__ uint64_t sdram_read(uint16_t addr);
extern __longramfunc__ void sdram_auto_refresh(void);
extern __longramfunc__ void sdram_precharge(void);
extern __longramfunc__ void sdram_precharge_all(void);
extern __longramfunc__ void sdram_sleep(void);
extern __longramfunc__ void sdram_wake(void);
extern __longramfunc__ void sdram_bank(uint8_t bank);
}

#endif
