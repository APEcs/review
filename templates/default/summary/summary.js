window.addEvent('domready', function() {
    var accordion = new Fx.Accordion($$('.acc-title'),$$('.acc-content'), {
            onActive: function(toggler) { toggler.setStyles({'background-color': '#d4d4ff',
                                                             'background-image': 'url(templates/default/images/open.png)'}); },
        onBackground: function(toggler) { toggler.setStyles({'background-color': '#f7f7ff',
                                                             'background-image': 'url(templates/default/images/closed.png)'}); },

    });
});
