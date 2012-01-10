/* Based on code from http://davidwalsh.name/mootools-zebra-table-plugin 
 * Requires mootools core 1.2
 *
 * Removed colourisation on intitalise, zebraTables.zebraize() must be called 
 * when the DOM is ready. Added code to remove css classes and events in
 * zebraize() so that it can safely be called repeatedly.
 */
var ZebraTable = new Class(
{
    //implements
    Implements: [Options,Events],
    
    // options
    options: 
    {
        cssZebra: 'zebra',
        cssEven: 'alt1',
        cssOdd: 'alt2',
        cssHead: 'alth',
        cssMouseEnter: 'hover'
    },
    
    // initialization
    initialize: function(options) 
    {
        //set options
        this.setOptions(options);
    },
    
    // colourise table rows with alternating colours.
    zebraize: function(table) {
        var pos = 0;

        // for every row in this table...
        table.getElements('tr').each(function(tr,i) {
            var options = this.options;
           
            var hasheader = false;
            var elem = tr.getFirst();
            while(elem && !hasheader) {
                hasheader = elem.get('tag') == 'th';
                elem = elem.getNext();
            }

            // check to see if the row has th's, or it's invisible, if so, leave it alone
            if(!hasheader && tr.style.display != 'none') {
                // We might not know which class we have (if any), so check for either
                if(tr.hasClass(options.cssEven)) {
                    tr.removeClass(options.cssEven);
                } else if(tr.hasClass(options.cssOdd)) {
                    tr.removeClass(options.cssOdd);
                }

                // This is rather harsh, but provided the only events get added in zebraize()
                // it should be safe enough…
                tr.removeEvents();

                // set the class for this based on odd/even
                var klass = ++pos % 2 ? options.cssEven : options.cssOdd;
                
                // start the events!
                tr.addClass(klass).addEvents({
                    //mouseenter
                    mouseenter: function () {
                         if(!tr.hasClass(options.cssHighlight)) tr.addClass(options.cssMouseEnter).removeClass(klass);
                    },
                    //mouseleave
                    mouseleave: function () {
                        if(!tr.hasClass(options.cssHighlight)) tr.removeClass(options.cssMouseEnter).addClass(klass);
                    },
                });
            } else if(hasheader  && tr.style.display != 'none') {
                if(!tr.hasClass(options.cssHead)) {
                    tr.addClass(options.cssHead);
                }
            }

            // We want to forcibly make eveything have the zebra class no matter what it is
            if(!tr.hasClass(options.cssZebra)) {
                tr.addClass(options.cssZebra);

                // Process the children to ensure they are all marked
                var child = tr.getFirst();
                while(child) {
                    // If the child is a header or data cell with no zebra class, add it.
                    if(!child.hasClass(options.cssZebra) && (child.get('tag') == 'th' || child.get('tag') == 'td')) {
                        child.addClass(options.cssZebra);
                    }
                    // And interate!
                    child = child.getNext();
                }
            }
                
        },this);
    }
});

// Convert all tables with the zebra class into coloured zebra tables.
function doZebra() 
{
    var zebTable = new ZebraTable();

    $$('table.zebra').each(function(element,index) {
        zebTable.zebraize(element);
    });
}

// When the dom is ready to process, do it.
window.addEvent('domready', function() { 
        doZebra();
    });
