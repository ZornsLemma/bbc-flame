#!/bin/bash
python3 make-mainblock.py > mainblock.asm
python3 make-tables.py > tables.asm
beebasm -w -opt 3 -i flame.asm -do flame.ssd -v > flame.lst
