#!/bin/bash

rm -f oops.pl
./random_mashup.pl
perl -I../lib -MPerl::Tidy::Guarantee::ExcludeCOPs -c oops.pl
