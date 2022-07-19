# This is an internal-only module.

# It's intended to be used like this:
#
#   perl -MO=Concise -MPerl::Tidy::Guarantee::ExcludeCOPs foobar.pl


####################################################################################################
package Perl::Tidy::Guarantee::ExcludeCOPs;
####################################################################################################

use strict;
use warnings;

use B::Concise;

# Suppress output of COPs when running B::Concise.
#
# COPs contain only file and line-number information, so when Perl::Tidy moves statements to a
# different line, this could cause tidy_compare() to incorrectly assume a mismatch.
#
# https://metacpan.org/pod/perloptree#COP
B::Concise::add_callback(
    sub {
        my ($h, $op, $format, $level, $stylename) = @_;

        $h->{SKIP} = 1
                if ($h->{class} eq 'COP');
    });



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

use strict;
use warnings;


# These modules MUST be installed locally and fully loaded, in order for other code to compile
# correctly. They just so happen to be mostly things that are bundled with Perl core.
our %do_not_stub = map {$_ => 1} qw(
        vars
        Carp
        Fcntl
        Socket
    );


# Unfortunately we can't entirely ignore the contents of CPAN modules -- some modules provide
# exports that have a real impact on how other code is parsed / whether other code can be compiled
# successfully.
#
# One solution is to require the user to install each of the modules listed below.
#
# Another (better?) solution is to provide bare-minimum stubs for these exports.
our %stub_exports = parse_stub_exports(<<'EOF');
# ------------------------------------------------------------------------------

Moose
    extends with has before after around override augment super inner

Moose::Role
    extends with has before after around override augment super inner

Mouse
    extends with has before after around override super augment inner

Moo
    extends with has before after around

MooX
    extends with has before after around

Dancer
    after any before before_template cookie cookies config content_type dance dancer_version debug
    del dirname info error engine false forward from_dumper from_json from_yaml from_xml get halt
    header headers hook layout load load_app logger mime options param param_array params pass path
    patch post prefix push_header put redirect render_with_layout request send_file send_error set
    setting set_cookie session splat status start template to_dumper to_json to_yaml to_xml true
    upload captures uri_for var vars warning

Log::ger
    log_trace log_debug log_info log_warn log_error log_fatal
    log_is_trace log_is_debug log_is_info log_is_warn log_is_error log_is_fatal

Coro
    async async_pool cede schedule terminate current unblock_sub rouse_cb rouse_wait

Net::EmptyPort
    empty_port check_port

File::Slurper
    >read_binary >read_text >read_lines >write_binary >write_text >read_dir

FormValidator::Lite::Constraint
    rule file_rule alias delsp

Types::Standard
    LaxNum StrictNum Num ClassName RoleName Optional CycleTuple Dict Overload StrMatch OptList Tied
    InstanceOf ConsumerOf HasMethods Enum Any Item Bool Undef Defined Value Str Int Ref CodeRef
    RegexpRef GlobRef FileHandle ArrayRef HashRef ScalarRef Object Maybe Map Tuple

Module::Signature
    >sign >verify >$SIGNATURE >$AUTHOR >$KeyServer >$Cipher >$Preamble

Carp::Assert
    assert affirm should shouldnt DEBUG

Readonly
    Readonly >Scalar >Array >Hash >Scalar1 >Array1 >Hash1

Test::More
    ok use_ok require_ok is isnt like unlike is_deeply cmp_ok skip todo todo_skip pass fail eq_array
    eq_hash eq_set $TODO plan done_testing can_ok isa_ok new_ok diag note explain subtest BAIL_OUT

Date::Calc
    Days_in_Year Days_in_Month Weeks_in_Year leap_year check_date check_time
    check_business_date Day_of_Year Date_to_Days Day_of_Week Week_Number
    Week_of_Year Monday_of_Week Nth_Weekday_of_Month_Year Standard_to_Business
    Business_to_Standard Delta_Days Delta_DHMS Delta_YMD Delta_YMDHMS
    N_Delta_YMD N_Delta_YMDHMS Normalize_DHMS Add_Delta_Days Add_Delta_DHMS
    Add_Delta_YM Add_Delta_YMD Add_Delta_YMDHMS Add_N_Delta_YMD
    Add_N_Delta_YMDHMS System_Clock Today Now Today_and_Now This_Year Gmtime
    Localtime Mktime Timezone Date_to_Time Time_to_Date Easter_Sunday
    Decode_Month Decode_Day_of_Week Decode_Language Decode_Date_EU
    Decode_Date_US Fixed_Window Moving_Window Compress Uncompress
    check_compressed Compressed_to_Text Date_to_Text Date_to_Text_Long
    English_Ordinal Calendar Month_to_Text Day_of_Week_to_Text
    Day_of_Week_Abbreviation Language_to_Text Language Languages Decode_Date_EU2
    Decode_Date_US2 Parse_Date ISO_LC ISO_UC
# ------------------------------------------------------------------------------
EOF

#use Data::Dumper;
#die Dumper \%stub_exports;


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

    return if ($do_not_stub{$module_name});

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

    return unless ($stub_exports{$pkg});

    if (@_ == 0) {
        push @_, keys(%{$stub_exports{$pkg}});
    }

    foreach my $symbol (@_) {
        if ($symbol eq ':all') {
            push @_, keys(%{$stub_exports{$pkg}});
        }
        # also generate a stub sub inside the main package
        stub_one_symbol("${pkg}::$symbol");
    }

    foreach my $arg (@_) {
        my $symbol = $arg;
        next unless (exists $stub_exports{$pkg}{$symbol});
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
        # (because this makes the "foreach my $arg (@_)" statement above simpler)
        $sigil = $1;
    }

    no strict 'refs';
    if ($sigil eq '$') {
        *{$symbol} = \'';
    } else {
        *{$symbol} = sub {};
    }
}


# symbol prefixes:
#       >       is in @EXPORT_OK
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
                if ($token =~ s/^>//) {
                    $ret{$current_module}{$token} = 'ok';
                } else {
                    $ret{$current_module}{$token} = undef;
                }
            }
        }
    }

    return %ret;
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
# modules stop erroring out when that particular condition occurs.
#
# (Or, at least, find a way to run "no strict 'subs'" in the top-level file only? Like, maybe
# monkey-patching strict::import()?)
#
# https://metacpan.org/pod/everywhere

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
    # stub out absolutely every module
    unshift @INC, \&INC_hook;
}


# https://perldoc.perl.org/functions/require#:~:text=hooks
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



1;

