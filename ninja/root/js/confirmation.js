var hashUriMods = new Object();

$(document).ready(function() {

    get_ajax_status();

    // timer loop to get status of server
    var clearInterval = setInterval("get_ajax_status()", 60000);
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
        if (input_content) {
            var evt_id = '#' + evt.target.id;

            var evt_id_val;
            var evt_id_check = 0;
            var urlstr = evt_id.split(/-/g)
            var mynew_url = urlstr[1];
            if ($(evt_id).is(':checked')) {
                evt_id_val = 'CHECKED';
                $("#my_url").text(mynew_url);
                $("#ok-dialog-message").dialog({
                    modal: true,
                    close: function() {
                      
                        if (evt_id_check) {
                            $(evt_id).attr('checked', true);
                            $.ajax({
                                data: {
                                    id: evt_id,
                                    name: mynew_url,
                                    action: 'add'
                                }
                            });
                            
                            update_additions_in_page(evt_id, 'add');
                        }
                        else {
                            $(evt_id).attr('checked', false);
                        }
                    },
                    buttons: {

                        Ok: function() {
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
                        if (evt_id_check) {
                            $(evt_id).attr('checked', false);
                            $.ajax({
                                data: {
                                    id: evt_id,
                                    name: mynew_url,
                                    action: 'remove'
                                }
                            });
                            update_additions_in_page(evt_id, 'delete');
                     
                        }
                        else {
                            $(evt_id).attr('checked', true);
                        }
                    },
                    buttons: {
                        Ok: function() {
                            evt_id_check = 1;
                            $(this).dialog('close');
                        }
                    }
                });
            }
        }
    });
});

function update_additions_in_page(evt_id, action) {

    var classRegExpId = /#checkbx_\d+-(.+)/;
    var classResultId;

    if (classResultId = classRegExpId.exec(evt_id)) {
        var id_to_match = classResultId[1];
        hashUriMods[id_to_match] = action;


        update_table_checkboxes();
        //var classRegExpCheckbox = /(<input.+?id="(checkbx_\d+-(.+?))".+?checkbox.+>)/;
        //var classResultCheckbox;
        //var classRegExpChecked = /checked="yes"/;

        //$('.tablesorter td').each(function() {

        //    var node = $(this);
        //    var html = node.html();

        //    if (classResultCheckbox = classRegExpCheckbox.exec(html)) {

        //        var id_str = '#' + classResultCheckbox[2];
        //        if( hashUriMods[classResultCheckbox[3]] == 'add' ) {
        //            $(id_str).attr('checked', true);
        //        }
        //        else {
        //            $(id_str).attr('checked', false);
        //        }
        //    }
        //});
    }
}


function update_table_checkboxes() {

        var classRegExpCheckbox = /(<input.+?id="(checkbx_\d+-(.+?))".+?checkbox.+>)/;
        var classResultCheckbox;
        var classRegExpChecked = /checked="yes"/;

        $('.tablesorter td').each(function() {

            var node = $(this);
            var html = node.html();

            if (classResultCheckbox = classRegExpCheckbox.exec(html)) {

                var id_str = '#' + classResultCheckbox[2];
                if( hashUriMods[classResultCheckbox[3]] == 'add' ) {
                    $(id_str).attr('checked', true);
                }
                else {
                    $(id_str).attr('checked', false);
                }
            }
        });
}
