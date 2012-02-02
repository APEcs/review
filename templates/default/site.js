
function persistWarning() {
    var persist = $('persist').checked;

    if(persist) {
        $('persistwarn').reveal();
    } else {
        $('persistwarn').dissolve();
    }
}

/** Set the contents of a select box to the options in the specified XML
 *  node list. This takes a select element, and a list of XML nodes, and
 *  adds the nodes to the select box using the textContent of each node as
 *  the text of the options, and the value attribute of each node for the
 *  option values.
 * 
 * @param elem    The select element to add the options to.
 * @param options An array of XML nodes containing the option data.  
 */
function setOptions(elem, options) {
    
    // Do nothing if there are no options specified.
    if(options) {
        for(var opt = 0; opt < options.length; ++opt) {
            // new html element for the option...
            var newOpt = new Element('option');
            newOpt.text  = options[opt].textContent;
            newOpt.value = options[opt].getAttribute('value');

            // And shove it onto the end of the select options.
            elem.add(newOpt, null);
        }
    }
}

/** Conditionally add a CSS class to an element. If setClass is true, and the
 *  element does not have the specified conditional class, this will add the 
 *  class to the element (otherwise it does nothing). If setClass is false, this
 *  will remove the conditional class from the element if it has it set, otherwise
 *  it will do nothing.
 * 
 *  @param element   The element to add or remove the class from.
 *  @param condClass The name of the css class to add or remove.
 *  @param setClass  If true, the css class is added to the element, otherwise it
 *                   is removed.
 */
function conditionalClass(element, condClass, setClass) {

    if(setClass && !element.hasClass(condClass)) element.addClass(condClass);
    if(!setClass && element.hasClass(condClass)) element.removeClass(condClass);

}
