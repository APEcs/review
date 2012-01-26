## @file
# This file contains the implementation of the config xml generator.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    9 January 2012
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
package XML::Config;

## @class XML::Config
# This class generates XML containing the config for the logged-in
# user's sort. The class looks at the currently logged-in user's cohort
# to determine which set of formfield values should be sent to the flashq
# application.
use strict;
use base qw(XML); # This class extends XML
use Logging qw(die_log);


## @method private $ build_formfields($userid)
# Build the list of form fields set for the cohort the specified user is in. This
# will attempt to look up the form fields set for the user's cohort, and return
# a string containing an xml representation of the fields in a form that
# flashq can understand.
#
# @param userid The ID of the user to obtain the fields for.
# @return A string containing the form fields to present to the user in flashq.
sub build_formfields {
    my $self   = shift;
    my $userid = shift;

    # Obtain the user's record, and hence the cohort id.
    my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($userid);
    return "" unless($user && $user -> {"cohort_id"});

    # Got the cohort, look up the fields for it...
    my $fieldh = $self -> {"dbh"} -> prepare("SELECT f.*
                                              FROM ".$self -> {"settings"} -> {"database"} -> {"cohort_fields"}." AS c,
                                                   ".$self -> {"settings"} -> {"database"} -> {"formfields"}." AS f
                                              WHERE f.id = c.field_id
                                              AND c.cohort_id = ?
                                              ORDER BY c.position");
    $fieldh -> execute($user -> {"cohort_id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform form field lookup query: ".$self -> {"dbh"} -> errstr);

    my $element = $self -> {"template"} -> load_template("xml/elem.tem");
    my $fields = "";
    while(my $field = $fieldh -> fetchrow_hashref()) {
        # Input fields may have labels and notes
        $fields .= $self -> {"template"} -> process_template($element, {"***elem***"    => "label",
                                                                        "***attrs***"   => "",
                                                                        "***content***" => $field -> {"label"} . ($field -> {"required"} ? "*" : "")})
            if($field -> {"label"});

        $fields .= $self -> {"template"} -> process_template($element, {"***elem***"    => "note",
                                                                        "***attrs***"   => "",
                                                                        "***content***" => $field -> {"note"}})
            if($field -> {"note"});

        # Build the attributes
        my $attrs = ' type="'.$field -> {"type"}.'" required="'.($field -> {"required"} ? "true" : "false").'"';
        $attrs .= ' restricted="'.$field -> {"restricted"}.'"' if(defined($field -> {"restricted"}));
        $attrs .= ' maxlength="'.$field -> {"maxlength"}.'"' if(defined($field -> {"maxlength"}));

        # And now the input
        $fields .= $self -> {"template"} -> process_template($element, {"***elem***"    => "input",
                                                                        "***attrs***"   => $attrs,
                                                                        "***content***" => $field -> {"value"}});
    }

    return $fields;
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;
    my $tree = "";

    # User must be logged in before we can do anything else
    if($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) {
        $tree = $self -> build_formfields($self -> {"session"} -> {"sessuser"});
    }

    print $self -> {"cgi"} -> header(-type => 'application/xml',
                                     -charset => 'utf-8');
    print Encode::encode_utf8($self -> {"template"} -> load_template("xml/config.tem", {"***formfields***"  => $tree,
                                                                                        "***negcol***"      => $self -> {"settings"} -> {"config"} -> {"XML::Config:negativeColour"},
                                                                                        "***neucol***"      => $self -> {"settings"} -> {"config"} -> {"XML::Config:neutralColour"},
                                                                                        "***poscol***"      => $self -> {"settings"} -> {"config"} -> {"XML::Config:positiveColour"},
                                                                     }));
    exit;
}

1;
