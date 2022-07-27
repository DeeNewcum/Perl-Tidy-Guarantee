package Perl::Tidy::Guarantee::ExportStubs;

# Provides a centralized place to store export-stub information.
#
# Also provides a public API for companies to add export-stub information for
# their own DarkPAN modules. See Perl/Tidy/Guarantee.pm for POD documentation
# of this public API.

use strict;
use warnings;

use File::Temp ();      # in Perl core since v5.6.1
use Storable ();        # in Perl core since v5.7.3

use Exporter 5.57 'import';
our @EXPORT_OK = qw(add_exportstubs delete_exportstub);


# These modules MUST be installed locally and fully loaded, in order for other code to compile
# correctly. They just so happen to be mostly things that are bundled with Perl core.
our %do_not_stub;


# Unfortunately Perl::Tidy::Guarantee::DontLoadAnyModules can't entirely ignore the contents of CPAN
# modules -- some modules provide exports that have a real impact on how other code is parsed /
# whether other code can be compiled successfully.
#
# One solution is to require the user to install each of the modules listed below.
#
# A better solution is to provide bare-minimum stubs for just the modules' exports.

# TODO -- Prune this export-stub information to just what's needed by
#         Perl::Tidy::Guarantee::NoStrictSubs -- I don't think we need to cater to
#         Perl::Tidy::Guarantee::DontLoadAnyModules any more, since NoStrictSubs seems to do a
#         capable job.
our %export_stubs = _parse_export_stubs(<<'EOF');
# ------------------------------------------------------------------------------

Moose
    extends with has before after around override augment super inner

Catalyst
    extends with has before after around override augment super inner

Moose::Role
    extends with has before after around override augment super inner

Mouse
    extends with has before after around override super augment inner

Moo
    extends with has before after around

MooX
    extends with has before after around

inc::Module::Install
    name all_from abstract abstract_from author author_from version version_from license
    license_from perl_version perl_version_from recommends requires test_requires configure_requires
    requires_external_bin install_script no_index installdirs install_as_core install_as_cpan
    install_as_site install_as_vendor WriteAll

# vars.pm exports the requested scalars/lists/hashes, and it should be allowed to do so
vars
    (don't stub)

Carp
    (don't stub)

Fcntl
    (don't stub)

Socket
    (don't stub)

# sets several useful variables
FindBin
    (don't stub)

# sets $opt_* as a side-effect
Getopt::Std
    (don't stub)

Test::More
    (don't stub)

# ------------------------------------------------------------------------------
EOF

#use Data::Dumper;
#print STDERR Data::Dumper->Dump([\%export_stubs, \%do_not_stub], [qw(%export_stubs %do_not_stub)]); exit;


# symbol suffixes:
#       =OK         should be in @EXPORT_OK
#       =new        should be treated like a FooBar->new() stub, in that it should return a blessed reference
sub _parse_export_stubs {
    my ($here_doc) = @_;

    my %ret;

    # TODO -- now that this can be called via an outside API (add_exportstubs()), is there any way
    #         we can provide minimal error-reporting?

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

            if (@tokens == 2 && $tokens[0] eq "(don't" && $tokens[1] eq "stub)") {
                $do_not_stub{$current_module} = 1;
                next;
            }

            foreach my $token (@tokens) {
                if ($token eq 'new') {
                    # automatically use stub_new() for subs titled 'new'
                    $token .= '=new';
                }

                if ($token =~ s/=.*//) {
                    $ret{$current_module}{$token} = $&;
                } else {
                    $ret{$current_module}{$token} = '';
                }
            }
        }
    }

    return %ret;
}


# $here_doc is expected to be in a format that's parsable by _parse_export_stubs()
sub add_exportstubs {
    my ($here_doc) = @_;
    my %new_exportstubs = _parse_export_stubs($here_doc);

    # Merge %new_exportstubs into %export_stubs.
    while (my ($module, $stubs) = each %new_exportstubs) {
        while (my ($symbol, $value) = each %$stubs) {
            $export_stubs{$module}{$symbol} = $value;
        }
    }
}


# Clears a single entry from %export_stubs. Though it's intended to be used mainly for DarkPAN
# modules, it does work on CPAN modules too.
#
# Returns a boolean indicating whether that module's entry could be deleted.
sub delete_exportstub {
    my ($module) = @_;
    my $ret = exists $export_stubs{$module};
    delete $export_stubs{$module};
    return $ret;
}


# Writes the contents of %export_stubs and %do_not_stub to a File::Temp file.
#
# The parent process calls this, just before creating the child process via IPC::Open3.
sub _write_to_temp_file {
    my ($temp_fh, $temp_filename) = File::Temp::tempfile();
    Storable::nstore_fd({
            export_stubs => \%export_stubs,
            do_not_stub  => \%do_not_stub,
        },
        $temp_fh);
    close($temp_fh);
    return $temp_filename;
}


# Reads the contents of %export_stubs and %do_not_stub from the specified file.
#
# The child process calls this at the very beginning, as it starts up.
sub _read_from_file {
    my ($filename) = @_;
    my $hashref = Storable::retrieve($filename);
    %export_stubs = %{$hashref->{export_stubs}};
    %do_not_stub  = %{$hashref->{do_not_stub}};
}


1;
