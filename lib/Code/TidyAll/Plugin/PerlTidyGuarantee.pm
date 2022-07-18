package Code::TidyAll::Plugin::PerlTidyGuarantee;
 
use strict;
use warnings;

our $VERSION = '0.01';

use parent 'Code::TidyAll::Plugin::PerlTidy';
use Perl::Tidy::Guarantee ();
use Path::Tiny ();
 

my $last_path_intercepted;


sub transform_source {
    my $self = shift;
    my ($source_before_tidying) = @_;
    my $source_after_tidying = $self->SUPER::transform_source(@_);
    # dies if a difference is found
    Perl::Tidy::Guarantee::tidy_compare($source_before_tidying, $source_after_tidying,
                                        $last_path_intercepted);
    return $source_after_tidying;
}


# We're intercepting another module's sub, which... is not good. But we need the full path of the
# file, and I'm not sure how else to get it.
my $orig_slurp_raw = \&Path::Tiny::slurp_raw;
no warnings 'redefine';
*Path::Tiny::slurp_raw = sub {
        my ($self) = @_;
        $last_path_intercepted = $self->stringify;
        return $orig_slurp_raw->(@_);
    };


1;
__END__

=encoding utf-8

=head1 NAME

Code::TidyAll::Plugin::PerlTidyGuarantee - A plugin for Code::TidyAll that provides a guarantee that Perl::Tidy has only
made cosmetic non-functional changes to your code

=head1 SYNOPSIS

In your F<tidyall.ini> or F<.tidyallrc> file, rename any C<[PerlTidy]> section to C<[PerlTidyGuarantee]>.

Do B<not> try to set parameters in C<[PerlTidy]> directly, or the C<tidy_compare()> sub won't get run.

=head1 LICENSE

Copyright (C) Dee Newcum.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Dee Newcum E<lt>deenewcum@cpan.orgE<gt>

=cut

