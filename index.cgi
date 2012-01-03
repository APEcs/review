#!/usr/bin/perl -wT

use strict;
use lib qw(/var/www/webperl);
use lib qw(modules);
use utf8;

# System modules
# use CGI::Compress::Gzip qw/:standard -utf8/;
use CGI qw/:standard -utf8/; # Can't use CGI::Compress::Gzip because CentOS is an outdated pile of shit.
use CGI::Carp qw(fatalsToBrowser set_message); # Catch as many fatals as possible and send them to the user as well as stderr
use DBI;
use Encode;
use Time::HiRes qw(time);

# Webperl modules
use ConfigMicro;
use Logging qw(start_log end_log die_log);
use HTMLValidator;
use Template;
use SessionHandler;
use Modules;
use Utils qw(path_join is_defined_numeric get_proc_size);

# local modules
use SSHCohortAuth;

my $dbh;                                   # global database handle, required here so that the END block can close the database connection
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
END {
    # Nicely close the database connection. Possibly not vital, but good to be sure..
    $dbh -> disconnect() if($dbh);

    # Stop logging if it has been enabled.
    end_log();
}

# =============================================================================
#  Core page code and dispatcher

my $starttime = time();

# Create a new CGI object to generate page content through
my $out = CGI -> new();

# Load the system config
my $settings = ConfigMicro -> new("config/site.cfg")
    or die_log($out -> remote_host(), "index.cgi: Unable to obtain configuration file: ".$ConfigMicro::errstr);

# Database initialisation. Errors in this will kill program.
$dbh = DBI->connect($settings -> {"database"} -> {"database"},
                    $settings -> {"database"} -> {"username"},
                    $settings -> {"database"} -> {"password"},
                    { RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1 })
    or die_log($out -> remote_host(), "index.cgi: Unable to connect to database: ".$DBI::errstr);

# Pull configuration data out of the database into the settings hash
$settings -> load_db_config($dbh, $settings -> {"database"} -> {"settings"});

# Start doing logging if needed
start_log($settings -> {"config"} -> {"logfile"}) if($settings -> {"config"} -> {"logfile"});

# Create the template handler object
my $template = Template -> new(basedir   => path_join($settings -> {"config"} -> {"base"}, "templates"),
                               blockname => 1,
                               mailcmd   => '/usr/sbin/sendmail -t -f '.$settings -> {"config"} -> {"Core:envelope_address"})
    or die_log($out -> remote_host(), "Unable to create template handling object: ".$Template::errstr);

# Create the authenticator
my $auth =  SSHCohortAuth -> new(cgi => $out,
                           dbh => $dbh,
                           settings => $settings)
    or die_log($out -> remote_host(), "Unable to create auth object: ".$SessionHandler::errstr);

# Start the session engine...
my $session = SessionHandler -> new(cgi      => $out,
                                    dbh      => $dbh,
                                    auth     => $auth,
                                    template => $template,
                                    settings => $settings)
    or die_log($out -> remote_host(), "Unable to create session object: ".$SessionHandler::errstr);

# And now we can make the module handler
my $modules = Modules -> new(cgi      => $out,
                             dbh      => $dbh,
                             settings => $settings,
                             template => $template,
                             session  => $session,
                             blockdir => "blocks",
                             logtable => $settings -> {"database"} -> {"logging"})
    or die_log($out -> remote_host(), "Unable to create module handling object: ".$Modules::errstr);

# Obtain the page moduleid, fall back on the default if this fails
my $pageblock = $out -> param("block");
$pageblock = $settings -> {"config"} -> {"default_block"} if(!$pageblock); # This ensures $pageblock is defined and non-zero

# Obtain an instance of the page module
my $pageobj = $modules -> new_module($pageblock)
    or die_log($out -> remote_host(), "Unable to load page module $pageblock: ".$Modules::errstr);

# And call the page generation function of the page module
my $content = $pageobj -> page_display();

print $out -> header(-charset => 'utf-8',
                     -cookie  => $session -> session_cookies());

my $endtime = time();
my ($user, $system, $cuser, $csystem) = times();
my $debug = "";

if($settings -> {"config"} -> {"debug"}) {
    $debug = $template -> load_template("debug.tem", {"***secs***"   => sprintf("%.2f", $endtime - $starttime),
                                                      "***user***"   => $user,
                                                      "***system***" => $system,
                                                      "***memory***" => $template -> bytes_to_human(get_proc_size())});
}

print Encode::encode_utf8($template -> process_template($content, {"***debug***" => $debug}));
$template -> set_module_obj(undef);

