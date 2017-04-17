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

my $basedir = "$FindBin::Bin/..";
$basedir = Cwd::realpath($basedir);
$basedir = File::Spec->abs2rel($basedir);

my $filter = qr/^/;
if (@ARGV) {
    my $r = join('|', map { quotemeta } @ARGV);
    $filter = qr{^\w+://(?:$r)/};
}

my %repos_offline = ();
my %repos = ();
my %prefixes = ();

my @data_files = glob("$basedir/data/*");
for my $path (@data_files) {
    my $section = '';
    my $prev_line = '';
    open(my $fh, '<', $path);
    while (defined(my $line = <$fh>)) {
        chomp $line;
        if ($line =~ /^(?:#|\s*$)/) {
            next;
        }
        if ($line =~ /^\Q[rules]\E$/) {
            if ($section eq '') {
                $section = 'rules';
                $prev_line = '';
                next;
            } else {
                die "$path:$NR: unexpected section [rules]";
            }
        }
        if ($line =~ /^\Q[tests]\E$/) {
            if ($section eq 'rules') {
                $section = 'tests';
                $prev_line = '';
                next;
            } else {
                die "$path:$NR: unexpected section [tests]";
            }
        }
        if ($line =~ /^(\[.+\])$/) {
            die "$path:$NR: unexpected section $1";
        }
        if ($section eq 'rules') {
            if ($line =~ /(\S+) = (\S+)$/) {
                if ($line le $prev_line) {
                   die "$path:$NR: unsorted lines";
                }
                $prev_line = $line;
                my ($src, $dst) = ($1, $2);
                if (exists $prefixes{$src}) {
                   die "$path:$NR: duplicate $src";
                };
                if ($src =~ $filter) {
                    $prefixes{$src} = 1;
                }
                ($src = $dst) =~ s/^https:/http:/ or die "$path:$NR: target URL is not HTTPS";
                if ($src =~ $filter) {
                    $prefixes{$src} = 0;
                }
                next;
            }
        }
        if ($section eq 'tests') {
            if ($line =~ m/^(\S+)( OFFLINE)? = (\S+)( OFFLINE)?$/) {
                if ($line le $prev_line) {
                   die "$path:$NR: unsorted lines";
                }
                $prev_line = $line;
                my ($src, $src_offline, $dst, $dst_offline) = ($1, $2, $3, $4);
                $dst =~ m{https://} or die "$dst is not HTTPS";
                if (exists $repos{$src}) {
                    die "$path:$NR: duplicate $src";
                }
                if ($src =~ $filter) {
                    $repos{$src} = $dst;
                }
                if ($src_offline) {
                    $repos_offline{$src} = 1;
                };
                if ($dst_offline) {
                    $repos_offline{$dst} = 1;
                }
                next;
            }
        }
        die "$path:$NR: syntax error";
    }
    close($fh);
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
        my $output = capture('timeout', '10s', 'git', '-C', $tmpdir, 'ls-remote', $url, 'HEAD');
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
