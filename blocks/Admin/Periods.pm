## @file
# This file contains the implementation of the admin period management interface.
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

## @class Admin::Periods
# Implementation of the sort period management interface. This code allows
# admin users to add, edit, and remove the periods that determine when
# students may perform sorts.
use strict;
use base qw(Admin); # This class extends Admin
use Logging qw(die_log);
use POSIX qw(ceil);
use Utils qw(is_defined_numeric);
use Data::Dumper;

# ============================================================================
#  General utility stuff.

## @method private $ can_modify_period($periodid)
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


## @method private $ get_period_count()
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


## @method private $ get_sort_field()
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
#  Period editing

## @method private $ get_editable_period()
# Pull the id of the period the user is attempting to edit from the query string,
# and determine whether or not it is ediable.
#
# @return A reference to a hash containing the period data if it is editable, an
#         error message otherwise.
sub get_editable_period {
    my $self = shift;

    # Get the period id
    my $periodid = is_defined_numeric($self -> {"cgi"}, "id");
    $self -> log("admin edit", "Request modification of period ".($periodid || "undefined"));
    return $self -> {"template"} -> replace_langvar("ADMIN_PERIOD_ERR_NOID")
        unless($periodid);

    # Is the period valid?
    my $periodh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"periods"}."
                                               WHERE id = ?");
    $periodh -> execute($periodid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform period lookup query: ".$self -> {"dbh"} -> errstr);

    my $period = $periodh -> fetchrow_hashref();
    return $self -> {"template"} -> replace_langvar("ADMIN_PERIOD_ERR_BADID")
        unless($period);

    # Is the period ediable?
    return $self -> {"template"} -> replace_langvar("ADMIN_PERIOD_NOEDIT")
        unless($self -> can_modify_period($periodid));

    return $period;
}


## @method private $ delete_period()
# Delete the period the user has selected from the database. This will check that
# the period is safe to delete before doing so.
#
# @return An error message on failure, undef on success.
sub delete_period {
    my $self = shift;

    # Is the period editable?
    my $period = $self -> get_editable_period();
    if(ref($period) ne "HASH") {
        $self -> log("admin edit", "Delete failed: $period");
        return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                      {"***message***" => $period});
    }

    # Yes; delete it
    my $nukeh = $self -> {"dbh"} -> prepare("DELETE FROM ".$self -> {"settings"} -> {"database"} -> {"periods"}."
                                             WHERE id = ?");
    $nukeh -> execute($period -> {"id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform period delete query: ".$self -> {"dbh"} -> errstr);

    $self -> log("admin edit", "Deleted period ".$period -> {"id"}." (".$period -> {"name"}.", ".$period -> {"year"}.")");

    return undef;
}


## @method private $ build_admin_editperiod($isadd, $args, $error)
# Construct the page containing the period edit/addition form. This will create
# the period addition or edit form, prepopulating the fields with the contents of
# the args hash if provided.
#
# @param isadd If true, this generates an addition form rather than edit form.
# @param args  A reference to a hash of values to set the form fields to.
# @param error An error box to show before the form.
# @return A string containing the period addition or edit form.
sub build_admin_editperiod {
    my $self  = shift;
    my $isadd = shift;
    my $args  = shift;
    my $error = shift;

    # If we have an edit, but no args, fetch the selected period for editing
    if(!$isadd && !defined($args)) {
        $args = $self -> get_editable_period();
        return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                      {"***message***" => $args})
            unless(ref($args) eq "HASH");
    }

    # Fix up formatting for the user-visible input boxes.
    # FIXME: This only works provided the locale is set to en-GB. Can datepicker be set to do this
    #        automagically based on the current locale?
    my $format_start = $self -> {"template"} -> format_time($args -> {"startdate"}, "%d/%m/%Y %H:%M")
        if($args -> {"startdate"});

    my $format_end = $self -> {"template"} -> format_time($args -> {"enddate"}, "%d/%m/%Y %H:%M")
        if($args -> {"enddate"});

    return $self -> {"template"} -> load_template("admin/periods/".($isadd ? "add" : "edit").".tem",
                                                  {"***error***"         => $error,
                                                   "***id***"            => $args -> {"id"},
                                                   "***year***"          => $args -> {"year"},
                                                   "***startdate***"     => $args -> {"startdate"},
                                                   "***startdate_fmt***" => $format_start,
                                                   "***enddate***"       => $args -> {"enddate"},
                                                   "***enddate_fmt***"   => $format_end,
                                                   "***name***"          => $args -> {"name"},
                                                   "***dosort***"        => $args -> {"allow_sort"} ? 'checked="checked"' : '',
                                                  });
}


## @method private @ validate_edit_period($isadd)
# Determine whether the value specified by the user in a period add/edit
# form are valid.
#
# @param isadd Set to true when called as part of an add process. Checks
#              that the period is valid and ediable are skipped if set.
# @return A reference to a hash of values submitted by the user, and a
#         string containing any error messages.
sub validate_edit_period {
    my $self  = shift;
    my $isadd = shift;
    my $args  = {};
    my ($error, $errors, $period);

    my $errtem = $self -> {"template"} -> load_template("error_entry.tem");

    # If this isn't an add, check that the period is valid and editable
    if(!$isadd) {
        $period = $self -> get_editable_period();
        return ($args, $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                              {"***message***" => $period}))
                unless(ref($period) eq "HASH");

        # Store the id for use later
        $args -> {"id"} = $period -> {"id"};
    }

    # year field should be pretty easy to deal with...
    ($args -> {"year"}, $error) = $self -> validate_string("year", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_ACYEAR"),
                                                                    "required" => 1,
                                                                    "minlen"   => 4,
                                                                    "maxlen"   => 4,
                                                                    "formattest" => '^\d+$',
                                                                    "formatdesc" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_ONLYDIGITS")});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # Is the year in a sane range?
    $errors .= $self -> {"template"} -> process_template($errtem,
                                                         { "***error***" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_ACYEAR_RANGE",
                                                                                                                     { "***min***" => $self -> {"settings"} -> {"config"} -> {"Admin:period_minyear"},
                                                                                                                       "***max***" => $self -> {"settings"} -> {"config"} -> {"Admin:period_maxyear"}})
                                                         })
        if($args -> {"year"} && ( $args -> {"year"} < $self -> {"settings"} -> {"config"} -> {"Admin:period_minyear"} ||
                                  $args -> {"year"} > $self -> {"settings"} -> {"config"} -> {"Admin:period_maxyear"}));

    ($args -> {"startdate"}, $error) = $self -> validate_string("startdate", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_START"),
                                                                              "required" => 1,
                                                                              "formattest" => '^\d+$',
                                                                              "formatdesc" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_ONLYDIGITS")});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # Does the start date clash with another period?
    if($args -> {"startdate"}) {
        my $clashperiod = $self -> get_period($args -> {"startdate"});

        # If we have a clash, and either the clash doesn't match the currently edited period
        # or we don't have a current edit period, white at the user about a clash.
        $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_PERIOD_CLASH", {"***name***" => $self -> {"template"} -> replace_langvar("ADMIN_START")})})
            if($clashperiod && (!$period || $clashperiod -> {"id"} != $period -> {"id"}));
    }

    ($args -> {"enddate"}, $error) = $self -> validate_string("enddate", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_END"),
                                                                          "required" => 1,
                                                                          "formattest" => '^\d+$',
                                                                          "formatdesc" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_ONLYDIGITS")});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # Does the end date clash with another period?
    if($args -> {"enddate"}) {
        my $clashperiod = $self -> get_period($args -> {"enddate"});

        # If we have a clash, and either the clash doesn't match the currently edited period
        # or we don't have a current edit period, white at the user about a clash.
        $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_PERIOD_CLASH", {"***name***" => $self -> {"template"} -> replace_langvar("ADMIN_END")})})
            if($clashperiod && (!$period || $clashperiod -> {"id"} != $period -> {"id"}));
    }

    # Start date must fall before the end date!
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_PERIOD_FLIP")})
        unless($args -> {"startdate"} < $args -> {"enddate"});

    # Title needs no faffing...
    ($args -> {"name"}, $error) = $self -> validate_string("name", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_NAME"),
                                                                    "required" => 1,
                                                                    "maxlen"   => 80});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # sort allowance even less so...
    $args -> {"allow_sort"} = $self -> {"cgi"} -> param("allow_sort") ? 1 : 0;

    # Wrap the errors if needed
    $errors = $self -> {"template"} -> load_template("error_list.tem", {"***message***" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_SUBMIT_FAIL"),
                                                                        "***errors***"  => $errors})
        if($errors);

    return ($args, $errors);
}


## @method private $ add_period()
# Attempt to add a period to the system.
#
# @return A string containing the page content to return to the user.
sub add_period {
    my $self = shift;

    # Determine whether the submission is valid
    my ($args, $errors) = $self -> validate_edit_period(1);

    # If there are any errors, report them and send the form back.
    return $self -> build_admin_addperiod($args, $errors)
        if($errors);

    local $Data::Dumper::Terse = 1;
    $self -> log("admin edit", "Adding new period: ".Dumper($args));

    # No errors - do the insert...
    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"periods"}."
                                            (year, startdate, enddate, name, allow_sort)
                                            VALUES(?, ?, ?, ?, ?)");
    $newh -> execute($args -> {"year"},
                     $args -> {"startdate"},
                     $args -> {"enddate"},
                     $args -> {"name"},
                     $args -> {"allow_sort"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform period insert query: ".$self -> {"dbh"} -> errstr);

    return $self -> build_admin_periods($self -> {"template"} -> load_template("admin/periods/add_done.tem"));
}


## @method private $ edit_period()
# Attempt to edit a period in the system.
#
# @return A string containing the page content to return to the user.
sub edit_period {
    my $self = shift;

    # Determine whether the submission is valid
    my ($args, $errors) = $self -> validate_edit_period();

    # If there are any errors, report them and send the form back.
    return $self -> build_admin_addperiod($args, $errors)
        if($errors);

    local $Data::Dumper::Terse = 1;
    $self -> log("admin edit", "Editing period: ".Dumper($args));

    my $edith = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"periods"}."
                                             SET year = ?, startdate = ?, enddate = ?, name = ?, allow_sort = ?
                                             WHERE id = ?");
    $edith -> execute($args -> {"year"},
                      $args -> {"startdate"},
                      $args -> {"enddate"},
                      $args -> {"name"},
                      $args -> {"allow_sort"},
                      $args -> {"id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform period edit query: ".$self -> {"dbh"} -> errstr);

    return $self -> build_admin_periods($self -> {"template"} -> load_template("admin/periods/edit_done.tem"));
}


# ============================================================================
#  Period listing

## @method private $ build_periods_sort_headers($field, $way, $page)
# Generate the sort control icons and links to show in the period list table header.
#
# @param field The current sort field.
# @param way   The sorting direction.
# @param page  The current page number.
# @return A hash containing the table sort strings to pass to Template::load_template().
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


## @method private $ build_admin_periods($error)
# Generate the admin periods list page.
#
# @param error An error message to show at the top of the page.
# @return A string containing the period list page.
sub build_admin_periods {
    my $self    = shift;
    my $error   = shift;
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
    $datafields -> {"***error***"}    = $error;

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

        my $body;
        # Dispatch based on selected operation, if any
        if(defined($self -> {"cgi"} -> param("addperiod"))) {
            $self -> log("admin edit", "Add period");
            $body = $self -> build_admin_editperiod(1);

        } elsif(defined($self -> {"cgi"} -> param("doadd"))) {
            $self -> log("admin edit", "Do add period");
            $body = $self -> add_period();

        } elsif(defined($self -> {"cgi"} -> param("edit"))) {
            $self -> log("admin edit", "Edit period");
            $body = $self -> build_admin_editperiod();

        } elsif(defined($self -> {"cgi"} -> param("doedit"))) {
            $self -> log("admin edit", "Do edit period");
            $body = $self -> edit_period();

        } elsif(defined($self -> {"cgi"} -> param("delete"))) {
            $self -> log("admin edit", "Delete period");
            $body = $self -> build_admin_periods($self -> delete_period());

        } else {
            $self -> log("admin view", "Periods");
            $body = $self -> build_admin_periods();
        }

        # Show the admin page
        $content = $self -> {"template"} -> load_template("admin/admin.tem", {"***tabbar***" => $self -> generate_admin_tabbar("periods"),
                                                                              "***body***"   => $body})

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
