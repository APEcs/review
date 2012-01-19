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
package ReviewBlock;

## @class ReviewBlock
# The 'base' class for all Review blocks. This extends the standard
# webperl Block class with additional functions common to all Review
# UI and backend modules.
use strict;
use base qw(Block); # This class extends Block
use HTML::Entities;
use Logging qw(die_log);
use List::Util qw(max);
use MIME::Base64;   # Needed for base64 encoding of popup bodies.
use Utils qw(superchomp);

# ============================================================================
#  General utility stuff.

## @method $ truncate_words($data, $len)
# Truncate the specified string to the nearest word boundary less than the specified
# length. This will take a string and, if it is longer than the specified length
# (or the default length set in the settings, if the length is not given), it will truncate
# it to the nearest space, hyphen, or underscore less than the desired length. If the
# string is truncated, it will have an elipsis ('...') appended to it.
#
# @param data The string to truncate.
# @param len  Optional length in characters. If not specified, this will default to the
#             Core:truncate_length value set in the configuation. If the config value
#             is missing, this function does nothing.
# @return A string that fits into the specified length.
sub truncate_words {
    my $self = shift;
    my $data = shift;
    my $len  = shift || $self -> {"settings"} -> {"config"} -> {"Core:truncate_length"}; # fall back on the default if not set

    # return the string unmodified if it fits inside the truncation length (or one isn't set)
    return $data if(!defined($len) || length($data) <= $len);

    # make space for the elipsis
    $len -= 3;

    my $trunc = substr($data, 0, $len);
    $trunc =~ s/^(.{0,$len})[-_\s].*$/$1/;

    return $trunc."...";
}


## @fn $ fix_colour($colour)
# Remove any leading 0x or # from the specified hex colour string.
#
# @param colour The colour to remove the leading 0x or # from.
# @return The processed colour string.
sub fix_colour {
    my $colour = shift;

    $colour =~ s/^0x//;
    $colour =~ s/^#//;

    return $colour;
}

## @fn $ text_to_html($text, $nobrs)
# Convert the contents of the specified text to something that can be
# safely and sanely displayed in a html document. This will nuke *ANY*
# unsafe characters in the string, and convert newlines to br
# No formatting features are permitted or preserved - the output is
# free of html tags save br!
#
# @param text    The text to process.
# @param noparas If set, newlines are not converted to br
# @return The processed text in a form safe for inclusion in html.
sub text_to_html {
    my $text    = shift;
    my $noparas = shift;

    # First decode html entities in the text, and then re-encode them.
    # This avoid issues with double-encoding, and also ensures that all entities are done.
    $text = encode_entities(decode_entities($text));

    # Now paragraphise
    $text =~ s|\n|<br />\n|g unless($noparas);

    return $text;
}


## @method $ check_sort_permissions($sortid, $write)
# Determine whether the current session user has access to view the sort with the
# specified id. This will return an error message if the user does not have access,
# otherwise it will return a reference to the user data for *THE SORT OWNER*
#
# @param sortid The ID of the sort to check permissions for.
# @param write  If set, the user is attempting to update the sort.
# @return A reference to the sort user's data on success, an error message on failure.
sub check_sort_permissions {
    my $self   = shift;
    my $sortid = shift;
    my $write  = shift;

    # Get the sort header to ensure it exists, and we can security check against it
    my $sort = $self -> get_sort_byids($sortid, 0);
    return $sort unless(ref($sort) eq "HASH");

    # Get the user so that the cohort can be checked, and permissions can be verified
    my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($sort -> {"user_id"});
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $self -> {"template"} -> replace_langvar("SORTGRID_ERR_NOUSER",
                                                                                                               {"***userid***" => $sort -> {"userid"}})
                                                  })
        unless($user);

    # Get the session user so that permissions can be checked
    my $sessuser = $self -> {"session"} -> {"auth"} -> get_user_byid($self -> {"session"} -> {"sessuser"});
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $self -> {"template"} -> replace_langvar("SORTGRID_ERR_NOUSER",
                                                                                                               {"***userid***" => $self -> {"session"} -> {"sessuser"}})
                                                  })
        unless($sessuser);

    # Error the user doesn't match the sort, and the session user isn't an admin.
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $self -> {"template"} -> replace_langvar("SORTGRID_ERR_PERM",
                                                                                                               {"***userid***" => $sort -> {"userid"},
                                                                                                                "***sortid***" => $sortid})
                                                  })
        # Admin users can read, but not write. Sort owner may read and write
        unless((!$write && $sessuser -> {"user_type"} == 3) || $sort -> {"user_id"} == $sessuser -> {"user_id"});

    return $user;
}


# ============================================================================
#  Sort grid generation functions

## @method void _get_sort_data($sortid, $griddata)
# Pull the data for the 'sort' variable for the specified sortid into the grid.
# This does the work of pulling the 'sort' value from the database for the specified
# sort, parsing it into individual cell selections, and filling in the griddata
# with statements and data for each cell.
#
# @param sortid   The ID of the sort to load the data for.
# @param griddata A reference to a hash to store the sort data in.
sub _get_sort_data {
    my $self     = shift;
    my $sortid   = shift;
    my $griddata = shift;
    my @colours  = (fix_colour($self -> {"settings"} -> {"config"} -> {"XML::Config:negativeColour"}),
                    fix_colour($self -> {"settings"} -> {"config"} -> {"XML::Config:neutralColour"}),
                    fix_colour($self -> {"settings"} -> {"config"} -> {"XML::Config:positiveColour"}));

    # Get the sort data
    my $sorth = $self -> {"dbh"} -> prepare("SELECT value FROM ".$self -> {"settings"} -> {"database"} -> {"sortdata"}."
                                             WHERE name = 'sort'
                                             AND sort_id = ?");
    $sorth -> execute($sortid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort data lookup query: ".$self -> {"dbh"} -> errstr);

    my $sortrow = $sorth -> fetchrow_arrayref();

    # Need to be able to pull statements from the database
    my $statementh = $self -> {"dbh"} -> prepare("SELECT s.statement
                                                  FROM ".$self -> {"settings"} -> {"database"} -> {"statements"}." AS s,
                                                       ".$self -> {"settings"} -> {"database"} -> {"cohort_states"}." AS c
                                                  WHERE s.id = c.statement_id
                                                  AND c.id = ?");

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
                          "shorttext" => $self -> truncate_words($statement -> [0]),
                          "colour"    => $colours[$celldata[2] - 1],
                          "col"       => $col,
            };

            # store the field
            push(@{$griddata -> {$col} -> {"rows"}}, $field);

            # If this is the first or last column, store comment markers
            if($col == $griddata -> {"ranges"} -> {"mincol"} || $col == $griddata -> {"ranges"} -> {"maxcol"}) {
                $griddata -> {"comment"} -> {$celldata[0]} = $field;
                push(@{$griddata -> {$col} -> {"comments"}}, $field);
            }
        }
        ++$col;
    # process sort fields until we have dealt with them all, or run out of columns (the latter should not happen)
    } while($pos < scalar(@sortfields) && $col <= $griddata -> {"ranges"} -> {"maxcol"});
}


## @method void _get_sort_comments($sortid, $griddata)
# Extract the sort comments entered by the user from the database and store them
# in the specified grid.
#
# @param sortid   The ID of the sort to load the data for.
# @param griddata A reference to a hash to store the sort data in.
sub _get_sort_comments {
    my $self     = shift;
    my $sortid   = shift;
    my $griddata = shift;

    # Need a query to fetch the comments
    my $sorth = $self -> {"dbh"} -> prepare("SELECT value FROM ".$self -> {"settings"} -> {"database"} -> {"sortdata"}."
                                             WHERE name LIKE 'comment%'
                                             AND sort_id = ?");

    $sorth -> execute($sortid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform comment lookup query: ".$self -> {"dbh"} -> errstr);

    while(my $comment = $sorth -> fetchrow_arrayref()) {
        my ($id, $data) = $comment -> [0] =~ /^\(s(\d+)\)\s*(.*)$/;

        die_log($self -> {"cgi"} -> remote_host(), "FATAL: malformed comment data for sort $sortid: ".$comment -> [0])
            if(!$id);

        $griddata -> {"comment"} -> {$id} -> {"comment"} = $data;
    }
}


## @method void _get_sort_times($sortid, $griddata)
# Obtain the sort timings for the specified sort.
#
# @param sortid   The ID of the sort to load the data for.
# @param griddata A reference to a hash to store the sort timings in.
sub _get_sort_times {
    my $self     = shift;
    my $sortid   = shift;
    my $griddata = shift;

    my $sortheader = $self -> get_sort_byids($sortid);
    $griddata -> {"times"} -> {"sortdate"} = $sortheader -> {"sortdate"};
    $griddata -> {"times"} -> {"updated"}  = $sortheader -> {"updated"};

    # Query to fetch the durations
    my $timeh = $self -> {"dbh"} -> prepare("SELECT value FROM ".$self -> {"settings"} -> {"database"} -> {"sortdata"}."
                                             WHERE name = ?
                                             AND sort_id = ?");
    # The durations to fetch:
    my @durations = ("dur0", # Total time taken from start of stage 1 to immediately before submitting
                     "dur1", # Time spent on stage 1 (sorting into piles)
                     "dur2", # Time spent on stage 2 (sorting into grid)
                     "dur3", # Time spent on stage 3 (review grid placement)
                     "dur4", # Time spent on stage 4 (commentry form)
                     "dur5", # Time spent on stage 5 (details form)
                    );
    foreach my $dur (@durations) {
        $timeh -> execute($dur, $sortid)
            or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort data lookup query: ".$self -> {"dbh"} -> errstr);

        my $timer = $timeh -> fetchrow_arrayref();

        $griddata -> {"times"} -> {$dur} = $timer ? $timer -> [0] : "Unknown";
    }
}


## @method $ _build_sort_data($sortid, $cohortid)
# Store the sort data for the specified sort in the provided griddata hash. Note
# that this does not ensure that the current user has permission to access this
# sort - the caller must verify that this is the case!
#
# @param sortid   The ID of the sort to load the data for.
# @param cohortid The cohort the sort user is in.
# @return A reference to the sort data hash on success, otherwise an error message.
sub _build_sort_data {
    my $self     = shift;
    my $sortid   = shift;
    my $cohortid = shift;

    # pull in the map for the sort user's cohort
    my $maph = $self -> {"dbh"} -> prepare("SELECT m.*
                                            FROM ".$self -> {"settings"} -> {"database"} -> {"cohort_maps"}." AS c,
                                                 ".$self -> {"settings"} -> {"database"} -> {"maps"}." AS m
                                            WHERE m.id = c.map_id
                                            AND c.cohort_id = ?");
    $maph -> execute($cohortid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform map range lookup query: ".$self -> {"dbh"} -> errstr);

    my $griddata = { "ranges" => {} };
    while(my $maprow = $maph -> fetchrow_hashref()) {
        $griddata -> {$maprow -> {"flashq_id"}} = { "count"  => $maprow -> {"count"} };
        $griddata -> {$maprow -> {"flashq_id"}} -> {"rows"} = [ undef,
                                                                { "colour"    => $maprow -> {"colour"},
                                                                  "shorttext" => $maprow -> {"flashq_id"} },
                                                              ];

        # Work out the range of columns as the rows are processed
        $griddata -> {"ranges"} -> {"mincol"} = $maprow -> {"flashq_id"}
            if(!defined($griddata -> {"ranges"} -> {"mincol"}) || $maprow -> {"flashq_id"} < $griddata -> {"ranges"} -> {"mincol"});

        $griddata -> {"ranges"} -> {"maxcol"} = $maprow -> {"flashq_id"}
            if(!defined($griddata -> {"ranges"} -> {"maxcol"}) || $maprow -> {"flashq_id"} > $griddata -> {"ranges"} -> {"maxcol"});

        $griddata -> {"ranges"} -> {"maxrow"} = $maprow -> {"count"}
            if(!defined($griddata -> {"ranges"} -> {"maxrow"}) || $maprow -> {"count"} > $griddata -> {"ranges"} -> {"maxrow"});
    }

    # Bail if there is no map data
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $self -> {"template"} -> replace_langvar("SORTGRID_ERR_NOMAP",
                                                                                                               {"***cohortid***" => $cohortid})
                                                  })
        unless(scalar(keys(%{$griddata})));

    # Add the notes for the minimum and maximum columns
    $griddata -> {$griddata -> {"ranges"} -> {"mincol"}} -> {"rows"} -> [0] -> {"shorttext"} = $self -> {"template"} -> replace_langvar("SORTGRID_LEASTLIKE");
    $griddata -> {$griddata -> {"ranges"} -> {"maxcol"}} -> {"rows"} -> [0] -> {"shorttext"} = $self -> {"template"} -> replace_langvar("SORTGRID_MOSTLIKE");

    # Pull in the actual data
    $self -> _get_sort_data($sortid, $griddata);
    $self -> _get_sort_comments($sortid, $griddata);
    $self -> _get_sort_times($sortid, $griddata);

    return $griddata;
}


## @method $ _build_sort_grid($griddata)
# Generate the html representation of the sort contained in the specified grid
# data hash.
#
# @param griddata A reference to a hash containing the sort data to render as HTML.
# @return The sort grid string.
sub _build_sort_grid {
    my $self     = shift;
    my $griddata = shift;

    # Precache templates needed to build the table
    my $templates = { "label"  => { "set"   => $self -> {"template"} -> load_template("sort/label_set.tem"),
                                    "unset" => $self -> {"template"} -> load_template("sort/label_unset.tem") },
                      "header" => { "set"   => $self -> {"template"} -> load_template("sort/header_set.tem"),
                                    "unset" => $self -> {"template"} -> load_template("sort/header_unset.tem") },
                      "data"   => { "set"   => $self -> {"template"} -> load_template("sort/data_set.tem"),
                                    "unset" => $self -> {"template"} -> load_template("sort/data_unset.tem") },
                      "row"    => $self -> {"template"} -> load_template("sort/row.tem"),
    };

    # Now start building the table. Rows 0 and 1 are special (0 is the labels, 1 is the headers)
    # but we should be able to nicely handle that in one loop!
    my $sortrows = "";
    for(my $row = 0; $row <= ($griddata -> {"ranges"} -> {"maxrow"} + 1); ++$row) {
        my $sortcols = "";
        $sortrows .= $self -> {"template"} -> load_template("sort/emptyrow.tem") if($row == 2);

        for(my ($col, $tem) = ($griddata -> {"ranges"} -> {"mincol"}, ""); $col <= $griddata -> {"ranges"} -> {"maxcol"}; ++$col) {
            # Pick the template based on the row number (FIXME: Find a less sucky way to do this...)
            if($row == 0) {
                $tem = $templates -> {"label"} -> {defined($griddata -> {$col} -> {"rows"} -> [$row]) ? "set" : "unset"};
            } elsif($row == 1) {
                $tem = $templates -> {"header"} -> {defined($griddata -> {$col} -> {"rows"} -> [$row]) ? "set" : "unset"};
            } else {
                $tem = $templates -> {"data"} -> {defined($griddata -> {$col} -> {"rows"} -> [$row]) ? "set" : "unset"};
            }

            $sortcols .= $self -> {"template"} -> process_template($tem, {"***data***"     => $griddata -> {$col} -> {"rows"} -> [$row] -> {"shorttext"},
                                                                          "***fulldata***" => $griddata -> {$col} -> {"rows"} -> [$row] -> {"fulltext"},
                                                                          "***colour***"   => $griddata -> {$col} -> {"rows"} -> [$row] -> {"colour"},
                                                                   });
            print STDERR "sort row/col: $row/$col\n";

        }
        $sortrows .= $self -> {"template"} -> process_template($templates -> {"row"}, {"***cols***" => $sortcols})
            if($sortcols);
    }

    return $self -> {"template"} -> load_template("sort/table.tem", {"***rows***"       => $sortrows,
                                                                     "***cellwidth***"  => int(100 / (1 + ($griddata -> {"ranges"} -> {"maxcol"} - $griddata -> {"ranges"} -> {"mincol"})))."%",
                                                                     "***cellheight***" => "5em",
                                                  });
}


## @method $ _build_sort_comments($griddata)
# Generate the html representation of the sort comments contained in the specified grid
# data hash.
#
# @param griddata A reference to a hash containing the sort comments to render as HTML.
# @return The sort comment string.
sub _build_sort_comments {
    my $self     = shift;
    my $griddata = shift;
    my $rows     = "";

    # Work out how many comment rows there need to be
    my $count = max(scalar(@{$griddata -> {$griddata -> {"ranges"} -> {"mincol"}} -> {"comments"}}),
                    scalar(@{$griddata -> {$griddata -> {"ranges"} -> {"maxcol"}} -> {"comments"}}));

    # load the comment templates
    my $templates = { "data"   => { "set"   => $self -> {"template"} -> load_template("sort/comment_set.tem"),
                                    "unset" => $self -> {"template"} -> load_template("sort/comment_unset.tem") },
                      "row"    => $self -> {"template"} -> load_template("sort/comment_row.tem")
    };

    for(my $row = 0; $row < $count; ++$row) {
        my $neg = $griddata -> {$griddata -> {"ranges"} -> {"mincol"}} -> {"comments"} -> [$row] ? "set" : "unset";
        my $pos = $griddata -> {$griddata -> {"ranges"} -> {"maxcol"}} -> {"comments"} -> [$row] ? "set" : "unset";

        $rows .= $self -> {"template"} -> process_template($templates -> {"row"},
                                                           {"***negside***" => $self -> {"template"} -> process_template($templates -> {"data"} -> {$neg},
                                                                                                                         {"***fulldata***" => $griddata -> {$griddata -> {"ranges"} -> {"mincol"}} -> {"comments"} -> [$row] -> {"fulltext"},
                                                                                                                          "***colour***"   => $griddata -> {$griddata -> {"ranges"} -> {"mincol"}} -> {"comments"} -> [$row] -> {"colour"},
                                                                                                                          "***data***"     => $griddata -> {$griddata -> {"ranges"} -> {"mincol"}} -> {"comments"} -> [$row] -> {"shorttext"},
                                                                                                                          "***comment***"  => $griddata -> {$griddata -> {"ranges"} -> {"mincol"}} -> {"comments"} -> [$row] -> {"comment"}}),
                                                            "***posside***" => $self -> {"template"} -> process_template($templates -> {"data"} -> {$pos},
                                                                                                                         {"***fulldata***" => $griddata -> {$griddata -> {"ranges"} -> {"maxcol"}} -> {"comments"} -> [$row] -> {"fulltext"},
                                                                                                                          "***colour***"   => $griddata -> {$griddata -> {"ranges"} -> {"maxcol"}} -> {"comments"} -> [$row] -> {"colour"},
                                                                                                                          "***data***"     => $griddata -> {$griddata -> {"ranges"} -> {"maxcol"}} -> {"comments"} -> [$row] -> {"shorttext"},
                                                                                                                          "***comment***"  => $griddata -> {$griddata -> {"ranges"} -> {"maxcol"}} -> {"comments"} -> [$row] -> {"comment"}}),
                                                           });
        print STDERR "Comment row: $row\n";
    }

    return $self -> {"template"} -> load_template("sort/comment_table.tem", {"***negcol***" => $griddata -> {$griddata -> {"ranges"} -> {"mincol"}} -> {"rows"} -> [1] -> {"colour"},
                                                                             "***poscol***" => $griddata -> {$griddata -> {"ranges"} -> {"maxcol"}} -> {"rows"} -> [1] -> {"colour"},
                                                                             "***rows***"   => $rows, });
}


## @method $ _build_sort_times($griddata)
# Generate the html representation of the sort times contained in the specified grid
# data hash.
#
# @param griddata A reference to a hash containing the sort times to render as HTML.
# @return The sort times string.
sub _build_sort_times {
    my $self      = shift;
    my $griddata  = shift;
    my $stagelist = "";

    # Grab some templates..
    my $popuptem   = $self -> {"template"} -> load_template("popup.tem");
    my $stagetem   = $self -> {"template"} -> load_template("sort/stage.tem");
    my $dividertem = $self -> {"template"} -> load_template("sort/stagediv.tem");

    # Remove trailing whitespace
    superchomp($popuptem);
    superchomp($stagetem);

    # Stages...
    my @stages = ({"name"  => "dur1",
                   "title" => $self -> {"template"} -> replace_langvar("TIMES_STAGE1_TITLE"),
                   "desc"  => $self -> {"template"} -> replace_langvar("TIMES_STAGE1_DESC")},
                  {"name"  => "dur2",
                   "title" => $self -> {"template"} -> replace_langvar("TIMES_STAGE2_TITLE"),
                   "desc"  => $self -> {"template"} -> replace_langvar("TIMES_STAGE2_DESC")},
                  {"name"  => "dur3",
                   "title" => $self -> {"template"} -> replace_langvar("TIMES_STAGE3_TITLE"),
                   "desc"  => $self -> {"template"} -> replace_langvar("TIMES_STAGE3_DESC")},
                  {"name"  => "dur4",
                   "title" => $self -> {"template"} -> replace_langvar("TIMES_STAGE4_TITLE"),
                   "desc"  => $self -> {"template"} -> replace_langvar("TIMES_STAGE4_DESC")},
                  {"name"  => "dur5",
                   "title" => $self -> {"template"} -> replace_langvar("TIMES_STAGE5_TITLE"),
                   "desc"  => $self -> {"template"} -> replace_langvar("TIMES_STAGE5_DESC")},
        );
    foreach my $stage (@stages) {
        $stagelist .= $dividertem if($stagelist);

        $stagelist .= $self -> {"template"} -> process_template($stagetem, {"***time***"  => $self -> {"template"} -> humanise_seconds($griddata -> {"times"} -> {$stage -> {"name"}}),
                                                                            "***popup***" => $self -> {"template"} -> process_template($popuptem, {"***title***"   => $stage -> {"title"},
                                                                                                                                                   "***b64body***" => encode_base64($stage -> {"desc"})})});
    }

    return $self -> {"template"} -> load_template("sort/times.tem", {"***neucol***"    => fix_colour($self -> {"settings"} -> {"config"} -> {"XML::Config:neutralColour"}),
                                                                     "***sorttime***"  => $self -> {"template"} -> format_time($griddata -> {"times"} -> {"sortdate"}),
                                                                     "***updated***"   => $self -> {"template"} -> format_time($griddata -> {"times"} -> {"updated"}),
                                                                     "***totaltime***" => $self -> {"template"} -> humanise_seconds($griddata -> {"times"} -> {"dur0"}),
                                                                     "***stages***"    => $stagelist});
}


## @method $ build_sort_view($sortid)
# Generate the sort grid table for the specified sort id. This will ensure that the
# user has permission to view the sort (either the sort owner or an admin user)
# and then generates the table containing the user's sort data.
#
# @param sortid The ID of the sort to generate the table for.
# @return A string containing the sort, or an error message.
sub build_sort_view {
    my $self   = shift;
    my $sortid = shift;

    # Check the permissions, and fall over if we don't have permission to view the sort.
    my $sortuser = $self -> check_sort_permissions($sortid);
    return $sortuser unless(ref($sortuser) eq "HASH");

    # Pull in the user's sort data
    my $griddata = $self -> _build_sort_data($sortid, $sortuser -> {"cohort_id"});
    return $griddata unless(ref($griddata) eq "HASH");

    return $self -> {"template"} -> load_template("sort/view.tem", {"***sortgrid***"     => $self -> _build_sort_grid($griddata),
                                                                    "***sortcomments***" => $self -> _build_sort_comments($griddata),
                                                                    "***sorttimes***"    => $self -> _build_sort_times($griddata),
                                                  });
}


# ============================================================================
#  Sort summary generation functions

## @method $ build_sort_summaries($sortid, $firstonly)
# Generate the sort summary view list for the specified sortid.
#
# @param sortid    The id of the sort to generate the summary list for.
# @param firstonly Show only the first summary, and do not include edit features.
# @return The summary list html.
sub build_sort_summaries {
    my $self      = shift;
    my $sortid    = shift;
    my $firstonly = shift;

    # Check the permissions, and fall over if we don't have permission to view the sort.
    my $sortuser = $self -> check_sort_permissions($sortid);
    return $sortuser unless(ref($sortuser) eq "HASH");

    # Look up summaries for the specified sort
    my $summaryh = $self -> {"dbh"} -> prepare("SELECT id, summary, storetime
                                                FROM ".$self -> {"settings"} -> {"database"} -> {"summaries"}."
                                                WHERE sort_id = ?
                                                ORDER BY storetime DESC");
    $summaryh -> execute($sortid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort summary lookup query: ".$self -> {"dbh"} -> errstr);

    # Precache the entry templates for speed
    my $entrytem = $self -> {"template"} -> load_template("summary/entry.tem");
    my @titles   = ($self -> {"template"} -> load_template("summary/title_current.tem"),
                    $self -> {"template"} -> load_template("summary/title_previous.tem"));
    my @editopt  = ($self -> {"template"} -> load_template("summary/editopt_current_".($firstonly ? "noedit" : "edit").".tem"),
                    $self -> {"template"} -> load_template("summary/editopt_previous.tem"));
    my @printable = ("", " printhide");

    my $entries   = "";
    my $donefirst = 0;
    my $first     = {"date"      => $self -> {"template"} -> replace_langvar("SUMMARYLIST_NOTITLE"),
                     "printable" => $self -> {"template"} -> replace_langvar("SUMMARYLIST_NOSUM")};
    while(my $summary = $summaryh -> fetchrow_hashref()) {
        $entries .= $self -> {"template"} -> process_template($entrytem, {"***title***"     => $self -> {"template"} -> process_template($titles[$donefirst], {"***stored***" => $self -> {"template"} -> format_time($summary -> {"storetime"})}),
                                                                          "***summary***"   => text_to_html($summary -> {"summary"}),
                                                                          "***editopt***"   => $editopt[$donefirst],
                                                                          "***printable***" => $printable[$donefirst]});

        if(!$donefirst) {
            $first -> {"summary"}   = text_to_html($summary -> {"summary"}, 1);
            $first -> {"printable"} = text_to_html($summary -> {"summary"});
            $first -> {"date"}      = $self -> {"template"} -> process_template($titles[$donefirst], {"***stored***" => $self -> {"template"} -> format_time($summary -> {"storetime"})});
            $donefirst = 1;
            last if($firstonly);
        }
    }

    $entries = $self -> {"template"} -> load_template("summary/noentries_".($firstonly ? "noedit" : "edit").".tem")
        if(!$entries);

    return $self -> {"template"} -> load_template("summary/entries.tem", {"***summaries***"    => $entries,
                                                                          "***id***"           => $sortid,
                                                                          "***firstsummary***" => $first -> {"summary"},
                                                                          "***firstprint***"   => $first -> {"printable"},
                                                                          "***firstdate***"    => $first -> {"date"}});
}


# ============================================================================
#  Database interaction functions

## @method $ get_current_period($allow_sort)
# Obtain the data for the current time period as given in the sort_periods table.
# This will look in the sort_periods table for a period that the current day and
# time falls within, and if it finds one it will return a reference to a hash
# containing its data. If no appropriate sort period exists, this will return undef.
#
# @note If two or more sort periods overlap the current day and time, this will only
#       return the data for one of them. The period that gets returned is entirely
#       at the whim of the database - there is no guarantee of consistency or
#       sanity here. Long story short: don't define overlapping periods in the
#       sort_periods table!
#
# @param allow_sort Only return sort periods that allow users to perform sorts.
# @return A reference to a hash containing the sort period data, or undef if no
#         suitable sort period exists.
sub get_current_period {
    my $self       = shift;
    my $allow_sort = shift;

    my $periodh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"periods"}."
                                               WHERE startdate <= UNIX_TIMESTAMP()
                                               AND enddate >= UNIX_TIMESTAMP()
                                              ".($allow_sort ? "AND allow_sort = 1" : ""));
    $periodh -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform period lookup query: ".$self -> {"dbh"} -> errstr);

    return $periodh -> fetchrow_hashref();
}


## @method $ user_can_sort()
# Determine whether the owner of the current session is allowed to perform a sort.
# If the user is not allowed to, this will return an error message to that effect,
# otherwise it will return undef if they are allowed to sort.
#
# @return undef if the user can sort, an error message otherwise.
sub user_can_sort {
    my $self = shift;

    # Users must be logged in to sort
    return $self -> {"template"} -> replace_langvar("SORT_NOLOGIN")
        unless($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"});

    # The user is logged in and not anonymous, have they recorded a sort already? To work
    # this out, we need the current period...
    my $period = $self -> get_current_period(1);
    return $self -> {"template"} -> replace_langvar("SORT_NOPERIOD")
        if(!$period);

    # Has the user already submitted a sort for this period?
    my $sort = $self -> get_sort_data($self -> {"session"} -> {"sessuser"}, $period -> {"id"});

    return $self -> {"template"} -> replace_langvar("SORT_HAVEDONE")
        if($sort);

    # No sort, and sorts are allowed, so the user can do one..
    return undef;
}


## @method $ get_sort_data($userid, $periodid, $fullsort)
# Obtain the sort data submitted by the user during the specified period. Each user may perform a
# sort exactly once during any period, so this method can only return at most one sort of data.
#
# @param userid   The id of the user to fetch the sort dadta for.
# @param periodid The period during which the user should have performed the sort.
# @param fullsort If this is set, the full sort data is included in the returned hash, otherwise
#                 only the sort header (user, period, sort date and last update) will be returned.
# @return A reference to a hash containing the sort data, including a hash of sort answers,
#         justifications, survey answers, and an array of summary hashes if $fullsort is set.
sub get_sort_data {
    my $self     = shift;
    my $userid   = shift;
    my $periodid = shift;
    my $fullsort = shift;

    # Get the sort header first, this is pretty easy to pull...
    my $sorth = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"sorts"}."
                                             WHERE user_id = ?
                                             AND period_id = ?");
    $sorth -> execute($userid, $periodid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort lookup query: ".$self -> {"dbh"} -> errstr);

    # If there is no sort record for this user/period, or fullsort is not set, return whatever we got...
    my $sort = $sorth -> fetchrow_hashref();
    return $sort if(!$sort || !$fullsort); # order is important here!

    # fullsort is set, so the rest of the sort data needs to be loaded...
    my $datah = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"sortdata"}."
                                             WHERE sort_id = ?");
    $datah -> execute($sort -> {"id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort data lookup query: ".$self -> {"dbh"} -> errstr);

    # Copy any data we get into the sort hash
    while(my $data = $datah -> fetchrow_hashref()) {
        $sort -> {"data"} -> {$data -> {"name"}} = $data -> {"value"};
    }

    # now load the summaries, newest first
    my $summh = $self -> {"dbh"} -> prepare("SELECT summary, storetime FROM ".$self -> {"settings"} -> {"database"} -> {"summaries"}."
                                             WHERE sort_id = ?
                                             ORDER BY storetime DESC");
    $summh -> execute($sort -> {"id"})
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort summary lookup query: ".$self -> {"dbh"} -> errstr);

    # Fetch all the rows as an array of hashrefs...
    $sort -> {"summaries"} = $summh -> fetchall_arrayref({});

    # And done...
    return $sort;
}


## @method @ get_user_sorts($userid)
# Obtain a list of sort ids and timestamps for the specified user. This returns a
# reference to an array of hashes, one hash for each sort the user has performed.
# If the user has performed a sort during the current time period, the second value
# returned by this function is a hashref containing the id and timestamp of the
# current-period sort.
#
# @param userid The ID of the user to obtain sorts for.
# @return A reference to an array of hashes for each sort, ordered in reverse chronological
#         order, and either a reference to a hash for the current period sort, or undef if
#         the user has not done a sort during the current period.
sub get_user_sorts {
    my $self   = shift;
    my $userid = shift;

    my $sorth = $self -> {"dbh"} -> prepare("SELECT s.id, s.sortdate, s.updated, s.period_id, p.year, p.name
                                             FROM ".$self -> {"settings"} -> {"database"} -> {"sorts"}." AS s,
                                                  ".$self -> {"settings"} -> {"database"} -> {"periods"}." AS p
                                             WHERE s.user_id = ?
                                             AND p.id = s.period_id
                                             ORDER BY s.sortdate DESC");
    $sorth -> execute($userid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort lookup query: ".$self -> {"dbh"} -> errstr);

    # Query to get the number of summaries for a given sort
    my $counth = $self -> {"dbh"} -> prepare("SELECT COUNT(id) FROM ".$self -> {"settings"} -> {"database"} -> {"summaries"}."
                                              WHERE sort_id = ?");

    # Get the current period for reference ease...
    my $period = $self -> get_current_period();
    my $current;
    my @sorts;
    while(my $sort = $sorth -> fetchrow_hashref()) {
        # Work out the sort summary count for this sort
        $counth -> execute($sort -> {"id"})
            or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort summary count query: ".$self -> {"dbh"} -> errstr);

        my $count = $counth -> fetchrow_arrayref();
        $sort -> {"summary_count"} = $count ? $count -> [0] : 0;

        # If this is the current period sort, make sure it is recorded as such, then
        # store the sort reference in the sort array to send back to the caller.
        $current = $sort if($period && $period -> {"id"} == $sort -> {"period_id"});
        push(@sorts, $sort);
    }

    return (\@sorts, $current);
}


## @method $ get_sort_byids($sortid, $userid)
# Obtain the sort header for the specified sortid. If the userid is provided, this will
# only return the sort header if the sort exists and the provided userid is the owner
# of the sort. Note that, if the userid is not specified or is 0, this may be a potential
# security leak unless the caller checks the current user has access to the sort by other
# means.
#
# @param sortid The ID of the sort to fetch.
# @param userid The ID of the user performing the lookup.
# @return A reference to the sort header data on success, an error message on failure.
sub get_sort_byids {
    my $self   = shift;
    my $sortid = shift;
    my $userid = shift;

    my $sorth = $self -> {"dbh"} -> prepare("SELECT s.*, p.name, p.year
                                             FROM ".$self -> {"settings"} -> {"database"} -> {"sorts"}." AS s,
                                                  ".$self -> {"settings"} -> {"database"} -> {"periods"}." AS p
                                             WHERE s.period_id = p.id
                                             AND s.id = ?");
    $sorth -> execute($sortid)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort lookup query: ".$self -> {"dbh"} -> errstr);

    my $sort = $sorth -> fetchrow_hashref();

    # Error if there is no sort data.
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $self -> {"template"} -> replace_langvar("SORTGRID_ERR_NOSORT",
                                                                                                               {"***sortid***" => $sortid})
                                                  })
        if(!$sort);

    # Error if we have a user, but the user doesn't match the sort.
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $self -> {"template"} -> replace_langvar("SORTGRID_ERR_BADSORT",
                                                                                                               {"***userid***" => $userid,
                                                                                                                "***sortid***" => $sortid})
                                                  })
        unless(!$userid || $sort -> {"user_id"} == $userid);

    return $sort;
}


# ============================================================================
#  Content generation functions

## @method $ generate_topright()
# Generate the username/login/logout links at the top right of the page, based on
# whether the user has logged in yet or not.
#
# @return A string containing the content to show in the page top-right menu block.
sub generate_topright {
    my $self = shift;

    # Has the user logged in?
    if($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) {
        # We need the user's details
        my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($self -> {"session"} -> {"sessuser"});

        # Quick and dirty admin check, go...
        my $admin = "";
        $admin = $self -> {"template"} -> load_template("topright_admin.tem") if($user -> {"user_type"} == $self -> {"session"} -> {"auth"} -> {"ADMINTYPE"});

        return $self -> {"template"} -> load_template("topright_loggedin.tem", {"***user***"  => $user -> {"username"},
                                                                                "***admin***" => $admin});
    }

    # User hasn't logged in, return the basic login stuff
    return $self -> {"template"} -> load_template("topright_loggedout.tem");
}

1;
