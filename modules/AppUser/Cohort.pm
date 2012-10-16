## @file
# This file contains the implementation of the Cohort application user class.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
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

## @class
package AppUser::Cohort;

use strict;
use base qw(AppUser);

# ============================================================================
#  Post-auth functions.

## @method $ post_authenticate($username, $password, $auth)
# Ensure that a newly-logged-in user is placed into a cohort based on their
# username, or the current cohort if necessary.
#
# @param username The username of the user to update the user_auth field for.
# @param password The user's password.
# @param auth     A reference to the auth object calling this.
# @return A reference to a hash containing the user's data on success,
#         otherwise an error message.
sub post_authenticate {
    my $self     = shift;
    my $username = shift;
    my $password = shift;
    my $auth     = shift;

    # Call the superclass method to handle making sure the user exists
    my $user = $self -> SUPER::post_authenticate($username, $password, $auth);

    # Otherwise make sure the user is set up
    return $self -> _set_user_cohort($user, $auth);
}


# ============================================================================
#  Internal functions

## @method private $ _set_user_cohort($user, $auth)
# Determine which cohort the user is is in, and set it if needed. This will check whether
# the specified user has been placed into a cohort, and if they have not it will attempt
# to add them to the appropriate one.
#
# @param user A reference to a hash containing the user's data
# @param auth A reference to the auth object performing the post-auth.
# @return A reference to the user's data, or undef on error.
sub _set_user_cohort {
    my $self = shift;
    my $user = shift;
    my $auth = shift;

    # If the user already has a cohort id, just return the user hash...
    return $user if($user -> {"cohort_id"});

    # No cohort set, check the user cohort cache to get a cohort
    my $cohorth = $self -> {"dbh"} -> prepare("SELECT cohort_id
                                               FROM ".$self -> {"settings"} -> {"database"} -> {"usercache"}."
                                               WHERE username = ?");
    $cohorth -> execute($user -> {"username"})
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform usercache query: ".$self -> {"dbh"} -> errstr);

    my $cohortrow = $cohorth -> fetchrow_arrayref();

    # If there is no cohort, and strict cohort assigment is enabled, fall over horribly
    if(!$cohortrow && $self -> {"settings"} -> {"config"} -> {"SSHCohortAuth:strict_assignment"}) {
        $auth -> {"lasterr"} .= "Unable to determine cohort for user. Please contact ".$self -> {"settings"} -> {"config"} -> {"SSHCohortAuth:strict_assignment"}." for assistance, giving your username and this error.";
        return undef;
    }

    # If there is a cohort, update the user hash to contain it
    if($cohortrow) {
        $user -> {"cohort_id"} = $cohortrow -> [0];

    # No cohort, put them into the current one if possible
    } else {
        # Find the cohort the current time falls in
        my $cohorth = $self -> {"dbh"} -> prepare("SELECT id, name
                                                   FROM ".$self -> {"settings"} -> {"database"} -> {"cohorts"}."
                                                   WHERE startdate <= UNIX_TIMESTAMP()
                                                   AND enddate >= UNIX_TIMESTAMP()");
        $cohorth -> execute()
            or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform cohort lookup query: ".$self -> {"dbh"} -> errstr);

        my $cohort = $cohorth -> fetchrow_hashref();

        # Did we get a cohort id and name? If not, give up with an error
        if(!$cohort) {
            $auth -> {"lasterr"} .= "Unable to determine cohort for user, or obtain a fallback cohort. Please contact ".$self -> {"settings"} -> {"config"} -> {"Auth:support_email"}." for assistance, giving your username and this error.";
            return undef;
        }

        # set the id in the user's data and possibly set the warning message
        $user -> {"cohort_id"} = $cohort -> {"id"};
        $auth -> {"lasterr"} .= "Warning: the system has fallen back on using the current cohort (".$cohort -> {"name"}.") as your cohort as it could not determine your cohort by other means. If this is incorrect, please stop at this point and contact ".$self -> {"settings"} -> {"config"} -> {"Auth:support_email"}." for assistance, giving your username and this warning."
            if($self -> {"settings"} -> {"config"} -> {"Cohort:fallback_warning"});
    }

    # Update the user's record with the new cohort id
    my $newch = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                             SET cohort_id = ?
                                             WHERE user_id = ?");
    $newch -> execute($user -> {"cohort_id"}, $user -> {"user_id"})
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform user update query: ".$self -> {"dbh"} -> errstr);

    # Done, return the user with the new cohort id set...
    return $user;
}


1;
