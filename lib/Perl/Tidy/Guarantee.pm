package Perl::Tidy::Guarantee;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

use English;                # in Perl core since v5.000
use IPC::Open3 ();          # in Perl core since v5.000
use Symbol ();              # in Perl core

use Carp;                   # in Perl core since v5.000
our @CARP_NOT = (__PACKAGE__);

use Perl::Tidy::Guarantee::ExportStubs qw(add_exportstubs delete_exportstub);
use Exporter 5.57 'import';
our @EXPORT = qw(add_exportstubs delete_exportstub);        # re-export these public APIs


# right now, this variable is used only by random_mashup.pl
our $special_debug_mode = 0;

# dies if there's a non-cosmetic difference
#
# parameter '$filename' is entirely optional, and is used only as an arbitrary human-readable string
sub tidy_compare {
    my ($code_before_tidying, $code_after_tidying, $filename) = @_;

    my $optree_before_tidying = _generate_optree($code_before_tidying, $filename);
    my $orig_CHILD_ERROR = $CHILD_ERROR;
    my $optree_after_tidying  = _generate_optree($code_after_tidying, $filename);
    if ($special_debug_mode) {
        if (($optree_before_tidying eq '' && $optree_after_tidying eq '')
            || ($optree_before_tidying ne '' && $optree_after_tidying ne ''))
        {
            return 1;
        }
    }
    return 0 if ($orig_CHILD_ERROR >> 8);      # should we croak here?
    return 0 if ($CHILD_ERROR >> 8);      # should we croak here?

    if (!defined($optree_before_tidying)
        || !defined($optree_after_tidying)
        || $optree_before_tidying ne $optree_after_tidying)
    {
        croak "tidy_compare() found a functional change";
    }

    return 1;
}


# Input -- the contents of one Perl source file
# Output -- what B::Concise produces from that source file
#
# parameter '$filename' is entirely optional, and is used only as an arbitrary human-readable string
sub _generate_optree {
    my ($perl_source, $filename) = @_;

    # used only by t/exportstubs_Storable.t
    my $is_test_mode = (ref($perl_source) eq '--testing only--');

    my $exportstubs_tempfile = Perl::Tidy::Guarantee::ExportStubs::_write_to_temp_file();

    my @cmd = ($EXECUTABLE_NAME);
    # TODO -- is this right? Do we want to add EVERY path in @INC to the command line?
    foreach my $inc (reverse @INC) {
        push(@cmd, "-I$inc")
            unless (ref($inc));     # skip any hooks in @INC
                                    # see https://perldoc.perl.org/functions/require#:~:text=hooks
    }
    push(@cmd, "-MO=Concise")
        if (!$is_test_mode);
    push(@cmd, "-MPerl::Tidy::Guarantee::ExcludeCOPs=$exportstubs_tempfile");
    if ($is_test_mode) {
        push(@cmd, '-MData::Dumper');
        push(@cmd, '-e', 'print Dumper \%Perl::Tidy::Guarantee::ExportStubs::export_stubs, \%Perl::Tidy::Guarantee::ExportStubs::do_not_stub');

        if (0) {
            # output a command-line string that can be copy-n-pasted directly into the shell
            use Data::Dumper ();
            foreach (@cmd) {
                if (/[ \t'"\\]/) {
                    print Data::Dumper::_quote($_), " ";
                } else {
                    print "$_ ";
                }
            }
            print "\n";
            exit;
        }
    }

    my $chld_err = Symbol::gensym();
    my $pid = IPC::Open3::open3(my $chld_in, my $chld_out, $chld_err,
                    @cmd);

    # When run without a -e or a script filename, Perl tries to read the Perl source from STDIN.
    # NOTE that if a script attempts to read from STDIN within a BEGIN {} block, it will end up
    # reading an empty string (versus stopping and waiting for information to be read in, if we were
    # to instead write the source code to a File::Temp file first, and pass that filename into
    # @cmd). Honestly though, it seems like it'd be pretty weird to read from STDIN during a
    # BEGIN {} block.
    local $SIG{PIPE} = 'IGNORE';
    print $chld_in $perl_source
        if (!$is_test_mode);
    close $chld_in;

    local $INPUT_RECORD_SEPARATOR = undef;      # slurp all the lines at once
    my $optree = <$chld_out>;
    my $chld_err_str = <$chld_err>;
    if ($chld_err_str !~ /^- syntax OK\s*$/s) {
        if (defined($filename)) {
            # insert the desired filename into the error message
            $chld_err_str =~ s/(?<= at )-(?= line \d+)|^-(?= had compilation errors)/$filename/mg;
        }
        print STDERR $chld_err_str;
    }

    waitpid( $pid, 0 );

    # I don't think File::Temp::cleanup() will throw an error if we unlink the temp file early.
    unlink($exportstubs_tempfile);

    if ($? << 8) {
        # DELETE THIS SECTION before releasing, this is DEBUG ONLY
        #use Path::Tiny ();
        #Path::Tiny::path("oops.pl")->spew($perl_source);
        #print STDERR "perl -MO=Concise had an exit code of " . ($? << 8) . " and a signal of " . ($? & 127) .  "\n";
        #exit(1);
        return undef;
    }

    if ($optree eq '') {
        croak "perl -MO=Concise returned an empty string.\n";
    }

    return $optree;
}


1;
__END__

=encoding utf-8

=head1 NAME

Perl::Tidy::Guarantee - Provides a guarantee that Perl::Tidy has only made cosmetic non-functional
changes to your code

=head1 REASON FOR EXISTENCE

L<Perl::Tidy> I<tries> to only make cosmetic changes to your code. Unfortunately, it provides no
guarantees about whether it can absolutely avoid making any functional changes. If you have a lot of
poorly-indented code in production, like I do, that's a problem.

Perl::Tidy::Guarantee performs some extra checks after Perl::Tidy is finished, and so is able to
provide you that guarantee.

=head1 SYNOPSIS

    # Create a tidyall.ini or .tidyallrc at the top of your project
    #
    # If you have an existing tidyall.ini or .tidyallrc, simply rename
    # the [PerlTidy] section to [PerlTidyGuarantee].
    #
    [PerlTidyGuarantee]
    select = **/*.{pl,pm,t}
    argv = -noll -it=2

    # Process one or more specific files,
    # look upwards from the first file for conf file
    #
    % tidyall file [file...]

See L<tidyall> for more.

=head1 WHAT DOES PERL::TIDY SAY?

perltidy.sourceforge.net/FAQ.html L<used to
read|https://web.archive.org/web/20180609065751/http://perltidy.sourceforge.net/FAQ.html> "an error
in which a reformatted script does not function correctly is quite serious. ??? Perltidy goes to great
lengths to catch any mistakes that it might make, and it reports all such errors. For example, it
checks for balanced braces, parentheses, and square brackets. And it runs a perl syntax check on the
reformatted script if possible. (It cannot do this unless all modules referenced on use statements
are available). B<There is no guarantee that these checks will catch every error>, but they are
quite effective. For example, if perltidy were to accidentally miss the start of a here document, it
would most likely report a syntax error after trying to parse the contents of the here document ???
It's difficult to give an absolute measure of reliability, but to give some practical sense of it, I
can mention that I have a growing collection of perl scripts, currently about 500 MB in size, that I
process in nightly batch runs after every programming change. ... Of the perl scripts that were
written by people other than myself, Perltidy only fails to parse 1 correctly, as far as I can tell,
and for that file, perltidy catches its own error and ends with a message to that effect."

To me, that gets 99% of the way there, but I still worry that final 1% could bite me in the butt in
production.

=head2 What does PPI say?

Perl::Tidy doesn't do the parsing of Perl code on its own, as this is a L<VERY difficult
problem|PPI/"Background">. Instead, it relies on L<PPI> to do the parsing for it. PPI is the
recognized leader in parsing Perl code, outside of the Perl interpreter itself.

L<PPI::Tokenizer> says "The Tokenizer uses an immense amount of heuristics, guessing and cruft ???
It is by far the most complex and twisty piece of perl I've ever written that is actually still
built properly and isn't a terrible spaghetti-like mess."

L<PPI> says "PPI seeks to be good enough ??? However, there are going to be limits to this process. ???
B<Any code written using source filters should not be assumed to be parsable.> ??? There are only 28
non-Acme Perl modules in CPAN that PPI is incapable of parsing."

Note that L<Filter::Util::Call> is a L<river
stage|https://metacpan.org/about/faq#whatdoestheriverstageindicate> four, and I count 16 .xs files
in CPAN that call L<filter_add()|perlfilter>, one being a river stage three (L<Devel::Declare>). So
this isn't necessarily a small issue. (however, it's unclear whether source filters ever modify code
beyond the file that directly C<use>d them, whether their influence ever cascades to "files that use
files that use source filters")

=head1 HOW IT WORKS

A guarantee is provided by doing this:

=over

=item 1

run Perl::Tidy on the desired piece of code

=item 2

generate the L<optree|perloptree> from the before-perltidy-source

=over

=item

(The optree is the "bytecode" that Perl uses internally, and it roughly corresponds to the syntax
tree. L<B::Concise> is used to generate its textual representation.)

=back

=item 3

generate the optree from the after-perltidy-source

=item 4

compare the two optrees; if a difference is found, then we declare that Perl::Tidy has created a
functional change in the desired piece of code

=back

=head1 EXPORT-STUBS FOR PRIVATE COMPANY MODULES

TODO -- Provide some background information for why any export-stub information is needed in the
first place. I imagine that newcommers will feel kind of lost without that information.

To provide support for private organizations who have their own
L<DarkPAN|https://www.olafalders.com/2019/02/19/about-the-various-pans/> modules, we provide a way to
pass additional export-stub information to us.

=head2 How to get your code loaded within tidyall

Create a new module and put it somewhere that's within your C<@INC> or $PERL5LIB. Copy-and-paste
something like this into F<Code/TidyAll/Plugin/CompanyName_stubs.pm>:

    package Code::TidyAll::Plugin::CompanyName_stubs;

    use strict;
    use warnings;

    # While this line pulls in a lot of methods, it really is just needed so that
    # Code::TidyAll can successfully load this module from tidyall.ini.
    use parent 'Code::TidyAll::Plugin';

    use Perl::Tidy::Guarantee;


    add_exportstubs(<<'EOF');
    # ------------------------------------------------------------------------------

    CompanyName::Logger
        log

    CompanyName::ConnectToDB
        dbconnect

    # (adjust this text as needed for your custom stubs)

    # ------------------------------------------------------------------------------
    EOF


    1;

Then you need to cause your custom-stub module to be loaded by Code::TidyAll. To do that, simply add
this to your F<tidyall.ini> or F<.tidyallrc>:

    [CompanyName_stubs]
    # the above line should cause the information within Code::TidyAll::Plugin::CompanyName_stubs to
    # be loaded

=head2 add_exportstubs( $here_doc )

C<$here_doc> is a multi-line string, written in a custom syntax. It's not well-documented yet, but
you can look at L<Perl::Tidy::Guarantee::ExportStubs>'s C<%export_stubs> and
C<_parse_export_stubs()> to get an idea of the expected format.

TODO -- document this better

TODO -- Might we consider changing the syntax to L<YAML::XS> instead? That might be much better
documented, and more intuitive?

=head2 delete_exportstub( $module )

Clears the current export-stub information for the specified module. While it's mainly intended for
DarkPAN modules, it does work with any module's information.

Returns a boolean indicating whether that module's entry could be deleted.

=head1 CURRENT STATUS

At this point, I've got 497 SLOC written across 9 Perl files and 103 commits, and I started
publishing this project 23 days ago. And version 1 is only 80% complete.

PPI says presciently "Using an embedded perl parser was widely considered to be the most likely
avenue for finding a solution to parsing Perl. It has been investigated from time to time, but
attempts have generally failed or suffered from sufficiently bad corner cases that they were
abandoned."

Here. Be. Dragons.

Blithely ignoring that sage advise, I forged ahead, trying to... literally use an embedded Perl
parser to double-check Perl::Tidy's work.

Currently, I feel that I can "see the light at the end of the tunnel" ??? I feel I'm close to being
able to wrap this project up. However, B<do note> that I've felt I could see the light at the end of
the tunnel for 30+ hours now, so take that with a grain of salt.

=head1 LICENSE

Copyright (C) Dee Newcum.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Dee Newcum E<lt>deenewcum@cpan.orgE<gt>

=cut

