#!/bin/bash
git submodule update --init
PERL_USE_UNSAFE_INC=1 perl cpm/cpm install
