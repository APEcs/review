## @file
# This file contains the implementation of the LDAP-Cohort authentication class.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    17 February 2012
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

## @class
# Implementation of a LDAP authentication module that understands cohorts.
# This will allow users to be authenticated against an LDAP server and then
#  assigned to appropriate cohorts if they are not already recorded as being
# in one.
package LDAPCohortAuth;

use strict;
use Net::LDAPS;

# Custom module imports
use Logging qw(die_log);
use Utils qw(blind_untaint);

# ============================================================================
#  Constructor

## @cmethod LDAPCohortAuth new(@args)
# Create a new LDAPCohortAuth object.
#
# @param args A hash of key, value pairs to initialise the object with.
# @return     A reference to a new LDAPCohortAuth object.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = {
        cgi       => undef,
        dbh       => undef,
        settings  => undef,
        @_,
    };

    # Ensure that we have objects that we need
    return set_error("cgi object not set") unless($self -> {"cgi"});
    return set_error("dbh object not set") unless($self -> {"dbh"});
    return set_error("settings object not set") unless($self -> {"settings"});

    $self -> {"ANONYMOUS"} = $self -> {"settings"} -> {"config"} -> {"LDAPCohortAuth:anonymous"};
    $self -> {"ADMINTYPE"} = $self -> {"settings"} -> {"config"} -> {"LDAPCohortAuth:admintype"};

    return bless $self, $class;
}


# ============================================================================
#  Interface code

## @method $ get_config($name)
# Obtain the value for the specified configuration variable.
#
# @param name The name of the configuration variable to return.
# @return The value for the name, or undef if the value is not set.
sub get_config {
    my $self = shift;
    my $name = shift;

    # Make sure the configuration name starts with the appropriate module handle
    $name = "LDAPCohortAuth:$name" unless($name =~ /^LDAPCohortAuth:/);

    return $self -> {"settings"} -> {"config"} -> {$name};
}


## @method $ get_user_byid($userid, $onlyreal)
# Obtain the user record for the specified user, if they exist. This should
# return a reference to a hash of user data corresponding to the specified userid,
# or undef if the userid does not correspond to a valid user. If the onlyreal
# argument is set, the userid must correspond to 'real' user - bots or inactive
# users should not be returned.
#
# @param userid   The id of the user to obtain the data for.
# @param onlyreal If true, only users of type 0 or 3 are returned.
# @return A reference to a hash containing the user's data, or undef if the user
#         can not be located (or is not real)
sub get_user_byid {
    my $self     = shift;
    my $userid   = shift;
    my $onlyreal = shift || 0;

    my $userh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                             WHERE user_id = ?".
                                            ($onlyreal ? " AND user_type IN (0,3)" : ""));
    $userh -> execute($userid)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute user lookup query. Error was: ".$self -> {"dbh"} -> errstr);

    my $user = $userh -> fetchrow_hashref();

    # Return the user record
    return $user;
}


## @method $ unique_id($extra)
# Obtain a unique ID number. This id number is guaranteed to be unique across calls, and
# may contain non-alphanumeric characters. The returned scalar may contain binary data.
#
# @param extra An extra string to append to the id before returning it.
# @return A unique ID. May contain binary data, is guaranteed to start with a number.
sub unique_id {
    my $self  = shift;
    my $extra = shift || "";

    # Potentially not atomic, but putting something in place that is really isn't worth it right now...
    my $id = $self -> {"settings"} -> {"config"} -> {"LDAPCohortAuth:unique_id"};
    $self -> {"settings"} -> set_db_config($self -> {"dbh"}, $self -> {"settings"} -> {"database"} -> {"settings"}, "LDAPCohortAuth:unique_id", ++$id);

    # Ask urandom for some randomness to combat potential problems with the above non-atomicity
    my $buffer;
    open(RND, "/dev/urandom")
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to open urandom: $!");
    read(RND, $buffer, 24);
    close(RND);

    # append the process id and random buffer to the id we got from the database. The
    # PID should be enough to prevent atomicity problems, the random junk just makes sure.
    return $id.$$.$buffer.$extra;
}


## @method $ valid_user($username, $password)
# Determine whether the specified user is valid, and obtain their user record.
# This will authenticate the user, and if the credentials supplied are valid, the
# user's internal record will be returned to the caller.
#
# @param username The username to check.
# @param password The password to check.
# @return A reference to a hash containing the user's data if the user is valid,
#         undef if the user is not valid. If this returns undef, the reason is
#         contained in $self -> {"lasterr"}. Note that this may return a user
#         AND have a value in $self -> {"lasterr"}, in which case the value in
#         lasterr is a warning regarding the user...
sub valid_user {
    my $self     = shift;
    my $username = shift;
    my $password = shift;

    $self -> {"lasterr"} = "";

    # First, determine whether the user is valid
    return undef unless($self -> _ldap_valid_user($username, $password));

    # can we get the user's data?
    my $user = $self -> _get_user_byusername($username);

    # No user? Try to make one...
    if(!$user) {
        # No record for this user, need to make one...
        my $newuser = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                                   (username, created, last_login)
                                                   VALUES(?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())");
        $newuser -> execute($username)
            or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to create new user record: ".$self -> {"dbh"} -> errstr);

        $user = $self -> _get_user_byusername($username);
    }

    # Looks like addition failed, give up...
    if(!$user) {
        $self -> {"lasterr"} = "User addition failed.";
        return undef;
    }

    # Touch the user's record...
    my $pokeh = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                             SET last_login = UNIX_TIMESTAMP()
                                             WHERE user_id = ?");
    $pokeh -> execute($user -> {"user_id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to update user record: ".$self -> {"dbh"} -> errstr);

    # Send back the user record, making sure they are in a cohort.
    return $self -> _set_user_cohort($user);
}


# ============================================================================
#  Internal stuff, do not use from elsewhere

## @method private $ _get_user_byusername($username)
# Obtain the user with the specified username from the database. This will return the
# user's record in the database if they are found, undef otherwise.
#
# @param username The username of the user to obtain the data for.
# @return A reference to a hash containing the user's data, undef if the user can not be found.
sub _get_user_byusername {
    my $self     = shift;
    my $username = shift;

    my $userh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                             WHERE username LIKE ?");
    $userh -> execute($username)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to query database for user record: ".$self -> {"dbh"} -> errstr);

    return $userh -> fetchrow_hashref();
}


## @method private $ _ldap_valid_user($username, $password)
# Attempt to authenticate the user against the LDAP server. This will check the user's
# login against the configured LDAP server, and return true if the login is valid.
#
# @param username The username to check against the server.
# @param password The password to check against the server.
# @return true if the login is valid, false otherwise. If the return value is false,
#         $self -> {"lasterr"} contains the response from the ssh server.
sub _ssh_valid_user {
    my $self     = shift;
    my $username = shift;
    my $password = shift;
    my $valid    = 0;

    $self -> {"lasterr"} = "";
    if($username && $password) {

        # First obtain the user dn
        my $userdn;
        my $ldap = Net::LDAPS -> new($self -> {"settings"} -> {"config"} -> {"LDAPCohortAuth:server"});

        # Anonymous bind will fork for CS/Uni.
        # FIXME: allow admin login for search?
        my $mesg = $ldap -> bind();
        if($mesg -> code) {
            $self -> {"lasterr"} = "LDAP bind to ".$self -> {"settings"} -> {"config"} -> {"SSHCohortAuth:server"}." failed. Response was: ".$mesg -> error;
        } else {
            # Search for a user with the specified username in the base dn
            my $result = $ldap -> search("base"   => $self -> {"settings"} -> {"config"} -> {"LDAPCohortAuth:base"},
                                         "filter" => "uid=$username");

            my $entry = $result -> shift_entry;
            if(!$entry) {
                $self -> {"lasterr"} = "LDAP login failed: unknown user";
            } else {
                $userdn = $entry -> dn;
            }
        }

        $ldap -> unbind();

        # If a userdn has been obtained, check that the password for it is valid
        if($userdn) {
            # Open a new connection, as the server may not allow reuse.
            my $vldap = Net::LDAPS -> new();

            # Do the actual login...
            $mesg = $vldap -> bind($userdn, password => $password);
            if($mesg -> code) {
                $self -> {"lasterr"} = "LDAP login failed: incorrect password";
            } else {
                $valid = 1;
            }

            $vldap -> unbind();
        }

        return $valid;
    }

    $self -> {"lasterr"} = "LDAP login failed: username and password are required";
    return 0;
}


## @method private $ _set_user_cohort($user)
# Determine which cohort the user is is in, and set it if needed. This will check whether
# the specified user has been placed into a cohort, and if they have not it will attempt
# to add them to the appropriate one.
#
# @param user A reference to a hash containing the user's data
# @return A reference to the user's data, or undef on error.
sub _set_user_cohort {
    my $self = shift;
    my $user = shift;

    # If the user already has a cohort id, just return the user hash...
    return $user if($user -> {"cohort_id"});

    # No cohort set, check the user cohort cache to get a cohort
    my $cohorth = $self -> {"dbh"} -> prepare("SELECT cohort_id
                                               FROM ".$self -> {"settings"} -> {"database"} -> {"usercache"}."
                                               WHERE username = ?");
    $cohorth -> execute($user -> {"username"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform usercache query: ".$self -> {"dbh"} -> errstr);

    my $cohortrow = $cohorth -> fetchrow_arrayref();

    # If there is no cohort, and strict cohort assigment is enabled, fall over horribly
    if(!$cohortrow && $self -> {"settings"} -> {"config"} -> {"SSHCohortAuth:strict_assignment"}) {
        $self -> {"lasterr"} = "Unable to determine cohort for user. Please contact ".$self -> {"settings"} -> {"config"} -> {"SSHCohortAuth:strict_assignment"}." for assistance, giving your username and this error.";
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
            or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform cohort lookup query: ".$self -> {"dbh"} -> errstr);

        my $cohort = $cohorth -> fetchrow_hashref();

        # Did we get a cohort id and name? If not, give up with an error
        if(!$cohort) {
            $self -> {"lasterr"} = "Unable to determine cohort for user, or obtain a fallback cohort. Please contact ".$self -> {"settings"} -> {"config"} -> {"SSHCohortAuth:support_email"}." for assistance, giving your username and this error.";
            return undef;
        }

        # set the id in the user's data and possibly set the warning message
        $user -> {"cohort_id"} = $cohort -> {"id"};
        $self -> {"lasterr"} = "Warning: the system has fallen back on using the current cohort (".$cohort -> {"name"}.") as your cohort as it could not determine your cohort by other means. If this is incorrect, please stop at this point and contact ".$self -> {"settings"} -> {"config"} -> {"SSHCohortAuth:support_email"}." for assistance, giving your username and this warning."
            if($self -> {"settings"} -> {"config"} -> {"SSHCohortAuth:fallback_warning"});
    }

    # Update the user's record with the new cohort id
    my $newch = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                             SET cohort_id = ?
                                             WHERE user_id = ?");
    $newch -> execute($user -> {"cohort_id"}, $user -> {"user_id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform user update query: ".$self -> {"dbh"} -> errstr);

    # Done, return the user with the new cohort id set...
    return $user;
}

1;
