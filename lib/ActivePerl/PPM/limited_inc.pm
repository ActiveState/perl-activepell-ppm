#
# This module tweak @INC so that PPM will only pick up modules from
# the same install area as itself lives in.  This make it safe to install
# upgrades to packages that PPM depend in the 'site' or 'home' areas.
#

@main::INC_ORIG = @INC;

(my $dir = __FILE__) =~ s,/ActivePerl/PPM/.*,,;

if (grep $_ eq $dir, @INC) {
    shift(@INC) while $INC[0] ne $dir;
}

1;
