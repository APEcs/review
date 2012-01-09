## @file
# This file contains the implementation of the FlashQ view form.
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
package FlashQ;

## @class FlashQ
# This class implements the FlashQ page generation feature for the
# review webapp.
use strict;
use base qw(ReviewBlock); # This class extends ReviewBlock
use Logging qw(die_log);

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
        $self -> log("view", "FlashQ view") if($self -> {"settings"} -> {"config"} -> {"Log:all_the_things"});

        # Can the user sort?
        my $sorterr = $self -> user_can_sort();
        if(!$sorterr) {
            $self -> log("view", "FlashQ view allowed") if($self -> {"settings"} -> {"config"} -> {"Log:all_the_things"});

            $content = $self -> {"template"} -> load_template("blocks/sort_page.tem");

        # User can't sort, punt them to an error.
        } else {
            $self -> log("view", "FlashQ view failed: $sorterr") if($self -> {"settings"} -> {"config"} -> {"Log:all_the_things"});

            $content = $self -> {"template"} -> load_template("blocks/sort_error.tem", {"***message***" => $sorterr});
        }
    # User has not logged in, force them to
    } else {
        my $url = "index.cgi?block=login&amp;back=".$self -> {"session"} -> encode_querystring($self -> {"cgi"} -> query_string());

        print $self -> {"cgi"} -> redirect($url);
        exit;
    }

    # Done generating the page content, return the filled in page template
    return $self -> {"template"} -> load_template("page_nofooter.tem", {"***title***"     => $title,
                                                                        "***topright***"  => $self -> generate_topright(),
                                                                        "***extrahead***" => "",
                                                                        "***content***"   => $content});
}

1;
