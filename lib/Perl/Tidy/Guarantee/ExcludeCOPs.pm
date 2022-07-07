# This is an internal-only module.

# It's intended to be used kind of like this:
#
#   perl -MO=Concise -MPerl::Tidy::Guarantee::ExcludeCOPs foobar.pl


package Perl::Tidy::Guarantee::ExcludeCOPs;

use strict;
use warnings;

use B::Concise;

B::Concise::add_callback(
    sub {
        my ($h, $op, $format, $level, $stylename) = @_;

        # "Control ops (cops) are one of the two ops OP_NEXTSTATE and OP_DBSTATE"

        $h->{SKIP} = 1
                if ($op->name eq 'nextstate');
    });

1;
