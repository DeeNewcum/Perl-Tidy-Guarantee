package Perl::Tidy::Guarantee;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";

use Carp;                   # in Perl core since v5.000
use English;                # in Perl core since v5.000
use IPC::Open3 ();          # in Perl core since v5.000
use Symbol ();              # in Perl core

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
    return 0 if ($orig_CHILD_ERROR >> 8);      # should we die here?
    return 0 if ($CHILD_ERROR >> 8);      # should we die here?

    if ($optree_before_tidying ne $optree_after_tidying) {
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

    my @cmd = ($EXECUTABLE_NAME);
    # TODO -- is this right? Do we want to add EVERY path in @INC to the command line?
    foreach my $inc (reverse @INC) {
        push(@cmd, "-I$inc")
            unless (ref($inc));     # skip any "hooks" in @INC
                                    # see https://perldoc.perl.org/functions/require#:~:text=hooks
    }
    push(@cmd, "-MO=Concise");
    push(@cmd, "-MPerl::Tidy::Guarantee::ExcludeCOPs");

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
    print $chld_in $perl_source;
    close $chld_in;

    local $INPUT_RECORD_SEPARATOR = undef;
    my $optree = <$chld_out>;
    my $chld_err_str = <$chld_err>;
    if ($chld_err_str !~ /^- syntax OK\s*$/s) {
        if (defined($filename)) {
            # insert the desired filename into the error message
            $chld_err_str =~ s/(?<= at )-(?= line \d+)/$filename/g;
        }
        print STDERR $chld_err_str;
    }

    waitpid( $pid, 0 );

    if ($? << 8) {
        # DELETE THIS SECTION before releasing, this is DEBUG ONLY
        #use Path::Tiny ();
        #Path::Tiny::path("oops.pl")->spew($perl_source);
        #print STDERR "perl -MO=Concise had an exit code of " . ($? << 8) . " and a signal of " . ($? & 127) .  "\n";
        exit(1);
    }

    if ($optree eq '') {
        die "perl -MO=Concise returned an empty string.\n";
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

=head1 DESCRIPTION

A guarantee is provided by doing this:

Perl::Tidy is run on the desired piece of code. Both before and after running Perl::Tidy, this
module passes your code through L<B::Concise>, which is a module that generates a textual
representation of Perl's internal L<OP tree|perloptree>. If that OP tree has changed (excluding
COPs, which are Control OPs, which merely contain line number information used for debugging), then
an error is thrown.

=head1 WHAT DOES PERL::TIDY SAY?

perltidy.sourceforge.net/FAQ.html (which unfortunately became a dead link) L<used to
read|https://web.archive.org/web/20180609065751/http://perltidy.sourceforge.net/FAQ.html> "an error
in which a reformatted script does not function correctly is quite serious. … Perltidy goes to great
lengths to catch any mistakes that it might make, and it reports all such errors. For example, it
checks for balanced braces, parentheses, and square brackets. And it runs a perl syntax check on the
reformatted script if possible. (It cannot do this unless all modules referenced on use statements
are available). B<There is no guarantee that these checks will catch every error>, but they are
quite effective. For example, if perltidy were to accidentally miss the start of a here document, it
would most likely report a syntax error after trying to parse the contents of the here document …
It's difficult to give an absolute measure of reliability, but to give some practical sense of it, I
can mention that I have a growing collection of perl scripts, currently about 500 MB in size, that I
process in nightly batch runs after every programming change. ... Of the perl scripts that were
written by people other than myself, Perltidy only fails to parse 1 correctly, as far as I can tell,
and for that file, perltidy catches its own error and ends with a message to that effect."

To me, that gets 99% of the way there, but I still worry that final 1% could bite me in the butt in
production.

=head2 What does PPI say?

Perl::Tidy doesn't do the parsing of Perl code on its own, as this is a L<very difficult
problem|https://everything2.com/title/Only+perl+can+parse+Perl>. Instead, it relies on L<PPI> to do
the parsing for it.

L<PPI::Tokenizer> says "The Tokenizer uses an immense amount of heuristics, guessing and cruft …
It is by far the most complex and twisty piece of perl I've ever written that is actually still
built properly and isn't a terrible spaghetti-like mess."

L<PPI> says "PPI seeks to be good enough … However, there are going to be limits to this process. …
B<Any code written using source filters should not be assumed to be parsable.> … There are only 28
non-Acme Perl modules in CPAN that PPI is incapable of parsing."

Note that L<Filter::Util::Call> is a L<river
stage|https://metacpan.org/about/faq#whatdoestheriverstageindicate> four, and I count 16 .xs files
in CPAN that call L<filter_add()|perlfilter>, one being a river stage three (L<Devel::Declare>). So
this isn't necessarily a small issue. (however, it's unclear whether source filters ever modify code
beyond the file that directly C<use>d them, whether their influence ever cascades to "files that use
files that use source filters" or beyond)

=head1 LICENSE

Copyright (C) Dee Newcum.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Dee Newcum E<lt>deenewcum@cpan.orgE<gt>

=cut

