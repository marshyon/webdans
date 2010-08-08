
function get_ajax_status() {
    $('#status').load('http://10.11.11.50:3000/send?action=status');
}

$(document).ready(function() {

// set up ajax defaults

$.ajaxSetup({
    type: 'POST',
    url: 'http://10.11.11.50:3000/send',
    timeout: 3000,
});

// timer loop to get status of server


var clearInterval = setInterval( "this.get_ajax_status()" , 3000);
get_ajax_status();
//clearInterval(animationTimer);



// set up ajax error reporting

$("#msg").ajaxError(function(event, request, settings) {
    $(this).html("Error requesting page " + settings.url + "!");
});


// bind a delegated event handler to all 'input' elements in 
// the tablesorter class

$('.tablesorter').bind('click', function(evt) {
var input = $(evt.target).closest('input');
var input_content = input[0];

// ignore all events other than those with content
if(input_content) { 
    var evt_id = '#' + evt.target.id;
    //console.log('got input !!!', input_content, typeof evt_id, evt_id); 
    //console.log(evt_id);
    var evt_id_val;
    var evt_id_check = 0;
 	var urlstr = evt_id.split(/-/g)
    var mynew_url = urlstr[1];
                    if( $(evt_id).is(':checked') ) {
                        evt_id_val = 'CHECKED';
		        $("#my_url").text(mynew_url);
		        $("#ok-dialog-message").dialog({
			        modal: true,
                                close: function() { 
                                    //console.log('checked CLOSE [', evt_id_check, ']');
                                    if(evt_id_check) {
                                        $(evt_id).attr('checked', true);
                                        $.ajax({ 
                                            data: { id: evt_id, name: mynew_url, action: 'add' } 
                                        }); 
                                    }
                                    else {
                                        $(evt_id).attr('checked', false);
                                    }
                                },
			        buttons: {

				        Ok: function() {
                                                //console.log('ok clicked');
                                                evt_id_check = 1;
					        $(this).dialog('close');
				        }

			        }
		        });
                    }
                    else {
                        evt_id_val = 'nada';
		        $("#my_url").text(mynew_url);

		        $("#dialog-message").dialog({
			        modal: true,
                                close: function() { 
                                    //console.log('UNchecked CLOSE [', evt_id_check, ']');
                                    if(evt_id_check) {
                                        $(evt_id).attr('checked', false);
                                        $.ajax({ 
                                            data: { id: evt_id, name: mynew_url, action: 'remove' } 
                                        }); 
                                    }
                                    else {
                                        $(evt_id).attr('checked', true);
                                    }
                                },
			        buttons: {
				        Ok: function() {
                                                //console.log('ok clicked');
                                                evt_id_check = 1;
					        $(this).dialog('close');
				        }
			        }
		        });
                    }

                    //console.log('evt_id_val : ', evt_id_val);
}
                });
});

