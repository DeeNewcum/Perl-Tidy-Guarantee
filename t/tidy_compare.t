use strict;
use warnings;

use Test2::V0;
use Test2::Tools::Exception qw(dies lives);

use Perl::Tidy::Guarantee ();

plan(4);


lives_tidy_compare("for loop", <<'EOF');
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



lives_tidy_compare("subroutine calls", <<'EOF');
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


dies_tidy_compare("subroutine call in a different order", <<'EOF');
    sub a {
        print "hello world";
    }

    a();
--------------------
    a();

    sub a {
        print "hello world";
    }
EOF


dies_tidy_compare("change interpolation", <<'EOF');
    my $w = "world";
    print "hello $w";
--------------------
    my $w = "world";
    print 'hello $w';
EOF

exit;




# accepts two chunks of code inside one here-doc, separated by a line of exactly 20 dashes
sub dies_tidy_compare {
    my ($test_name, $here_doc) = @_;

    my ($source_a, $source_b) = split(/^--------------------$/m, $here_doc);

    like(
        dies { Perl::Tidy::Guarantee::tidy_compare($source_a, $source_b) },
        qr/^tidy_compare\(\) found a functional change/,
        $here_doc
        );
}


# accepts two chunks of code inside one here-doc, separated by a line of exactly 20 dashes
sub lives_tidy_compare {
    my ($test_name, $here_doc) = @_;

    my ($source_a, $source_b) = split(/^--------------------$/m, $here_doc);

    ok(
        lives { Perl::Tidy::Guarantee::tidy_compare($source_a, $source_b) },
        $test_name);
}
