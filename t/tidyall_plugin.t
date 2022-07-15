use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Exception qw(dies lives);

use Code::TidyAll;
use Code::TidyAll::Plugin::PerlTidyGuarantee;
use Scalar::Util;
use Test::MockModule;

plan(0);


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

# right now, the Code::TidyAll::Plugin::PerlTidyGuarantee->new() command is throwing the error
# message:
# 		Validation failed for type named Object declared in package Specio::Library::Builtins
# 		(/home/newcum/perl5/lib/perl5/Specio/Library/Builtins.pm) at line 293
# so try to send the debugger to exactly the right location (debugging these numerous random evals
# really sucks!)
use Specio::TypeChecks;
if (!Specio::TypeChecks::isa_class($tidyall, 'Code::TidyAll')) {
	die "validation as Specio Object failed";
	exit(1);
}
	# see also https://metacpan.org/release/DROLSKY/Code-TidyAll-0.82/source/lib/Code/TidyAll/Plugin.pm#L77

#Scalar::Util::weaken($tidyall);

my $plugin = Code::TidyAll::Plugin::PerlTidyGuarantee->new(
		select  => '*',
		name    => 'PerlTidyGuarantee',
		tidyall => $tidyall,
	);
$plugin->transform_source($source_before_tidy1);


#ok(
#	lives { Code::TidyAll::Plugin::PerlTidyGuarantee->transform_source($source_before_tidy1) },
#	"tidyall succeeds");
	

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
