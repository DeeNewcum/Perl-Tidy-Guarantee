# NAME

Perl::Tidy::Guarantee - Provides a guarantee that Perl::Tidy has only made cosmetic non-functional
changes to your code

# REASON FOR EXISTENCE

[Perl::Tidy](https://metacpan.org/pod/Perl%3A%3ATidy) _tries_ to only make cosmetic changes to your code. Unfortunately, it provides no
guarantees about whether it can absolutely avoid making any functional changes. If you have a lot of
poorly-indented production code, like I do, that's a problem.

Perl::Tidy::Guarantee performs some extra checks after Perl::Tidy is finished, and so is able to
provide you that guarantee.

# SYNOPSIS

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

See [tidyall](https://metacpan.org/pod/tidyall) for more.

# DESCRIPTION

A guarantee is provided by doing this:

Perl::Tidy is run on the desired piece of code. Both before and after running Perl::Tidy, this
module passes your code through [B::Concise](https://metacpan.org/pod/B%3A%3AConcise), which is a module that generates a textual
representation of Perl's internal [OP tree](https://metacpan.org/pod/perloptree). If that OP tree has changed (excluding
COPs, which are Control OPs, which merely contain line number information used for debugging), then
an error is thrown.

# WHAT DOES PERL::TIDY SAY?

perltidy.sourceforge.net/FAQ.html [used to
read](https://web.archive.org/web/20180609065751/http://perltidy.sourceforge.net/FAQ.html) "an error
in which a reformatted script does not function correctly is quite serious. … Perltidy goes to great
lengths to catch any mistakes that it might make, and it reports all such errors. For example, it
checks for balanced braces, parentheses, and square brackets. And it runs a perl syntax check on the
reformatted script if possible. (It cannot do this unless all modules referenced on use statements
are available). **There is no guarantee that these checks will catch every error**, but they are
quite effective. For example, if perltidy were to accidentally miss the start of a here document, it
would most likely report a syntax error after trying to parse the contents of the here document …
It's difficult to give an absolute measure of reliability, but to give some practical sense of it, I
can mention that I have a growing collection of perl scripts, currently about 500 MB in size, that I
process in nightly batch runs after every programming change. ... Of the perl scripts that were
written by people other than myself, Perltidy only fails to parse 1 correctly, as far as I can tell,
and for that file, perltidy catches its own error and ends with a message to that effect."

To me, that gets 99% of the way there, but that final 1% could still bite me in the butt in
production.

## What does PPI say?

Perl::Tidy doesn't do the parsing of Perl code on its own, as this is a [very difficult
problem](https://everything2.com/title/Only+perl+can+parse+Perl). Instead, it relies on [PPI](https://metacpan.org/pod/PPI) to do
the parsing for it.

[PPI::Tokenizer](https://metacpan.org/pod/PPI%3A%3ATokenizer) says "The Tokenizer uses an immense amount of heuristics, guessing and cruft …
It is by far the most complex and twisty piece of perl I've ever written that is actually still
built properly and isn't a terrible spaghetti-like mess."

[PPI](https://metacpan.org/pod/PPI) says "How good is Good Enough? … **Any code written using source filters should not be
assumed to be parsable.** … There are only 28 non-Acme Perl modules in CPAN that PPI is incapable of
parsing.".

Note that [Filter::Util::Call](https://metacpan.org/pod/Filter%3A%3AUtil%3A%3ACall) is a [river
stage](https://metacpan.org/about/faq#whatdoestheriverstageindicate) four, and I count 16 .xs files
in CPAN that [call filter\_add()](https://metacpan.org/pod/perlfilter), [one being](https://metacpan.org/pod/Devel%3A%3ADeclare) river stage three. So this
isn't necessarily a small issue.

# LICENSE

Copyright (C) Dee Newcum.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Dee Newcum <deenewcum@cpan.org>
