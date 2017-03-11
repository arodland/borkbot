#!/usr/bin/env perl
use strict;
use warnings;
use lib 'local/lib/perl5';
use lib 'lib';

use Borkbot;
Borkbot->new_with_options->run;
