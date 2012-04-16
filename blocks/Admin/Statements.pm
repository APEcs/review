## @file
# This file contains the implementation of the admin statement management interface.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    27 January 2012
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
package Admin::Statements;

## @class Admin::Statements
# Implementation of the statement management interface. This code allows
# admin users to add, edit, and remove the statements in the statement pool.
use strict;
use base qw(Admin); # This class extends Admin
use POSIX qw(ceil);
use Utils qw(is_defined_numeric);
use Data::Dumper;

# ============================================================================
#  General utility stuff.

## @method private $ can_modify_statement($statementid)
# Determine whether the user can modify the statement specified. This will check
# whether any sorts have been performed that include the statement specified,
# and if so it will return false. If no sorts have been performed using the
# statement, this will return true.
#
# @param statementid The statement to check for sorts.
# @return 1 if the user can modify the statement, 0 otherwise.
sub can_modify_statement {
    my $self        = shift;
    my $statementid = shift;

    # A query to determine whether a sort has happened with the specified statement id.
    # Note the 'LIMIT 1' - it doesn't matter if there might be more than one row, as soon as
    # one is found we know the user can't modify the statement!
    my $usedh = $self -> {"dbh"} -> prepare("SELECT s.id
                                             FROM ".$self -> {"settings"} -> {"database"} -> {"sorts"}." AS s,
                                                  ".$self -> {"settings"} -> {"database"} -> {"users"}." AS u,
                                                  ".$self -> {"settings"} -> {"database"} -> {"cohort_states"}." AS cs
                                             WHERE cs.statement_id = ?
                                             AND u.cohort_id = cs.cohort_id
                                             AND s.user_id = u.user_id
                                             LIMIT 1");
    $usedh -> execute($statementid)
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform used statement count query: ".$self -> {"dbh"} -> errstr);

    my $used = $usedh -> fetchrow_arrayref();
    return $used ? 0 : 1; # Theoretically !$used should work, but this is safer.
}


## @method private $ get_statement_count()
# Count how many statements are currently defined in the database.
#
# @return The number of defined statements.
sub get_statement_count {
    my $self = shift;

    my $counth = $self -> {"dbh"} -> prepare("SELECT COUNT(*) FROM ".$self -> {"settings"} -> {"database"} -> {"statements"});
    $counth -> execute()
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform statement count query: ".$self -> {"dbh"} -> errstr);

    my $count = $counth -> fetchrow_arrayref();

    return $count ? $count -> [0] : 0;
}


## @method private $ get_sort_direction()
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
    return (!$way || $way eq "asc") ? "ASC" : "DESC";
}


## @method private @ get_page()
# Obtain the current page number for the statement table.
#
# @return An array of two values: the current page number, and the maximum page number.
sub get_page {
    my $self = shift;

    my $statementcount = $self -> get_statement_count();
    my $maxpage     = int($statementcount / $self -> {"settings"} -> {"config"} -> {"Admin:page_length"});

    # Check for pagination and range.
    my $page = is_defined_numeric($self -> {"cgi"}, "page");
    $page    = 0 if(!defined($page) || $page < 0);
    $page    = $maxpage if($page > $maxpage);

    return ($page, $maxpage);
}


# ============================================================================
#  Statement editing

## @method private $ get_editable_statement()
# Pull the id of the statement the user is attempting to edit from the query string,
# and determine whether or not it is ediable.
#
# @return A reference to a hash containing the statement data if it is editable, an
#         error message otherwise.
sub get_editable_statement {
    my $self = shift;

    # Get the statement id
    my $statementid = is_defined_numeric($self -> {"cgi"}, "id");
    $self -> log("admin edit", "Request modification of statement ".($statementid || "undefined"));
    return $self -> {"template"} -> replace_langvar("ADMIN_STATE_ERR_NOID")
        unless($statementid);

    # Is the statement valid?
    my $statementh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"statements"}."
                                                  WHERE id = ?");
    $statementh -> execute($statementid)
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform statement lookup query: ".$self -> {"dbh"} -> errstr);

    my $statement = $statementh -> fetchrow_hashref();
    return $self -> {"template"} -> replace_langvar("ADMIN_STATE_ERR_BADID")
        unless($statement);

    # Is the statement ediable?
    return $self -> {"template"} -> replace_langvar("ADMIN_STATE_NOEDIT")
        unless($self -> can_modify_statement($statementid));

    return $statement;
}


## @method private $ delete_statement()
# Delete the statement the user has selected from the database. This will check that
# the statement is safe to delete before doing so.
#
# @return An error message on failure, undef on success.
sub delete_statement {
    my $self = shift;

    # Is the statement editable?
    my $statement = $self -> get_editable_statement();
    if(ref($statement) ne "HASH") {
        $self -> log("admin edit", "Delete failed: $statement");
        return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                      {"***message***" => $statement});
    }

    # Yes; delete it
    my $nukeh = $self -> {"dbh"} -> prepare("DELETE FROM ".$self -> {"settings"} -> {"database"} -> {"statements"}."
                                             WHERE id = ?");
    $nukeh -> execute($statement -> {"id"})
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform statement delete query: ".$self -> {"dbh"} -> errstr);

    $self -> log("admin edit", "Deleted statement ".$statement -> {"id"}." (".$statement -> {"statement"}.")");

    return undef;
}


## @method private $ build_admin_editstatement($isadd, $args, $error)
# Construct the page containing the statement edit/addition form. This will create
# the statement addition or edit form, prepopulating the fields with the contents of
# the args hash if provided.
#
# @param isadd If true, this generates an addition form rather than edit form.
# @param args  A reference to a hash of values to set the form fields to.
# @param error An error box to show before the form.
# @return A string containing the statement addition or edit form.
sub build_admin_editstatement {
    my $self  = shift;
    my $isadd = shift;
    my $args  = shift;
    my $error = shift;

    # If we have an edit, but no args, fetch the selected statement for editing
    if(!$isadd && !defined($args)) {
        $args = $self -> get_editable_statement();
        return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                      {"***message***" => $args})
            unless(ref($args) eq "HASH");
    }

    # Avoid hash access warnings
    $args = {} if(!defined($args));

    my ($page, $maxpage) = $self -> get_page();

    return $self -> {"template"} -> load_template("admin/statements/".($isadd ? "add" : "edit").".tem",
                                                  {"***error***"         => $error,
                                                   "***id***"            => $args -> {"id"},
                                                   "***statement***"     => $args -> {"statement"},
                                                   "***page***"          => $page,
                                                   "***way***"           => lc($self -> get_sort_direction()),
                                                  });
}


## @method private @ validate_edit_statement($isadd)
# Determine whether the value specified by the user in a statement add/edit
# form are valid.
#
# @param isadd Set to true when called as part of an add process. Checks
#              that the statement is valid and ediable are skipped if set.
# @return A reference to a hash of values submitted by the user, and a
#         string containing any error messages.
sub validate_edit_statement {
    my $self  = shift;
    my $isadd = shift;
    my $args  = {};
    my ($error, $errors, $statement);

    my $errtem = $self -> {"template"} -> load_template("error_entry.tem");

    # If this isn't an add, check that the statement is valid and editable
    if(!$isadd) {
        $statement = $self -> get_editable_statement();
        return ($args, $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                              {"***message***" => $statement}))
                unless(ref($statement) eq "HASH");

        # Store the id for use later
        $args -> {"id"} = $statement -> {"id"};
    }

    # Statement text is easy...
    ($args -> {"statement"}, $error) = $self -> validate_string("statement", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_STATE"),
                                                                              "required" => 1,
                                                           });
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # Wrap the errors if needed
    $errors = $self -> {"template"} -> load_template("error_list.tem", {"***message***" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_SUBMIT_FAIL"),
                                                                        "***errors***"  => $errors})
        if($errors);

    return ($args, $errors);
}


## @method private $ add_statement()
# Attempt to add a statement to the system.
#
# @return A string containing the page content to return to the user.
sub add_statement {
    my $self = shift;

    # Determine whether the submission is valid
    my ($args, $errors) = $self -> validate_edit_statement(1);

    # If there are any errors, report them and send the form back.
    return $self -> build_admin_editstatement(1, $args, $errors)
        if($errors);

    local $Data::Dumper::Terse = 1;
    $self -> log("admin edit", "Adding new statement: ".Dumper($args));

    # No errors - do the insert...
    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"statements"}."
                                            (statement)
                                            VALUES(?)");
    $newh -> execute($args -> {"statement"})
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform statement insert query: ".$self -> {"dbh"} -> errstr);

    return $self -> build_admin_statements($self -> {"template"} -> load_template("admin/statements/add_done.tem"));
}


## @method private $ edit_statement()
# Attempt to edit a statement in the system.
#
# @return A string containing the page content to return to the user.
sub edit_statement {
    my $self = shift;

    # Determine whether the submission is valid
    my ($args, $errors) = $self -> validate_edit_statement();

    # If there are any errors, report them and send the form back.
    return $self -> build_admin_editstatement(0, $args, $errors)
        if($errors);

    local $Data::Dumper::Terse = 1;
    $self -> log("admin edit", "Editing statement: ".Dumper($args));

    my $edith = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"statements"}."
                                             SET statement = ?
                                             WHERE id = ?");
    $edith -> execute($args -> {"statement"},
                      $args -> {"id"})
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform statement edit query: ".$self -> {"dbh"} -> errstr);

    return $self -> build_admin_statements($self -> {"template"} -> load_template("admin/statements/edit_done.tem"));
}


# ============================================================================
#  Statement listing

## @method private $ build_statements_sort_headers($way, $page)
# Generate the sort control icons and links to show in the statement list table header.
#
# @param way   The sorting direction.
# @param page  The current page number.
# @return A hash containing the table sort strings to pass to Template::load_template().
sub build_statements_sort_headers {
    my $self  = shift;
    my $way   = shift;
    my $page  = shift;
    my $fields = {};

    my $temcache = { "asc"  => $self -> {"template"} -> load_template("admin/sort_asc.tem",  {"***block***" => "stateadmin",
                                                                                              "***page***"  => $page}),
                     "desc" => $self -> {"template"} -> load_template("admin/sort_desc.tem", {"***block***" => "stateadmin",
                                                                                              "***page***"  => $page})};
    $fields -> {"***statesort***"} = $self -> {"template"} -> process_template($temcache -> {lc($way)}, {"***sort***" => 'statement'});

    return $fields;
}


## @method private $ build_admin_statements($error)
# Generate the admin statements list page.
#
# @param error An error message to show at the top of the page.
# @return A string containing the statement list page.
sub build_admin_statements {
    my $self    = shift;
    my $error   = shift;
    my $statements = "";

    # Need to know how many statements are defined.
    my ($page, $maxpage) = $self -> get_page();

    # Check for sorting direction
    my $sortdir   = $self -> get_sort_direction();

    # Convert the page to a start offset.
    my $start = $page * $self -> {"settings"} -> {"config"} -> {"Admin:page_length"};

    # Now fetch the statements from the database. Can use LIMIT as no funky filtering is involved...
    my $statementh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"statements"}."
                                                  ORDER BY `statement` $sortdir
                                                  LIMIT $start,".$self -> {"settings"} -> {"config"} -> {"Admin:page_length"});
    $statementh -> execute()
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform statement lookup query: ".$self -> {"dbh"} -> errstr);

    # precache some templates needed later
    my $temcache = { "row" => $self -> {"template"} -> load_template("admin/statements/row.tem"),
                     "doedit" => [ $self -> {"template"} -> load_template("admin/statements/modify_off.tem"),
                                   $self -> {"template"} -> load_template("admin/statements/modify_on.tem", {"***page***" => $page,
                                                                                                             "***way***"  => lc($sortdir)}) ]
    };

    while(my $statement = $statementh -> fetchrow_hashref()) {
        # Determine whether this statement can be edited/deleted.
        my $modify = $self -> can_modify_statement($statement -> {"id"});

        # Put a row together
        $statements .= $self -> {"template"} -> process_template($temcache -> {"row"}, {"***statement***" => $statement -> {"statement"},
                                                                                        "***ops***"       => $self -> {"template"} -> process_template($temcache -> {"doedit"} -> [$modify], {"***id***" => $statement -> {"id"}}),
                                                              });
    }

    my $datafields = $self -> build_statements_sort_headers($sortdir, $page);
    $datafields -> {"***paginate***"} = $self -> build_pagination("stateadmin", $maxpage, $page, {"way" => lc($sortdir)});
    $datafields -> {"***statements***"}  = $statements;
    $datafields -> {"***error***"}    = $error;

    return $self -> {"template"} -> load_template("admin/statements/statements.tem", $datafields);
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    # We need to determine what the page title should be, and the content to shove in it...
    my ($title, $content) = ($self -> {"template"} -> replace_langvar("ADMIN_STATE_TITLE"), "");

    # User must be logged in before we can do anything else
    if($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) {

        # Bomb immediately if the user does not have admin permission
        my $sessuser = $self -> check_admin_permission($self -> {"session"} -> {"sessuser"});
        if(ref($sessuser) ne "HASH") {
            $self -> log("admin view", "Permission denied");
            $content = $sessuser;
        } else {

            my $body;
            # Dispatch based on selected operation, if any
            if(defined($self -> {"cgi"} -> param("addstatement"))) {
                $self -> log("admin edit", "Add statement");
                $body = $self -> build_admin_editstatement(1);

            } elsif(defined($self -> {"cgi"} -> param("doadd"))) {
                $self -> log("admin edit", "Do add statement");
                $body = $self -> add_statement();

            } elsif(defined($self -> {"cgi"} -> param("edit"))) {
                $self -> log("admin edit", "Edit statement");
                $body = $self -> build_admin_editstatement();

            } elsif(defined($self -> {"cgi"} -> param("doedit"))) {
                $self -> log("admin edit", "Do edit statement");
                $body = $self -> edit_statement();

            } elsif(defined($self -> {"cgi"} -> param("delete"))) {
                $self -> log("admin edit", "Delete statement");
                $body = $self -> build_admin_statements($self -> delete_statement());

            } else {
                $self -> log("admin view", "Statements");
                $body = $self -> build_admin_statements();
            }

            # Show the admin page
            $content = $self -> {"template"} -> load_template("admin/admin.tem", {"***tabbar***" => $self -> generate_admin_tabbar("stateadmin"),
                                                                                  "***body***"   => $body})
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
                                                               "***extrahead***" => '<link href="templates/default/admin/admin.css" rel="stylesheet" type="text/css" />'.
                                                                   $self -> {"template"} -> load_template("admin/datepicker_head.tem"),
                                                               "***content***"   => $content});

}

1;
