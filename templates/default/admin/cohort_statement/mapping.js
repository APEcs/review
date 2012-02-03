var mode    = "disabled";
var moveReq;

/** Display an error message in the page error box. This will set the error box
 *  text to the message provided, and then show the error box for 3 second.
 * 
 * @param message The message to show in the error box.
 */
function showErrorMessage(message) {
    $('errormsg').set('text', message);
    $('errorbox').reveal();
    setTimeout(function() { $('errorbox').dissolve() }, 3000);
}


function moveStatement(fromList, toList, mode) {
    // selectedIndex only gives the first selection... but it's a quick way to
    // tell that there *are* any selections...
    var sel = fromList.selectedIndex;

    if(sel != -1 && mode != "disabled") {

        // Need to get the cohort id too...
        if($('cohorts').selectedIndex != -1) {
            var cid = $('cohorts').options[$('cohorts').selectedIndex].value;

            if(cid) {
                sel = 0;
                var idlist = mode; // Stick the mode at the start of the id list 
                while(sel < fromList.options.length) {
                    if(fromList.options[sel].selected) {
                        // Record the id of the statement to move
                        idlist += "&sid="+fromList.options[sel].value;
                        
                        // Move the item, do not increment pos as the current item will
                        // be removed, dropping down the next.
                        exchangeOption(fromList, sel, toList);
                    } else {
                        ++sel;
                    }
                }

                // do AJAX to move the item...
                moveReq.send("block=cstateapi&id="+cid+"&"+idlist);
            }
        }
    }
}


/** Set the contents of the set and available statement lists. This takes the data
 *  in the specified response XML tree and uses it to fill in the contents of the
 *  set and available statement lists, and enable or disable the controls to move
 *  statements between the lists.
 * 
 * @param responseXML The XML tree received from the server 
 */
function setStatementLists(responseXML) {
    
    // Get the cstatedata node
    var data = responseXML.getElementsByTagName('cstatedata')[0];
    if(data) {
        mode = data.getAttribute('modify');

        // Set disabled states as needed
        $('availstates').disabled = (mode == "disabled");
        $('setstate').src = "templates/default/admin/images/setstatement"+(mode == "disabled" ? "-off" : "")+".png";
        $('delstate').src = "templates/default/admin/images/delstatement"+(mode == "disabled" ? "-off" : "")+".png";

        var setstates   = responseXML.getElementsByTagName('setstates')[0];
        if(setstates) setOptions($('setstates'), setstates.getElementsByTagName('option'));

        var availstates = responseXML.getElementsByTagName('availstates')[0];
        if(availstates) setOptions($('availstates'), availstates.getElementsByTagName('option'));

        if(mode != "disabled") {
            $('setstate').addEvent('click', function() { moveStatement($('availstates'), $('setstates'), "add"); });
            $('delstate').addEvent('click', function() { moveStatement($('setstates'), $('availstates'), "remove"); });
        }
        conditionalClass($('setstate'), "pointer", mode != "disabled");
        conditionalClass($('delstate'), "pointer", mode != "disabled");
    } else {
        // No cstatedata, is it an error?
        data = responseXML.getElementsByTagName('error')[0];
        if(data) {
            showErrorMessage(data.textContent);
        } else {
            showErrorMessage("Malformed XML response from server. Unable to update statement lists.");   
        }
    }
}


/** Update the statement lists in response to changes in selection in the cohort list.
 *  This clears the statement lists, and triggers an AJAX request to fetch the 
 *  list data for the new selection. 
 */ 
function updateStatementLists() {
    // clear the current list contents    
    $('setstates').options.length = 0;
    $('availstates').options.length = 0;

    // Remove click events from the control buttons
    $('setstate').removeEvents('click');
    $('delstate').removeEvents('click');

    // get the selected cohort
    if($('cohorts').selectedIndex != -1) {
        var cid = $('cohorts').options[$('cohorts').selectedIndex].value;

        if(cid) {
            $('statusbox').set('text', 'Loading statements...');
            $('statusbox').reveal();

            var statementReq = new Request({
                url: 'index.cgi',
                method: 'get',
                onSuccess: function(responseText, responseXML){
                    setStatementLists(responseXML);
                    $('statusbox').dissolve();
                },  
                onFailure: function(){
                    $('statusbox').dissolve();
                    showErrorMessage('Unable to process AJAX request.');
                }
            });

            statementReq.send("block=cstateapi&statements&id="+cid);
        }
    }
}


window.addEvent('domready', function() {
    $('errorbox').hide();
    $('cohorts').addEvent('change', function() { updateStatementLists(); });

    updateStatementLists();

    moveReq = new Request({
        url: 'index.cgi',
        method: 'get',
        onSuccess: function(responseText, responseXML){
            //checkMoveItems();
            $('statusbox').dissolve();
        },
        onFailure: function(){
            $('statusbox').dissolve();
            showErrorMessage('Unable to process AJAX request.');
        }
    });

});