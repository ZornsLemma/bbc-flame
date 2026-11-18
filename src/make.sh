#!/bin/bash

set -e
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit
mkdir -p gen
python3 generate.py wide
beebasm -w -opt 3 -i flame.asm -do gen/intermediate.ssd -v > gen/flame-wide.lst
python3 generate.py narrow
beebasm -w -opt 3 -i flame.asm -di gen/intermediate.ssd -do gen/flame.ssd -v > gen/flame-narrow.lst
