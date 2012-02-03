## @file
# This file contains the implementation of the admin cohort statement interface.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    1 February 2012
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
package Admin::CohortStateAPI;

## @class Admin::CohortStateAPI
# Implementation of the cohort statement API. This code provides the actual
# functionality needed to add and remove statement associations from cohorts,
# as opposed to Admin::CohortStatements which is essentially a frontend server.
use strict;
use base qw(Admin); # This class extends Admin
use Logging qw(die_log);
use POSIX qw(ceil);
use Utils qw(is_defined_numeric);

# ============================================================================
#  Statement movement functions


## @method void add_statements($cohortid)
# Add the statements requested by the user to the specified cohort. This will
# use the contents of the 'sid' query string parameter (which may be given
# multiple times) to determine which statements to add to the cohort.
#
# @param cohortid The ID of the cohort to add statements to.
sub add_statements {
    my $self     = shift;
    my $cohortid = shift;

    # Is the cohort editable?
    $self -> generate_error_xml($self -> {"template"} -> replace_langvar("ADMIN_COHORTSTATES_ERR_NOEDIT"))
        if($self -> cohort_has_sorts($cohortid));

    # Get the list of statement ids
    my @sids = $self -> {"cgi"} -> param("sid");

    # strip non-numeric values
    my @valid_ids = grep /^\d+$/, @sids;

    # Bomb if there are no ids to process
    $self -> generate_error_xml($self -> {"template"} -> replace_langvar("ADMIN_COHORTSTATES_ERR_NOSID"))
        unless(scalar(@valid_ids));

    # Prepare some sql needed for the insert...
    my $stateh = $self -> {"dbh"} -> prepare("SELECT id FROM ".$self -> {"settings"} -> {"database"} -> {"statements"}."
                                              WHERE id = ?");
    my $checkh = $self -> {"dbh"} -> prepare("SELECT id FROM ".$self -> {"settings"} -> {"database"} -> {"cohort_states"}."
                                              WHERE cohort_id = ?
                                              AND statement_id = ?");
    my $inserth = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"cohort_states"}."
                                               (cohort_id, statement_id)
                                               VALUES(?, ?)");

    $self -> log("admin add", "Adding statements to cohort $cohortid: ".join(",", @valid_ids));

    # process each statement...
    foreach my $id (@valid_ids) {
        # Does the statement even exist?
        $stateh -> execute($id)
            or $self -> generate_error_xml("FATAL: Unable to perform statement lookup query: ".$self -> {"dbh"} -> errstr);

        if($stateh -> fetchrow_arrayref()) {
            # Is the statement already set for this cohort?
            $checkh -> execute($cohortid, $id)
                or $self -> generate_error_xml("FATAL: Unable to perform cohort statement lookup query: ".$self -> {"dbh"} -> errstr);

            # If there is no row, the statement needs to be inserted
            if(!$checkh -> fetchrow_arrayref()) {
                $inserth -> execute($cohortid, $id)
                    or $self -> generate_error_xml("FATAL: Unable to perform cohort statement insert query: ".$self -> {"dbh"} -> errstr);
            }
        } else {
            $self -> generate_error_xml($self -> {"template"} -> replace_langvar("ADMIN_COHORTSTATES_ERR_BADSID", {"***sid***" => $id}))
        }
    }

    $self -> generate_success_xml($self -> {"template"} -> replace_langvar("ADMIN_COHORTSTATES_ADDDONE"));
}


## @method void remove_statements($cohortid)
# Remove the statements requested by the user from the specified cohort. This will
# use the contents of the 'sid' query string parameter (which may be given
# multiple times) to determine which statements to remove from the cohort.
#
# @param cohortid The ID of the cohort to remove statements to.
sub remove_statements {
    my $self     = shift;
    my $cohortid = shift;

    # Is the cohort editable?
    $self -> generate_error_xml($self -> {"template"} -> replace_langvar("ADMIN_COHORTSTATES_ERR_NOEDIT"))
        if($self -> cohort_has_sorts($cohortid));

    # Get the list of statement ids
    my @sids = $self -> {"cgi"} -> param("sid");

    # strip non-numeric values
    my @valid_ids = grep /^\d+$/, @sids;

    # Bomb if there are no ids to process
    $self -> generate_error_xml($self -> {"template"} -> replace_langvar("ADMIN_COHORTSTATES_ERR_NOSID"))
        unless(scalar(@valid_ids));

    $self -> log("admin delete", "Removing statements from cohort $cohortid: ".join(",", @valid_ids));

    # Only really need one query for this...
    my $nukeh = $self -> {"dbh"} -> prepare("DELETE FROM ".$self -> {"settings"} -> {"database"} -> {"cohort_states"}."
                                             WHERE cohort_id = ?
                                             AND statement_id = ?");
    foreach my $id (@valid_ids) {
        $nukeh -> execute($cohortid, $id)
            or $self -> generate_error_xml("FATAL: Unable to perform cohort statement delete query: ".$self -> {"dbh"} -> errstr);
    }

    $self -> generate_success_xml($self -> {"template"} -> replace_langvar("ADMIN_COHORTSTATES_REMDONE"));
}


# ============================================================================
#  Statement list generation functions

## @method $ build_set_statements($cohortid)
# Generate the list of statements currently associated with the specified
# cohort. This generates a block of options suitable for shoving into a
# select list - no preselection is supported.
#
# @param cohortid The ID of the cohort to generate the statement list for.
# @return The cohort statement option list.
sub build_set_statements {
    my $self     = shift;
    my $cohortid = shift;

    # Pretty easy lookup job...
    my $statesh = $self -> {"dbh"} -> prepare("SELECT s.id, s.statement
                                               FROM ".$self -> {"settings"} -> {"database"} -> {"statements"}." AS s,
                                                    ".$self -> {"settings"} -> {"database"} -> {"cohort_states"}." AS c
                                               WHERE s.id = c.statement_id
                                               AND c.cohort_id = ?
                                               ORDER BY s.statement");
    $statesh -> execute($cohortid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform cohort statement lookup query: ".$self -> {"dbh"} -> errstr);

    my $options = "";
    while(my $statement = $statesh -> fetchrow_arrayref()) {
        my $showstatement = $self -> truncate_words($statement -> [1]);
        $options .= '<option value="'.$statement -> [0].'" title="'.$statement -> [1].'">'.$showstatement."</option>\n";
    }

    return $options;
}


## @method $ build_unset_statements($cohortid)
# Generate the list of statements not associated with the specified cohort.
# This generates a block of options suitable for use in a select list.
#
# @param cohortid The ID of the cohort to generate the statement list for.
# @return The cohort statement option list.
sub build_unset_statements {
    my $self     = shift;
    my $cohortid = shift;

    # 'unused' statements is a bit trickier than used ones...
    my $statesh = $self -> {"dbh"} -> prepare("SELECT s.id, s.statement
                                               FROM ".$self -> {"settings"} -> {"database"} -> {"statements"}." AS s
                                               WHERE s.id NOT IN (SELECT c.statement_id
                                                                  FROM ".$self -> {"settings"} -> {"database"} -> {"cohort_states"}." AS c
                                                                  WHERE c.cohort_id = ?)
                                               ORDER BY s.statement");
    $statesh -> execute($cohortid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform cohort statement lookup query: ".$self -> {"dbh"} -> errstr);

    my $options = "";
    while(my $statement = $statesh -> fetchrow_arrayref()) {
        my $showstatement = $self -> truncate_words($statement -> [1]);
        $options .= '<option value="'.$statement -> [0].'" title="'.$statement -> [1].'">'.$showstatement."</option>\n";

    }

    return $options;
}


## @method void generate_statements_xml($cohortid)
# Generate an XML response containing the set and unset statements for the
# specified cohortid. This will generate the XML that should be sent to the
# caller in response to a 'statements' request.
#
# @param cohortid The ID of the cohort to generate the statement XML for.
sub generate_statements_xml {
    my $self = shift;
    my $cohortid = shift;

    $self -> log("admin view", "Fetching cohort statement list");

    # Can this cohort be edited?
    my $disabled = $self -> cohort_has_sorts($cohortid) ? ' modify="disabled"' : '';

    # Work out the set and unset lists
    my $setstates = $self -> {"template"} -> load_template("xml/elem.tem", {"***elem***"    => "setstates",
                                                                            "***attrs***"   => '',
                                                                            "***content***" => $self -> build_set_statements($cohortid) });
    my $unsetstates =  $self -> {"template"} -> load_template("xml/elem.tem", {"***elem***"    => "availstates",
                                                                               "***attrs***"   => '',
                                                                               "***content***" => $disabled ? "" : $self -> build_unset_statements($cohortid) });
    my $content = $self -> {"template"} -> load_template("xml/elem.tem", {"***elem***"    => "cstatedata",
                                                                          "***attrs***"   => $disabled,
                                                                          "***content***" => "$setstates$unsetstates"});
    # Put together the xml...
    print $self -> {"cgi"} -> header(-type => 'application/xml',
                                     -charset => 'utf-8');
    print Encode::encode_utf8($self -> {"template"} -> load_template("xml/xml.tem", {"***base***"  => "response",
                                                                                     "***dtd***"   => '<!DOCTYPE response SYSTEM "dtds/cstateapi.dtd" >',
                                                                                     "***attrs***" => '',
                                                                                     "***tree***"  => $content}));
    exit;
}


## @method void generate_error_xml($errormsg)
# Generate an XML response containing an error message.
#
# @param errormsg The text of the error to return to the caller.
sub generate_error_xml {
    my $self     = shift;
    my $errormsg = shift;

    $self -> log("admin error", "CohortStateAPI error = $errormsg");

    my $content = $self -> {"template"} -> load_template("xml/elem.tem", {"***elem***"    => "error",
                                                                          "***attrs***"   => '',
                                                                          "***content***" => $errormsg});
    # Put together the xml...
    print $self -> {"cgi"} -> header(-type => 'application/xml',
                                     -charset => 'utf-8');
    print Encode::encode_utf8($self -> {"template"} -> load_template("xml/xml.tem", {"***base***"  => "response",
                                                                                     "***dtd***"   => '<!DOCTYPE response SYSTEM "dtds/cstateapi.dtd" >',
                                                                                     "***attrs***" => '',
                                                                                     "***tree***"  => $content}));
    exit;
}


## @method void generate_success_xml($successmsg)
# Generate an XML response containing an success message.
#
# @param successmsg The text of the success to return to the caller.
sub generate_success_xml {
    my $self     = shift;
    my $successmsg = shift;

    my $content = $self -> {"template"} -> load_template("xml/elem.tem", {"***elem***"    => "success",
                                                                          "***attrs***"   => '',
                                                                          "***content***" => $successmsg});
    # Put together the xml...
    print $self -> {"cgi"} -> header(-type => 'application/xml',
                                     -charset => 'utf-8');
    print Encode::encode_utf8($self -> {"template"} -> load_template("xml/xml.tem", {"***base***"  => "response",
                                                                                     "***dtd***"   => '<!DOCTYPE response SYSTEM "dtds/cstateapi.dtd" >',
                                                                                     "***attrs***" => '',
                                                                                     "***tree***"  => $content}));
    exit;
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
             $content = $sessuser;
        } else {

            # Get the cohort id, this should always be present
            my $cohortid = is_defined_numeric($self -> {"cgi"}, "id");
            if($cohortid) {
                # Has the caller requested the statement lists?
                if(defined($self -> {"cgi"} -> param("statements"))) {
                    $self -> generate_statements_xml($cohortid);
                } elsif(defined($self -> {"cgi"} -> param("add"))) {
                    $self -> add_statements($cohortid);
                }  elsif(defined($self -> {"cgi"} -> param("remove"))) {
                    $self -> remove_statements($cohortid);
                }

            } else {
                $self -> log("admin error", "CohortStateAPI call with no cohort id");

                $self -> generate_error_xml($self -> {"template"} -> replace_langvar("ADMIN_COHORTSTATES_ERR_NOCID"));
            }
        }

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
