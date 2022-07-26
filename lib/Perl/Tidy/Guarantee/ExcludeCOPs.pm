# This is an internal-only module.

# It's intended to be used like this:
#
#   perl -MO=Concise -MPerl::Tidy::Guarantee::ExcludeCOPs=export_stubs.bin foobar.pl


use Perl::Tidy::Guarantee::ExportStubs ();


####################################################################################################
package Perl::Tidy::Guarantee::ExcludeCOPs;
####################################################################################################

use strict;
use warnings;

use B::Concise ();

# Suppress output of COPs when running B::Concise.
#
# COPs contain only file and line-number information. Perl::Tidy sometimes moves statements to a
# different line for cosmetic reasons, so we don't consider line-number changes significant.
#
# https://metacpan.org/pod/perloptree#COP
B::Concise::add_callback(
    sub {
        my ($h, $op, $format, $level, $stylename) = @_;

        $h->{SKIP} = 1
                if ($h->{class} eq 'COP');
    });



# allow the export-stubs filename to be specified on the command-line when starting B::Concise
sub import {
    my ($pkg, $exportstubs_filename) = @_;
    if (defined($exportstubs_filename)) {
        Perl::Tidy::Guarantee::ExportStubs::_read_from_file($exportstubs_filename);
    }
}



####################################################################################################
package Perl::Tidy::Guarantee::DontLoadAnyModules;
####################################################################################################

our $is_enabled = 0;

# Perl::Tidy doesn't try to load any use/require modules, while B::Concise *does* try to load them.
# So, when a desired module hasn't been installed locally yet, Perl::Tidy will succeed while
# B::Concise will fail. This is obviously a problem -- we want B::Concise's success/fail status to
# precisely match Perl::Tidy's success/fail status.
#
# One solution is, when running B::Concise, to hook @INC and stub out every single use/require,
# returning "dummy" code for each attempt to require a module.
#
# https://perldoc.perl.org/functions/require#:~:text=hooks


# ================ why I stopped working on this potential solution ================================
# This is THE definition of "falling down a rabbit hole" -- it turns out that %export_stubs needs to
# be filled out for MANY different CPAN modules (and private company-internal-only modules too!!).
# This means that 1) for our team's purposes, the total amount of work required to fill out
# %export_stubs could potentially be very large (and it's probably difficult to estimate, to boot).
# And 2) for public use of this module, it would require end-users to do some cumbersome preliminary
# work before they could ever properly use this module, and I'm not sure many people would want to
# do that (even IF we communicated that caveat up front in huge red bold flashing text, which,
# honestly, is the right thing to do).


use strict;
use warnings;


our %stubs = (
    'File::chdir' => <<'EOF',
        package File::chdir;
        our $VERSION = 99999999;
        our $CWD, @CWD;
        1;
EOF
);


if ($is_enabled) {
    unshift @INC, \&INC_hook;
}


# https://perldoc.perl.org/functions/require#:~:text=hooks
sub INC_hook {
    my ($self, $filename) = @_;
            # $filename is something like 'Foo/Bar.pm'

    (my $module_name = $filename) =~ s#[/\\]#::#g;
    $module_name =~ s/\.pm$//;

    return if ($Perl::Tidy::Guarantee::ExportStubs::do_not_stub{$module_name});

    # 1) At a bare minimum, modules must return true. 2) If a version check is requested, they
    # must declare the proper package name and have some kind of [correct?] version number.
    # 3) If a package is found within %export_stubs, then we want to import() some symbols into
    # the correct package.
    my $prepend_text = <<"EOF";
package $module_name;
our \$VERSION = 99999999;
sub import {Perl::Tidy::Guarantee::DontLoadAnyModules::import(\@_)}
1;
EOF
    if (exists $stubs{$module_name}) {
        $prepend_text = $stubs{$module_name};
    }
    my $filehandle = undef;
    my $subref = sub {
            # The subref is expected to generate one line of source code per call, writing the line
            # into $_ and returning 1. At EOF, it should return 0.
            return 0;
        };
    return (\$prepend_text, $filehandle, $subref);
}


sub import {
    my $pkg = shift;
    my $callpkg = caller(1);

    #use Data::Dumper;
    #die Dumper [$pkg, $callpkg, \@_, \%args];

    return unless ($Perl::Tidy::Guarantee::ExportStubs::export_stubs{$pkg});

    if (@_ == 0) {
        push @_, keys(%{$Perl::Tidy::Guarantee::ExportStubs::export_stubs{$pkg}});
    }

    foreach my $symbol (@_) {
        if ($symbol eq ':all') {
            push @_, keys(%{$Perl::Tidy::Guarantee::ExportStubs::export_stubs{$pkg}});
        }
        # also generate a stub sub inside the main package
        stub_one_symbol("${pkg}::$symbol");
    }

    foreach my $arg (@_) {
        my $symbol = $arg;
        next unless (exists $Perl::Tidy::Guarantee::ExportStubs::export_stubs{$pkg}{$symbol});
        #print STDERR "exporting ${pkg}::$symbol into $callpkg\n";
        stub_one_symbol("${callpkg}::$symbol");
    }
}


# $symbol should contain both the package and the final symbol name
sub stub_one_symbol {
    my ($symbol) = @_;
    my $sigil = '';

    if ($symbol =~ s/^[\$]//) {
        $sigil = $1;
    } elsif ($symbol =~ s/::[\$](?=[^:]+$)/::/s) {
        # we also allow the weird syntax of placing the sigil just after the final pair of colons
        # (because this makes the "foreach my $arg (@_)" statement above much simpler)
        $sigil = $1;
    }

    #print STDERR "creating stub for $symbol\n";

    no strict 'refs';
    if ($sigil eq '$') {
        *{$symbol} = \'';
    } else {
        *{$symbol} = sub {};
    }
}


####################################################################################################
package Perl::Tidy::Guarantee::MaybeAllModules;
####################################################################################################

our $is_enabled = 0;

# Another way to deal with the problem (that B::Concise tries to require/use modules while
# Perl::Tidy does not) is to turn every "use" into a "use maybe" when running under
# B::Concise. This way, the desired module will be loaded if it's currently availble, but if it's
# not, B::Concise will (more or less) continue on without failing.
#
# https://metacpan.org/pod/maybe


# ================ why I stopped working on this potential solution ================================
# It turns out that blithely forging ahead after failing to use/require a module doesn't actually
# work. Many pieces of code require certain exports to be in place before they can successfully
# compile.
#
# While we do deal with this somewhat by having our own INC_hook() call
# Perl::Tidy::Guarantee::DontLoadAnyModules::INC_hook() at the end, my gut feeling is that this
# solution provides no value-add beyond what Perl::Tidy::Guarantee::DontLoadAnyModules already
# provides. If that's true, then why not just use that solution and leave this one totally out of
# it?


use strict;
use warnings;

# These subroutines are known to try to speculatively load packages. If these packages aren't
# actually loaded already, then we don't want to provide any stubs for them.
our %will_speculatively_require = map {$_ => 1} qw(
        Sys::Syslog::can_load
        Date::Calc::BEGIN
        Net::DNS::Resolver::BEGIN
    );

if ($is_enabled) {
    # because the hook is placed at the *end* of @INC, it only gets used if the actual file couldn't
    # be found locally
    push @INC, \&INC_hook;
}


sub INC_hook {
    my ($self, $filename) = @_;
            # $filename is something like 'Foo/Bar.pm'

    for (my $depth=0; ; $depth++) {
        my @frame = caller($depth);
        last unless @frame;
        my $sub = $frame[3];
        #print STDERR ">>$sub\n";
        if ($will_speculatively_require{$sub}) {
            return;
        }
    }

    return Perl::Tidy::Guarantee::DontLoadAnyModules::INC_hook(@_);
}



####################################################################################################
package Perl::Tidy::Guarantee::NoStrictSubs;
####################################################################################################

our $is_enabled = 1;

# Yet another way to deal with the problem might be to run "no strict 'subs'" everywhere, so that
# modules stop erroring out when they run into an export that we inadvertently removed by stubbing
# out that module.
#
# https://metacpan.org/pod/everywhere
#
# The way we actually implement this is to monkey-patch strict::import(), so that whenever anyone
# tries to execute "use strict @list", we change that to be "use strict @list; no strict 'subs';".
# (more precisely, "use strict everything-in-@list-except-for-'subs'")


use strict;
use warnings;

# verbatim from strict.pm
my %bitmask = (
    refs => 0x00000002,
    subs => 0x00000200,
    vars => 0x00000400,
);

# verbatim from strict.pm
my %explicit_bitmask = (                                                                                               
    refs => 0x00000020,                                                                                             
    subs => 0x00000040,                                                                                             
    vars => 0x00000080,                                                                                             
);                    


# verbatim from strict.pm in Perl 5.36.0
my $bits = 0;
$bits |= $_ for values %bitmask;

my $inline_all_bits = $bits;
*all_bits = sub () { $inline_all_bits };


# verbatim from strict.pm in Perl 5.36.0
$bits = 0;
$bits |= $_ for values %explicit_bitmask;

my $inline_all_explicit_bits = $bits;
*all_explicit_bits = sub () { $inline_all_explicit_bits };


if ($is_enabled) {
    # Modifying a core module's internals is clearly misbehaving -- tisk tisk.
    #my $original_import = \&strict::import;
    no warnings 'redefine';
    *strict::import = \&strict_import;
}


sub strict_import {
    # We have to replicate what strict::import() does EXACTLY. Unfortunately, calling
    # $original_import doesn't work because $^H only modifies the parent's scope. I don't know
    # of a way to get it to modify the scope "two levels up".
    my $pkg = shift;

    # [more or less] verbatim from strict.pm in Perl 5.36.0
    $^H |= @_ ? strict::bits(@_) : all_bits() | all_explicit_bits();

    # but always do 'no strict "subs"' afterwards
    $^H &= ~strict::bits("subs");
}


if ($is_enabled) {
    # stub out almost every module
    unshift @INC, \&INC_hook;
}


# https://perldoc.perl.org/functions/require#:~:text=hooks
sub INC_hook {
    my ($self, $filename) = @_;
            # $filename is something like 'Foo/Bar.pm'

    (my $module_name = $filename) =~ s#[/\\]#::#g;
    $module_name =~ s/\.pm$//;

    # Never ever stub Data::Dumper -- t/exportstubs_Storable.t needs Data::Dumper to actually
    # function.
    return if ($module_name eq 'Data::Dumper');

    return if ($Perl::Tidy::Guarantee::ExportStubs::do_not_stub{$module_name});

    # 1) At a bare minimum, modules must return true. 2) If a version check is requested, they
    # must declare the proper package name and have some kind of [correct?] version number.
    # 3) If a package is found within %export_stubs, then we want to import() some symbols into
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


####################################################################################################
package Perl::Tidy::Guarantee::AutoloadEverything;
####################################################################################################

our $is_enabled = 0;

# Perl::Tidy::Guarantee::NoStrictSubs still allows some syntax error messages through. This module
# provides a UNIVERSAL::AUTOLOAD() that will let you autoload ALL THE THINGS.
#
# (this is a *terrible* idea, by the way)


# ================ why I stopped working on this potential solution ================================
# There are internal technical problems with this current implementation. This implementation
# currently causes tidyall to hang in practically all situations.
#
# It's possible that reading these documents could help with solving the current hanging behavior,
# but it's also possible they're totally off-base, so take them with a grain of salt:
#       https://stackoverflow.com/a/28732045/1042525
#       https://metacpan.org/pod/Autoload::AUTOCAN
#       https://metacpan.org/dist/UNIVERSAL-canAUTOLOAD/view/README
#
# In short, this solution is only ~60% implemented and has never functioned remotely properly.


# ================ why I stopped working on this potential solution ================================
# As a second point, AUTOLOAD can only magically summon *subroutines* into existence, and AFAIK it
# can't magically summon scalars/lists/hashes/etc into existence. This is a problem because some
# CPAN modules *require* scalars/lists/hashes/etc to be exported before the parent code can
# successfully compile ('vars' is a prime example). It's possible this could be an inherent
# limitation of AUTOLOAD, but I'm not sure yet.


use strict;
use warnings;


if ($is_enabled) {
    # did I mention this was a terrible idea?
    *UNIVERSAL::AUTOLOAD = \&AUTOLOAD;
}


# https://perldoc.perl.org/perlsub#Autoloading
sub AUTOLOAD {
    print STDERR "autoloading $UNIVERSAL::AUTOLOAD\n";
    Perl::Tidy::Guarantee::DontLoadAnyModules::stub_one_symbol($UNIVERSAL::AUTOLOAD);
}


1;
