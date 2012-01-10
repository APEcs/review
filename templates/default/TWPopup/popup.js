/* Script: popup.js
 *  
 *  A class to create popups in a document, relative to another element with a user-
 *  controllable offset and configurable show and hide delays and effects.
 *
 *  Requires mootools-core (developed for 1.2.3), does not need -more
 *
 *  Copyright (C) 2009 Chris Page <chris@starforge.co.uk>
 *  This work is licensed under the Creative Commons Attribution-Share Alike 2.0
 *  License. To view a copy of this license, visit
 *  http://creativecommons.org/licenses/by/2.0/ or send a letter to Creative
 *  Commons, 171 Second Street, Suite 300, San Francisco, California, 94105, USA.
 *
 *  This software is provided 'as is', without any warranty of merchantabilty
 *  or fitness for a particular purpose. You may use this code in your project
 *  provided that this copyright notice is retained, and attribution is given in the
 *  resulting program credits.
 *
 */
var Popup = new Class({

    Implements: [Events, Options],

    options: {
        onShow: function(popup){
            // uses the long version of fading in, as fade('in')
            // may not work properly on initial load. NFC why this is.
            // popup.get('tween').start('opacity', 0, 1);
            popup.fade('in');
        },
        onHide: function(popup){
            //popup.get('tween').start('opacity', 1, 0);
            popup.fade('out');
        },
        showDelay: 100,
        hideDelay: 100,
        relativeTo: null,
        hoverElem: null,
        haltElem: null,
        system: null,
        offset: {x: 16, y: 16},
    },

    initialize: function(element, options) {
        this.setOptions(options);
        
        var core = this.options.coreElem;
        
        // Work out what the element is relative to
        if(this.options.relativeTo == null) this.options.relativeTo = element;

        // Make sure that there's an element to add the events to
        if(this.options.hoverElem == null) this.options.hoverElem = element;

        // Maybe have a halt element too?
        if(this.options.haltElem == null) this.options.haltElem = $(document.body);

        // create the popup and ensure the timer is clear
        this.options.popup = this.createPopup(core);
        this.timer = $clear(this.timer);

        // Add the new div to the document
        this.options.haltElem.grab(this.options.popup, 'after');

        core.dispose();

        // This acts as a means of ensuring that the fade out
        // can not happen until the fade in has at least started.
        this.needfade = false;
    },

    createPopup: function(element) {
        // First we want a copy of all the contents of the div
        var contents = Base64.decode(element.get('html'));

        // We need a new div...
        element = new Element('div', {'class': 'twpopup'});

        // work out the core name
        var corename = 'twpopup-core';
        if(this.options.system) {
            corename += "-sys";
        }

        // Add in the contents inside a popup...
        element.adopt(
            new Element('div', {'class': 'twpopup-header'}).adopt(new Element('div', {'class': 'twpopup-corner'}),
                                                                  new Element('div', {'class': 'twpopup-bar'})),
            new Element('div', {'class': 'twpopup-body'  }).adopt(new Element('div', {'class': corename, 'html': contents}),
                                                                  new Element('div', {'class': 'twpopup-bar'})),
            new Element('div', {'class': 'twpopup-footer'}).adopt(new Element('div', {'class': 'twpopup-corner'}),
                                                                  new Element('div', {'class': 'twpopup-bar'}))
        );

        // Attach events for mouse enter and leave.
        var events = ['enter', 'leave'];
        events.each(function(value) {
            this.options.hoverElem.addEvent('mouse' + value, this['anchor' + value.capitalize()].bindWithEvent(this, element));
            element.addEvent('mouse' + value, this['popup' + value.capitalize()].bindWithEvent(this, element));
        }, this);
       
        var relCoords = this.getRelativePos(this.options.relativeTo, 'left', 'bottom');
        var popupPos  = { left: relCoords['x'] + this.options.offset['x'],
                           top: relCoords['y'] + this.options.offset['y'] };
        
        this.setPopupPos(element, popupPos);

        return element;
    },


    anchorEnter: function(event, element){
        var relCoords = this.getRelativePos(this.options.relativeTo, 'left', 'bottom');
        var popupPos  = { left: relCoords['x'] + this.options.offset['x'],
                           top: relCoords['y'] + this.options.offset['y'] };

        this.setPopupPos(this.options.popup, popupPos);

        this.timer = $clear(this.timer);
        this.timer = this.show.delay(this.options.showDelay, this, element);
    },

    anchorLeave: function(event, element){
        $clear(this.timer);
        this.timer = this.hide.delay(this.options.hideDelay, this, element);
    },


    popupEnter: function(event, element) {
        this.timer = $clear(this.timer);
        if(!this.needfade) {
            this.timer = this.show.delay(this.options.showDelay, this, element);
        }
    },

    popupLeave: function(event, element) {
        $clear(this.timer);
        if(this.needfade) {
            this.timer = this.hide.delay(this.options.hideDelay, this, element);
        }
    },

    show: function(element) {
        if(!this.needfade) {
            this.needfade = true;
            this.fireEvent('show', [this.options.popup, element]);
        }
    },

    hide: function(element) {
        if(this.needfade) {
            this.fireEvent('hide', [this.options.popup, element]);
            this.needfade = false;
        }
    },

    getRelativePos: function(element, xhandle, yhandle) {
        var obj = element;

        var curleft = 0;
        var curtop = 0;
        // Work out the top left corner of the specified element.
        // Note that we need to stop the search at the first absolute 
        // position element encountered, as coords for left and top will
        // be relative to that element!
        while(obj.offsetParent && obj.getStyle('position') != 'absolute') {// &&  obj != this.options.haltElem) {
            curleft += obj.offsetLeft;
            curtop  += obj.offsetTop;
            obj = obj.offsetParent;
        }

        // If the x handle is set to something other than 'left', deal with it
        if(xhandle == 'right') {
            curleft += element.getSize().x;
        } else if(xhandle == 'center') {
            curleft += parseInt(element.getSize().x / 2);
        }

        // Now do the same for the y
        if(yhandle == 'bottom') {
            curtop += element.getSize().y;
        } else if(yhandle == 'center') {
            curtop += parseInt(element.getSize().y / 2);
        }

        return { x: curleft, y: curtop }
    },

    // Sourced from:
    // http://www.geekdaily.net/2007/07/04/javascript-cross-browser-window-size-and-centering/
    windowSize: function () {
        var w = 0;
        var h = 0;

        //IE
        if(!window.innerWidth) {
            //strict mode
            if(!(document.documentElement.clientWidth == 0)) {
                w = document.documentElement.clientWidth;
                h = document.documentElement.clientHeight;
            
            //quirks mode
            } else {
                w = document.body.clientWidth;
                h = document.body.clientHeight;
            }
        //w3c
        } else {
            w = window.innerWidth;
            h = window.innerHeight;
        }

        // Adjust for scrollbar
        w -= this.getScrollBarWidth();

        return {width: w , height: h};
    },

    // Sourced from:
    // http://www.alexandre-gomes.com/?p=115
    getScrollBarWidth: function () {
        var inner = document.createElement('p');
        inner.style.width = "100%";
        inner.style.height = "200px";

        var outer = document.createElement('div');
        outer.style.position = "absolute";
        outer.style.top = "0px";
        outer.style.left = "0px";
        outer.style.visibility = "hidden";
        outer.style.width = "200px";
        outer.style.height = "150px";
        outer.style.overflow = "hidden";
        outer.appendChild (inner);

        document.body.appendChild (outer);
        var w1 = inner.offsetWidth;
        outer.style.overflow = 'scroll';
        var w2 = inner.offsetWidth;
        if (w1 == w2) w2 = outer.clientWidth;

        document.body.removeChild (outer);

        return (w1 - w2);
    },

    setPopupPos: function (element, location) {
        winSize = this.windowSize();

        // Determine whether the popup will fit on the page sanely at the specified location
        if(location.left + element.getSize().x > winSize.width) {
            location.left = winSize.width - element.getSize().x - 1;

            // Make sure left can't go negative, even if it forces overflow.
            if(location.left < 0) location.left = 0;
        }

        element.setStyles(location);
    }

});


function isString() {
    if (typeof arguments[0] == 'string') return true;

    if (typeof arguments[0] == 'object') {  
        var criterion = arguments[0].constructor.toString().match(/string/i); 
        return (criterion != null);  
    }

    return false;
}


function buildpopup(element, hDel, sDel, xOff, yOff, hEl, sys) 
{
    // Get the child inner
    var coreElem = element.getElement('span.twpopup-inner');
    if(!coreElem) return;

    // Get the element title and parse if it needed...
    var title = coreElem.getProperty('title');
    if(title) {
        // nuke the title to prevent stray popups
        element.removeProperty('title');

        var settings = new Array();
        var pairs = title.split(/\;/);
        for (var i in pairs) {
            if(isString(pairs[i])) {
                var nameVal = pairs[i].split(/\=/);
                settings[nameVal[0]] = nameVal[1];
            }
        }
        
        xOff = settings['xoff'] ? parseInt(settings['xoff']) : xOff;
        yOff = settings['yoff'] ? parseInt(settings['yoff']) : yOff;
        hDel = settings['hide'] ? parseInt(settings['hide']) : hDel;
        sDel = settings['show'] ? parseInt(settings['show']) : sDel;
    }

    new Popup(element, 
              { coreElem: coreElem,
                hideDelay: hDel,
                showDelay: sDel,
                offset: {'x': xOff, 'y': yOff},
                haltElem: hEl,
                system: sys, 
              });
}

// When the DOM is ready, we need to fix up the popups.
window.addEvent('domready', function() { 
    // Go through each popup span in the document replacing it with a popup.
    $$('span.twpopup').each(function(element,index) {
        buildpopup(element, 2000, 500, 16, 0, document.getElementById('content'), 0);
    });

    $$('span.twpopup-sys').each(function(element,index) {
        buildpopup(element, 2000, 500, 16, 0, document.getElementById('content'), 1);
    });
});
