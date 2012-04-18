## @file
# This file contains the implementation of the admin form field management interface.
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
package Admin::Fields;

## @class Admin::Fields
# Implementation of the form field management interface. This code allows
# admin users to add, edit, and remove the fields in the form field pool.
use strict;
use base qw(Admin); # This class extends Admin
use MIME::Base64;               # Needed for base64 encoding of popup bodies.
use POSIX qw(ceil);
use Utils qw(is_defined_numeric);
use Data::Dumper;

# ============================================================================
#  General utility stuff.

## @method private $ can_modify_field($fieldid)
# Determine whether the user can modify the field specified. This will check
# whether any sorts have been performed that include the field specified,
# and if so it will return false. If no sorts have been performed using the
# field, this will return true.
#
# @param fieldid The field to check for sorts.
# @return 1 if the user can modify the field, 0 otherwise.
sub can_modify_field {
    my $self        = shift;
    my $fieldid = shift;

    # A query to determine whether a sort has happened with the specified field id.
    # Note the 'LIMIT 1' - it doesn't matter if there might be more than one row, as soon as
    # one is found we know the user can't modify the field!
    my $usedh = $self -> {"dbh"} -> prepare("SELECT s.id
                                             FROM ".$self -> {"settings"} -> {"database"} -> {"sorts"}." AS s,
                                                  ".$self -> {"settings"} -> {"database"} -> {"users"}." AS u,
                                                  ".$self -> {"settings"} -> {"database"} -> {"cohort_fields"}." AS cf
                                             WHERE cf.field_id = ?
                                             AND u.cohort_id = cf.cohort_id
                                             AND s.user_id = u.user_id
                                             LIMIT 1");
    $usedh -> execute($fieldid)
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform used field count query: ".$self -> {"dbh"} -> errstr);

    my $used = $usedh -> fetchrow_arrayref();
    return $used ? 0 : 1; # Theoretically !$used should work, but this is safer.
}


## @method private $ get_field_count()
# Count how many form fields are currently defined in the database.
#
# @return The number of defined form fields.
sub get_field_count {
    my $self = shift;

    my $counth = $self -> {"dbh"} -> prepare("SELECT COUNT(*) FROM ".$self -> {"settings"} -> {"database"} -> {"formfields"});
    $counth -> execute()
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform form field count query: ".$self -> {"dbh"} -> errstr);

    my $count = $counth -> fetchrow_arrayref();

    return $count ? $count -> [0] : 0;
}


## @method private @ get_page()
# Obtain the current page number for the form field table.
#
# @return An array of two values: the current page number, and the maximum page number.
sub get_page {
    my $self = shift;

    my $fieldcount = $self -> get_field_count();
    my $maxpage    = int($fieldcount / $self -> {"settings"} -> {"config"} -> {"Admin:page_length"});

    # Check for pagination and range.
    my $page = is_defined_numeric($self -> {"cgi"}, "page");
    $page    = 0 if(!defined($page) || $page < 0);
    $page    = $maxpage if($page > $maxpage);

    return ($page, $maxpage);
}


## @method private $ build_typelist($default)
# Obtain the list of select options the user may choose from to select the
# form field type. This returns a string containing the html options that
# should appear in the 'type' select box in the add/edit form.
#
# @param default Optional default selection for the type.
sub build_typelist {
    my $self    = shift;
    my $default = shift || "";

    # Which types do we support?
    my $values = $self -> get_enum_values($self -> {"settings"} -> {"database"} -> {"formfields"}, "type");
    $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), $values) unless(ref($values) eq "ARRAY");

    print STDERR "Values: ".Dumper($values);

    my $options = "";
    foreach my $type (@{$values}) {
        $options .= "<option value=\"$type\"";
        $options .= ' selected="selected"' if($default eq $type);
        $options .= ">$type</option>\n";
    }

    return $options;
}


# ============================================================================
#  Form field editing

## @method private $ get_editable_field()
# Pull the id of the field the user is attempting to edit from the query string,
# and determine whether or not it is ediable.
#
# @return A reference to a hash containing the field data if it is editable, an
#         error message otherwise.
sub get_editable_field {
    my $self = shift;

    # Get the field id
    my $fieldid = is_defined_numeric($self -> {"cgi"}, "id");
    $self -> log("admin edit", "Request modification of field ".($fieldid || "undefined"));
    return $self -> {"template"} -> replace_langvar("ADMIN_FIELD_ERR_NOID")
        unless($fieldid);

    # Is the field valid?
    my $fieldh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"formfields"}."
                                              WHERE id = ?");
    $fieldh -> execute($fieldid)
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform field lookup query: ".$self -> {"dbh"} -> errstr);

    my $field = $fieldh -> fetchrow_hashref();
    return $self -> {"template"} -> replace_langvar("ADMIN_FIELD_ERR_BADID")
        unless($field);

    # Is the field ediable?
    return $self -> {"template"} -> replace_langvar("ADMIN_FIELD_NOEDIT")
        unless($self -> can_modify_field($fieldid));

    return $field;
}


## @method private $ delete_field()
# Delete the field the user has selected from the database. This will check that
# the field is safe to delete before doing so.
#
# @return An error message on failure, undef on success.
sub delete_field {
    my $self = shift;

    # Is the field editable?
    my $field = $self -> get_editable_field();
    if(ref($field) ne "HASH") {
        $self -> log("admin edit", "Delete failed: $field");
        return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                      {"***message***" => $field});
    }

    # Yes; delete it
    my $nukeh = $self -> {"dbh"} -> prepare("DELETE FROM ".$self -> {"settings"} -> {"database"} -> {"formfields"}."
                                             WHERE id = ?");
    $nukeh -> execute($field -> {"id"})
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform field delete query: ".$self -> {"dbh"} -> errstr);

    $self -> log("admin edit", "Deleted field ".$field -> {"id"}." (".$field -> {"label"}.")");

    return undef;
}


## @method private $ build_admin_editfield($isadd, $args, $error)
# Construct the page containing the field edit/addition form. This will create
# the field addition or edit form, prepopulating the fields with the contents of
# the args hash if provided.
#
# @param isadd If true, this generates an addition form rather than edit form.
# @param args  A reference to a hash of values to set the form fields to.
# @param error An error box to show before the form.
# @return A string containing the field addition or edit form.
sub build_admin_editfield {
    my $self  = shift;
    my $isadd = shift;
    my $args  = shift;
    my $error = shift;

    # If we have an edit, but no args, fetch the selected field for editing
    if(!$isadd && !defined($args)) {
        $args = $self -> get_editable_field();
        return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                      {"***message***" => $args})
            unless(ref($args) eq "HASH");
    }

    # Avoid hash access warnings
    $args = {} if(!defined($args));

    my ($page, $maxpage) = $self -> get_page();

    return $self -> {"template"} -> load_template("admin/fields/".($isadd ? "add" : "edit").".tem",
                                                  {"***error***"      => $error,
                                                   "***id***"         => $args -> {"id"},
                                                   "***page***"       => $page,
                                                   "***label***"      => $args -> {"label"},
                                                   "***note***"       => $args -> {"note"},
                                                   "***value***"      => $args -> {"value"},
                                                   "***type***"       => $self -> build_typelist($args -> {"type"}),
                                                   "***required***"   => $args -> {"required"} ? ' checked="checked"': '',
                                                   "***maxlength***"  => $args -> {"maxlength"},
                                                   "***restricted***" => $args -> {"restricted"},
                                                   "***scale***"      => $args -> {"scale"},
                                                   "***help***"       => $self -> {"template"} -> load_template("popup.tem", {"***title***"   => $self -> {"template"} -> load_template("helpicon.tem"),
                                                                                                                              "***b64body***" => encode_base64($self -> {"template"} -> load_template("admin/fields/valuehelp.tem"))}),
                                                  });
}


## @method private @ validate_edit_field($isadd)
# Determine whether the value specified by the user in a field add/edit
# form are valid.
#
# @param isadd Set to true when called as part of an add process. Checks
#              that the field is valid and ediable are skipped if set.
# @return A reference to a hash of values submitted by the user, and a
#         string containing any error messages.
sub validate_edit_field {
    my $self  = shift;
    my $isadd = shift;
    my $args  = {};
    my ($error, $errors, $field);

    my $errtem = $self -> {"template"} -> load_template("error_entry.tem");

    # If this isn't an add, check that the field is valid and editable
    if(!$isadd) {
        $field = $self -> get_editable_field();
        return ($args, $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                              {"***message***" => $field}))
                unless(ref($field) eq "HASH");

        # Store the id for use later
        $args -> {"id"} = $field -> {"id"};
    }

    # Deal with the simple fields first - label and note are just straight validates
    ($args -> {"label"}, $error) = $self -> validate_string("label", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_FIELD_LABEL"),
                                                                      "required" => 1,
                                                                      "maxlen"   => 128});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    ($args -> {"note"}, $error) = $self -> validate_string("note", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_FIELD_NOTE"),
                                                                    "required" => 0,
                                                                    "maxlen"   => 255});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    ($args -> {"scale"}, $error) = $self -> validate_string("scale", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_FIELD_SCALE"),
                                                                      "required" => 0});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # Required is either set or not...
    $args -> {"required"} = $self -> {"cgi"} -> param("required") ? 1 : 0;

    # Just let restricted through as-is - trying to validate it would be insane,
    # and Flash should deal with pretty much anything in here for us anyway.
    ($args -> {"restricted"}, $error) = $self -> validate_string("restricted", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_FIELD_LIMIT"),
                                                                                "required" => 0,
                                                                                "maxlen"   => 80});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # Maximum length, if specified, must be numeric
    ($args -> {"maxlength"}, $error) = $self -> validate_string("maxlength", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_FIELD_LEN"),
                                                                              "required" => 0,
                                                                              "maxlen"   => 6,
                                                                              "formattest" => '^\d+$',
                                                                              "formatdesc" => $self -> {"template"} -> replace_langvar("ADMIN_ERR_ONLYDIGITS")
                                                                });
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # Check that type is valid...
    my $values = $self -> get_enum_values($self -> {"settings"} -> {"database"} -> {"formfields"}, "type");
    $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), $values) unless(ref($values) eq "ARRAY");

    ($args -> {"type"}, $error) = $self -> validate_options("type", {"nicename" => $self -> {"template"} -> replace_langvar("ADMIN_FIELD_TYPE"),
                                                                     "required" => 1,
                                                                     "source"   => $values });
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);


    return ($args, $errors);
}


## @method private $ add_field()
# Attempt to add a form field to the system form field pool.
#
# @return A string containing the page content to return to the user.
sub add_field {
    my $self = shift;

    # Determine whether the submission is valid
    my ($args, $errors) = $self -> validate_edit_field(1);

    # If there are any errors, report them and send the form back.
    return $self -> build_admin_fields(1, $args, $errors)
        if($errors);

    local $Data::Dumper::Terse = 1;
    $self -> log("admin edit", "Adding new field: ".Dumper($args));

    # No errors - do the insert...
    my $newh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"formfields"}."
                                            (label, note, type, value, scale, required, maxlength, restricted)
                                            VALUES(?, ?, ?, ?, ?, ?, ?, ?)");
    $newh -> execute($args -> {"label"},
                     $args -> {"note"}
                     $args -> {"type"},
                     $args -> {"value"},
                     $args -> {"scale"},
                     $args -> {"required"},
                     $args -> {"maxlength"},
                     $args -> {"restricted"})
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform field insert query: ".$self -> {"dbh"} -> errstr);

    return $self -> build_admin_fields($self -> {"template"} -> load_template("admin/fields/add_done.tem"));
}


# ============================================================================
#  Field listing

## @method private $ build_admin_fields($error)
# Generate the admin form field list page.
#
# @param error An error message to show at the top of the page.
# @return A string containing the field list page.
sub build_admin_fields {
    my $self   = shift;
    my $error  = shift;
    my $fields = "";

    # Need to know how many fields are defined.
    my ($page, $maxpage) = $self -> get_page();

    # Convert the page to a start offset.
    my $start = $page * $self -> {"settings"} -> {"config"} -> {"Admin:page_length"};

    # Now fetch the statements from the database. Can use LIMIT as no funky filtering is involved...
    my $fieldh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"formfields"}."
                                              ORDER BY `label` ASC
                                              LIMIT $start,".$self -> {"settings"} -> {"config"} -> {"Admin:page_length"});
    $fieldh -> execute()
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform form field lookup query: ".$self -> {"dbh"} -> errstr);

    # precache some templates needed later
    my $temcache = { "row"      => $self -> {"template"} -> load_template("admin/fields/row.tem"),
                     "doedit"   => [ $self -> {"template"} -> load_template("admin/fields/modify_off.tem"),
                                     $self -> {"template"} -> load_template("admin/fields/modify_on.tem", {"***page***" => $page}) ],
                     "required" => [ $self -> {"template"} -> load_template("admin/fields/required_off.tem"),
                                     $self -> {"template"} -> load_template("admin/fields/required_on.tem"), ]
    };

    while(my $field = $fieldh -> fetchrow_hashref()) {
        # Determine whether this statement can be edited/deleted.
        my $modify = $self -> can_modify_field($field -> {"id"});

        # Put a row together
        $fields .= $self -> {"template"} -> process_template($temcache -> {"row"}, {"***label***"     => $self -> {"template"} -> truncate_words($field -> {"label"}), #, $self -> {"settings"} -> {"config"} -> {"Admin::Fields:truncate_length"}),
                                                                                    "***labelfull***" => $field -> {"label"},
                                                                                    "***note***"      => $self -> {"template"} -> truncate_words($field -> {"note"}, $self -> {"settings"} -> {"config"} -> {"Admin::Fields:truncate_length"}),
                                                                                    "***notefull***"  => $field -> {"note"},
                                                                                    "***value***"     => $self -> {"template"} -> truncate_words($field -> {"value"}, $self -> {"settings"} -> {"config"} -> {"Admin::Fields:truncate_length"}),
                                                                                    "***valfull***"   => $field -> {"value"},
                                                                                    "***scale***"     => $self -> {"template"} -> truncate_words($field -> {"scale"}, $self -> {"settings"} -> {"config"} -> {"Admin::Fields:truncate_length"}),
                                                                                    "***scalefull***" => $field -> {"scale"},
                                                                                    "***type***"      => $field -> {"type"},
                                                                                    "***required***"  => $temcache -> {"required"} -> [$field -> {"required"}],
                                                                                    "***maxlen***"    => $field -> {"maxlength"},
                                                                                    "***limit***"     => $field -> {"restricted"},
                                                                                    "***ops***"       => $self -> {"template"} -> process_template($temcache -> {"doedit"} -> [$modify], {"***id***" => $field -> {"id"}}),
                                                              });
    }

    return $self -> {"template"} -> load_template("admin/fields/fields.tem", {"***paginate***" => $self -> build_pagination("fields", $maxpage, $page),
                                                                              "***fields***"   => $fields,
                                                                              "***error***"    => $error });
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
            if(defined($self -> {"cgi"} -> param("addfield"))) {
                $self -> log("admin edit", "Add field");
                $body = $self -> build_admin_editfield(1);

            } elsif(defined($self -> {"cgi"} -> param("doadd"))) {
                $self -> log("admin edit", "Do add field");
                $body = $self -> add_field();

            } elsif(defined($self -> {"cgi"} -> param("edit"))) {
                $self -> log("admin edit", "Edit field");
                $body = $self -> build_admin_editfield();

            } elsif(defined($self -> {"cgi"} -> param("doedit"))) {
                $self -> log("admin edit", "Do edit field");
                $body = $self -> edit_field();

            } elsif(defined($self -> {"cgi"} -> param("delete"))) {
                $self -> log("admin edit", "Delete field");
                $body = $self -> build_admin_fields($self -> delete_field());

            } else {
                $self -> log("admin view", "Fields");
                $body = $self -> build_admin_fields();
            }

            # Show the admin page
            $content = $self -> {"template"} -> load_template("admin/admin.tem", {"***tabbar***" => $self -> generate_admin_tabbar("fields"),
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
                                                               "***extrahead***" => '<link href="templates/default/admin/admin.css" rel="stylesheet" type="text/css" />',
                                                               "***content***"   => $content});

}

1;
