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



# confirm that transfer_parent_to_child() all by itself works
restore_initial_contents();
print STDERR ">>>>", transfer_parent_to_child(), "<<<<\n";


exit;





sub restore_initial_contents {
    %Perl::Tidy::Guarantee::ExportStubs::export_stubs = %initial_export_stubs;
    %Perl::Tidy::Guarantee::ExportStubs::do_not_stub  = %initial_do_not_stub;
}


# We transfer whatever the current contents of %export_stubs and %do_not_stub from parent process to
# child process.
sub transfer_parent_to_child {
    # Although this process normally happens as part of calling B::Concise, we're not going to
    # actually invoke B::Concise here. We want to zoom in on just the data structure that gets
    # transfered across.

    # apparently 'bless' will let you use damn near any string for the package name
    my $text_in = bless([], '--testing only--');    # cause $is_test_mode to be true
    my $text_out = Perl::Tidy::Guarantee::_generate_optree($text_in);

    return $text_out;
}
