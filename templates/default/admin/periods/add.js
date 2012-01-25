function checkDate(element, timestamp)
{
    var idstr = '';

    if($('id')) {
        idstr = '&amp;id=' + $('id').value;
    }

    element.load('index.cgi?block=periodcheck&time='+timestamp+idstr);    
}

window.addEvent('domready', function() {
    Locale.use('en-GB')
    new Picker.Date($('year'), { 
                        pickOnly: 'years',
                        format: '%Y',
                        positionOffset: {x: 5, y: 0}, 
                        pickerClass: 'datepicker_dashboard', 
                        useFadeInOut: !Browser.ie,
    });

    new Picker.Date($('start_pick'), { 
                        timePicker: true, 
                        yearPicker: true, 
                        positionOffset: {x: 5, y: 0}, 
                        pickerClass: 'datepicker_dashboard', 
                        useFadeInOut: !Browser.ie,
                        onSelect: function(date){ 
                            $('startdate').set('value', date.format('%s'));
                            checkDate($('startvalid'), date.format('%s'));
                        }   
    });

    new Picker.Date($('end_pick'), { 
                        timePicker: true, 
                        yearPicker: true, 
                        positionOffset: {x: 5, y: 0}, 
                        pickerClass: 'datepicker_dashboard', 
                        useFadeInOut: !Browser.ie,
                        onSelect: function(date){ 
                            $('enddate').set('value', date.format('%s')); 
                            checkDate($('endvalid'), date.format('%s'));
                        }   
    });
});