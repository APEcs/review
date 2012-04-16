## @file
# This file contains the implementation of the admin base class.
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
package Admin;

## @class Admin
# This class is the base class for all Admin modules. It provides functions
# common to all Admin modules.
use strict;
use base qw(ReviewBlock); # This class extends ReviewBlock


## @method $ check_admin_permission($userid)
# Determine whether the specified userid has access to the admin
# interface.
#
# @param userid The ID of the user to check for admin permission.
# @return The user's record if they have admin permission, an error message otherwise.
sub check_admin_permission {
    my $self   = shift;
    my $userid = shift;

    # Get the user's record
    my $sessuser = $self -> {"session"} -> {"auth"} -> get_user_byid($userid);
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $self -> {"template"} -> replace_langvar("SORTGRID_ERR_NOUSER",
                                                                                                               {"***userid***" => $userid})
                                                  })
        unless($sessuser);

    # Is the user an admin user?
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_NOPERMISSION")
                                                  })
        unless($sessuser -> {"user_type"} == $self -> {"session"} -> {"auth"} -> {"ADMINTYPE"});

    # TODO: Add session admin check?

    # User is an admin, return their record
    return $sessuser;
}


## @method $ generate_admin_tabbar($current)
# Generate the admin tab bar to show at the top of each admin page.
#
# @param current The block name of the current admin block.
# @return A string containing the admin tab bar.
sub generate_admin_tabbar {
    my $self    = shift;
    my $current = shift;

    my $blocks = $self -> {"dbh"} -> prepare("SELECT a.*, b.name
                                              FROM ".$self -> {"settings"} -> {"database"} -> {"adminblocks"}." AS a,
                                                   ".$self -> {"settings"} -> {"database"} -> {"blocks"}." AS b
                                              WHERE b.id = a.block_id
                                              ORDER BY a.position");
    $blocks -> execute()
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to execute admin block lookup query: ".$self -> {"dbh"} -> errstr);

    my $entrytem = $self -> {"template"} -> load_template("admin/bar_entry.tem");
    my $entries = "";
    while(my $block = $blocks -> fetchrow_hashref()) {
        $entries .= $self -> {"template"} -> process_template($entrytem, {"***current***" => ($block -> {"name"} eq $current ? " current" : ""),
                                                                          "***block***"   => $block -> {"name"},
                                                                          "***name***"    => $block -> {"title"}});
    }

    return $self -> {"template"} -> load_template("admin/bar.tem", {"***entries***" => $entries});
}


## @method $ cohort_has_sorts($cohortid)
# Determine whether any of the members of the specified cohort have performed
# sorts.
#
# @param cohortid The id of the cohort to check for member sorts.
# @return true if any of the members of the cohort have performed a sort, false
#         otherwise.
sub cohort_has_sorts {
    my $self     = shift;
    my $cohortid = shift;

    # Note the limit here - it doesn't matter if there is more than one sort, this really just
    # cares whether there are zero or one, as one is enough to determine that the cohort has
    # sorts recorded.
    my $checkh = $self -> {"dbh"} -> prepare("SELECT u.user_id
                                              FROM ".$self -> {"settings"} -> {"database"} -> {"users"}." AS u,
                                                   ".$self -> {"settings"} -> {"database"} -> {"sorts"}." AS s
                                              WHERE s.user_id = u.user_id
                                              AND u.cohort_id = ?
                                              LIMIT 1");
    $checkh -> execute($cohortid)
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort check query: ".$self -> {"dbh"} -> errstr);

    # If the row fetch was successful, one or more sorts have been peformed
    return $checkh -> fetchrow_arrayref();
}

1;
