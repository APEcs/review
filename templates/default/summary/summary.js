var editbox;

window.addEvent('domready', function() {
    var accordion = new Fx.Accordion($$('.acc-title'),$$('.acc-content'), {
            onActive: function(toggler) { toggler.setStyles({'background-color': '#d4d4ff',
                                                             'background-image': 'url(templates/default/images/open.png)'}); },
        onBackground: function(toggler) { toggler.setStyles({'background-color': '#f7f7ff',
                                                             'background-image': 'url(templates/default/images/closed.png)'}); },

    });

    editbox = new LightFace({title: 'Edit Reflective Summary',
                             draggable: true,
                             buttons: [
                                      { title: 'Save', event: function() { $('summaryform***id***').submit(); }, color: 'blue' },
                                      { title: 'Cancel', event: function() { this.close(); } }
                                      ],
                             content: '<p class="left">Enter your reflective summary here. Note that newlines will be preserved, but any HTML formatting will be stripped.</p><form id="summaryform***id***" action="index.cgi" method="post"><input type="hidden" name="block" value="summary" /><input type="hidden" name="sortid" value="***id***" /><textarea id="summarytext***id***" name="summarytext***id***" rows="10" cols="76"></textarea></form>'
    });

    $('summarytext***id***').value = $('summarydata***id***').innerHTML;
});
