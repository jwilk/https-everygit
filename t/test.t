#!/usr/bin/env perl

# Copyright © 2017 Jakub Wilk <jwilk@jwilk.net>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

use strict;
use warnings;

use Carp;
use English qw(-no_match_vars);
use File::Temp ();
use FindBin ();

use autodie qw(open close symlink);

use Test::More;

use IPC::System::Simple qw(run capture);

my $here = "$FindBin::Bin";
my $basedir = "$here/../";

my $filter = qr/^/;
if (@ARGV) {
    my $r = join('|', map { quotemeta $_ } @ARGV);
    $filter = qr{^\w+://(?:$r)/};
}

my %repos_offline = ();
my %repos = ();
{
    open(my $file, '<', "$here/data");
    my $prev_line = '';
    while (defined(my $line  = <$file>)) {
        $line gt $prev_line or die;
        $line =~ m{^(\S+) -> (https://\S+)( OFFLINE)?$} or die;
        my ($src, $dst, $offline) = ($1, $2, $3);
        exists $repos{$src} and die;
        if ($src =~ $filter) {
            $repos{$src} = $dst;
        }
        if ($offline) {
            $repos_offline{$src} = 1;
            $repos_offline{$dst} = 1;
        }
        $prev_line = $line;
    }
    close($file);
}

my %prefixes = ();
{
    open(my $file, '<', "$basedir/src");
    while (defined(my $line  = <$file>)) {
        $line =~ /^(\S+) -> (\S+)$/ or die;
        my ($src, $dst) = ($1, $2);
        exists $prefixes{$src} and die;
        if ($src =~ $filter) {
            $prefixes{$src} = 1;
        }
        if ($dst =~ /^https:/) {
            ($src = $dst) =~ s//http:/;
            if ($src =~ $filter) {
                $prefixes{$src} = 0;
            }
        }
    }
    close($file);
}

plan tests => 2 * (keys %repos) + 1 * (keys %prefixes);

my $tmpdir = File::Temp->newdir();

local $ENV{GIT_CONFIG_NOSYSTEM} = '1';
local $ENV{HOME} = $tmpdir;
local $ENV{XDG_CONFIG_HOME} = $tmpdir;

SKIP: {
    my $var = 'HTTPS_EVERYGIT_ONLINE_TESTS';
    if (not $ENV{$var}) {
        skip "set $var=1 to enable online tests", scalar keys %repos;
    }

    my %ls_remote_cache = ();

    sub ls_remote
    {
        my ($url) = @_;
        my $cached = $ls_remote_cache{$url};
        return $cached if defined $cached;
        my $output = capture('git', '-C', $tmpdir, 'ls-remote', $url, 'HEAD');
        $ls_remote_cache{$url} = $output;
        return $output;
    }

    while (my ($src, $dst) = each %repos)
    {
        TODO: {
            my ($ls_src, $ls_dst);
            eval {
                $ls_src = ls_remote($src);
            } or do {
                local $TODO = undef;
                if (exists $repos_offline{$src}) {
                    $TODO = "$src is offline";
                }
                fail("remote $src");
                next;
            };
            eval {
                $ls_dst = ls_remote($dst);
            } or do {
                local $TODO = undef;
                if (exists $repos_offline{$dst}) {
                    $TODO = "$dst is offline" ;
                }
                fail("remote $dst");
                next;
            };
            cmp_ok($ls_dst, 'eq', $ls_src, "remote $src");
        }
    }

}

symlink("$basedir/gitconfig", "$tmpdir/.gitconfig");

while (my ($src, $dst) = each %repos)
{
    my $gitdst = capture('git', '-C', $tmpdir, 'ls-remote', '--get-url', $src);
    chomp($gitdst);
    cmp_ok($gitdst, 'eq', $dst, "offline $src");
}

my @prefixes = reverse sort { (length $a) - (length $b) } keys %prefixes;
while (my ($src, $dst) = each %repos)
{
    for my $prefix (@prefixes) {
        if ($src =~ /^\Q$prefix\E/) {
            $prefixes{$prefix} = 1;
        }
    }
}

while (my ($prefix, $coverage) = each %prefixes)
{
    cmp_ok($coverage, 'eq', 1, "coverage for $prefix");
}

# vim:ts=4 sts=4 sw=4 et
