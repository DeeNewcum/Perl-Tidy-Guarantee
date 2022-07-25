use strict;
use warnings;

use Test2::V0;

use Perl::Tidy::Guarantee ();

plan(2);


test_generate_optree("for loop", <<'EOF');
    for (1..3) {
        print "hello world";
    }
--------------------
    for
        (1..3)
    {
        print
            "hello world"
    }
EOF



test_generate_optree("subroutine calls", <<'EOF');
    sub a {
        b();
    }

    sub b {
        print "hello world";
    }

    a();
--------------------
    sub
        # testing 1 2 3
        a
    {
        b();
    }

    sub
        # testing 1 2 3
        b
    {
        print "hello world";
    }

    a();
EOF


exit;



# accepts two chunks of code inside one here-doc, separated by a line of exactly 20 dashes
sub test_generate_optree {
    my ($test_name, $here_doc) = @_;

    my ($source_a, $source_b) = split(/^--------------------$/m, $here_doc);

    is(
        Perl::Tidy::Guarantee::_generate_optree($source_a),
        Perl::Tidy::Guarantee::_generate_optree($source_b),
        $test_name);
}
