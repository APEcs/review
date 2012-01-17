## @file
# This file contains the implementation of the summary view features.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    12 January 2012
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
package Summary;

## @class Summary
# Implementation of the summary view functionality for the review webapp. This
# displays the selected sort (if the logged in user matches the id of the user
# that did the sort), and allows the user to update the reflective summary for it.
use strict;
use base qw(ReviewBlock); # This class extends ReviewBlock
use Logging qw(die_log);
use Utils qw(is_defined_numeric);

## @method $ build_summary_view($sortid)
# Generate the summary view for the specified sortid, or an error if the user
# requesting the view is not logged in or is not the user who did the sort.
#
# @param sortid The ID of the sort to show.
# @return The summary view, or an error message.
sub build_summary_view {
    my $self   = shift;
    my $sortid = shift;

    # Obtain the logged-in user's record
    my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($self -> {"session"} -> {"sessuser"});
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $self -> {"template"} -> replace_langvar("SORTGRID_ERR_NOUSER",
                                                                                                               {"***userid***" => $self -> {"session"} -> {"sessuser"}})
                                                  })
        unless($user);

    # Obtain the sort data
    my $sort = $self -> get_sort_byids($sortid, $user -> {"id"});
    return $sort unless(ref($sort) eq "HASH");

    # Try to store the summary if there is one.
    my $storeerr;
    $storeerr = $self -> store_summary($sortid) if($self -> {"cgi"} -> param("summarytext"));

    return $self -> {"template"} -> load_template("blocks/summaryview.tem", {"***user***"      => $user -> {"username"},
                                                                             "***period***"    => $sort -> {"name"},
                                                                             "***year***"      => $sort -> {"year"},
                                                                             "***error***"     => $storeerr,
                                                                             "***sortgrid***"  => $self -> build_sort_view($sortid),
                                                                             "***summaries***" => $self -> build_sort_summaries($sortid),
                                                  });
}


## @method $ store_summary($sortid)
# Store the summary submitted by the user, if present, for the specified
# sortid.
#
sub store_summary {
    my $self   = shift;
    my $sortid = shift;

    # Obtain the summary text
    my ($summary, $errs) = $self -> validate_string("summarytext", {"nicename" => $self -> {"template"} -> replace_langvar("SUMMARYLIST_TITLE"),
                                                                    "default"  => ""});
    return $self -> {"template"} -> load_template("blocks/error_box.tem",
                                                  {"***message***" => $errs })
        if($errs);

    # Do nothing if there is no summary
    return undef if(!$summary);

    # Check that the user has permission to modify the sort
    my $sortuser = $self -> check_sort_permissions($sortid, 1);
    return $sortuser unless(ref($sortuser) eq "HASH");

    $self -> log("edit", "Summary edit, sortid = ".($sortid || "undefined")) if($self -> {"settings"} -> {"config"} -> {"Log:all_the_things"});

    # Sort update granted, push the new update into the database
    my $summaryh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"summaries"}."
                                                (sort_id, summary, storetime)
                                                VALUES(?, ?, UNIx_TIMESTAMP())");
    $summaryh -> execute($sortid, $summary)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to perform sort summary insert query: ".$self -> {"dbh"} -> errstr);
}

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

        $content = $self -> build_summary_view($sortid);

    # User has not logged in, force them to
    } else {
        my $url = "index.cgi?block=login&amp;back=".$self -> {"session"} -> encode_querystring($self -> {"cgi"} -> query_string());

        print $self -> {"cgi"} -> redirect($url);
        exit;
    }

    # Done generating the page content, return the filled in page template
    return $self -> {"template"} -> load_template("page.tem", {"***title***"     => $title,
                                                               "***topright***"  => $self -> generate_topright(),
                                                               "***extrahead***" => $self -> {"template"} -> load_template("summary/lightface.tem"),
                                                               "***content***"   => $content});

}

1;
