package Perl::Tidy::Guarantee;
use 5.008001;
use strict;
use warnings;

our $VERSION = "0.01";


sub compare {
    my ($code_before_tidying, $code_after_tidying) = @_;
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
poorly-indented production code, like I do, that's a problem.

Perl::Tidy::Guarantee does some extra checks after Perl::Tidy is finished, and so is able to provide
you that guarantee.

=head1 SYNOPSIS

    use Perl::Tidy::Guarantee;

    # compare() will die if a non-cosmetic change is detected
    Perl::Tidy::Guarantee::compare($code_before_tidying, $code_after_tidying);

=head1 DESCRIPTION

A guarantee is provided by doing this:

Perl::Tidy is run on the desired piece of code. Both before and after running Perl::Tidy, this
module passes your code through L<B::Concise>, which is a module that generates a textual
representation of Perl's internal OP tree. If that OP tree has changed (excluding COPs, which are
Control OPs, which contain line number information used for debugging), then an error is thrown.

=head1 WHAT PERL::TIDY SAYS

L<http://perltidy.sourceforge.net/FAQ.html> reads "an error in which a reformatted script does not
function correctly is quite serious. … Perltidy goes to great lengths to catch any mistakes that it
might make, and it reports all such errors. For example, it checks for balanced braces, parentheses,
and square brackets. And it runs a perl syntax check on the reformatted script if possible. (It
cannot do this unless all modules referenced on use statements are available). B<There is no
guarantee that these checks will catch every error>, but they are quite effective. For example, if
perltidy were to accidentally miss the start of a here document, it would most likely report a
syntax error after trying to parse the contents of the here document … It's difficult to give an
absolute measure of reliability, but to give some practical sense of it, I can mention that I have a
growing collection of perl scripts, currently about 500 MB in size, that I process in nightly batch
runs after every programming change. ... Of the perl scripts that were written by people other than
myself, Perltidy only fails to parse 1 correctly, as far as I can tell, and for that file, perltidy
catches its own error and ends with a message to that effect."

To me, that gets 99% of the way there, but that final 1% could still bite me in the butt in
production.

=head2 What PPI says

Perl::Tidy doesn't do the parsing of Perl code on its own, as this is a L<very difficult
problem|https://everything2.com/title/Only+perl+can+parse+Perl>. Instead, it relies on L<PPI> to do
the parsing for it.

L<PPI::Tokenizer> says "The Tokenizer uses an immense amount of heuristics, guessing and cruft …
It is by far the most complex and twisty piece of perl I've ever written that is actually still
built properly and isn't a terrible spaghetti-like mess."

L<PPI> says "How good is Good Enough? … B<Any code written using source filters should not be
assumed to be parsable.> … There are only 28 non-Acme Perl modules in CPAN that PPI is incapable of
parsing.".

Note that L<Filter::Util::Call> is a L<river
stage|https://metacpan.org/about/faq#whatdoestheriverstageindicate> four, and I count 16 .xs files
in CPAN that L<call filter_add()|perlfilter>, L<one being|Devel::Declare> river stage three. So it
isn't a small issue.

=head1 LICENSE

Copyright (C) Dee Newcum.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Dee Newcum E<lt>deenewcum@cpan.orgE<gt>

=cut

