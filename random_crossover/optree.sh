#!/bin/bash

rm -f oops.pl.optree oops.pl.tdy oops.pl.tdy.optree

perltidy oops.pl
perl -MO=Concise -I../lib -MPerl::Tidy::Guarantee::ExcludeCOPs oops.pl     > oops.pl.optree
perl -MO=Concise -I../lib -MPerl::Tidy::Guarantee::ExcludeCOPs oops.pl.tdy > oops.pl.tdy.optree
