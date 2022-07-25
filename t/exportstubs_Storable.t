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


plan(2);

# Grab a copy of the initial contents of these two variables, so that we can ensure that each test
# runs in an isolated manner.
our %initial_export_stubs = %Perl::Tidy::Guarantee::ExportStubs::export_stubs;
our %initial_do_not_stub  = %Perl::Tidy::Guarantee::ExportStubs::do_not_stub;



# ---------------- check that transfer_parent_to_child() all by itself works
restore_initial_contents();

like(transfer_parent_to_child(),
     qr/^\$VAR1 = .*\bDecode_Date_EU2\b/s,
     'transfer_parent_to_child() by itself');


# ---------------- check that add_exportstubs() works
restore_initial_contents();

Perl::Tidy::Guarantee::add_exportstubs(<<'EOF');
Foo::Bar
    one_one_one_one
EOF

like(transfer_parent_to_child(),
     qr/\bone_one_one_one\b/s,
     'add_exportstubs() works');

exit;





sub restore_initial_contents {
    %Perl::Tidy::Guarantee::ExportStubs::export_stubs = %initial_export_stubs;
    %Perl::Tidy::Guarantee::ExportStubs::do_not_stub  = %initial_do_not_stub;
}


# We transfer whatever the current contents of %export_stubs and %do_not_stub from parent process to
# child process, then use Data::Dumper to send the text representation back to us.
sub transfer_parent_to_child {
    # Although this process normally happens as part of calling B::Concise, we're not going to
    # actually invoke B::Concise here. We want to zoom in on just the data structure that gets
    # transfered across.

    # apparently 'bless' will let you use damn near any string for the package name
    my $text_in = bless([], '--testing only--');    # cause $is_test_mode to be true
    my $dumper_output = Perl::Tidy::Guarantee::_generate_optree($text_in);

    return $dumper_output;
}
