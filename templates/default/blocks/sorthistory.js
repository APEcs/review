
function controlCompare()
{
    var selCount = 0;

    $$('input.compare').each(function(element, index) {
        if(element.checked) ++selCount;
    });

    if($('compare')) $('compare').disabled = (selCount < 2);
}

window.addEvent('domready', function() {
    $$('input.compare').each(function(element, index) {
        element.addEvent('click', function() { controlCompare() });
    });

    controlCompare();
});

