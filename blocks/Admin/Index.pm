## @file
# This file contains the implementation of the admin 'index' view.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    19 January 2012
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
package Admin::Index;

## @class Admin::Index
# Implementation of the basic 'index and status' page for the Review webapp
# admin interface. This shows basic stats about the system, and links to
# modules to manage periods, maps, statements, and so on.
use strict;
use base qw(Admin); # This class extends Admin
use Logging qw(die_log);

## @method private $ admin_table_count($table)
# Count the number of rows in the specified table. This will return a dumb
# count of all the rows in the specified table, with the assumption that
# there are no duplicate rows.
#
# @param table The table to count the rows in.
# @return The number of rows in the table, or "Unknown" if a problem occurred.
sub admin_table_count {
    my $self  = shift;
    my $table = shift;

    my $counth = $self -> {"dbh"} -> prepare("SELECT COUNT(*) FROM ".$self -> {"settings"} -> {"database"} -> {$table});
    $counth -> execute()
            or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to execute count query on table $table: ".$self -> {"dbh"} -> errstr);

    my $count = $counth -> fetchrow_arrayref();

    return $count ? $count -> [0] : "Unknown";
}


## @method private $ build_admin_index()
# Generate the contents of the admin index page proper. This creates the actual
# content of the page to show between the admin tab bar and the footer.
#
# @return The admin index page content.
sub build_admin_index {
    my $self = shift;

    # Here are the tables we want stats from....
    my @tables = ("cohorts", "formfields", "maps", "logging", "periods", "sorts", "statements", "summaries", "users");
    my $stats  = {};
    foreach my $table (@tables) {
        $stats -> {"***".$table."***"} = $self -> admin_table_count($table);
    }

    # Need a special query to work out how many sorts have no summaries
    # FIXME: There is probably a more efficient way to do this!
    my $counth = $self -> {"dbh"} -> prepare("SELECT COUNT(id) FROM ".$self -> {"settings"} -> {"database"} -> {"sorts"}."
                                              WHERE id NOT IN (SELECT DISTINCT(sort_id) FROM ".$self -> {"settings"} -> {"database"} -> {"summaries"}.")");

    $counth -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to execute missing summary count query: ".$self -> {"dbh"} -> errstr);

    my $count = $counth -> fetchrow_arrayref();

    $stats -> {"***nosums***"} = $count ? $count -> [0] : "Unknown";

    # Fix the 'anonymous' user
    --$stats -> {"***users***"};

    # Pull in the last N log entries (where N is Admin:shortlog_count in the settings)
    my $logh = $self -> {"dbh"} -> prepare("SELECT l.*, u.username
                                            FROM ".$self -> {"settings"} -> {"database"} -> {"logging"}." AS l,
                                                 ".$self -> {"settings"} -> {"database"} -> {"users"}." AS u
                                            WHERE u.user_id = l.user_id
                                            ORDER BY logtime DESC
                                            LIMIT ".$self -> {"settings"} -> {"config"} -> {"Admin:shortlog_count"});
    $logh -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to execute log query: ".$self -> {"dbh"} -> errstr);

    my $logrow = $self -> {"template"} -> load_template("admin/index_logline.tem");
    $stats -> {"***loglines***"} = "";
    while(my $log = $logh -> fetchrow_hashref()) {
        $stats -> {"***loglines***"} .= $self -> {"template"} -> process_template($logrow, {"***time***" => $self -> {"template"} -> format_time($log -> {"logtime"}),
                                                                                            "***user***" => $log -> {"username"},
                                                                                            "***ip***"   => $log -> {"ipaddr"},
                                                                                            "***type***" => $log -> {"logtype"},
                                                                                            "***data***" => $log -> {"logdata"}});
    }

    return $self -> {"template"} -> load_template("admin/index_content.tem", $stats);
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    # We need to determine what the page title should be, and the content to shove in it...
    my ($title, $content) = ($self -> {"template"} -> replace_langvar("ADMIN_STATS_TITLE"), "");

    # User must be logged in before we can do anything else
    if($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) {
        # Admin operations are always logged
        $self -> log("admin view", "Admin index");

        # Bomb immediately if the user does not have admin permission
        my $sessuser = $self -> check_admin_permission($self -> {"session"} -> {"sessuser"});
        if(ref($sessuser) ne "HASH") {
            $self -> log("admin view", "Permission denied");
            return $sessuser;
        }

        # Show the admin page
        $content = $self -> {"template"} -> load_template("admin/admin.tem", {"***tabbar***" => $self -> generate_admin_tabbar("admin"),
                                                                              "***body***"   => $self -> build_admin_index()})

    # User has not logged in, force them to
    } else {
        my $url = "index.cgi?block=login&amp;back=".$self -> {"session"} -> encode_querystring($self -> {"cgi"} -> query_string());

        print $self -> {"cgi"} -> redirect($url);
        exit;
    }

    # Done generating the page content, return the filled in page template
    return $self -> {"template"} -> load_template("page.tem", {"***title***"     => $title,
                                                               "***topright***"  => $self -> generate_topright(),
                                                               "***extrahead***" => '<link href="templates/default/admin/admin.css" rel="stylesheet" type="text/css" />',
                                                               "***content***"   => $content});

}

1;
