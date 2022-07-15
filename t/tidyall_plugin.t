use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Exception qw(dies lives);

use Code::TidyAll;
use Code::TidyAll::Plugin::PerlTidyGuarantee;
use Scalar::Util;
use Test::MockModule;

plan(2);


my $source_before_tidy1 = <<'EOF';
    for
        (1
            ..
            3
        )
    {
        print
            "hello world"
    }
EOF

my $tidyall = Code::TidyAll->new(
        root_dir => '.',
        plugins => { },
        no_cache => 1,          # don't litter my Git repo with **/tidyall.d/ directories
        no_backups => 1,        # don't litter my Git repo with **/tidyall.d/ directories
    );

# Why does Code::TidyAll::Plugin::PerlTidyGuarantee->new() error out if we uncomment the following
# line? Code::TidyAll::Plugin specifically says that the 'tidyall' parameter should be a 'weak_ref'.
#Scalar::Util::weaken($tidyall);

my $guarantee_plugin = Code::TidyAll::Plugin::PerlTidyGuarantee->new(
        select  => '*',
        name    => 'PerlTidyGuarantee',
        tidyall => $tidyall,
        argv    => '--noprofile',      # ignore any .perltidyrc the user might have
    );

my $is_lives = lives { $guarantee_plugin->transform_source($source_before_tidy1) };
    
ok($is_lives, "tidyall should succeed");

if (!$is_lives) {
    # call it without lives(), so that any error messages will be visible to the user
    $guarantee_plugin->transform_source($source_before_tidy1);
}
    

# The goal here is to find a piece of code that succeeds with Perl::Tidy but fails with
# Perl::Tidy::Guarantee. Unfortunately, this is like hunting unicorns -- the Perl::Tidy maintainers
# intentionally make such a piece of code very rare.
#
# So instead, we'll stub out Perl::Tidy, and instruct the stub to 1) always succeed, and 2) return
# a piece of code that contains actual functional changes.
#
# (Sidenote: random_mashup.pl was written to try to go unicorn hunting, but that rabbit hole ended
# up being much deeper than I had expected. It turned out that fleshing out %stub_exports within
# Perl::Tidy::Guarantee::DontLoadAnyModules became an extremely time-consuming process, and without
# %stub_exports being properly filled out, many CPAN modules improperly error out when passed
# through Perl::Tidy::Guarantee::_generate_optree().)

{
    my $source_before_tidy2 = <<'EOF';
            for (1..3) {
                print "hello world";
            }
EOF

    my $source_after_tidy2 = <<'EOF';
            print "and now, for something completely different";
EOF

    my $module = Test::MockModule->new('Perl::Tidy');
    $module->mock('perltidy', sub {
                # this is a stub for Perl::Tidy::perltidy()
                my %input_hash = @_;

                ${$input_hash{destination}} = $source_after_tidy2;

                return my $error_flag = 0;
        });

    like(
        dies { $guarantee_plugin->transform_source($source_before_tidy2) },
        qr/^tidy_compare\(\) found a functional change/,
        "tidyall should fail"
        );
}
