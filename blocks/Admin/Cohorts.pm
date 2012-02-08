## @file
# This file contains the implementation of the admin cohort management interface.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    26 January 2012
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
package Admin::Cohorts;

## @class Admin::Cohorts
# Implementation of the cohort management interface. This code allows
# admin users to add, edit, and remove the cohorts that students may
# be placed in.
use strict;
use base qw(Admin); # This class extends Admin
use Logging qw(die_log);
use POSIX qw(ceil);
use Utils qw(is_defined_numeric);
use Data::Dumper;

# ============================================================================
#  General utility stuff.

## @method private $ can_delete_cohort($cohortid)
# Determine whether the user can delete the cohort specified. This will check
# whether any users are members of the cohort, and if so it will return false.
# If no users are members of the cohort, this will return true.
#
# @param cohortid The cohort to check for users.
# @return 1 if the user can delete the cohort, 0 otherwise.
sub can_delete_cohort {
    my $self     = shift;
    my $cohortid = shift;

    my $checkh = $self -> {"dbh"} -> prepare("SELECT COUNT(user_id) FROM ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                              WHERE cohort_id = ?");
    $checkh -> execute($cohortid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform cohort delete check query: ".$self -> {"dbh"} -> errstr);

    my $count = $checkh -> fetchrow_arrayref();

    # Can the user delete? If we have no row (unlikely as it's a count!), or the count is 0, they cay.
    return !($count && $count -> [0]);
}


## @method private $ get_cohort_count()
# Count how many cohorts are currently defined in the database.
#
# @return The number of defined cohorts.
sub get_cohort_count {
    my $self = shift;

    my $counth = $self -> {"dbh"} -> prepare("SELECT COUNT(*) FROM ".$self -> {"settings"} -> {"database"} -> {"cohorts"});
    $counth -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform cohort count query: ".$self -> {"dbh"} -> errstr);

    my $count = $counth -> fetchrow_arrayref();

    return $count ? $count -> [0] : 0;
}


## @method private $ get_sort_field()
# Obtain the name of the field the cohort table should be sorted on. This checks
# whether the user has selected a sort field via the query string, and if so
# whether the selection is valid.
#
# @return The table column to sort on.
sub get_sort_field {
    my $self = shift;
    my @valid_fields = ("startdate", "enddate", "name");
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
    return (!$way || $way eq "desc") ? "DESC" : "ASC";
}


# ============================================================================
#  Cohort editing

## @method private $ get_deletable_cohort($isedit)
# Pull the id of the cohort the user is attempting to edit from the query string,
# and determine whether or not it is ediable.
#
# @param isedit If true, the user is requesting an edit rather than a delete.
# @return A reference to a hash containing the cohort data if it is editable, an
#         error message otherwise.
sub get_deletable_cohort {
    my $self   = shift;
    my $isedit = shift;

    # Get the cohort id
    my $cohortid = is_defined_numeric($self -> {"cgi"}, "id");
    $self -> log("admin edit", "Request modification of cohort ".($cohortid || "undefined"));
    return $self -> {"template"} -> replace_langvar("ADMIN_COHORT_ERR_NOID")
        unless($cohortid);

    # Is the cohort valid?
    my $cohorth = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"cohorts"}."
                                               WHERE id = ?");
    $cohorth -> execute($cohortid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform cohort lookup query: ".$self -> {"dbh"} -> errstr);

    my $cohort = $cohorth -> fetchrow_hashref();
    return $self -> {"template"} -> replace_langvar("ADMIN_COHORT_ERR_BADID")
        unless($cohort);

    # Is the cohort deletable?
    return $self -> {"template"} -> replace_langvar("ADMIN_COHORT_NODEL")
        unless($isedit || $self -> can_delete_cohort($cohortid));

    return $cohort;
}


## @method private $ delete_cohort()
# Delete the cohort the user has selected from the database. This will check that
# the cohort is safe to delete before doing so.
#
# @return An error message on failure, undef on success.
sub delete_cohort {
    my $self = shift;

    # Is the cohort editable?
    my $cohort = $self -> get_deletable_cohort();
    if(ref($cohort) ne "HASH") {
        $self -> log("admin edit", "Delete failed: $cohort");
        return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                      {"***message***" => $cohort});
    }

    # Yes; delete it
    my $nukeh = $self -> {"dbh"} -> prepare("DELETE FROM ".$self -> {"settings"} -> {"database"} -> {"cohorts"}."
                                             WHERE id = ?");
    $nukeh -> execute($cohort -> {"id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform cohort delete query: ".$self -> {"dbh"} -> errstr);

    $self -> log("admin edit", "Deleted cohort ".$cohort -> {"id"}." (".$cohort -> {"name"}.")");

    return undef;
}


## @method private $ build_admin_editcohort($isadd, $args, $error)
# Construct the page containing the cohort edit/addition form. This will create
# the cohort addition or edit form, prepopulating the fields with the contents of
# the args hash if provided.
#
# @param isadd If true, this generates an addition form rather than edit form.
# @param args  A reference to a hash of values to set the form fields to.
# @param error An error box to show before the form.
# @return A string containing the cohort addition or edit form.
sub build_admin_editcohort {
    my $self  = shift;
    my $isadd = shift;
    my $args  = shift;
    my $error = shift;

    # If we have an edit, but no args, fetch the selected cohort for editing
    if(!$isadd && !defined($args)) {
        $args = $self -> get_deletable_cohort(1);
        return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                      {"***message***" => $args})
            unless(ref($args) eq "HASH");
    }

    # Avoid hash access warnings
    $args = {} if(!defined($args));

    # Fix up formatting for the user-visible input boxes.
    # FIXME: This only works provided the locale is set to en-GB. Can datepicker be set to do this
    #        automagically based on the current locale?
    my $format_start = $self -> {"template"} -> format_time($args -> {"startdate"}, "%d/%m/%Y %H:%M")
        if($args -> {"startdate"});

    my $format_end = $self -> {"template"} -> format_time($args -> {"enddate"}, "%d/%m/%Y %H:%M")
        if($args -> {"enddate"});

    return $self -> {"template"} -> load_template("admin/cohorts/".($isadd ? "add" : "edit").".tem",
                                                  {"***error***"         => $error,
                                                   "***id***"            => $args -> {"id"},
                                                   "***startdate***"     => $args -> {"startdate"},
                                                   "***startdate_fmt***" => $format_start,
                                                   "***enddate***"       => $args -> {"enddate"},
                                                   "***enddate_fmt***"   => $format_end,
                                                   "***name***"          => $args -> {"name"},
                                                  });
}


## @method private @ validate_edit_cohort($isadd)
# Determine whether the value specified by the user in a cohort add/edit
# form are valid.
#
# @param isadd Set to true when called as part of an add process. Checks
#              that the cohort is valid and ediable are skipped if set.
# @return A reference to a hash of values submitted by the user, and a
#         string containing any error messages.
sub validate_edit_cohort {
    my $self  = shift;
    my $isadd = shift;
    my $args  = {};
    my ($error, $errors, $cohort);

    my $errtem = $self -> {"template"} -> load_template("error_entry.tem");

    # If this isn't an add, check that the cohort is valid and editable
    if(!$isadd) {
        $cohort = $self -> get_deletable_cohort(1);
        return ($args, $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                              {"***message***" => $cohort}))
                unless(ref($cohort) eq "HASH");

        # Store the id for use later
        $args -> {"id"} = $cohort -> {"id"};
    }

    ($args -> {"startdate"}, $error) = $self -> validate_string("startdate", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_START"),
                                                                              "required" => 1,
                                                                              "formattest" => '^\d+$',
                                                                              "formatdesc" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_ONLYDIGITS")});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # Does the start date clash with another cohort?
    if($args -> {"startdate"}) {
        my $clashcohort = $self -> get_cohort_bytime($args -> {"startdate"});

        # If we have a clash, and either the clash doesn't match the currently edited cohort
        # or we don't have a current edit cohort, white at the user about a clash.
        $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_COHORT_CLASH", {"***name***" => $self -> {"template"} -> replace_langvar("ADMIN_START")})})
            if($clashcohort && (!$cohort || $clashcohort -> {"id"} != $cohort -> {"id"}));
    }

    ($args -> {"enddate"}, $error) = $self -> validate_string("enddate", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_END"),
                                                                          "required" => 1,
                                                                          "formattest" => '^\d+$',
                                                                          "formatdesc" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_ONLYDIGITS")});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # Does the end date clash with another cohort?
    if($args -> {"enddate"}) {
        my $clashcohort = $self -> get_cohort_bytime($args -> {"enddate"});

        # If we have a clash, and either the clash doesn't match the currently edited cohort
        # or we don't have a current edit cohort, white at the user about a clash.
        $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_COHORT_CLASH", {"***name***" => $self -> {"template"} -> replace_langvar("ADMIN_END")})})
            if($clashcohort && (!$cohort || $clashcohort -> {"id"} != $cohort -> {"id"}));
    }

    # Start date must fall before the end date!
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_COHORT_FLIP")})
        unless($args -> {"startdate"} < $args -> {"enddate"});

    # Title needs no faffing...
    ($args -> {"name"}, $error) = $self -> validate_string("name", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_NAME"),
                                                                    "required" => 1,
                                                                    "maxlen"   => 80});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # Wrap the errors if needed
    $errors = $self -> {"template"} -> load_template("error_list.tem", {"***message***" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_SUBMIT_FAIL"),
                                                                        "***errors***"  => $errors})
        if($errors);

    return ($args, $errors);
}


## @method private $ add_cohort()
# Attempt to add a cohort to the system.
#
# @return A string containing the page content to return to the user.
sub add_cohort {
    my $self = shift;

    # Determine whether the submission is valid
    my ($args, $errors) = $self -> validate_edit_cohort(1);

    # If there are any errors, report them and send the form back.
    return $self -> build_admin_editcohort(1, $args, $errors)
        if($errors);

    local $Data::Dumper::Terse = 1;
    $self -> log("admin edit", "Adding new cohort: ".Dumper($args));

    # No errors - do the insert...
    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"cohorts"}."
                                            (startdate, enddate, name)
                                            VALUES(?, ?, ?)");
    $newh -> execute($args -> {"startdate"},
                     $args -> {"enddate"},
                     $args -> {"name"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform cohort insert query: ".$self -> {"dbh"} -> errstr);

    return $self -> build_admin_cohorts($self -> {"template"} -> load_template("admin/cohorts/add_done.tem"));
}


## @method private $ edit_cohort()
# Attempt to edit a cohort in the system.
#
# @return A string containing the page content to return to the user.
sub edit_cohort {
    my $self = shift;

    # Determine whether the submission is valid
    my ($args, $errors) = $self -> validate_edit_cohort();

    # If there are any errors, report them and send the form back.
    return $self -> build_admin_editcohort(0, $args, $errors)
        if($errors);

    local $Data::Dumper::Terse = 1;
    $self -> log("admin edit", "Editing cohort: ".Dumper($args));

    my $edith = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"cohorts"}."
                                             SET startdate = ?, enddate = ?, name = ?
                                             WHERE id = ?");
    $edith -> execute($args -> {"startdate"},
                      $args -> {"enddate"},
                      $args -> {"name"},
                      $args -> {"id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform cohort edit query: ".$self -> {"dbh"} -> errstr);

    return $self -> build_admin_cohorts($self -> {"template"} -> load_template("admin/cohorts/edit_done.tem"));
}


# ============================================================================
#  Cohort listing

## @method private $ build_cohorts_sort_headers($field, $way, $page)
# Generate the sort control icons and links to show in the cohort list table header.
#
# @param field The current sort field.
# @param way   The sorting direction.
# @param page  The current page number.
# @return A hash containing the table sort strings to pass to Template::load_template().
sub build_cohorts_sort_headers {
    my $self  = shift;
    my $field = shift;
    my $way   = shift;
    my $page  = shift;
    my $fields = {};

    my @valid_fields = ("startdate", "enddate", "name");
    my $temcache = { "sort" => $self -> {"template"} -> load_template("admin/sort.tem",      {"***block***" => "cohorts",
                                                                                              "***page***"  => $page}),
                     "asc"  => $self -> {"template"} -> load_template("admin/sort_asc.tem",  {"***block***" => "cohorts",
                                                                                              "***page***"  => $page}),
                     "desc" => $self -> {"template"} -> load_template("admin/sort_desc.tem", {"***block***" => "cohorts",
                                                                                              "***page***"  => $page})};
    # Check each field to determine whether it is the currently selected field,
    # and which direction it is sorted in, to create the sort headers
    foreach my $name (@valid_fields) {
        $fields -> {"***".$name."***"} = $self -> {"template"} -> process_template($temcache -> {($name eq $field) ? lc($way) : "sort"}, {"***sort***" => $name});
    }

    return $fields;
}


## @method private $ build_admin_cohorts($error)
# Generate the admin cohorts list page.
#
# @param error An error message to show at the top of the page.
# @return A string containing the cohort list page.
sub build_admin_cohorts {
    my $self    = shift;
    my $error   = shift;
    my $cohorts = "";

    # precache some templates needed later
    my $temcache = { "row"   => $self -> {"template"} -> load_template("admin/cohorts/row.tem"),
                     "dodel" => [ $self -> {"template"} -> load_template("admin/cohorts/delete_off.tem"),
                                  $self -> {"template"} -> load_template("admin/cohorts/delete_on.tem") ]
    };

    # Need to know how many cohorts are defined.
    my $cohortcount = $self -> get_cohort_count();
    my $maxpage     = int($cohortcount / $self -> {"settings"} -> {"config"} -> {"Admin:page_length"});

    # Check for sorting
    my $sortfield = $self -> get_sort_field();
    my $sortdir   = $self -> get_sort_direction();

    # Check for pagination and range.
    my $page = is_defined_numeric($self -> {"cgi"}, "page");
    $page    = 0 if(!defined($page) || $page < 0);
    $page    = $maxpage if($page > $maxpage);

    # Convert the page to a start offset.
    my $start = $page * $self -> {"settings"} -> {"config"} -> {"Admin:page_length"};

    # Now fetch the cohorts from the database. Can use LIMIT as no funky filtering is involved...
    my $cohorth = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"cohorts"}."
                                               ORDER BY `$sortfield` $sortdir
                                               LIMIT $start,".$self -> {"settings"} -> {"config"} -> {"Admin:page_length"});
    $cohorth -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform cohort lookup query: ".$self -> {"dbh"} -> errstr);

    while(my $cohort = $cohorth -> fetchrow_hashref()) {
        # Determine whether this cohort can be deleted.
        my $delete = $self -> can_delete_cohort($cohort -> {"id"});

        # Put a row together
        $cohorts .= $self -> {"template"} -> process_template($temcache -> {"row"}, {"***start***"  => $self -> {"template"} -> format_time($cohort -> {"startdate"}),#, $self -> {"settings"} -> {"config"} -> {"datefmt"}),
                                                                                     "***end***"    => $self -> {"template"} -> format_time($cohort -> {"enddate"}),#, $self -> {"settings"} -> {"config"} -> {"datefmt"}),
                                                                                     "***name***"   => $cohort -> {"name"},
                                                                                     "***ops***"    => $self -> {"template"} -> process_template($temcache -> {"dodel"} -> [$delete], {"***id***" => $cohort -> {"id"}}),
                                                              });
    }

    my $datafields = $self -> build_cohorts_sort_headers($sortfield, $sortdir, $page);
    $datafields -> {"***paginate***"} = $self -> build_pagination("cohorts", $maxpage, $page, {"sort" => $sortfield,
                                                                                               "way"  => lc($sortdir)});
    $datafields -> {"***cohorts***"}  = $cohorts;
    $datafields -> {"***error***"}    = $error;

    return $self -> {"template"} -> load_template("admin/cohorts/cohorts.tem", $datafields);
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    # We need to determine what the page title should be, and the content to shove in it...
    my ($title, $content) = ($self -> {"template"} -> replace_langvar("ADMIN_COHORT_TITLE"), "");

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
            if(defined($self -> {"cgi"} -> param("addcohort"))) {
                $self -> log("admin edit", "Add cohort");
                $body = $self -> build_admin_editcohort(1);

            } elsif(defined($self -> {"cgi"} -> param("doadd"))) {
                $self -> log("admin edit", "Do add cohort");
                $body = $self -> add_cohort();

            } elsif(defined($self -> {"cgi"} -> param("edit"))) {
                $self -> log("admin edit", "Edit cohort");
                $body = $self -> build_admin_editcohort();

            } elsif(defined($self -> {"cgi"} -> param("doedit"))) {
                $self -> log("admin edit", "Do edit cohort");
                $body = $self -> edit_cohort();

            } elsif(defined($self -> {"cgi"} -> param("delete"))) {
                $self -> log("admin edit", "Delete cohort");
                $body = $self -> build_admin_cohorts($self -> delete_cohort());

            } else {
                $self -> log("admin view", "Cohorts");
                $body = $self -> build_admin_cohorts();
            }

            # Show the admin page
            $content = $self -> {"template"} -> load_template("admin/admin.tem", {"***tabbar***" => $self -> generate_admin_tabbar("cohorts"),
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
