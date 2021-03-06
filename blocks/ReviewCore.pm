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

# ============================================================================
#  Content generation functions

## @method private $ build_sort_list()
# Generate a list of sorts the current user has performed, with links to view the
# sort and edit the sort summary text.
#
# @return The page block containing the sort list.
sub build_sort_list {
    my $self     = shift;
    my $sortlist = "";
    my $compare  = "";

    # Fetch the list of sorts to process into html...
    my ($sorts, $current) = $self -> get_user_sorts($self -> {"session"} -> {"sessuser"});

    # If there are no sorts, fall back on the "no sorts done" message
    if(!$sorts || !scalar(@{$sorts})) {
        $sortlist = $self -> {"template"} -> load_template("blocks/sort_history_noentries.tem");

    # Otherwise, process the sorts
    } else {
        my $sorttem = $self -> {"template"} -> load_template("blocks/sort_history_entry.tem");

        foreach my $sort (@{$sorts}) {
            # Precalculate some fiddlier things before processing the template
            my $isactive   = $current && ($current -> {"id"} == $sort -> {"id"});
            my $hassummary = $self -> {"template"} -> replace_langvar($sort -> {"summary_count"} ? "SORTHIST_GOTSUMMARY" : "SORTHIST_NOSUMMARY");
            my $title      = $self -> {"template"} -> replace_langvar($isactive ? "SORTHIST_CURRENT" : "SORTHIST_PAST");

            # Dumb append, this should just be a series of consecutive entries anyway
            $sortlist .= $self -> {"template"} -> process_template($sorttem, {"***id***"          => $sort -> {"id"},
                                                                              "***state***"       => $isactive ? "active" : "inactive",
                                                                              "***name***"        => $sort -> {"name"},
                                                                              "***year***"        => $sort -> {"year"},
                                                                              "***taken***"       => $self -> {"template"} -> format_time($sort -> {"sortdate"}),
                                                                              "***updated***"     => $self -> {"template"} -> format_time($sort -> {"updated"}),
                                                                              "***hassummary***"  => $hassummary,
                                                                              "***summaryicon***" => $sort -> {"summary_count"} ? "tick" : "warn",
                                                                              "***title***"       => $title});
        }

        $compare = $self -> {"template"} -> load_template("blocks/sort_history_compare.tem");
    }

    return $self -> {"template"} -> load_template("blocks/sort_history.tem", {"***sorthist***" => $sortlist,
                                                                              "***compare***"  => $compare});
}


## @method private $ build_sort_option()
# Create the sort option box to send back to the user. This will put together the
# sort status message and form based on the user's ability to perform a sort in the
# current period. If the user can not sort, this returns a block stating that and
# the reason, if the user can sort this returns a "do sort" form.
#
# @return The page block containing the sort message and form.
sub build_sort_option {
    my $self = shift;

    my $cansort = $self -> user_can_sort();
    my $message = $self -> {"template"} -> load_template($cansort ? "blocks/sort_option_disabled.tem" : "blocks/sort_option_enabled.tem",
                                                         { "***reason***" => $cansort });
    my $form    = $cansort ? "" : $self -> {"template"} -> load_template("blocks/sort_option_form.tem");

    return $self -> {"template"} -> load_template("blocks/sort_option.tem", {"***sortmsg***"  => $message,
                                                                             "***sortform***" => $form});
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
        # Excessive logging enabled? If so, log the user viewing this...
        $self -> log("view", "Sort history") if($self -> {"settings"} -> {"config"} -> {"Log:all_the_things"});

        $content = $self -> {"template"} -> load_template("blocks/core.tem", {"***sorthist***" => $self -> build_sort_list(),
                                                                              "***takesort***" => $self -> build_sort_option(),
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
