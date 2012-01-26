## @file
# This file contains the implementation of the FlashQ save facility.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    22 December 2011
# @copy    2011, Chris Page &lt;chris@starforge.co.uk&gt;
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
package SaveSort;

## @class SaveSort
# This class implements the sort saving facility, allowing a user's sort to be
# stored when they are done.
use strict;
use base qw(ReviewBlock); # This class extends ReviewBlock
use Logging qw(die_log);
use Encode;


## @method private $ save_sort($userid)
# Store the data submitted by flashq in the database. This will create the appropriate
# sort header for the user's submission, and store the data from flashq in the sort
# data table with the appropriate sortid.
#
# @param userid The id of the user associated with the current session.
# @return A success string. Failures will halt the script with an error.
sub save_sort {
    my $self   = shift;
    my $userid = shift;

    # need the current period for the sort header...
    my $period = $self -> get_current_period();

    # Processing a sort, so create a sort header for the user.
    my $headerh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"sorts"}."
                                               (user_id, period_id, sortdate, updated)
                                               VALUES(?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())");
    $headerh -> execute($userid, $period -> {"id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort header creation query: ".$self -> {"dbh"} -> errstr);

    # Get the ID that was created. This is horrible and icky, but it should be realiable on MySQL...
    my $sortid = $self -> {"dbh"} -> {"mysql_insertid"};

    # Now add each of the data values sent by flashq
    my $datah = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"sortdata"}."
                                             (sort_id, name, value)
                                             VALUES(?, ?, ?)");
    my %params = $self -> {"cgi"} -> Vars;
    foreach my $param (keys(%params)) {
        $datah -> execute($sortid, $param, $params{$param})
                    or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort data creation query ($param = $params{param} failed): ".$self -> {"dbh"} -> errstr);
    }

    return "status=1";
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self    = shift;
    my $content = "status=-2"; # Default to failure.

    # User must be logged in before we can do anything else
    if($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) {
        # Excessive logging enabled? If so, log the user viewing this...
        $self -> log("view", "FlashQ sort save") if($self -> {"settings"} -> {"config"} -> {"Log:all_the_things"});

        # Can the user sort?
        my $sorterr = $self -> user_can_sort();
        if(!$sorterr) {
            $self -> log("save", "FlashQ sort save allowed") if($self -> {"settings"} -> {"config"} -> {"Log:all_the_things"});

            # Store the sort - this will set the content to a success string if it works.
            $content = $self -> save_sort($self -> {"session"} -> {"sessuser"});

        # Sort not allowed - save nothing.
        } else {
            $self -> log("save", "FlashQ sort save not allowed: $sorterr") if($self -> {"settings"} -> {"config"} -> {"Log:all_the_things"});
        }
    } else {
        $self -> log("view", "FlashQ sort save failed: not logged in") if($self -> {"settings"} -> {"config"} -> {"Log:all_the_things"});
    }

    print $self -> {"cgi"} -> header(-type => 'text/plain',
                                     -charset => 'utf-8',
                                     -expires => '-1d');
    print Encode::encode_utf8($content);
    exit;
}

1;


