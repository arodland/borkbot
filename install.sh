#!/bin/bash
git submodule update --init
chmod +x cpm/cpm
PERL_USE_UNSAFE_INC=1 ./cpm/cpm install
