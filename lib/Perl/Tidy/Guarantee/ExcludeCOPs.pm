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



package Perl::Tidy::Guarantee::DontLoadAnyModules;

# There's a problem -- Perl::Tidy doesn't try to load any use/require modules, while B::Concise
# *does*. Therefore, when a desired module is missing, Perl::Tidy will succeed while B::Concise will
# fail.
#
# So we'll just hook @INC and stub out every single use/require.
#
# https://perldoc.perl.org/functions/require#:~:text=hooks


use strict;
use warnings;


# exports that are required for the rest of the code to merely *compile*, not run
our %stub_exports = parse_stub_exports(<<'EOF');
# ------------------------------------------------------------------------------

Mouse
    extends with has before after around override super augment inner

Dancer
    after any before before_template cookie cookies config content_type dance dancer_version debug
    del dirname info error engine false forward from_dumper from_json from_yaml from_xml get halt
    header headers hook layout load load_app logger mime options param param_array params pass path
    patch post prefix push_header put redirect render_with_layout request send_file send_error set
    setting set_cookie session splat status start template to_dumper to_json to_yaml to_xml true
    upload captures uri_for var vars warning

# ------------------------------------------------------------------------------
EOF


#use Data::Dumper;
#die Dumper \%stub_exports;


push @INC, \&INC_hook;


sub INC_hook {
    my ($self, $filename) = @_;
            # $filename is something like 'Foo/Bar.pm'

    (my $module_name = $filename) =~ s#[/\\]#::#g;
    $module_name =~ s/\.pm$//;

    # 1) At a bare minimum, modules must return true. 2) If a version check is requested, they
    # must declare the proper package name and have some kind of [correct?] version number.
    # 3) If a package is found within %stub_exports, then we want to import() some symbols into
    # the correct package.
    my $prepend_text = <<"EOF";
package $module_name;
our \$VERSION = 99999999;
sub import {Perl::Tidy::Guarantee::DontLoadAnyModules::import(\@_)}
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


sub import {
    my ($pkg) = @_;
    my $callpkg = caller(1);

    use Data::Dumper;
    #die Dumper [$pkg, $callpkg];

    return unless ($stub_exports{$pkg});

    while (my ($symbol, $definition) = each %{$stub_exports{$pkg}}) {
        #print STDERR ">>exporting ${callpkg}::$symbol to $pkg\n";
        no strict 'refs';
        *{"${callpkg}::$symbol"} = sub {};
    }
}


sub parse_stub_exports {
    my ($here_doc) = @_;

    my %ret;

    my @lines = split /^/m, $here_doc;
    my $current_module;
    foreach my $line (@lines) {
        chomp $line;
        next if ($line =~ /^\s*#/);     # comment lines start with an arbitrary number of spaces, followed by a pound
        next unless ($line =~ /\S/);    # blank lines

        if ($line =~ /^\S/) {
            $current_module = $line;
            $ret{$current_module} = {};
        } elsif ($line =~ s/^\s+//) {
            my @tokens = split ' ', $line;
            foreach my $token (@tokens) {
                $ret{$current_module}{$token} = 1;
            }
        }
    }

    return %ret;
}


package Perl::Tidy::Guarantee::MaybeAllModules;

# One way to deal with this is to turn every "use" into a "use maybe" when running under B::Concise,
# so that the desired module will be loaded if it's currently availble, but if it's not, B::Concise
# won't fail.
#
# https://metacpan.org/pod/maybe

use strict;
use warnings;


1;

