# NAME

Perl::Tidy::Guarantee - Provides a guarantee that Perl::Tidy has only made cosmetic non-functional
changes to your code

# REASON FOR EXISTENCE

[Perl::Tidy](https://metacpan.org/pod/Perl%3A%3ATidy) _tries_ to only make cosmetic changes to your code. Unfortunately, it provides no
guarantees about whether it can absolutely avoid making any functional changes. If you have a lot of
poorly-indented code in production, like I do, that's a problem.

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

To me, that gets 99% of the way there, but I still worry that final 1% could bite me in the butt in
production.

## What does PPI say?

Perl::Tidy doesn't do the parsing of Perl code on its own, as this is a [VERY difficult
problem](https://metacpan.org/pod/PPI#Background). Instead, it relies on [PPI](https://metacpan.org/pod/PPI) to do the parsing for it. PPI is the
recognized leader in parsing Perl code, outside of the Perl interpreter itself.

[PPI::Tokenizer](https://metacpan.org/pod/PPI%3A%3ATokenizer) says "The Tokenizer uses an immense amount of heuristics, guessing and cruft …
It is by far the most complex and twisty piece of perl I've ever written that is actually still
built properly and isn't a terrible spaghetti-like mess."

[PPI](https://metacpan.org/pod/PPI) says "PPI seeks to be good enough … However, there are going to be limits to this process. …
**Any code written using source filters should not be assumed to be parsable.** … There are only 28
non-Acme Perl modules in CPAN that PPI is incapable of parsing."

Note that [Filter::Util::Call](https://metacpan.org/pod/Filter%3A%3AUtil%3A%3ACall) is a [river
stage](https://metacpan.org/about/faq#whatdoestheriverstageindicate) four, and I count 16 .xs files
in CPAN that call [filter\_add()](https://metacpan.org/pod/perlfilter), one being a river stage three ([Devel::Declare](https://metacpan.org/pod/Devel%3A%3ADeclare)). So
this isn't necessarily a small issue. (however, it's unclear whether source filters ever modify code
beyond the file that directly `use`d them, whether their influence ever cascades to "files that use
files that use source filters")

# HOW IT WORKS

A guarantee is provided by doing this:

1. run Perl::Tidy on the desired piece of code
2. generate the [optree](https://metacpan.org/pod/perloptree) from the before-perltidy-source
    - (The optree is the "bytecode" that Perl uses internally, and it roughly corresponds to the syntax
    tree. [B::Concise](https://metacpan.org/pod/B%3A%3AConcise) is used to generate its textual representation.)
3. generate the optree from the after-perltidy-source
4. compare the two optrees; if a difference is found, then we declare that Perl::Tidy has created a
functional change in the desired piece of code

# EXPORT-STUBS FOR PRIVATE COMPANY MODULES

TODO -- Provide some background information for why any export-stub information is needed in the
first place. I imagine that newcommers will feel kind of lost without that information.

To provide support for private organizations who have their own
[DarkPAN](https://www.olafalders.com/2019/02/19/about-the-various-pans/) modules, we provide a way to
pass additional export-stub information to us.

## How to get your code loaded within tidyall

Create a new module and put it somewhere that's within your `@INC` or $PERL5LIB. Copy-and-paste
something like this into `Code/TidyAll/Plugin/CompanyName_stubs.pm`:

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
this to your `tidyall.ini` or `.tidyallrc`:

    [CompanyName_stubs]
    # the above line should cause the information within Code::TidyAll::Plugin::CompanyName_stubs to
    # be loaded

## add\_exportstubs( $here\_doc )

`$here_doc` is a multi-line string, written in a custom syntax. It's not well-documented yet, but
you can look at [Perl::Tidy::Guarantee::ExportStubs](https://metacpan.org/pod/Perl%3A%3ATidy%3A%3AGuarantee%3A%3AExportStubs)'s `%export_stubs` and
`_parse_export_stubs()` to get an idea of the expected format.

TODO -- document this better

TODO -- Might we consider changing the syntax to [YAML::XS](https://metacpan.org/pod/YAML%3A%3AXS) instead? That might be much better
documented, and more intuitive?

## delete\_exportstub( $module )

Clears the current export-stub information for the specified module. While it's mainly intended for
DarkPAN modules, it does work with any module's information.

Returns a boolean indicating whether that module's entry could be deleted.

# CURRENT STATUS

At this point, I've got 497 SLOC written across 9 Perl files and 103 commits, and I started
publishing this project 23 days ago. And version 1 is only 80% complete.

PPI says presciently "Using an embedded perl parser was widely considered to be the most likely
avenue for finding a solution to parsing Perl. It has been investigated from time to time, but
attempts have generally failed or suffered from sufficiently bad corner cases that they were
abandoned."

Here. Be. Dragons.

Blithely ignoring that sage advise, I forged ahead, trying to... literally use an embedded Perl
parser to double-check Perl::Tidy's work.

Currently, I feel that I can "see the light at the end of the tunnel" — I feel I'm close to being
able to wrap this project up. However, **do note** that I've felt I could see the light at the end of
the tunnel for 30+ hours now, so take that with a grain of salt.

# LICENSE

Copyright (C) Dee Newcum.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Dee Newcum <deenewcum@cpan.org>
