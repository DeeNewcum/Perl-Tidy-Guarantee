# Test whether the information in %export_stubs and %do_not_stub, within
# Perl::Tidy::Guarantee::ExportStubs, can properly be passed from parent process to child process
# (using Storable and File::Temp), when running B::Concise.

use strict;
use warnings;

use English;
use IPC::Open2 ();
use Test2::V0;

use Perl::Tidy::Guarantee ();
use Perl::Tidy::Guarantee::ExportStubs();


plan(4);

# Grab a copy of the initial contents of these two variables, so that we can ensure that each test
# runs in an isolated manner.
our %initial_export_stubs = %Perl::Tidy::Guarantee::ExportStubs::export_stubs;
our %initial_do_not_stub  = %Perl::Tidy::Guarantee::ExportStubs::do_not_stub;



exit;





sub restore_initial_contents {
    %Perl::Tidy::Guarantee::ExportStubs::export_stubs = %initial_export_stubs;
    %Perl::Tidy::Guarantee::ExportStubs::do_not_stub  = %initial_do_not_stub;
}


# We transfer whatever the current contents of %export_stubs and %do_not_stub from parent process to
# child process.
#
# This code is *VERY* similar to Perl::Tidy::Guarantee::_generate_optree().
sub transfer_parent_to_child {
    # Although this process normally happens as part of calling B::Concise, we're not going to
    # actually invoke B::Concise here. We want to zoom in on just the data structure that gets
    # transfered across.

    my $exportstubs_tempfile = Perl::Tidy::Guarantee::ExportStubs::_write_to_temp_file();

    my @cmd = ($EXECUTABLE_NAME);

    # TODO -- is this right? Do we want to add EVERY path in @INC to the command line?
    foreach my $inc (reverse @INC) {
        push(@cmd, "-I$inc")
            unless (ref($inc));     # skip any hooks in @INC
                                    # see https://perldoc.perl.org/functions/require#:~:text=hooks
    }
    push(@cmd, "-MPerl::Tidy::Guarantee::ExcludeCOPs=$exportstubs_tempfile");
    push(@cmd, "-MData::Dumper");
    push(@cmd, '-e', 'print Dumper \%Perl::Tidy::Guarantee::ExportStubs::export_stubs, \%%Perl::Tidy::Guarantee::ExportStubs::do_not_stub');

    # Here we use open(..., '-|') in place of IPC::Open3, because we only care about STDOUT in this
    # case. We want STDERR to go straight to the end user, uninterrupted, and we don't need to pipe
    # anything into STDIN.
    open my $chld_stdout, '-|', @cmd
        or die "Unable to start child process: $!\n";

    local $SIG{PIPE} = 'IGNORE';

    local $INPUT_RECORD_SEPARATOR = undef;      # slurp all the lines at once
    my $dumper_output = <$chld_stdout>;

    waitpid( $pid, 0 );

    # I don't think File::Temp::cleanup() will throw an error if we unlink the temp file early.
    unlink($exportstubs_tempfile);

    return $dumper_output;
}
