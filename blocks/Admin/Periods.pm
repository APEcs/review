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
package Admin::Periods;

## @class Admin::Index
# Implementation of the basic 'index and status' page for the Review webapp
# admin interface. This shows basic stats about the system, and links to
# modules to manage periods, maps, statements, and so on.
use strict;
use base qw(Admin); # This class extends Admin
use Logging qw(die_log);
use POSIX qw(ceil);
use Utils qw(is_defined_numeric);

# ============================================================================
#  General utility stuff.

## @method $ can_modify_period($periodid)
# Determine whether the user can modify the period specified. This will check
# whether any sorts have been performed during the period specified, and if
# so it will return false. If no sorts have been performed, this will return
# true.
#
# @param periodid The period to check for sorts.
# @return 1 if the user can modify the period, 0 otherwise.
sub can_modify_period {
    my $self     = shift;
    my $periodid = shift;

    my $checkh = $self -> {"dbh"} -> prepare("SELECT COUNT(id) FROM ".$self -> {"settings"} -> {"database"} -> {"sorts"}."
                                              WHERE period_id = ?");
    $checkh -> execute($periodid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform period modification check query: ".$self -> {"dbh"} -> errstr);

    my $count = $checkh -> fetchrow_arrayref();

    # Can the user edit? If we have no row (unlikely as it's a count!), or the count is 0, they cay.
    return !($count && $count -> [0]);
}


## @method $ get_period_count()
# Count how many periods are currently defined in the database.
#
# @return The number of defined periods.
sub get_period_count {
    my $self = shift;

    my $counth = $self -> {"dbh"} -> prepare("SELECT COUNT(*) FROM ".$self -> {"settings"} -> {"database"} -> {"periods"});
    $counth -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform period count query: ".$self -> {"dbh"} -> errstr);

    my $count = $counth -> fetchrow_arrayref();

    return $count ? $count -> [0] : 0;
}


## @method $ get_sort_field()
# Obtain the name of the field the period table should be sorted on. This checks
# whether the user has selected a sort field via the query string, and if so
# whether the selection is valid.
#
# @return The table column to sort on.
sub get_sort_field {
    my $self = shift;
    my @valid_fields = ("year", "startdate", "enddate", "name", "allow_sort");
    my $default      = "startdate";

    # Get the sort field specified, fall back on the default if not set
    my $field = $self -> {"cgi"} -> param("sort");
    return $default if(!$field);

    # Check that the field is valid
    foreach my $valid (@valid_fields) {
        # Return the defined value rather than user-specified to avoid tainting issues
        return $valid if($field eq $valid);
    }

    # Not valid, return the default
    return $default;
}


## @method $ get_sort_direction()
# Obtain the direction in which the table contents should be ordered. This checks
# the query string to determine whether the user has specified a sort direction,
# and if so whether that direction is valid.
#
# @return The direction to sort in, either "DESC" or "ASC"
sub get_sort_direction {
    my $self = shift;

    # Has the user specified a direction, and is it valid?
    my $way = $self -> {"cgi"} -> param("way");

    # Do not return the value provided by the user to avoid tainting, use internal versions
    return (!$way || $way eq "desc") ? "DESC" : "ASC";
}


# ============================================================================
#  Period listing

sub build_periods_sort_headers {
    my $self  = shift;
    my $field = shift;
    my $way   = shift;
    my $page  = shift;
    my $fields = {};

    my @valid_fields = ("year", "startdate", "enddate", "name", "allow_sort");
    my $temcache = { "sort" => $self -> {"template"} -> load_template("admin/sort.tem",      {"***block***" => "periods",
                                                                                              "***page***"  => $page}),
                     "asc"  => $self -> {"template"} -> load_template("admin/sort_asc.tem",  {"***block***" => "periods",
                                                                                              "***page***"  => $page}),
                     "desc" => $self -> {"template"} -> load_template("admin/sort_desc.tem", {"***block***" => "periods",
                                                                                              "***page***"  => $page})};
    # Check each field to determine whether it is the currently selected field,
    # and which direction it is sorted in, to create the sort headers
    foreach my $name (@valid_fields) {
        $fields -> {"***".$name."***"} = $self -> {"template"} -> process_template($temcache -> {($name eq $field) ? lc($way) : "sort"}, {"***sort***" => $name});
    }

    return $fields;
}


## @method $ build_admin_periods()
# Generate the admin periods list page.
#
# @return A string containing the period list page.
sub build_admin_periods {
    my $self    = shift;
    my $periods = "";

    # precache some templates needed later
    my $temcache = { "row" => $self -> {"template"} -> load_template("admin/periods/row.tem"),
                     "dosort" => [ $self -> {"template"} -> load_template("admin/periods/sort_no.tem"),
                                   $self -> {"template"} -> load_template("admin/periods/sort_yes.tem") ],
                     "doedit" => [ $self -> {"template"} -> load_template("admin/periods/modify_off.tem"),
                                   $self -> {"template"} -> load_template("admin/periods/modify_on.tem") ]
    };

    # Need to know how many periods are defined.
    my $periodcount = $self -> get_period_count();
    my $maxpage     = int($periodcount / $self -> {"settings"} -> {"config"} -> {"Admin:page_length"});

    # Check for sorting
    my $sortfield = $self -> get_sort_field();
    my $sortdir   = $self -> get_sort_direction();

    # Check for pagination and range.
    my $page = is_defined_numeric($self -> {"cgi"}, "page");
    $page    = 0 if(!defined($page) || $page < 0);
    $page    = $maxpage if($page > $maxpage);

    # Convert the page to a start offset.
    my $start = $page * $self -> {"settings"} -> {"config"} -> {"Admin:page_length"};

    # Now fetch the periods from the database. Can use LIMIT as no funky filtering is involved...
    my $periodh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"periods"}."
                                               ORDER BY `$sortfield` $sortdir
                                               LIMIT $start,".$self -> {"settings"} -> {"config"} -> {"Admin:page_length"});
    $periodh -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform period lookup query: ".$self -> {"dbh"} -> errstr);

    while(my $period = $periodh -> fetchrow_hashref()) {
        # Determine whether this period can be edited/deleted.
        my $modify = $self -> can_modify_period($period -> {"id"});

        # Put a row together
        $periods .= $self -> {"template"} -> process_template($temcache -> {"row"}, {"***year***"   => $period -> {"year"},
                                                                                     "***start***"  => $self -> {"template"} -> format_time($period -> {"startdate"}),#, $self -> {"settings"} -> {"config"} -> {"datefmt"}),
                                                                                     "***end***"    => $self -> {"template"} -> format_time($period -> {"enddate"}),#, $self -> {"settings"} -> {"config"} -> {"datefmt"}),
                                                                                     "***name***"   => $period -> {"name"},
                                                                                     "***dosort***" => $temcache -> {"dosort"} -> [$period -> {"allow_sort"}],
                                                                                     "***ops***"    => $self -> {"template"} -> process_template($temcache -> {"doedit"} -> [$modify], {"***id***" => $period -> {"id"}}),
                                                              });
    }

    my $datafields = $self -> build_periods_sort_headers($sortfield, $sortdir, $page);
    $datafields -> {"***paginate***"} = $self -> build_pagination("periods", $maxpage, $page, {"sort" => $sortfield,
                                                                                               "way"  => lc($sortdir)});
    $datafields -> {"***periods***"}  = $periods;

    return $self -> {"template"} -> load_template("admin/periods/periods.tem", $datafields);
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    # We need to determine what the page title should be, and the content to shove in it...
    my ($title, $content) = ($self -> {"template"} -> replace_langvar("ADMIN_PERIOD_TITLE"), "");

    # User must be logged in before we can do anything else
    if($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) {

        # Bomb immediately if the user does not have admin permission
        my $sessuser = $self -> check_admin_permission($self -> {"session"} -> {"sessuser"});
        if(ref($sessuser) ne "HASH") {
            $self -> log("admin view", "Permission denied");
            return $sessuser;
        }

        # Admin operations are always logged
        $self -> log("admin view", "Periods");

        # Show the admin page
        $content = $self -> {"template"} -> load_template("admin/admin.tem", {"***tabbar***" => $self -> generate_admin_tabbar("admin"),
                                                                              "***body***"   => $self -> build_admin_periods()})

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
