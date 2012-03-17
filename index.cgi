#!/usr/bin/perl -wT

use strict;
use lib qw(/var/www/webperl);
use utf8;

# System modules
use CGI::Carp qw(fatalsToBrowser set_message); # Catch as many fatals as possible and send them to the user as well as stderr

# Webperl modules
use AppUser::Cohort;
use Application;

my $contact = 'moodlesupport@cs.man.ac.uk'; # global contact address, for error messages

# install more useful error handling
BEGIN {
    $ENV{"PATH"} = ""; # Force no path.

    delete @ENV{qw(IFS CDPATH ENV BASH_ENV)}; # Clean up ENV
    sub handle_errors {
        my $msg = shift;
        print "<h1>Software error</h1>\n";
        print '<p>Server time: ',scalar(localtime()),'<br/>Error was:</p><pre>',$msg,'</pre>';
        print '<p>Please report this error to ',$contact,' giving the text of this error and the time and date at which it occured</p>';
    }
    set_message(\&handle_errors);
}

my $app = Application -> new(appuser => AppUser::Cohort -> new())
    or die "Unable to create application";
$app -> run();
