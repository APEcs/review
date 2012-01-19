var editbox;

window.addEvent('domready', function() {
    var accordion = new Fx.Accordion($$('.acc-title'),$$('.acc-content'), {
            onActive: function(toggler) { toggler.setStyles({'background-color': '#d4d4ff',
                                                             'background-image': 'url(templates/default/images/open.png)'}); },
        onBackground: function(toggler) { toggler.setStyles({'background-color': '#f7f7ff',
                                                             'background-image': 'url(templates/default/images/closed.png)'}); },

    });

    editbox = new LightFace({title: '{L_SUMMARYLIST_EDITTITLE}',
                             draggable: true,
                             buttons: [
                                      { title: '{L_SUMMARYLIST_EDIT}', event: function() { $('summaryform***id***').submit(); }, color: 'blue' },
                                      { title: '{L_SUMMARYLIST_CLOSE}', event: function() { this.close(); } }
                                      ],
                             content: '<p class="left">{L_SUMMARYLIST_EDITTEXT}</p><form id="summaryform***id***" action="index.cgi" method="post"><input type="hidden" name="block" value="summary" /><input type="hidden" name="sortid" value="***id***" /><textarea id="summarytext***id***" name="summarytext***id***" rows="10" cols="76"></textarea></form>'
    });

    $('summarytext***id***').value = $('summarydata***id***').innerHTML;
});
