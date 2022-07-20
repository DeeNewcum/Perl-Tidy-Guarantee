package Perl::Tidy::Guarantee::ExportStubs;

# Provides a centralized place to store export-stub information.
#
# Also provides a public API for companies to add export-stub information for their DarkPAN modules.

# TODO -- write documentation for how it's expected that Code::TidyAll will end up loading the
#         DarkPAN export-stub information

use strict;
use warnings;

use Exporter 5.57 'import';
our @EXPORT = qw(add_exportstubs delete_exportstub);


# Unfortunately we can't entirely ignore the contents of CPAN modules -- some modules provide
# exports that have a real impact on how other code is parsed / whether other code can be compiled
# successfully.
#
# One solution is to require the user to install each of the modules listed below.
#
# Another (better?) solution is to provide bare-minimum stubs for these exports.
our %export_stubs = _parse_export_stubs(<<'EOF');
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
#die Dumper \%export_stubs;


# These modules MUST be installed locally and fully loaded, in order for other code to compile
# correctly. They just so happen to be mostly things that are bundled with Perl core.
our %do_not_stub = map {$_ => 1} qw(
        vars
        Carp
        Fcntl
        Socket
    );


# symbol prefixes:
#       >       is in @EXPORT_OK
sub _parse_export_stubs {
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


# TODO -- write documentation for this public API
#
# $here_doc is expected to be in a format that's parsable by _parse_export_stubs()
sub add_exportstubs {
    my ($here_doc) = @_;
    die "TODO -- implement me";
}


# Clears a single entry from %export_stubs. Though it's intended to be used mainly for DarkPAN
# modules, it does work on CPAN modules too.
sub delete_exportstub {
    my ($module) = @_;
    die "TODO -- implement me";
}


1;
