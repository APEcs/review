
function persistWarning() {
    var persist = $('persist').checked;

    if(persist) {
        $('persistwarn').reveal();
    } else {
        $('persistwarn').dissolve();
    }
}

