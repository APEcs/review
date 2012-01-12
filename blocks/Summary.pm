## @file
# This file contains the implementation of the core review features.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    22 December 2011
# @copy    2011, Chris Page &lt;chris@starforge.co.uk&gt;
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
package ReviewCore;

## @class ReviewCore
# Implementation of the core functionality for the review webapp. This will show
# the user their list of past sorts, provide the option to start a new sort if it
# is available, and serve up the flashQ application page if appropriate.
use strict;
use base qw(ReviewBlock); # This class extends ReviewBlock
use Logging qw(die_log);


# ============================================================================
#  Content generation functions


sub build_sort_grid {
    my $self   = shift;
    my $userid = shift;
    my $sortid = shift;

    my @colours = ($self -> {"settings"} -> {"config"} -> {"XML::Config:negativeColour"},
                   $self -> {"settings"} -> {"config"} -> {"XML::Config:neutralColour"},
                   $self -> {"settings"} -> {"config"} -> {"XML::Config:positiveColour"});

    # First stage of grid construction is determining the user's cohort...
    my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($userid);
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $self -> {"template"} -> replace_langvar("SORTGRID_ERR_NOUSER",
                                                                                                               {"***userid***" => $userid})
                                                  })
        unless($user);

    # pull in the map for the cohort
    my $maph = $self -> {"dbh"} -> prepare("SELECT m.*
                                            FROM ".$self -> {"settings"} -> {"database"} -> {"cohort_maps"}." AS c,
                                                 ".$self -> {"settings"} -> {"database"} -> {"maps"}." AS m
                                            WHERE m.id = c.map_id
                                            AND c.cohort_id = ?");
    $maph -> execute($user -> {"cohort_id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform map range lookup query: ".$self -> {"dbh"} -> errstr);

    my $griddata = {};
    while(my $maprow = $maph -> fetchrow_hashref()) {
        $griddata -> {$maprow -> {"flashq_id"}} = { "colour" => $maprow -> {"colour"},
                                                    "count"  => $maprow -> {"count"} };
        $griddata -> {$maprow -> {"flashq_id"}} -> {"rows"} = [ "", $maprow -> {"flashq_id"} ];

        # Work out the range of columns as the rows are processed
        $griddata -> {"ranges"} -> {"mincol"} = $maprow -> {"flashq_id"}
            if(!defined($griddata -> {"ranges"} -> {"mincol"} || $maprow -> {"flashq_id"} < $griddata -> {"ranges"} -> {"mincol"}));

        $griddata -> {"ranges"} -> {"maxcol"} = $maprow -> {"flashq_id"}
            if(!defined($griddata -> {"ranges"} -> {"maxcol"} || $maprow -> {"flashq_id"} > $griddata -> {"ranges"} -> {"maxcol"}));

        $griddata -> {"ranges"} -> {"maxrow"} = $maprow -> {"count"}
            if(!defined($griddata -> {"ranges"} -> {"maxrow"} || $maprow -> {"count"} > $griddata -> {"ranges"} -> {"maxrow"}));
    }

    # Bail if there is no map data
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $self -> {"template"} -> replace_langvar("SORTGRID_ERR_NOMAP",
                                                                                                               {"***cohortid***" => $user -> {"cohort_id"}})
                                                  })
        unless(scalar(keys(%{$griddata})));

    # Add the notes for the minimum and maximum columns
    $griddata -> {$griddata -> {"ranges"} -> {"mincol"}} -> {"rows"} -> [0] = $self -> {"template"} -> replace_langvar("SORTGRID_LEASTLIKE");
    $griddata -> {$griddata -> {"ranges"} -> {"maxcol"}} -> {"rows"} -> [0] = $self -> {"template"} -> replace_langvar("SORTGRID_MOSTLIKE");

    # Now get the sort data
    my $sorth = $self -> {"dbh"} -> prepare("SELECT value FROM ".$self -> {"settings"} -> {"database"} -> {"sortdata"}."
                                             WHERE name = 'sort'
                                             AND sort_id = ?");
    $sorth -> execute($sortid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort data lookup query: ".$self -> {"dbh"} -> errstr);

    my $sortrow = $sorth -> fetchrow_arrayref();
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $self -> {"template"} -> replace_langvar("SORTGRID_ERR_NOSORT",
                                                                                                               {"***sortid***" => $sortid})
                                                  })
        unless($user);

    # Need to be able to pull statements from the database
    my $statementh = $self -> {"dbh"} -> prepare("SELECT statement FROM ".$self -> {"settings"} -> {"database"} -> {"statements"}."
                                                  WHERE id = ?");

    # "sort" contains data in the form 'statement id,column id,state|statement id,column id,state|...etc...'
    my @sortfields = split(/\|/, $sortrow -> [0]);
    my $pos = 0;
    my $col = $griddata -> {"ranges"} -> {"mincol"};
    do {
        for(my $row = 0; $row < $griddata -> {$col} -> {"count"}; ++$row, ++$pos) {
            my @celldata = split(/,/, $sortfields[$pos]);

            # Does the cell data column id match the current column?
            die_log($self -> {"cgi"} -> remote_host(), "FATAL: sort data column mismatch - expected $celldata[1] but got $col")
                unless($celldata[1] == $col);

            # Get the statement text
            $statementh -> execute($celldata[0])
                or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform statement lookup query: ".$self -> {"dbh"} -> errstr);

            my $statement = $statementh -> fetchrow_arrayref();
            die_log($self -> {"cgi"} -> remote_host(), "FATAL: Request for unknown statement $celldata[0]")
                unless($statement);

            my $field = { "fulltext"  => $statement -> [0],
                          "shorttext" => truncate_words($statement -> [0]),
                          "colour"    => $colours($celldata[2]),
            };

            # store the field
            push(@{$griddata -> {$col} -> {"rows"}}, $field);
        }
        ++$col;
    # process sort fields until we have dealt with them all, or run out of columns (the latter should not happen)
    } while($pos < scalar(@sortfields) && $col <= $griddata -> {"ranges"} -> {"maxcol"});




# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    # We need to determine what the page title should be, and the content to shove in it...
    my ($title, $content) = ($self -> {"template"} -> replace_langvar("PAGE_TITLE"), "");

    # User must be logged in before we can do anything else
    if($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) {
        my $sortid = is_defined_numeric($self -> {"cgi"}, "sortid");

        # Excessive logging enabled? If so, log the user viewing this...
        $self -> log("view", "Summary view, sortid = ".($sortid || "undefined")) if($self -> {"settings"} -> {"config"} -> {"Log:all_the_things"});

        $content = $self -> {"template"} -> load_template("blocks/summaryview.tem", {"***sortgrid***" => $self -> build_sort_grid($self -> {"session"} -> {"sessuser"}, $sortid),
                                                          });

    # User has not logged in, force them to
    } else {
        my $url = "index.cgi?block=login&amp;back=".$self -> {"session"} -> encode_querystring($self -> {"cgi"} -> query_string());

        print $self -> {"cgi"} -> redirect($url);
        exit;
    }

    # Done generating the page content, return the filled in page template
    return $self -> {"template"} -> load_template("page.tem", {"***title***"     => $title,
                                                               "***topright***"  => $self -> generate_topright(),
                                                               "***extrahead***" => "",
                                                               "***content***"   => $content});

}

1;
