## @file
# This file contains the implementation of the statements xml generator.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    6 January 2012
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
package XML::Statements;

## @class XML::Statements
# This class generates XML containing the statements for the logged-in
# user's sort. The class looks at the currently logged-in user's cohort
# to determine which set of statements should be sent to the flashq
# application.
use strict;
use base qw(XML); # This class extends XML
use Logging qw(die_log);


## @method $ build_statement_tree($userid)
# Build the list of statements set for the cohort the specified user is in. This
# will attempt to look up the statements set for the user's cohort, and return
# a string containing an xml representation of those statements in a form that
# flashq can understand.
#
# @param userid The ID of the user to obtain the statements for.
# @return A string containing the statements to present to the user in flashq.
sub build_statement_tree {
    my $self   = shift;
    my $userid = shift;

    my $element = $self -> {"template"} -> load_template("xml/elem.tem");

    # Obtain the user's record, and hence the cohort id.
    my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($userid);
    return $self -> {"template"} -> process_template($element, {"***elem***"    => "statement",
                                                                "***attrs***"   => ' id="1"',
                                                                "***content***" => $self -> {"template"} -> replace_langvar("XML_BADUSER")})
        if(!$user);

    return $self -> {"template"} -> process_template($element, {"***elem***"    => "statement",
                                                                "***attrs***"   => ' id="1"',
                                                                "***content***" => $self -> {"template"} -> replace_langvar("XML_BADCOHORT")})
        if(!$user -> {"cohort_id"});

    # Got the cohort, look up the statements for it...
    my $statementh = $self -> {"dbh"} -> prepare("SELECT c.id, s.statement
                                                  FROM ".$self -> {"settings"} -> {"database"} -> {"cohort_states"}." AS c,
                                                       ".$self -> {"settings"} -> {"database"} -> {"statements"}." AS s
                                                  WHERE s.id = c.statement_id
                                                  AND c.cohort_id = ?");
    $statementh -> execute($user -> {"cohort_id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to statement lookup query: ".$self -> {"dbh"} -> errstr);

    my $tree = "";
    while(my $statement = $statementh -> fetchrow_arrayref()) {
        $tree .= $self -> {"template"} -> process_template($element, { "***elem***"    => "statement",
                                                                       "***attrs***"   => ' id="'.$statement -> [0].'"',
                                                                       "***content***" => $statement -> [1] });
    }

    # Handle the situation where there are no statements defined
    $tree = $self -> {"template"} -> process_template($element, {"***elem***"    => "statement",
                                                                "***attrs***"   => ' id="1"',
                                                                "***content***" => $self -> {"template"} -> replace_langvar("XML_NOSTATEMENTS")})
        if(!$tree);

    return $tree;
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
        $tree = $self -> build_statement_tree($self -> {"session"} -> {"sessuser"});

    # User has not logged in, send back a single element with "Not logged in" in it
    } else {
        $tree = $self -> {"template"} -> load_template("xml/elem.tem", {"***elem***"    => "statement",
                                                                        "***attrs***"   => ' id="1"',
                                                                        "***content***" => $self -> {"template"} -> replace_langvar("XML_NOLOGIN")});
    }

    print $self -> {"cgi"} -> header(-type => 'application/xml',
                                     -charset => 'utf-8');
    print Encode::encode_utf8($self -> {"template"} -> load_template("xml/xml.tem", {"***base***"  => "statements",
                                                                                     "***attrs***" => ' version="1.0" htmlParse="false"',
                                                                                     "***tree***"  => $tree}));
    exit;
}

1;
