## @file
# This file contains the implementation of the admin period checker.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    24 January 2012
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
package Admin::PeriodCheck;

## @class Admin::PeriodCheck
# Implementation of the sort period checker. This is a simple module
# that checks whether a user-specified date falls within an already
# defined period. The script requires the user to be logged in before
# it will return a useful value. The caller must also supply a 'time'
# value containing a unix timestamp to check against the period table.
# The caller may optionally provide an 'id' value, containing the id
# of the period being edited - if the user sets a date within the
# currently edited period, the system will accept it as valid.
use strict;
use base qw(Admin); # This class extends Admin
use Logging qw(die_log);
use Utils qw(is_defined_numeric);

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    my $content = $self -> {"template"} -> load_template("admin/periods/period_invalid.tem");

    # User must be logged in before we can do anything else
    if($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) {
        # Get the tiemstamp to check
        my $time = is_defined_numeric($self -> {"cgi"}, "time");
        my $id   = is_defined_numeric($self -> {"cgi"}, "id");

        if($time) {
            # Does the time fall within a defined period?
            my $period = $self -> get_period($time);

            # If we do not have period here, or the period matches the current edited one, the date does not clash
            $content = $self -> {"template"} -> load_template("admin/periods/period_valid.tem")
                if(!$period || $period -> {"id"} == $id);
        }
    }

    print $self -> {"cgi"} -> header(-charset => 'utf-8');
    print Encode::encode_utf8($content);

    exit;
}

1;
