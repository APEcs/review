## @file
# This file contains the implementation of the admin cohort statement interface.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    30 January 2012
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
package Admin::CohortStatements;

## @class Admin::CohortStatements
# Implementation of the cohort statement management interface. This code allows
# admin users to select which statements are associated with each cohort.
use strict;
use base qw(Admin); # This class extends Admin
use Logging qw(die_log);
use POSIX qw(ceil);
use Utils qw(is_defined_numeric);


# ============================================================================
#  Cohort listing...

## @method $ get_cohort_options($defaultid)
# Create the list of defined cohorts, sorted by name, to show in the cohort/statements
# cohort list. Cohorts whose members have performed sorts will be marked as locked,
# but still selectable so that their set statements may be viewed.
#
# @param defaultid Optional default selected option id.
# @return A string containing the cohort option list.
sub get_cohort_options {
    my $self      = shift;
    my $defaultid = shift;

    my $cohorth = $self -> {"dbh"} -> prepare("SELECT id, name
                                               FROM ".$self -> {"settings"} -> {"database"} -> {"cohorts"}."
                                               ORDER BY name ASC");
    $cohorth -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform cohort list query: ".$self -> {"dbh"} -> errstr);

    my $locked = $self -> {"template"} -> load_template("admin/cohort_statement/locked_cohort.tem");
    my $options = "";
    while(my $cohort = $cohorth -> fetchrow_arrayref()) {
        my $has_sorts = $self -> cohort_has_sorts($cohort -> [0]);

        $options .= '<option value="'.$cohort -> [0].'"';
        $options .= ' class="locked"' if($has_sorts);
        $options .= ' selected="selected"' if($defaultid && $cohort -> [0] == $defaultid);
        $options .= '>'.$cohort -> [1];
        $options .= $locked if($has_sorts);
        $options .= "</option>\n";
    }

    return $options;
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

        # Show the admin page
        $content = $self -> {"template"} -> load_template("admin/admin.tem", {"***tabbar***" => $self -> generate_admin_tabbar("cstates"),
                                                                              "***body***"   => $self -> {"template"} -> load_template("admin/cohort_statement/mapping.tem", {"***cohorts***" => $self -> get_cohort_options()})});

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
