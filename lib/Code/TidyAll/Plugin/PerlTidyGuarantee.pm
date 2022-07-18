package Code::TidyAll::Plugin::PerlTidyGuarantee;
 
use strict;
use warnings;

our $VERSION = '0.01';

use parent 'Code::TidyAll::Plugin::PerlTidy';
use Perl::Tidy::Guarantee ();
 

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


# We're intercepting another module's internal-only sub, which... is not good. But we need the full
# path of the file, and I'm not sure how else to get it.
my $orig_cache_model_for = \&Code::TidyAll::_cache_model_for;
no warnings 'redefine';
*Code::TidyAll::_cache_model_for = sub {
        my ($self, $short_path, $full_path) = @_;
        $last_path_intercepted = $full_path->stringify;
        return $orig_cache_model_for->(@_);
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

