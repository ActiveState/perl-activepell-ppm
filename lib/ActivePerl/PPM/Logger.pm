package ActivePerl::PPM::Logger;

use strict;
use base qw(Exporter);

our @EXPORT = qw(LOG_EMERG LOG_ALERT LOG_CRIT LOG_ERR LOG_WARNING LOG_NOTICE LOG_INFO LOG_DEBUG
                 ppm_logger
		 ppm_log ppm_debug ppm_status);
our @EXPORT_OK = qw();

use Carp qw(croak);
use HTTP::Date qw(time2iso);
use File::Basename qw(basename);

# syslog inspired constants
sub LOG_EMERG   () { 0 }
sub LOG_ALERT   () { 1 }
sub LOG_CRIT    () { 2 }
sub LOG_ERR     () { 3 }
sub LOG_WARNING () { 4 }
sub LOG_WARN    () { 4 }  # unofficial
sub LOG_NOTICE  () { 5 }
sub LOG_INFO    () { 6 }
sub LOG_DEBUG   () { 7 }

my $logger;

sub ppm_logger {
    return $logger ||= ActivePerl::PPM::Logger->new;
}

sub ppm_log {
    ($logger || ppm_logger())->log(@_);
}

sub ppm_debug {
    ppm_log(LOG_DEBUG, @_);
}

sub ppm_status {
    ($logger || ppm_logger())->status(@_);
}

#
#  Objects
#

sub new {
    my($class, %opt) = shift;

    my $logfile = $opt{file} || $ENV{ACTIVEPERL_PPM_LOG_FILE} ||
	($^O eq "MSWin32" ? "$ENV{TEMP}\\ppm4.log" : "$ENV{HOME}/ppm4.log");
    my $fh;
    if (open($fh, ">>", $logfile)) {
	require IO::Handle;  # adds methods to $fh
	$fh->autoflush;
    }
    else {
	warn "Can't log to '$logfile': $!";
	$opt{cons}++;
    }

    return bless {
        level => _num_prio($opt{level} || $ENV{ACTIVEPERL_PPM_LOG_LEVEL} || LOG_DEBUG()),
        cons => ($opt{cons} || $ENV{ACTIVEPERL_PPM_LOG_CONS}),
        callinfo => 1, #($opt{callinfo} || $ENV{ACTIVEPERL_PPM_LOG_CALLINFO}),
	fh => $fh,
    }, $class;
}

sub log {
    my $self = shift;
    my $prio = _num_prio(shift);
    my $msg = shift;

    return if $prio > ($self->{level} || LOG_INFO);

    if ($self->{callinfo}) {
	# fill in caller info
	my $i = 0;
	CALLER: {
	    my($pkg, $file, $line) = caller($i++);
	    redo CALLER if $pkg eq __PACKAGE__;
	    $file = basename($file);
	    substr($msg, 0, 0) = "[$file:$line] ";
	};
    }

    # clean up message
    $msg =~ s/^\s+//;
    $msg =~ s/\s+\z//;
    $msg =~ s/\s+/ /g;
    $msg .= "\n";

    if ($self->{cons}) {
	warn $msg;
    }

    if (my $fh = $self->{fh}) {
	my @t = (localtime)[reverse 0..5];
	$t[0] += 1900; # year
	$t[1] ++;      # month
	$fh->print(sprintf "%04d-%02d-%02dT%02d:%02d:%02d <%d> %s", @t, $prio, $msg);
    }
}

sub status {
    my($self, $msg) = @_;
    $msg = "done" unless $msg;
    $self->log(LOG_INFO, $msg);
}

sub _num_prio {
    my $prio = shift;
    unless ($prio =~ /^\d+$/) {
	no strict 'refs';
	if (defined &{"LOG_$prio"}) {
	    $prio = &{"LOG_$prio"};
	}
	else {
	    croak("Unrecognized log priority '$prio'");
	}
    }
    return $prio;
}

1;
