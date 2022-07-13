# This is an internal-only module.

# It's intended to be used like this:
#
#   perl -MO=Concise -MPerl::Tidy::Guarantee::ExcludeCOPs foobar.pl


package Perl::Tidy::Guarantee::ExcludeCOPs;

use strict;
use warnings;

use B::Concise;

# Suppress output of COPs when running B::Concise.
#
# COPs contain only file and line-number information, so when Perl::Tidy moves statements to a
# different line, this could cause tidy_compare() to give the wrong result.
#
# https://metacpan.org/pod/perloptree#COP
B::Concise::add_callback(
    sub {
        my ($h, $op, $format, $level, $stylename) = @_;

        $h->{SKIP} = 1
                if ($h->{class} eq 'COP');
    });


# There's a problem -- Perl::Tidy doesn't try to load any use/require modules, while B::Concise
# *does*. Therefore, when a desired module is missing, Perl::Tidy will succeed while B::Concise will
# fail.
#
# One way to deal with this is to turn every "use" into a "use maybe" when running under B::Concise,
# so that the desired module will be loaded if it's currently availble, but if it's not, B::Concise
# won't fail.
#
# https://metacpan.org/pod/maybe
push @INC, \&INC_hook;


# see https://perldoc.perl.org/functions/require#:~:text=hooks
sub INC_hook {
    my ($self, $filename) = @_;
            # $filename is something like 'Foo/Bar.pm'

    (my $module_name = $filename) =~ s#[/\\]#::#g;
    $module_name =~ s/\.pm$//;

    # At a bare minimum, modules must return true. Further, if a version check is requested, they
    # must declare the proper package name and have some kind of [correct?] version number.
    my $prepend_text = <<"EOF";
package $module_name;
our \$VERSION = 99999999;
1;
EOF
    my $filehandle = undef;
    my $subref = sub {
            # The subref is expected to generate one line of source code per call, writing the line
            # into $_ and returning 1. At EOF, it should return 0.
            return 0;
        };
    return (\$prepend_text, $filehandle, $subref);
}


1;
