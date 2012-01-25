## @file
# This file contains the implementation of the ARCADE user cohort cache code.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    25 January 2012
# @copy    2012, Chris Page &lt;chris@starforge.co.uk&gt;
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

## @class UserCache::ARCADE
# Implementation of the ARCADE data source for the user cohort cache.
# This class uses ARCADE to obtain a list of which users are currently
# in the first, second, and third years, and populates the user cohort
# cache based on the cohorts they fall into.
package UserCache::ARCADE;

use strict;
use base qw(ReviewBlock); # This class extends ReviewBlock
use Date::Calc qw(Today Add_Delta_YM);
use Logging qw(die_log);
use Time::Local;
use Socket;

## @method $ cache_user($username, $cohortid)
# Store the specified user in the user cohort cache, if they are
# not already in the table.
#
# @param username The name of the user to store in the cache.
# @param cohortid The id of the cohort to place the user in.
# @return A string containing the status of the addition.
sub cache_user {
    my $self     = shift;
    my $username = shift;
    my $cohortid = shift;

    # Is the user already in the cache?
    my $checkh = $self -> {"dbh"} -> prepare("SELECT username FROM ".$self -> {"settings"} -> {"database"} -> {"usercache"}."
                                              WHERE username = ?");
    $checkh -> execute($username)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform usercache lookup query: ".$self -> {"dbh"} -> errstr);

    my $incache = $checkh -> fetchrow_arrayref();
    return "user already in cache" if($incache);

    # Not in cache, add them
    my $userh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"usercache"}."
                                             (username, cohort_id)
                                             VALUES(?, ?)");
    $userh -> execute($username, $cohortid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform usercache insert query: ".$self -> {"dbh"} -> errstr);

    return "user added to cache";
}


## @method $ arcade_lookup($course, $cohort)
# Query ARCADE for a list of all students on the specified course, and
# store entries for each user in the user cohort cache if needed.
#
# @param course The code for the course to ask ARCADE about.
# @param cohort A reference to a hash containing the data for the cohort
#               the users should be associated with.
# @return A string containing progress messages.
sub arcade_lookup {
    my $self   = shift;
    my $course = shift;
    my $cohort = shift;
    my $progress = "<h2>Adding users on $course to the cache with cohort ".$cohort -> {"id"}." (".$cohort -> {"name"}.")...</h2>\n";

    my $users = $self -> arcade_command($self -> {"settings"} -> {"config"} -> {"UserCache::ARCADE:ARCADE_command"}, $course);
    return "<h2>ARCADE returned an empty list for $course</h2>\n"
        if(!$users);

    # Split the user list into lines for easier processing
    my @lines = split(/^/, $users);
    foreach my $line (@lines) {
        chomp($line);
        next if(!$line); # Skip empties.

        # Usernames are the last word in the string
        my ($username) = $line =~ /(\w+)$/o;

        # If the username parsed out okay, cache the user.
        if($username) {
            $progress .= "Adding user $username: ".$self -> cache_user($username, $cohort -> {"id"})."<br />\n";
        } else {
            $progress .= "ERROR: Unable to parse user from $line<br />\n";
        }

    }

    return $progress;
}


## @method $ populate_usercache()
# Populate the user cache based on course/year information obtained
# from ARCADE.
#
# @return A string containing progress information.
sub populate_usercache {
    my $self = shift;

    # First work out which cohorts apply to this year, last year, and the year before that
    my $cohorts;
    my ($year, $month, $day) = Today();
    foreach my $yearoffset (0, -1, -2) {
        my ($tyear, $tmonth, $tday) = Add_Delta_YM($year, $month, $day, $yearoffset, 0);

        $cohorts -> {$yearoffset} = $self -> get_cohort_bytime(timelocal(0, 0, 0, $tday, $tmonth, $tyear))
            or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to obtain a cohort for offset $yearoffset (".timelocal(0, 0, 0, $tday, $tmonth, $tyear).")");
    }

    # Now the fun starts - ask the database for which courses we need to ask ARCADE for
    my $arcadeh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"arcade"});
    $arcadeh -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform arcade lookup query: ".$self -> {"dbh"} -> errstr);

    # Each course needs to be checked against arcade, and the resuling users stored
    my $progress = "";
    while(my $arcade = $arcadeh -> fetchrow_hashref()) {
        $progress .= $self -> arcade_lookup($arcade -> {"coursecode"}, $cohorts -> {$arcade -> {"yearoffset"}});
    }

    return $progress;
}


## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    my $content = $self -> populate_usercache();

    return "<html><body>$content</body></html>";
}


# ============================================================================
#  Internal stuff

## @method private $ arcade_connect()
# Open a connection to the ARCADE system and return a socket to
# perform operations through.
#
# @return A typeglob containing the ARCADE connection.
sub arcade_connect {
    my $self = shift;

    local *SOCK;

    my $iaddr   = inet_aton($self -> {"settings"} -> {"config"} -> {"UserCache::ARCADE:ARCADE_host"}) || die "Unable to resolve Arcade host ".$self -> {"settings"} -> {"config"} -> {"UserCache::ARCADE:ARCADE_host"};
    my $paddr   = sockaddr_in($self -> {"settings"} -> {"config"} -> {"UserCache::ARCADE:ARCADE_port"}, $iaddr);
    my $proto   = getprotobyname('tcp');

    socket(SOCK, PF_INET, SOCK_STREAM, $proto)  || die "Unable to create socket.\nError was: $!";
    connect(SOCK, $paddr) || die "Unable to connect to Arcade.\nError was: $!";

    my $auth = $self -> {"settings"} -> {"config"} -> {"UserCache::ARCADE:ARCADE_auth"};
    $auth =~ s/:/\n/g;
    print SOCK "$auth\n";
    return *SOCK;
}


## @method private $ arcade_command($command, $course)
# Send a command to the ARCADE server, and return the response.
#
# @param command The command to send to ARCADE.
# @param course  The ID of the course the query. Leading COMP is stripped.
# @return A string containing student data, one student per line. If the
#         command failed for some reason (unknown command, unknown course, etc)
#         this will return an empty string.
sub arcade_command {
    my $self = shift;
    my $command = shift;
    my $course = shift;

    # Strip leading COMP if needed
    $course =~ s/^COMP//;

    # Get a connection to ARCADE
    local *SOCK = $self -> arcade_connect();

    # Send it the command and course,
    print SOCK "$command:$course\n";
    my $OldSelect = select SOCK; $|=1; select $OldSelect;

    my $result = "";
    my $line;
    while(defined($line = <SOCK>)) {
        $result .= $line unless($line eq "++WORKING\n");
    }
    close (SOCK) || die "Error while closing socket connection.\nError was: $!";
    return $result;
}

1;
