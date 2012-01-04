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

1;
