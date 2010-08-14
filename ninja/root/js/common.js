// hide ok dialogues 




$(document).ready(function() {

            $("#ok-dialog-message").hide();
            $("#dialog-message").hide();
            $('#disclaimer').hide();

            var numberOfRows = $('.tablesorter tr').length;

            $(function() {
                $("table")
                        .tablesorter({widthFixed: true, widgets: ['zebra']})
                        .tablesorterPager({container: $("#pager")}) 
            });

            var height = $('.tablesorter').height() + 70;
            $('#mainContent').height(height);

            $('.pagesize').click(function() {
                var height = $('.tablesorter').height() + 70;
                $('#mainContent').height(height);
            });

            $('#toggleButton').click(function() {
                $('#disclaimer').slideToggle('slow');
                var txt = $('#toggleButton').val();
                if(txt == 'help') {
                    $('#toggleButton').val('hide');
                }
                else {
                    $('#toggleButton').val('help');
                }
            });
});


