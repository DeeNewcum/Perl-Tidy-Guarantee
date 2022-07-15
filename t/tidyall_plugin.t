use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Exception qw(dies lives);

use Code::TidyAll;
use Code::TidyAll::Plugin::PerlTidyGuarantee;
use Scalar::Util;
use Test::MockModule;

plan(1);


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
		plugins => {
			PerlTidyGuarantee => {
				select => '*',
			},
		},
		no_cache => 1,			# don't litter my Git repo with **/tidyall.d/ directories
		no_backups => 1,		# don't litter my Git repo with **/tidyall.d/ directories
	);

my $guarantee_plugin = Code::TidyAll::Plugin::PerlTidyGuarantee->new(
		select  => '*',
		name    => 'PerlTidyGuarantee',
		tidyall => $tidyall,
	);

ok(
	lives { $guarantee_plugin->transform_source($source_before_tidy1) },
	"tidyall succeeds");
	

# The goal here is to find a piece of code that succeeds with Perl::Tidy but fails with
# Perl::Tidy::Guarantee. Unfortunately, this is like hunting unicorns -- the Perl::Tidy maintainers
# intentionally make such a piece of code very rare.
#
# (sidenote -- random_mashup.pl was written to try to go unicorn hunting, but it has been much
# slower-going than I had expected)
#
# So instead, we'll stub out Perl::Tidy, and instruct the stub to 1) always succeed, and 2) return
# a piece of code that contains functional changes.

#{
#	my $source_before_tidy2 = <<'EOF';
#			for (1..3) {
#				print "hello world";
#			}
#EOF
#
#	my $source_after_tidy2 = <<'EOF';
#						sub and_now {
#							print @_;
#						}
#
#						and_now("for something completely different");
#EOF
#
#	my $module = Test::MockModule->new('Perl::Tidy');
#	$module->mock('perltidy', sub {
#				# this is a stub for Perl::Tidy::perltidy()
#				my %input_hash = @_;
#
#				${$input_hash{destination}} = $source_after_tidy2;
#
#				my $error_flag = 0;
#				return $error_flag;
#		});
#
#    like(
#        dies { Code::TidyAll::Plugin::PerlTidyGuarantee->transform_source($source_before_tidy2) },
#        qr/^tidy_compare\(\) found a functional change/,
#        "tidyall fails"
#        );
#}
