#!/usr/bin/perl
#

package S2::Scanner;
use strict;

sub new
{
    my ($class, $fh) = @_;
    bless {
        'fh' => $fh,
        'line' => 1,
        'col' => 1,
        'buf' => undef,
        'buflen' => 0,
        'bufpos' => 0,
    }, $class;
}

sub fillBuf
{
    my $this = shift;
    return 1 if $this->{'buflen'};
    $this->{'buf'} = $this->{'fh'}->getline;
    $this->{'buflen'} = length $this->{'buf'};
    $this->{'bufpos'} = 0;
    return $this->{'buflen'};
}

sub advance_pos
{
    my $this = shift;
    if (++$this->{'bufpos'} >= $this->{'buflen'}) {
        $this->{'buf'} = undef;
        $this->{'buflen'} = 0;
        $this->{'bufpos'} = 0;
    }
}

sub peek
{
    my ($this, $getting) = @_;

    if (defined $this->{'forceNext'}) {
        my $nx = $this->{'forceNext'};
        if ($getting) {
            undef $this->{'forceNext'};
            $this->advance_pos($this);
            return $nx;
        }
    }

    unless ($this->{'buflen'} || $this->fillBuf()) {
        return undef;
    }
    my $ch = substr($this->{'buf'}, $this->{'bufpos'}, 1);
    $this->advance_pos() if $getting;
    return $ch;
}

sub getChar
{
    my $this = shift;
    my $ch = $this->peek(1);
    if ($ch eq "\n") {
        if ($this->{'fakeNewline'}) {
            $this->{'fakeNewline'} = 0;
        } else {
            $this->{'line'}++;
            $this->{'col'} = 0;
        }
    }
    if ($ch eq "\t") {
        $this->{'col'} += 4;  # stupid assumption
    } else {
        $this->{'col'}++;
    }
    return $ch;
}

sub forceNextChar
{
    my ($this, $ch) = @_;
    if ($ch eq "\n") { $this->{'fakeNewline'} = 1; }
    $this->{'forceNext'} = $ch;
}

sub locationString
{
    my $this = shift;
    "line $this->{'line'}, column $this->{'col'}.";
}

sub getRealChar
{
    my $this = shift;
    my $ch = $this->getChar();
    S2::error(locationString($this), "Unexpected end of file!") unless defined $ch;
    return $ch;
}

1;
