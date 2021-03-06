#!/use/bin/env perl
use strict;
use warnings;
use Test::More;# tests => 494;
use FindBin qw($RealBin);

BEGIN 
{ 
    use_ok("Getopt::Long");
    use_ok("IO::Uncompress::Gunzip");
}
my $n_tests = 2;
my $script_prefix = "perl $RealBin/..";

testFormat("\t", "tab separated",   "tsv");
testFormat(",",  "comma separated", "csv");
testFormat(" ",  "space separated", "ssv");
testFile("\t", "all quoted", "$RealBin/test_data/test_quoted.tsv", 1);
done_testing($n_tests);

##################################################
sub testFormat{
    my $delimiter = shift;
    my $format = shift;
    my $ext = shift;
    testFile($delimiter, $format, "$RealBin/test_data/test.$ext");
    testFile($delimiter, "gzipped $format", "$RealBin/test_data/test.$ext.gz");
}
    
##################################################
sub testFile{
    my $delimiter = shift;
    my $format = shift;
    my $file = shift;
    my $quote_all = shift;
    my @cols = qw/ Foo Bar Rhubarb Etc /;
    my %data = map { $_ => getData($_, $delimiter, $quote_all) } @cols;
    #one col at a time...
    my $base_cmd =  "$script_prefix/columnSelector.pl $file ";
    if ($delimiter ne "\t"){
        $base_cmd .= " -d '$delimiter'";
    }
    for my $k (keys %data){
        my $cmd = "$base_cmd $k";
        testCmd($cmd, $data{$k}, "get '$k' column from $format data");
    }
    my %base_args = 
    (
        format     => $format,
        cmd        => $base_cmd,
        data       => \%data, 
        delimiter  => $delimiter, 
    );
#    doColCombinations
#    (
#        %base_args,
#        all_cols => \@cols, 
#    );
    @cols = reverse(@cols);
    doColCombinations
    (
        %base_args,
        all_cols => \@cols, 
    );
    #    @cols = map { $cols[$_] } 2, 1 ;
    #    doColCombinations
    #    (
    #        %base_args,
    #        all_cols => \@cols, 
    #    );
}

##################################################
sub doColCombinations{
    my %args = @_;
    for (my $i = 0; $i < @{$args{all_cols}}; $i++){
        my @cols_to_test = ($args{all_cols}->[$i]);
        for (my $j = $i + 1; $j < @{$args{all_cols}}; $j++){
            next if $j == $i;
            push @cols_to_test, $args{all_cols}->[$j];
            testTheseCols(%args, cols => \@cols_to_test);
        }
    }
}

##################################################
sub testTheseCols{
    my %args = @_;
    my $exp = dataToCols($args{data}, $args{delimiter}, $args{cols} ); 
    my $desc = "get '". 
               (join(", ", @{$args{cols}})) . 
               "' columns from $args{format} data";
    my $cmd = "$args{cmd} " . join(" ", @{$args{cols}});
    testCmd($cmd, $exp, $desc);
    my @uc = map { uc($_) } @{$args{cols}};
    $cmd = "$args{cmd} -i " . join(" ", @uc);
    $desc = "get '". 
            (join(", ", @uc)) . 
            "' columns (case-insensitive) from $args{format} data";
    testCmd($cmd, $exp, "$desc case-insensitive");
    $cmd = "$args{cmd} " . join(" ", @uc);
    failTest($cmd, "fail to find columns (case-sensitive) for " .join(", ", @uc));
}

##################################################
sub dataToCols{
    my $h = shift;
    my $d = shift;
    my $c = shift;
    my @twod = (); 
    (my $dd = $d) =~ s/((?:\\[a-zA-Z\\])+)/qq[qq[$1]]/ee;
    foreach my $col (@{$c}){
        my @lines = split("\n",  $h->{$col});
        for (my $i = 0; $i < @lines; $i++){
            push @{$twod[$i]}, $lines[$i];
        }
    }
    my $data = '';
    foreach my $row (@twod){
        $data .= join($dd, @{$row}) . "\n";
    }
    return $data;
}
        
        
##################################################
sub getData{
    my $f = shift;
    my $d = shift;
    my $quote_all = shift;
    $f = "$RealBin/test_data/$f.txt";
    open (my $IN, $f) or die "Could not open test data $f: $!\n";
    my $all = '';
    while (my $data = <$IN>){
        chomp $data;
        if ( ($data =~ /$d/ or $quote_all ) and $data !~ /^".+"$/ ){
            $data = "\"$data\"";
        }
        $all .= "$data\n";
    }
    close $IN;
    return $all;
}

##################################################
sub failTest{
    my ($cmd, $description) = @_;
    my $output = `$cmd 2>&1`;
    ok
    (
        $? > 0,
        $description,
    );
    $n_tests++; 
}
##################################################
sub testCmd{
    my ($cmd, $expected, $description) = @_;
    my $output = `$cmd`;
    is
    (
        $output,
        $expected,
        $description,
    );
    $n_tests++; 
}

