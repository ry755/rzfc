#!/bin/bash

set -e

../../vasm/vasmz80_oldstyle -Fbin -o bootrom.bin ry-dos.s
../../vasm/vasmz80_oldstyle -Fbin -o ../rom.bin bios.s
