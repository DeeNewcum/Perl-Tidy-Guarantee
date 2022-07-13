#!/usr/bin/perl

# uses the genetic operators (crossover + mutation) to randomly scan for Perl code that passe
# Perl::Tidy's own tests, but that fail Perl::Tidy::Guarantee's test.
#
# https://en.wikipedia.org/wiki/Crossover_(genetic_algorithm)

    use strict;
    use warnings;

    use Archive::Tar        ();     # Perl core
    use Path::Tiny          ();
    use Perl::Tidy          ();
    use Storable            ();     # Perl core
    use Text::LineNumber    ();
    use Try::Tiny;

    use Data::Dumper;

    use FindBin;
    use lib::relative '../lib/';

    use Perl::Tidy::Guarantee   ();

my $minicpan_dir = '/home/newcum/minicpan/mirror/';

my @tarballs;
if (-e "$FindBin::Bin/.tarball_list") {
    @tarballs = @{Storable::retrieve("$FindBin::Bin/.tarball_list")};
} else {
    @tarballs = list_tarballs($minicpan_dir);
    Storable::nstore(\@tarballs, "$FindBin::Bin/.tarball_list");
}

while (1) {
    print "============================================================\n";
    
    my $source_a = random_perl_file_contents(@tarballs);
    my $source_b = random_perl_file_contents(@tarballs);

    # convert Windows => Unix line endings (otherwise we can end up with a mishmash of the two)
    $source_a =~ s/\r\n/\n/sg;
    $source_b =~ s/\r\n/\n/sg;

    my $source_a_len = int rand length $source_a;
    my $source_b_len = int rand length $source_b;
    print "The first $source_a_len bytes of the first file, and the last $source_b_len bytes of the second file.\n";
        
    # cut each in half, and glue them together
    my $crossover_before_tidy = 
            substr($source_a, 0, $source_a_len)
            . substr($source_b, $source_b_len);

    # indicate which line contains the split
    my $tln = Text::LineNumber->new($source_a);
    my $line_split = $tln->off2lnr($source_a_len) + 1;
    if ($crossover_before_tidy =~ /^#!/s) {
        $crossover_before_tidy =~ s/\n/\n# split occurs at line $line_split\n/s;
    } else {
        $crossover_before_tidy = "# split occurs at line $line_split\n" . $crossover_before_tidy;
    }
        
    my $crossover_after_tidy = '';
    my $stderr = '';
    my $logfile = '';
    my $errorfile = '';

    my $error_flag = Perl::Tidy::perltidy(
        source            => \$crossover_before_tidy,
        destination       => \$crossover_after_tidy,
        perltidyrc        => '',
        logfile           => \$logfile,
        errorfile         => \$errorfile,
    );

    if ($error_flag == 0) {
        print "\$error_flag = 0;    # ran to completion with no error messages\n";
    } elsif ($error_flag == 1) {
        print "\$error_flag = 1;    # terminated early due to errors in the input parameters\n";
    } elsif ($error_flag == 2) {
        print "\$error_flag = 2;    # ran to completion but warning messages in \$errorfile\n";
    }

    if ($error_flag > 0) {
        #print Data::Dumper->Dump([$errorfile], [qw[$errorfile]]);
        next;
    }
    
    try {
        $Perl::Tidy::Guarantee::special_debug_mode = 1;
        Perl::Tidy::Guarantee::tidy_compare($crossover_before_tidy, $crossover_after_tidy);
    } catch {
        if (/^tidy_compare\(\) found a functional change/) {
            my $base = "error_found." . time() . ".pl";
            Path::Tiny::path($base)->spew($crossover_before_tidy);
            system "perltidy", $base;
            system "perl -MO=Concise -I../lib -MPerl::Tidy::Guarantee::ExcludeCOPs $base "
                        . "> $base.optree";
            system "perl -MO=Concise -I../lib -MPerl::Tidy::Guarantee::ExcludeCOPs $base.tdy "
                        . "> $base.tdy.optree";
            # double-check that Perl::Tidy::Guarantee::tidy_compare()'s check was good
            system "cmp", "--silent", "$base.optree", "$base.tdy.optree";
            if ($? >> 8 == 0) {
                warn "WTF? On second glance, there was no optree difference found.\n";
                unlink $base, "$base.optree", "$base.tdy", "$base.tdy.optree";
            } else {
                print "Error found, input Perl source written to $base.\n";
                exit;
            }
        } else {
            warn $_;
        }
    };

    sleep(1) if ($^O eq 'cygwin');
}

exit;


# given a minicpan mirror, returns a list of all tarballs under that tree
sub list_tarballs {
    my ($minicpan_dir) = @_;

    my $iter = Path::Tiny::path($minicpan_dir)->child('authors')->iterator( {
            recurse => 1,
        } );
    my @list;
    while (my $path = $iter->()) {
        if ($path->is_file && $path->basename =~ /\.tar\.gz$/) {
            push @list, $path->stringify;
        }
    }
    return @list;
}


# given a minicpan mirror, choose a random Perl source file, and return its contents
sub random_perl_file_contents {
    my (@tarballs) = @_;

    my $random_tarball = $tarballs[rand @tarballs];

    my $tar = Archive::Tar->new($random_tarball);
    my @pm_files;
    foreach my $filename ($tar->list_files()) {
        if ($filename =~ /\.pm$/) {
            push @pm_files, $filename;
        }
    }

    if (!@pm_files) {
        # no .pm files found, so choose another tarball
        return random_perl_file_contents(@tarballs);
    }

    my $filename = $pm_files[rand @pm_files];
    my $file_contents = $tar->get_content($filename);
        
    print "$random_tarball    $filename\n";

    return $file_contents;
}
