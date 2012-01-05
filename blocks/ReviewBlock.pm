## @file
# This file contains the implementation of the core review features.
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
package ReviewBlock;

## @class ReviewBlock
# The 'base' class for all Review blocks. This extends the standard
# webperl Block class with additional functions common to all Review
# UI and backend modules.
use strict;
use base qw(Block); # This class extends Block
use Logging qw(die_log);


# ============================================================================
#  Database interaction functions

## @method $ get_current_period($allow_sort)
# Obtain the data for the current time period as given in the sort_periods table.
# This will look in the sort_periods table for a period that the current day and
# time falls within, and if it finds one it will return a reference to a hash
# containing its data. If no appropriate sort period exists, this will return undef.
#
# @note If two or more sort periods overlap the current day and time, this will only
#       return the data for one of them. The period that gets returned is entirely
#       at the whim of the database - there is no guarantee of consistency or
#       sanity here. Long story short: don't define overlapping periods in the
#       sort_periods table!
#
# @param allow_sort Only return sort periods that allow users to perform sorts.
# @return A reference to a hash containing the sort period data, or undef if no
#         suitable sort period exists.
sub get_current_period {
    my $self       = shift;
    my $allow_sort = shift;

    my $periodh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"periods"}."
                                               WHERE startdate <= UNIX_TIMESTAMP()
                                               AND enddate >= UNIX_TIMESTAMP()
                                              ".($allow_sort ? "AND allow_sort = 1" : ""));
    $periodh -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform period lookup query: ".$self -> {"dbh"} -> errstr);

    return $periodh -> fetchrow_hashref();
}


## @method $ user_can_sort()
# Determine whether the owner of the current session is allowed to perform a sort.
# If the user is not allowed to, this will return an error message to that effect,
# otherwise it will return undef if they are allowed to sort.
#
# @return undef if the user can sort, an error message otherwise.
sub user_can_sort {
    my $self = shift;

    # Users must be logged in to sort
    return $self -> {"template"} -> replace_langvar("SORT_NOLOGIN")
        unless($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"});

    # The user is logged in and not anonymous, have they recorded a sort already? To work
    # this out, we need the current period...
    my $period = $self -> get_current_period(1);
    return $self -> {"template"} -> replace_langvar("SORT_NOPERIOD")
        if(!$period);

    # Has the user already submitted a sort for this period?
    my $sort = $self -> get_sort_data($self -> {"session"} -> {"sessuser"}, $period -> {"id"});

    return $self -> {"template"} -> replace_langvar("SORT_HAVEDONE")
        if($sort);

    # No sort, and sorts are allowed, so the user can do one..
    return undef;
}


## @method $ get_sort_data($userid, $periodid, $fullsort)
# Obtain the sort data submitted by the user during the specified period. Each user may perform a
# sort exactly once during any period, so this method can only return at most one sort of data.
#
# @param userid   The id of the user to fetch the sort dadta for.
# @param periodid The period during which the user should have performed the sort.
# @param fullsort If this is set, the full sort data is included in the returned hash, otherwise
#                 only the sort header (user, period, sort date and last update) will be returned.
# @return A reference to a hash containing the sort data (including a hash of sort answers,
#         justifications, survey answers, and an array of summary hashes if $fullsort is set)
sub get_sort_data {
    my $self     = shift;
    my $userid   = shift;
    my $periodid = shift;
    my $fullsort = shift;

    # Get the sort header first, this is pretty easy to pull...
    my $sorth = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"sorts"}."
                                             WHERE user_id = ?
                                             AND period_id = ?");
    $sorth -> execute($userid, $periodid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort lookup query: ".$self -> {"dbh"} -> errstr);

    # If there is no sort record for this user/period, or fullsort is not set, return whatever we got...
    my $sort = $sorth -> fetchrow_hashref();
    return $sort if(!$sort || !$fullsort); # order is important here!

    # fullsort is set, so the rest of the sort data needs to be loaded...
    my $datah = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"sortdata"}."
                                             WHERE sort_id = ?");
    $datah -> execute($sort -> {"id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort data lookup query: ".$self -> {"dbh"} -> errstr);

    # Copy any data we get into the sort hash
    while(my $data = $datah -> fetchrow_hashref()) {
        $sort -> {"data"} -> {$data -> {"name"}} = $data -> {"value"};
    }

    # now load the summaries, newest first
    my $summh = $self -> {"dbh"} -> prepare("SELECT summary, storetime FROM ".$self -> {"settings"} -> {"database"} -> {"summaries"}."
                                             WHERE sort_id = ?
                                             ORDER BY storetime DESC");
    $summh -> execute($sort -> {"id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort summary lookup query: ".$self -> {"dbh"} -> errstr);

    # Fetch all the rows as an array of hashrefs...
    $sort -> {"summaries"} = $summh -> fetchall_arrayref({});

    # And done...
    return $sort;
}


## @method @ get_user_sorts($userid)
# Obtain a list of sort ids and timestamps for the specified user. This returns a
# reference to an array of hashes, one hash for each sort the user has performed.
# If the user has performed a sort during the current time period, the second value
# returned by this function is a hashref containing the id and timestamp of the
# current-period sort.
#
# @param userid The ID of the user to obtain sorts for.
# @return A reference to an array of hashes for each sort (ordered in reverse chronological
#         order), and either a reference to a hash for the current period sort, or undef if
#         the user has not done a sort during the current period.
sub get_user_sorts {
    my $self   = shift;
    my $userid = shift;

    my $sorth = $self -> {"dbh"} -> prepare("SELECT s.id, s.sortdate, s.period_id, p.year, p.name
                                             FROM ".$self -> {"settings"} -> {"database"} -> {"sorts"}." AS s,
                                                  ".$self -> {"settings"} -> {"database"} -> {"periods"}." AS p
                                             WHERE s.user_id = ?
                                             AND p.id = s.period_id
                                             ORDER BY s.sortdate DESC");
    $sorth -> execute($userid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort lookup query: ".$self -> {"dbh"} -> errstr);

    # Query to get the number of summaries for a given sort
    my $counth = $self -> {"dbh"} -> prepare("SELECT COUNT(id) FROM ".$self -> {"settings"} -> {"database"} -> {"summaries"}."
                                              WHERE sort_id = ?");

    # Get the current period for reference ease...
    my $period = $self -> get_current_period();
    my $current;
    my @sorts;
    while(my $sort = $sorth -> fetchrow_hashref()) {
        # Work out the sort summary count for this sort
        $counth -> execute($sort -> {"id"})
            or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort summary count query: ".$self -> {"dbh"} -> errstr);

        my $count = $counth -> fetchrow_arrayref();
        $sort -> {"summary_count"} = $count ? $count -> [0] : 0;

        # If this is the current period sort, make sure it is recorded as such, then
        # store the sort reference in the sort array to send back to the caller.
        $current = $sort if($period && $period -> {"id"} == $sort -> {"period_id"});
        push(@sorts, $sort);
    }

    return (\@sorts, $current);
}


# ============================================================================
#  Content generation functions

## @method $ generate_topright()
# Generate the username/login/logout links at the top right of the page, based on
# whether the user has logged in yet or not.
#
# @return A string containing the content to show in the page top-right menu block.
sub generate_topright {
    my $self = shift;

    # Has the user logged in?
    if($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) {
        # We need the user's details
        my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($self -> {"session"} -> {"sessuser"});

        return $self -> {"template"} -> load_template("topright_loggedin.tem", {"***user***" => $user -> {"username"}});
    }

    # User hasn't logged in, return the basic login stuff
    return $self -> {"template"} -> load_template("topright_loggedout.tem");
}

1;
